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

-- 6. 店の推しポイント
alter table restaurants add column if not exists pitch text;
notify pgrst, 'reload schema';
notify pgrst, 'reload config';

-- 7. 店を探す・URLから位置を読む（データベースから外のサイトを呼ぶ）
create extension if not exists http with schema extensions;
create or replace function public.hp_search(q jsonb) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare k text; u text; r extensions.http_response;
begin
  select hp_key into k from settings where id = 1;
  if coalesce(k,'') = '' then return jsonb_build_object('error','no key'); end if;
  u := 'https://webservice.recruit.co.jp/hotpepper/gourmet/v1/?format=json&count=50&key=' || extensions.urlencode(k)
    || coalesce((select string_agg('&' || key || '=' || extensions.urlencode(value), '') from jsonb_each_text(q) where key in ('lat','lng','range','party_capacity','private_room','keyword')), '');
  perform extensions.http_set_curlopt('CURLOPT_CONNECTTIMEOUT_MS','8000');
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','15000');
  r := extensions.http_get(u);
  return r.content::jsonb;
end $$;
create or replace function public.shop_page(u text) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare r extensions.http_response; n int := 0; loc text;
begin
  loop
    if u !~ '^https://([a-z0-9-]+\.)*(tabelog\.com|hotpepper\.jp|goo\.gl|google\.com|google\.co\.jp)/' then return jsonb_build_object('error','host'); end if;
    perform extensions.http_set_curlopt('CURLOPT_CONNECTTIMEOUT_MS','8000');
    perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','15000');
    r := extensions.http_get(u);
    if r.status between 300 and 399 and n < 4 then
      select h.value into loc from unnest(r.headers) h where lower(h.field) = 'location';
      if loc is null then exit; end if;
      u := loc; n := n + 1;
    else exit; end if;
  end loop;
  return jsonb_build_object('url', u, 'status', r.status, 'body', left(r.content, 500000));
end $$;
grant execute on function public.hp_search(jsonb), public.shop_page(text) to anon, authenticated;
-- 外のサイトの返事を待てるよう、待ち時間の上限を3秒から20秒にのばす
alter role anon set statement_timeout = '20s';
alter role authenticated set statement_timeout = '20s';
notify pgrst, 'reload schema';
notify pgrst, 'reload config';
