create extension if not exists pgcrypto;

create table if not exists items (
  id text primary key,
  title text not null default 'Inventory item',
  category text not null default '',
  subcategory text not null default '',
  size text not null default '',
  color text not null default '',
  condition text not null default '',
  location text not null default '',
  notes text not null default '',
  tags text[] not null default '{}',
  status text not null default 'Available',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_id, name)
);

create table if not exists item_photos (
  id uuid primary key default gen_random_uuid(),
  item_id text not null references items(id) on delete cascade,
  storage_path text not null,
  content_type text not null default 'image/jpeg',
  created_at timestamptz not null default now()
);

create table if not exists item_events (
  id uuid primary key default gen_random_uuid(),
  item_id text not null references items(id) on delete cascade,
  status text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists item_photos_item_id_idx on item_photos(item_id);
create index if not exists item_events_item_id_idx on item_events(item_id);
create index if not exists items_status_idx on items(status);
create index if not exists items_updated_at_idx on items(updated_at desc);
create index if not exists categories_sort_order_idx on categories(sort_order, name);
create index if not exists subcategories_category_sort_order_idx on subcategories(category_id, sort_order, name);

insert into categories (name, sort_order)
values
  ('Clothing', 10),
  ('Equipment', 20),
  ('Tool', 30),
  ('Electronics', 40),
  ('Furniture', 50),
  ('Supply', 60),
  ('Document', 70),
  ('Artwork', 80),
  ('Part', 90),
  ('Container', 100),
  ('Other', 110)
on conflict (name) do update set sort_order = excluded.sort_order;

insert into subcategories (category_id, name, sort_order)
select c.id, v.name, v.sort_order
from categories c
join (
  values
    ('Clothing', 'Tops', 10),
    ('Clothing', 'Bottoms', 20),
    ('Clothing', 'Dresses', 30),
    ('Clothing', 'Outerwear', 40),
    ('Clothing', 'Shoes', 50),
    ('Clothing', 'Accessories', 60),
    ('Clothing', 'Bags', 70),
    ('Clothing', 'Jewelry', 80),
    ('Clothing', 'Kids', 90),
    ('Clothing', 'Other Clothing', 100),
    ('Equipment', 'Office Equipment', 10),
    ('Equipment', 'Medical Equipment', 20),
    ('Equipment', 'Audio/Visual', 30),
    ('Equipment', 'Field Equipment', 40),
    ('Equipment', 'Other Equipment', 100),
    ('Tool', 'Hand Tools', 10),
    ('Tool', 'Power Tools', 20),
    ('Tool', 'Tool Sets', 30),
    ('Tool', 'Measuring Tools', 40),
    ('Electronics', 'Computers', 10),
    ('Electronics', 'Phones/Tablets', 20),
    ('Electronics', 'Cameras', 30),
    ('Electronics', 'Cables/Adapters', 40),
    ('Furniture', 'Desk/Table', 10),
    ('Furniture', 'Chair/Seating', 20),
    ('Furniture', 'Shelf/Storage', 30),
    ('Supply', 'Office Supplies', 10),
    ('Supply', 'Cleaning Supplies', 20),
    ('Supply', 'Packaging Supplies', 30),
    ('Document', 'Forms', 10),
    ('Document', 'Manuals', 20),
    ('Document', 'Records', 30),
    ('Container', 'Box', 10),
    ('Container', 'Bin/Tote', 20),
    ('Container', 'Case', 30)
) as v(category_name, name, sort_order)
on c.name = v.category_name
on conflict (category_id, name) do update set sort_order = excluded.sort_order;

insert into storage.buckets (id, name, public)
values ('item-photos', 'item-photos', false)
on conflict (id) do nothing;
