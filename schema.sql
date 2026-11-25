-- ワンチーム食事会マップ：Supabase の SQL Editor で、3つのブロックを1つずつ実行する
-- 1. 表を作る
create table if not exists settings (id int primary key default 1, pass_hash text, office_lat float8, office_lng float8);
create table if not exists members (id uuid primary key default gen_random_uuid(), nickname text not null unique, animal text not null, created_at timestamptz default now());
create table if not exists restaurants (id uuid primary key default gen_random_uuid(), name text not null, url text, genre text, lat float8 not null, lng float8 not null, status text not null default 'wish', created_by uuid references members(id) on delete set null, created_at timestamptz default now());
create table if not exists wishes (restaurant_id uuid references restaurants(id) on delete cascade, member_id uuid references members(id) on delete cascade, primary key (restaurant_id, member_id));
create table if not exists visits (restaurant_id uuid references restaurants(id) on delete cascade, member_id uuid references members(id) on delete cascade, primary key (restaurant_id, member_id));

-- 2. アプリ(anon)から読み書きできるようにする（試作用。合言葉は画面での確認だけ）
alter table settings enable row level security;
alter table members enable row level security;
alter table restaurants enable row level security;
alter table wishes enable row level security;
alter table visits enable row level security;
drop policy if exists app_all on settings; create policy app_all on settings for all to anon using (true) with check (true);
drop policy if exists app_all on members; create policy app_all on members for all to anon using (true) with check (true);
drop policy if exists app_all on restaurants; create policy app_all on restaurants for all to anon using (true) with check (true);
drop policy if exists app_all on wishes; create policy app_all on wishes for all to anon using (true) with check (true);
drop policy if exists app_all on visits; create policy app_all on visits for all to anon using (true) with check (true);

-- 3. 変更を全員の画面にすぐ反映する
alter publication supabase_realtime add table settings, members, restaurants, wishes, visits;
