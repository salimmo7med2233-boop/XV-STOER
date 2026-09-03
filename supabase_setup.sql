-- XV database setup
create extension if not exists pgcrypto;
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cat text not null default 'تصميمات أخرى',
  price numeric not null default 0,
  old_price numeric not null default 0,
  badge text default '',
  description text default '',
  images text[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.products enable row level security;
create table if not exists public.admins (id uuid primary key references auth.users(id) on delete cascade);
create or replace function public.is_admin() returns boolean language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.admins where id=auth.uid());
$$;
alter table public.admins enable row level security;
drop policy if exists "admins own row" on public.admins;
create policy "admins own row" on public.admins for select to authenticated using (id=auth.uid());
drop policy if exists "public read products" on public.products;
create policy "public read products" on public.products for select to anon, authenticated using (true);
drop policy if exists "admins insert products" on public.products;
create policy "admins insert products" on public.products for insert to authenticated with check (public.is_admin());
drop policy if exists "admins update products" on public.products;
create policy "admins update products" on public.products for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admins delete products" on public.products;
create policy "admins delete products" on public.products for delete to authenticated using (public.is_admin());
-- Create a PUBLIC storage bucket named product-images in Supabase Storage.
insert into storage.buckets (id,name,public) values ('product-images','product-images',true) on conflict (id) do update set public=true;
drop policy if exists "public read product images" on storage.objects;
create policy "public read product images" on storage.objects for select to anon, authenticated using (bucket_id='product-images');
drop policy if exists "admins upload product images" on storage.objects;
create policy "admins upload product images" on storage.objects for insert to authenticated with check (bucket_id='product-images' and public.is_admin());
drop policy if exists "admins delete product images" on storage.objects;
create policy "admins delete product images" on storage.objects for delete to authenticated using (bucket_id='product-images' and public.is_admin());
-- After creating your admin user in Authentication, run:
-- insert into public.admins(id) values ('YOUR-AUTH-USER-UUID');

-- لو جدول products اتعمل قبل كده: شغّل السطر التالي مرة واحدة
alter table public.products add column if not exists active boolean not null default true;

-- XV store settings (WhatsApp number)
create table if not exists public.store_settings (
  id integer primary key default 1,
  whatsapp text not null default '201221009017',
  instagram text not null default '',
  tiktok text not null default '',
  updated_at timestamptz not null default now(),
  constraint store_settings_singleton check (id = 1)
);
alter table public.store_settings enable row level security;
drop policy if exists "public read store settings" on public.store_settings;
create policy "public read store settings" on public.store_settings for select to anon, authenticated using (true);
drop policy if exists "admins insert store settings" on public.store_settings;
create policy "admins insert store settings" on public.store_settings for insert to authenticated with check (public.is_admin());
drop policy if exists "admins update store settings" on public.store_settings;
create policy "admins update store settings" on public.store_settings for update to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.store_settings add column if not exists instagram text not null default '';
alter table public.store_settings add column if not exists tiktok text not null default '';
insert into public.store_settings (id, whatsapp, instagram, tiktok) values (1, '201221009017', '', '') on conflict (id) do nothing;


-- أسعار مستقلة لكل مقاس
alter table public.products add column if not exists size_prices jsonb not null default '{}'::jsonb;
update public.products set size_prices = jsonb_build_object('30x40', coalesce(price,0), '40x60', coalesce(price,0), '50x70', coalesce(price,0)) where size_prices = '{}'::jsonb or size_prices is null;
