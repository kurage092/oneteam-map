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

-- 4. P2（今月の会・候補日・割り勘・提案）で追加
alter table members add column if not exists order_no int;
alter table members add column if not exists dislikes text;
alter table restaurants add column if not exists budget int;
alter table settings add column if not exists hp_key text;
alter table settings add column if not exists stations jsonb;
create table if not exists events (id uuid primary key default gen_random_uuid(), month text not null unique, organizer_id uuid references members(id) on delete set null, final_date_id uuid, restaurant_id uuid references restaurants(id) on delete set null, meet_time text, meet_place text, total int, headcount int, round_unit int, reserved boolean default false, notified boolean default false, paid boolean default false, status text default 'planning', created_at timestamptz default now());
create table if not exists event_dates (id uuid primary key default gen_random_uuid(), event_id uuid references events(id) on delete cascade, day date not null);
create table if not exists date_answers (date_id uuid references event_dates(id) on delete cascade, member_id uuid references members(id) on delete cascade, ans text not null, primary key (date_id, member_id));
alter table events enable row level security;
alter table event_dates enable row level security;
alter table date_answers enable row level security;
drop policy if exists app_all on events; create policy app_all on events for all to anon using (true) with check (true);
drop policy if exists app_all on event_dates; create policy app_all on event_dates for all to anon using (true) with check (true);
drop policy if exists app_all on date_answers; create policy app_all on date_answers for all to anon using (true) with check (true);
grant select, insert, update, delete on events, event_dates, date_answers to anon, authenticated;
alter publication supabase_realtime add table events, event_dates, date_answers;

-- 5. 権限（最近のSupabaseでは必要）
grant select, insert, update, delete on settings, members, restaurants, wishes, visits to anon, authenticated;
