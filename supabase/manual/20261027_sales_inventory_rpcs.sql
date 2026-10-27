-- Operaciones transaccionales para ventas e inventario sobre el esquema actual.
-- Aplicar manualmente después de revisar. No recrea las tablas existentes.
alter table public.sales add column if not exists idempotency_key uuid;
alter table public.inventory_movements add column if not exists request_id uuid;
create unique index if not exists sales_business_idempotency_uidx
  on public.sales (business_id, idempotency_key)
  where idempotency_key is not null;
create unique index if not exists inventory_movements_request_uidx
  on public.inventory_movements (request_id)
  where request_id is not null;

create or replace function public.adjust_inventory(
  p_business_id uuid,
  p_product_id uuid,
  p_quantity_delta integer,
  p_movement_type text,
  p_reason text,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stock integer;
  v_movement_id uuid;
  v_existing public.inventory_movements%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.business_members m
    where m.business_id = p_business_id and m.user_id = (select auth.uid())
  ) then
    raise exception 'Not a member of this business' using errcode = '42501';
  end if;
  if p_quantity_delta is null or p_quantity_delta = 0 then
    raise exception 'Quantity change must be nonzero' using errcode = '22023';
  end if;
  if p_movement_type is null or p_movement_type not in ('RESTOCK', 'ADJUSTMENT') then
    raise exception 'Unsupported inventory movement type' using errcode = '22023';
  end if;
  if p_movement_type = 'RESTOCK' and p_quantity_delta < 0 then
    raise exception 'Restock quantity must be positive' using errcode = '22023';
  end if;
  if p_request_id is null then
    raise exception 'Request id is required' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));
  select m.* into v_existing
  from public.inventory_movements m where m.request_id = p_request_id;
  if found then
    if v_existing.product_id <> p_product_id
       or v_existing.quantity <> p_quantity_delta
       or v_existing.movement_type::text <> p_movement_type then
      raise exception 'Request id was already used for a different movement' using errcode = '22023';
    end if;
    return v_existing.id;
  end if;

  select p.stock into v_stock
  from public.products p
  where p.id = p_product_id and p.business_id = p_business_id
  for update;
  if not found then raise exception 'Product does not belong to this business' using errcode = '22023'; end if;
  if v_stock + p_quantity_delta < 0 then
    raise exception 'Adjustment would make stock negative' using errcode = '22003';
  end if;

  update public.products
  set stock = stock + p_quantity_delta, updated_at = now()
  where id = p_product_id and business_id = p_business_id;
  insert into public.inventory_movements (product_id, quantity, movement_type, reason, request_id)
  values (
    p_product_id,
    p_quantity_delta,
    p_movement_type,
    left(coalesce(nullif(btrim(p_reason), ''), 'Ajuste de inventario') || ' · Usuario ' || (select auth.uid())::text, 500),
    p_request_id
  )
  returning id into v_movement_id;
  return v_movement_id;
end;
$$;

create or replace function public.confirm_sale(
  p_business_id uuid,
  p_idempotency_key uuid,
  p_sale_channel text,
  p_payment_method text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sale_id uuid;
  v_product_id uuid;
  v_item record;
  v_stock integer;
  v_total numeric := 0;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.business_members m
    where m.business_id = p_business_id and m.user_id = (select auth.uid())
  ) then
    raise exception 'Not a member of this business' using errcode = '42501';
  end if;
  if p_idempotency_key is null then
    raise exception 'Idempotency key is required' using errcode = '22023';
  end if;
  if p_sale_channel not in ('PRESENCIAL', 'WHATSAPP', 'REDES_SOCIALES', 'OTRO') then
    raise exception 'Unsupported sale channel' using errcode = '22023';
  end if;
  if p_payment_method not in ('EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO') then
    raise exception 'Unsupported payment method' using errcode = '22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one sale item is required' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_business_id::text || ':' || p_idempotency_key::text, 0)
  );
  select s.id into v_sale_id
  from public.sales s
  where s.business_id = p_business_id and s.idempotency_key = p_idempotency_key;
  if found then return v_sale_id; end if;

  -- Lock all products in stable order to prevent overselling and deadlocks.
  for v_product_id in
    select distinct item.product_id
    from jsonb_to_recordset(p_items) as item(product_id uuid, quantity integer)
    order by item.product_id
  loop
    select p.stock into v_stock
    from public.products p
    where p.id = v_product_id and p.business_id = p_business_id
    for update;
    if not found then
      raise exception 'Product does not belong to this business' using errcode = '22023';
    end if;
  end loop;

  insert into public.sales (business_id, sale_channel, payment_method, total, status, idempotency_key)
  values (p_business_id, p_sale_channel, p_payment_method, 0, 'COMPLETED', p_idempotency_key)
  returning id into v_sale_id;

  for v_item in
    select item.product_id, sum(item.quantity)::integer as quantity, p.price, p.stock
    from jsonb_to_recordset(p_items) as item(product_id uuid, quantity integer)
    join public.products p on p.id = item.product_id and p.business_id = p_business_id
    group by item.product_id, p.price, p.stock
    order by item.product_id
  loop
    if v_item.quantity is null or v_item.quantity <= 0 then
      raise exception 'Item quantity must be positive' using errcode = '22023';
    end if;
    if v_item.stock < v_item.quantity then
      raise exception 'Insufficient stock for product %', v_item.product_id using errcode = '22003';
    end if;

    update public.products
    set stock = stock - v_item.quantity, updated_at = now()
    where id = v_item.product_id and business_id = p_business_id;

    insert into public.sale_items (sale_id, product_id, quantity, unit_price)
    values (v_sale_id, v_item.product_id, v_item.quantity, v_item.price);
    insert into public.inventory_movements (product_id, quantity, movement_type, reason)
    values (v_item.product_id, -v_item.quantity, 'SALE', 'Venta ' || v_sale_id::text);
    v_total := v_total + v_item.price * v_item.quantity;
  end loop;

  update public.sales set total = v_total where id = v_sale_id;
  return v_sale_id;
end;
$$;

create or replace function public.cancel_sale(p_sale_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_status text;
  v_item record;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select s.business_id, s.status into v_business_id, v_status
  from public.sales s where s.id = p_sale_id for update;
  if not found then raise exception 'Sale not found' using errcode = 'P0002'; end if;
  if not exists (
    select 1 from public.business_members m
    where m.business_id = v_business_id and m.user_id = (select auth.uid())
  ) then
    raise exception 'Not a member of this business' using errcode = '42501';
  end if;
  if v_status = 'CANCELLED' then return; end if;

  for v_item in
    select si.product_id, sum(si.quantity)::integer as quantity
    from public.sale_items si
    where si.sale_id = p_sale_id and si.product_id is not null
    group by si.product_id order by si.product_id
  loop
    update public.products
    set stock = stock + v_item.quantity, updated_at = now()
    where id = v_item.product_id and business_id = v_business_id;
    if not found then
      raise exception 'Sale product is missing from its business' using errcode = '22023';
    end if;
    insert into public.inventory_movements (product_id, quantity, movement_type, reason)
    values (v_item.product_id, v_item.quantity, 'ADJUSTMENT', 'Cancelación venta ' || p_sale_id::text);
  end loop;
  update public.sales set status = 'CANCELLED' where id = p_sale_id;
end;
$$;

revoke all on function public.confirm_sale(uuid, uuid, text, text, jsonb) from public, anon;
grant execute on function public.confirm_sale(uuid, uuid, text, text, jsonb) to authenticated;
revoke all on function public.cancel_sale(uuid) from public, anon;
grant execute on function public.cancel_sale(uuid) to authenticated;
revoke all on function public.adjust_inventory(uuid, uuid, integer, text, text, uuid) from public, anon;
grant execute on function public.adjust_inventory(uuid, uuid, integer, text, text, uuid) to authenticated;
