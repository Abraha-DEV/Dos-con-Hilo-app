-- RPC transaccional para registrar abonos de pedidos personalizados.
-- Aplicar después de revisar; requiere que custom_orders y order_payments
-- tengan RLS habilitado. No cambia las tablas existentes.
alter table public.order_payments add column if not exists request_id uuid;
alter table public.custom_orders add column if not exists request_id uuid;
create unique index if not exists order_payments_request_uidx
  on public.order_payments (request_id)
  where request_id is not null;
create unique index if not exists custom_orders_request_uidx
  on public.custom_orders (request_id)
  where request_id is not null;

drop function if exists public.record_order_payment(uuid, numeric, text);
create or replace function public.record_order_payment(
  p_order_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_agreed_price numeric;
  v_deposit numeric;
  v_status text;
  v_paid numeric;
  v_payment_id uuid;
  v_existing public.order_payments%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Payment amount must be positive' using errcode = '22023';
  end if;
  if p_payment_method is null or p_payment_method not in ('EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'OTRO') then
    raise exception 'Unsupported payment method' using errcode = '22023';
  end if;
  if p_request_id is null then
    raise exception 'Request id is required' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));
  select o.business_id, o.agreed_price, o.deposit, o.status
    into v_business_id, v_agreed_price, v_deposit, v_status
  from public.custom_orders o
  where o.id = p_order_id
  for update;
  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.business_members m
    where m.business_id = v_business_id and m.user_id = (select auth.uid())
  ) then
    raise exception 'Not a member of this business' using errcode = '42501';
  end if;
  select p.* into v_existing
  from public.order_payments p where p.request_id = p_request_id;
  if found then
    if v_existing.order_id <> p_order_id
       or v_existing.amount <> p_amount
       or v_existing.payment_method <> p_payment_method then
      raise exception 'Request id was already used for a different payment' using errcode = '22023';
    end if;
    return v_existing.id;
  end if;
  if v_status = 'CANCELLED' then
    raise exception 'Cannot record a payment on a cancelled order' using errcode = '22023';
  end if;

  select coalesce(sum(p.amount), 0)
    into v_paid
  from public.order_payments p
  where p.order_id = p_order_id;

  if v_deposit + v_paid + p_amount > v_agreed_price then
    raise exception 'Payment exceeds remaining balance' using errcode = '22003';
  end if;

  insert into public.order_payments (order_id, amount, payment_method, request_id)
  values (p_order_id, p_amount, p_payment_method, p_request_id)
  returning id into v_payment_id;
  return v_payment_id;
end;
$$;

revoke all on function public.record_order_payment(uuid, numeric, text, uuid) from public, anon;
grant execute on function public.record_order_payment(uuid, numeric, text, uuid) to authenticated;
