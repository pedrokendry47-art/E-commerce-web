-- ============================================================
-- seed.sql  (development only; run after schema.sql + policies.sql)
-- Placeholder images come from picsum.photos; replace with Supabase Storage
-- uploads through the admin dashboard.
-- ============================================================

insert into categories (name, slug, description) values
  ('Electronics', 'electronics', 'Phones, audio and accessories'),
  ('Fashion',     'fashion',     'Clothing, shoes and bags'),
  ('Home & Living','home-living','Furniture and kitchen essentials'),
  ('Beauty',      'beauty',      'Skincare and grooming')
on conflict (slug) do nothing;

with c as (select id, slug from categories)
insert into products (category_id, name, slug, description, price, discount_price, stock_quantity, is_featured, sold_count)
select c.id, p.name, p.slug, p.description, p.price, p.discount_price, p.stock, p.featured, p.sold
from (values
  ('electronics','Wireless Noise-Cancelling Headphones','wireless-headphones','Over-ear Bluetooth headphones with 30-hour battery life.',85000,69000,40,true,120),
  ('electronics','Smart Watch Series 5','smart-watch-5','Fitness tracking, heart-rate monitor and notifications.',65000,null,25,true,85),
  ('fashion','Classic Leather Sneakers','leather-sneakers','Handcrafted leather sneakers for everyday wear.',38000,32000,60,true,200),
  ('fashion','Ankara Print Tote Bag','ankara-tote','Durable tote bag in vibrant Ankara fabric.',12500,null,80,false,45),
  ('home-living','Ceramic Dinner Set (16pc)','ceramic-dinner-set','Dishwasher-safe dinner set for four.',42000,36000,15,false,30),
  ('beauty','Vitamin C Brightening Serum','vitamin-c-serum','30ml daily serum for even skin tone.',9500,null,120,true,310)
) as p(cat, name, slug, description, price, discount_price, stock, featured, sold)
join c on c.slug = p.cat
on conflict (slug) do nothing;

insert into product_images (product_id, url, alt_text, sort_order, is_primary)
select id, 'https://picsum.photos/seed/' || slug || '-1/800/800', name, 0, true from products
union all
select id, 'https://picsum.photos/seed/' || slug || '-2/800/800', name, 1, false from products;

insert into product_variants (product_id, size, color, sku, stock_quantity)
select id, s.size, null, 'SNK-' || s.size, 20 from products, (values ('41'),('42'),('43')) as s(size)
where slug = 'leather-sneakers'
union all
select id, null, col.color, 'WH-' || upper(col.color), 20 from products, (values ('Black'),('Silver')) as col(color)
where slug = 'wireless-headphones';

insert into coupons (code, discount_type, discount_value, min_order_amount, max_uses, expires_at) values
  ('WELCOME10', 'percentage', 10, 10000, 1000, now() + interval '1 year'),
  ('SAVE5000',  'fixed',      5000, 50000, 200,  now() + interval '6 months')
on conflict (code) do nothing;
