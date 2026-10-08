-- JEJAK: skema database komunitas (Supabase). Jalankan di SQL Editor.
-- Prinsip: anonim, minim data. Tidak ada nama, lokasi, atau pengenal perangkat.

create table if not exists public.scan_events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  brand       text check (brand is null or char_length(brand) <= 60),
  brand_slug  text check (brand_slug is null or char_length(brand_slug) <= 60),
  material    text not null check (char_length(material) between 1 and 20),
  source      text not null check (source in ('barcode','manual'))
);
create index if not exists scan_events_brand_idx on public.scan_events (brand_slug);
create index if not exists scan_events_time_idx  on public.scan_events (created_at desc);

alter table public.scan_events enable row level security;
-- Pengunjung anonim hanya boleh MENAMBAH baris. Tidak boleh membaca, mengubah, atau menghapus.
drop policy if exists "anon insert scans" on public.scan_events;
create policy "anon insert scans" on public.scan_events for insert to anon with check (true);

-- Agregat publik. Merek baru tampil setelah dipindai minimal 3 kali agar satu orang tidak bisa dikenali.
create or replace view public.brand_stats with (security_invoker = false) as
  select max(brand) as brand, brand_slug, count(*)::int as scans
  from public.scan_events
  where brand_slug is not null and created_at > now() - interval '90 days'
  group by brand_slug
  having count(*) >= 3;
grant select on public.brand_stats to anon;

-- Untuk Google Colab / pytrends: hasil analisis ditulis memakai service_role key (JANGAN taruh di situs).
create table if not exists public.trend_snapshots (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  keyword text not null, geo text not null default 'ID', period text not null, value numeric not null
);
alter table public.trend_snapshots enable row level security;
drop policy if exists "anon read trends" on public.trend_snapshots;
create policy "anon read trends" on public.trend_snapshots for select to anon using (true);

-- Batasi penyalahgunaan: pasang rate limit di Supabase (Auth > Rate limits) dan pertimbangkan Edge Function
-- bila nanti ada lonjakan penyisipan palsu.
