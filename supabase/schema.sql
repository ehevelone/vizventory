create extension if not exists pgcrypto;

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'My Organization',
  organization_type text not null default 'Personal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into organizations (id, name, organization_type)
values ('00000000-0000-0000-0000-000000000001', 'Default Organization', 'Personal')
on conflict (id) do nothing;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  default_organization_id uuid references organizations(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'admin',
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table if not exists items (
  id text primary key,
  organization_id uuid not null default '00000000-0000-0000-0000-000000000001' references organizations(id) on delete cascade,
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
  organization_id uuid references organizations(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
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
  organization_id uuid not null default '00000000-0000-0000-0000-000000000001' references organizations(id) on delete cascade,
  item_id text not null references items(id) on delete cascade,
  storage_path text not null,
  content_type text not null default 'image/jpeg',
  created_at timestamptz not null default now()
);

create table if not exists item_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default '00000000-0000-0000-0000-000000000001' references organizations(id) on delete cascade,
  item_id text not null references items(id) on delete cascade,
  status text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

alter table items add column if not exists organization_id uuid;
alter table items alter column organization_id set default '00000000-0000-0000-0000-000000000001';
update items set organization_id = '00000000-0000-0000-0000-000000000001' where organization_id is null;
alter table items alter column organization_id set not null;
alter table items drop constraint if exists items_organization_id_fkey;
alter table items add constraint items_organization_id_fkey foreign key (organization_id) references organizations(id) on delete cascade;

alter table categories add column if not exists organization_id uuid;
alter table categories drop constraint if exists categories_name_key;
alter table categories drop constraint if exists categories_organization_id_name_key;
alter table categories add constraint categories_organization_id_name_key unique (organization_id, name);
alter table categories drop constraint if exists categories_organization_id_fkey;
alter table categories add constraint categories_organization_id_fkey foreign key (organization_id) references organizations(id) on delete cascade;
update categories set organization_id = '00000000-0000-0000-0000-000000000001' where organization_id is null;

alter table item_photos add column if not exists organization_id uuid;
alter table item_photos alter column organization_id set default '00000000-0000-0000-0000-000000000001';
update item_photos set organization_id = '00000000-0000-0000-0000-000000000001' where organization_id is null;
alter table item_photos alter column organization_id set not null;
alter table item_photos drop constraint if exists item_photos_organization_id_fkey;
alter table item_photos add constraint item_photos_organization_id_fkey foreign key (organization_id) references organizations(id) on delete cascade;

alter table item_events add column if not exists organization_id uuid;
alter table item_events alter column organization_id set default '00000000-0000-0000-0000-000000000001';
update item_events set organization_id = '00000000-0000-0000-0000-000000000001' where organization_id is null;
alter table item_events alter column organization_id set not null;
alter table item_events drop constraint if exists item_events_organization_id_fkey;
alter table item_events add constraint item_events_organization_id_fkey foreign key (organization_id) references organizations(id) on delete cascade;

create index if not exists item_photos_item_id_idx on item_photos(item_id);
create index if not exists item_events_item_id_idx on item_events(item_id);
create index if not exists profiles_default_organization_id_idx on profiles(default_organization_id);
create index if not exists organization_memberships_user_id_idx on organization_memberships(user_id);
create index if not exists organization_memberships_organization_id_idx on organization_memberships(organization_id);
create index if not exists items_organization_id_idx on items(organization_id);
create index if not exists items_status_idx on items(status);
create index if not exists items_updated_at_idx on items(updated_at desc);
create index if not exists item_photos_organization_id_idx on item_photos(organization_id);
create index if not exists item_events_organization_id_idx on item_events(organization_id);
create index if not exists categories_sort_order_idx on categories(sort_order, name);
create index if not exists subcategories_category_sort_order_idx on subcategories(category_id, sort_order, name);

insert into categories (organization_id, name, sort_order)
values
  ('00000000-0000-0000-0000-000000000001', 'Clothing', 10),
  ('00000000-0000-0000-0000-000000000001', 'Equipment', 20),
  ('00000000-0000-0000-0000-000000000001', 'Tool', 30),
  ('00000000-0000-0000-0000-000000000001', 'Electronics', 40),
  ('00000000-0000-0000-0000-000000000001', 'Furniture', 50),
  ('00000000-0000-0000-0000-000000000001', 'Supply', 60),
  ('00000000-0000-0000-0000-000000000001', 'Document', 70),
  ('00000000-0000-0000-0000-000000000001', 'Artwork', 80),
  ('00000000-0000-0000-0000-000000000001', 'Part', 90),
  ('00000000-0000-0000-0000-000000000001', 'Container', 100),
  ('00000000-0000-0000-0000-000000000001', 'Other', 110)
on conflict (organization_id, name) do update set sort_order = excluded.sort_order;

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
