-- ============================================================
-- policies.sql  (run after schema.sql)
-- Model: the Express API uses the service-role key for privileged writes
-- (creating orders, recording payments, decrementing stock). Customers get
-- read access to their own data plus limited direct writes.
-- ============================================================

alter table profiles              enable row level security;
alter table categories            enable row level security;
alter table products              enable row level security;
alter table product_images        enable row level security;
alter table product_variants      enable row level security;
alter table addresses             enable row level security;
alter table coupons               enable row level security;
alter table carts                 enable row level security;
alter table cart_items            enable row level security;
alter table orders                enable row level security;
alter table order_items           enable row level security;
alter table payments              enable row level security;
alter table order_status_history  enable row level security;
alter table reviews               enable row level security;
alter table wishlists             enable row level security;

-- ---------- profiles ----------
create policy "profiles: read own or admin" on profiles for select
  using (id = auth.uid() or is_admin());
-- Users may edit their own profile but can never change their own role
create policy "profiles: update own" on profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = current_user_role());
create policy "profiles: admin update" on profiles for update
  using (is_admin()) with check (is_admin());

-- ---------- catalog (public read, admin write) ----------
create policy "categories: public read" on categories for select using (true);
create policy "categories: admin write" on categories for all
  using (is_admin()) with check (is_admin());

create policy "products: public read active" on products for select
  using (is_active or is_admin());
create policy "products: admin write" on products for all
  using (is_admin()) with check (is_admin());

create policy "product_images: public read" on product_images for select using (true);
create policy "product_images: admin write" on product_images for all
  using (is_admin()) with check (is_admin());

create policy "variants: public read" on product_variants for select using (true);
create policy "variants: admin write" on product_variants for all
  using (is_admin()) with check (is_admin());

-- ---------- addresses (own only) ----------
create policy "addresses: own" on addresses for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "addresses: admin read" on addresses for select using (is_admin());

-- ---------- coupons (admin only; API validates codes server-side) ----------
create policy "coupons: admin all" on coupons for all
  using (is_admin()) with check (is_admin());

-- ---------- carts ----------
create policy "carts: own" on carts for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "cart_items: own" on cart_items for all
  using (exists (select 1 from carts c where c.id = cart_id and c.user_id = auth.uid()))
  with check (exists (select 1 from carts c where c.id = cart_id and c.user_id = auth.uid()));

-- ---------- orders (customers read-only; writes via service role/admin) ----------
create policy "orders: read own or admin" on orders for select
  using (user_id = auth.uid() or is_admin());
create policy "orders: admin update" on orders for update
  using (is_admin()) with check (is_admin());

create policy "order_items: read own or admin" on order_items for select
  using (is_admin() or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid()));

create policy "payments: read own or admin" on payments for select
  using (is_admin() or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid()));

create policy "status_history: read own or admin" on order_status_history for select
  using (is_admin() or exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid()));

-- ---------- reviews ----------
create policy "reviews: public read" on reviews for select using (true);
create policy "reviews: insert own" on reviews for insert with check (user_id = auth.uid());
create policy "reviews: update own" on reviews for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reviews: delete own or admin" on reviews for delete
  using (user_id = auth.uid() or is_admin());

-- ---------- wishlists ----------
create policy "wishlists: own" on wishlists for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- Storage: public product images bucket ----------
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

create policy "product-images: public read" on storage.objects for select
  using (bucket_id = 'product-images');
create policy "product-images: admin insert" on storage.objects for insert
  with check (bucket_id = 'product-images' and is_admin());
create policy "product-images: admin update" on storage.objects for update
  using (bucket_id = 'product-images' and is_admin());
create policy "product-images: admin delete" on storage.objects for delete
  using (bucket_id = 'product-images' and is_admin());

-- ---------- Make yourself the first admin (run manually after signing up) ----------
-- update profiles set role = 'admin' where id = (select id from auth.users where email = 'you@example.com');
