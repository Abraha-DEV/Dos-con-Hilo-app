-- Complemento para el esquema EXISTENTE de Dos con Hilo.
-- No ejecuta ni recrea tablas. Revísalo antes de aplicar desde Supabase SQL Editor.
-- Mantiene el acceso público a productos publicados que ya tienes configurado.
-- Reemplaza la política ALL conocida de sales para cerrar escrituras directas.
begin;

alter table public.business_members enable row level security;
alter table public.businesses enable row level security;
alter table public.products enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.custom_orders enable row level security;
alter table public.order_payments enable row level security;

-- Una usuaria solo puede descubrir sus propias membresías. Esta política evita
-- que las políticas por negocio queden bloqueadas por la tabla sin políticas,
-- y evita el ciclo RLS típico de consultar la misma tabla recursivamente.
drop policy if exists "Users read own business memberships" on public.business_members;
create policy "Users read own business memberships"
on public.business_members for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Members read own businesses" on public.businesses;
create policy "Members read own businesses"
on public.businesses for select to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = businesses.id
    and m.user_id = (select auth.uid())
));

drop policy if exists "Members read inventory movements" on public.inventory_movements;
create policy "Members read inventory movements"
on public.inventory_movements for select to authenticated
using (exists (
  select 1
  from public.products p
  join public.business_members m on m.business_id = p.business_id
  where p.id = inventory_movements.product_id
    and m.user_id = (select auth.uid())
));

drop policy if exists "Members read sale items" on public.sale_items;
create policy "Members read sale items"
on public.sale_items for select to authenticated
using (exists (
  select 1 from public.sales s
  where s.id = sale_items.sale_id
));

drop policy if exists "Members read order payments" on public.order_payments;
create policy "Members read order payments"
on public.order_payments for select to authenticated
using (exists (
  select 1 from public.custom_orders o
  where o.id = order_payments.order_id
));

-- La política existente "Business members access sales" es ALL para public.
-- Ventas deben escribirse atómicamente por una RPC; hasta implementarla,
-- mantener SELECT para miembros y denegar INSERT/UPDATE/DELETE directos.
drop policy if exists "Business members access sales" on public.sales;
drop policy if exists "Members read sales" on public.sales;
create policy "Members read sales"
on public.sales for select to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = sales.business_id
    and m.user_id = (select auth.uid())
));

commit;
