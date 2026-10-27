-- Base inicial del administrador Dos con Hilo.
-- Aplicar únicamente en un proyecto Supabase dedicado o con respaldo.
create extension if not exists pgcrypto;

create type public.business_role as enum ('owner', 'admin', 'staff');
create type public.inventory_movement_type as enum ('entry', 'sale', 'adjustment', 'cancellation');
create type public.sale_status as enum ('completed', 'cancelled');
create type public.sales_channel as enum ('in_person', 'whatsapp', 'social');
create type public.payment_method as enum ('cash', 'transfer', 'card', 'other');
create type public.custom_order_status as enum ('pending', 'in_progress', 'ready', 'delivered', 'cancelled');

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.business_role not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text not null default '',
  category text not null default '',
  price numeric(12,2) not null check (price >= 0),
  quantity_available integer not null default 0 check (quantity_available >= 0),
  photo_path text,
  is_published boolean not null default false,
  low_stock_threshold integer not null default 3 check (low_stock_threshold >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  channel public.sales_channel not null,
  status public.sale_status not null default 'completed',
  payment_method public.payment_method not null,
  total_amount numeric(12,2) not null check (total_amount >= 0),
  idempotency_key uuid not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (business_id, idempotency_key)
);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete restrict,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) generated always as (quantity * unit_price) stored
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  movement_type public.inventory_movement_type not null,
  quantity_delta integer not null check (quantity_delta <> 0),
  reason text not null,
  sale_id uuid references public.sales(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.custom_orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_name text not null,
  description text not null,
  agreed_price numeric(12,2) not null check (agreed_price >= 0),
  deposit_amount numeric(12,2) not null default 0 check (deposit_amount >= 0 and deposit_amount <= agreed_price),
  due_date date,
  status public.custom_order_status not null default 'pending',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.order_payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  order_id uuid not null references public.custom_orders(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  payment_method public.payment_method not null,
  received_at timestamptz not null default now(),
  received_by uuid references auth.users(id) on delete set null
);

create index products_business_idx on public.products (business_id, name);
create index sales_business_created_idx on public.sales (business_id, created_at desc);
create index orders_business_status_idx on public.custom_orders (business_id, status);
create index movements_product_created_idx on public.inventory_movements (product_id, created_at desc);

create function public.is_business_member(target_business uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.business_members m
  where m.business_id = target_business and m.user_id = (select auth.uid())
) $$;

create function public.has_business_role(target_business uuid, allowed_roles public.business_role[])
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (
  select 1 from public.business_members m
  where m.business_id = target_business and m.user_id = (select auth.uid()) and m.role = any(allowed_roles)
) $$;

alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.products enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.custom_orders enable row level security;
alter table public.order_payments enable row level security;

create policy "Members read own business" on public.businesses for select to authenticated using (public.is_business_member(id));
create policy "Members read membership" on public.business_members for select to authenticated using (public.is_business_member(business_id));
create policy "Managers update products" on public.products for all to authenticated
  using (public.has_business_role(business_id, array['owner','admin']::public.business_role[]))
  with check (public.has_business_role(business_id, array['owner','admin']::public.business_role[]));
create policy "Members read products" on public.products for select to authenticated using (public.is_business_member(business_id));
create policy "Members read inventory" on public.inventory_movements for select to authenticated using (public.is_business_member(business_id));
create policy "Members read sales" on public.sales for select to authenticated using (public.is_business_member(business_id));
create policy "Members read sale items" on public.sale_items for select to authenticated using (public.is_business_member(business_id));
create policy "Members read orders" on public.custom_orders for select to authenticated using (public.is_business_member(business_id));
create policy "Members read order payments" on public.order_payments for select to authenticated using (public.is_business_member(business_id));

-- Público: solo catálogo publicado y columnas públicas. No conceder SELECT en products.
create view public.published_catalog
with (security_invoker = false) as
select id, business_id, name, description, category, price, quantity_available, photo_path, updated_at
from public.products
where is_published = true;
grant select on public.published_catalog to anon, authenticated;

-- La creación de ventas y sus movimientos queda cerrada a escrituras directas.
-- La función transaccional de confirmación se implementará en la siguiente etapa.
revoke insert, update, delete on public.sales, public.sale_items, public.inventory_movements from anon, authenticated;
revoke insert, update, delete on public.custom_orders, public.order_payments from anon, authenticated;
