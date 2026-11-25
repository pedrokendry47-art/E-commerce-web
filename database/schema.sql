-- ============================================================
-- E-Commerce Platform: schema.sql  (run first, in Supabase SQL editor)
-- Amounts are NGN, numeric(12,2). All PKs are UUIDs.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Enums ----------
create type user_role       as enum ('customer', 'admin');
create type discount_type   as enum ('percentage', 'fixed');
create type order_status    as enum ('placed','payment_confirmed','processing','shipped','out_for_delivery','delivered','cancelled');
create type payment_status  as enum ('pending','success','failed','abandoned');

-- ---------- Helpers ----------
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ---------- profiles (1:1 with auth.users) ----------
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  phone       text,
  avatar_url  text,
  role        user_role not null default 'customer',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger trg_profiles_updated before update on profiles
  for each row execute function set_updated_at();

-- Auto-create a profile on signup (role is ALWAYS customer here)
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, phone)
  values (new.id,
          new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'phone');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Admin check used by RLS (security definer avoids policy recursion)
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function current_user_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

-- ---------- categories ----------
create table categories (
  id          uuid primary key default gen_random_uuid(),
  parent_id   uuid references categories(id) on delete set null,
  name        text not null,
  slug        text not null unique,
  description text,
  image_url   text,
  created_at  timestamptz not null default now()
);

-- ---------- products ----------
create table products (
  id             uuid primary key default gen_random_uuid(),
  category_id    uuid references categories(id) on delete set null,
  name           text not null,
  slug           text not null unique,
  description    text,
  price          numeric(12,2) not null check (price >= 0),
  discount_price numeric(12,2) check (discount_price is null or (discount_price >= 0 and discount_price < price)),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  is_active      boolean not null default true,
  is_featured    boolean not null default false,
  rating_avg     numeric(3,2) not null default 0,
  rating_count   integer not null default 0,
  sold_count     integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index idx_products_category   on products(category_id);
create index idx_products_active_new on products(is_active, created_at desc);
create index idx_products_popularity on products(sold_count desc);
create index idx_products_price      on products(price);
create index idx_products_name_trgm  on products using gin (to_tsvector('english', name));
create trigger trg_products_updated before update on products
  for each row execute function set_updated_at();

-- ---------- product_images ----------
create table product_images (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  url        text not null,
  alt_text   text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_product_images_product on product_images(product_id, sort_order);

-- ---------- product_variants ----------
create table product_variants (
  id             uuid primary key default gen_random_uuid(),
  product_id     uuid not null references products(id) on delete cascade,
  size           text,
  color          text,
  sku            text unique,
  price_override numeric(12,2) check (price_override is null or price_override >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  created_at     timestamptz not null default now()
);
create index idx_variants_product on product_variants(product_id);

-- ---------- addresses ----------
create table addresses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  label        text,
  full_name    text not null,
  phone        text not null,
  address_line text not null,
  city         text not null,
  state        text not null,
  postal_code  text,
  is_default   boolean not null default false,
  created_at   timestamptz not null default now()
);
create index idx_addresses_user on addresses(user_id);
create unique index uq_addresses_one_default on addresses(user_id) where is_default;

-- ---------- coupons ----------
create table coupons (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,
  discount_type    discount_type not null,
  discount_value   numeric(12,2) not null check (discount_value > 0),
  min_order_amount numeric(12,2) not null default 0,
  max_uses         integer check (max_uses is null or max_uses > 0),
  used_count       integer not null default 0,
  expires_at       timestamptz,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  check (discount_type <> 'percentage' or discount_value <= 100)
);

-- ---------- carts ----------
create table carts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_carts_updated before update on carts
  for each row execute function set_updated_at();

create table cart_items (
  id         uuid primary key default gen_random_uuid(),
  cart_id    uuid not null references carts(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  variant_id uuid references product_variants(id) on delete cascade,
  quantity   integer not null check (quantity > 0),
  created_at timestamptz not null default now()
);
create unique index uq_cart_item on cart_items(cart_id, product_id, coalesce(variant_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- ---------- orders ----------
create sequence order_ref_seq start 1000;
create or replace function generate_order_reference() returns text
language sql as $$
  select 'ORD-' || to_char(now(), 'YYMMDD') || '-' || nextval('order_ref_seq');
$$;

create table orders (
  id                 uuid primary key default gen_random_uuid(),
  reference          text not null unique default generate_order_reference(),
  user_id            uuid not null references profiles(id) on delete restrict,
  status             order_status not null default 'placed',
  subtotal           numeric(12,2) not null check (subtotal >= 0),
  shipping_fee       numeric(12,2) not null default 0 check (shipping_fee >= 0),
  discount_amount    numeric(12,2) not null default 0 check (discount_amount >= 0),
  total              numeric(12,2) not null check (total >= 0),
  coupon_id          uuid references coupons(id) on delete set null,
  customer_name      text not null,
  customer_email     text not null,
  customer_phone     text not null,
  shipping_address   text not null,
  shipping_city      text not null,
  shipping_state     text not null,
  shipping_postal    text,
  delivery_notes     text,
  estimated_delivery date,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index idx_orders_user    on orders(user_id, created_at desc);
create index idx_orders_status  on orders(status);
create trigger trg_orders_updated before update on orders
  for each row execute function set_updated_at();

create table order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  product_id   uuid references products(id) on delete set null,
  variant_id   uuid references product_variants(id) on delete set null,
  product_name text not null,          -- snapshot at purchase time
  variant_label text,
  image_url    text,
  unit_price   numeric(12,2) not null check (unit_price >= 0),
  quantity     integer not null check (quantity > 0)
);
create index idx_order_items_order on order_items(order_id);

-- ---------- payments ----------
create table payments (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  reference    text not null unique,   -- Paystack reference
  provider     text not null default 'paystack',
  amount       numeric(12,2) not null check (amount >= 0),
  currency     text not null default 'NGN',
  status       payment_status not null default 'pending',
  paid_at      timestamptz,
  raw_response jsonb,
  created_at   timestamptz not null default now()
);
create index idx_payments_order on payments(order_id);
-- Duplicate-payment protection: an order can have only ONE successful payment
create unique index uq_one_success_payment_per_order on payments(order_id) where status = 'success';

-- ---------- order_status_history ----------
create table order_status_history (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null references orders(id) on delete cascade,
  status     order_status not null,
  note       text,
  changed_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index idx_status_history_order on order_status_history(order_id, created_at);

-- Log every status change automatically (drives the tracker + notifications)
create or replace function log_order_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into order_status_history(order_id, status, changed_by)
    values (new.id, new.status, auth.uid());
  end if;
  return new;
end $$;
create trigger trg_orders_status_log after insert or update of status on orders
  for each row execute function log_order_status();

-- ---------- reviews ----------
create table reviews (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  user_id    uuid not null references profiles(id) on delete cascade,
  rating     smallint not null check (rating between 1 and 5),
  comment    text,
  created_at timestamptz not null default now(),
  unique (product_id, user_id)
);
create index idx_reviews_product on reviews(product_id);

-- Keep products.rating_avg / rating_count in sync
create or replace function refresh_product_rating() returns trigger
language plpgsql security definer set search_path = public as $$
declare pid uuid := coalesce(new.product_id, old.product_id);
begin
  update products p set
    rating_avg   = coalesce((select round(avg(rating)::numeric, 2) from reviews where product_id = pid), 0),
    rating_count = (select count(*) from reviews where product_id = pid)
  where p.id = pid;
  return null;
end $$;
create trigger trg_reviews_rating after insert or update or delete on reviews
  for each row execute function refresh_product_rating();

-- ---------- wishlists ----------
create table wishlists (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);
create index idx_wishlists_user on wishlists(user_id);
