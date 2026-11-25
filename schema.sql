-- ワンチーム食事会マップ：Supabase の SQL Editor に貼って実行する
create table if not exists settings (
  id int primary key default 1 check (id = 1),
  pass_hash text,
  office_lat float8,
  office_lng float8
);
create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  nickname text not null unique,
  animal text not null,
  created_at timestamptz default now()
);
create table if not exists restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  url text,
  genre text,
  lat float8 not null,
  lng float8 not null,
  status text not null default 'wish' check (status in ('wish','visited')),
  created_by uuid references members(id) on delete set null,
  created_at timestamptz default now()
);
create table if not exists wishes (
  restaurant_id uuid references restaurants(id) on delete cascade,
  member_id uuid references members(id) on delete cascade,
  primary key (restaurant_id, member_id)
);
create table if not exists visits (
  restaurant_id uuid references restaurants(id) on delete cascade,
  member_id uuid references members(id) on delete cascade,
  primary key (restaurant_id, member_id)
);

-- 試作用：アプリのキー(anon)で読み書きできるようにする。
-- 合言葉は画面での確認だけなので、URLとキーを知っている人はデータを読めます（ニックネーム運用が前提）。
do $$ declare t text; begin
  foreach t in array array['settings','members','restaurants','wishes','visits'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "prototype all" on %I', t);
    execute format('create policy "prototype all" on %I for all to anon using (true) with check (true)', t);
  end loop;
end $$;

-- 変更を全員の画面にすぐ反映する
alter publication supabase_realtime add table settings, members, restaurants, wishes, visits;
