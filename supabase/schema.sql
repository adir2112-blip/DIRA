-- DIRA-CHANGE: family renovation tracker schema
-- Project: dira-change (ref bjicskzwuiojhqdwfyov) — do not run against any other Supabase project.

create extension if not exists pgcrypto;

-- ===== members (the 3 known people) =====
create table if not exists members (
  id            uuid primary key default gen_random_uuid(),
  full_name     text not null unique,
  id_last4_hash text not null,
  is_active     boolean not null default true,
  sort_order    smallint not null default 0,
  failed_attempts int not null default 0,
  locked_until  timestamptz,
  created_at    timestamptz not null default now()
);
alter table members enable row level security;
revoke all on members from anon, authenticated;

-- ===== apartments =====
create table if not exists apartments (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,
  display_name text not null,
  created_at   timestamptz not null default now()
);
alter table apartments enable row level security;
revoke insert, update, delete on apartments from anon, authenticated;

-- ===== sessions (bridge: anon auth.uid() -> known member) =====
create table if not exists sessions (
  id           uuid primary key default gen_random_uuid(),
  auth_uid     uuid not null unique references auth.users(id) on delete cascade,
  member_id    uuid not null references members(id),
  created_at   timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at   timestamptz not null
);
create index if not exists idx_sessions_auth_uid on sessions(auth_uid);
alter table sessions enable row level security;

drop policy if exists "read own session" on sessions;
create policy "read own session" on sessions for select to authenticated
  using (auth_uid = (select auth.uid()));
revoke insert, update, delete on sessions from anon, authenticated;

drop policy if exists "family can read apartments" on apartments;
create policy "family can read apartments" on apartments for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

-- ===== expenses =====
create table if not exists expenses (
  id                 uuid primary key default gen_random_uuid(),
  apartment_id       uuid not null references apartments(id),
  category           text not null check (category in
                        ('kitchen','doors','marble_ceramic','electrical','plumbing','ac','garden_exterior','general')),
  description        text not null,
  amount             numeric(12,2) not null check (amount >= 0),
  currency           text not null default 'ILS',
  status             text not null default 'pending' check (status in ('paid','pending')),
  expense_date       date not null default current_date,
  added_by_member_id uuid not null references members(id),
  notes              text,
  is_deleted         boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists idx_expenses_apartment on expenses(apartment_id, status);
alter table expenses enable row level security;

drop policy if exists "family can read expenses" on expenses;
drop policy if exists "family can write expenses" on expenses;
drop policy if exists "family can update expenses" on expenses;
drop policy if exists "family can delete expenses" on expenses;
create policy "family can read expenses" on expenses for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can write expenses" on expenses for insert to authenticated
  with check (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can update expenses" on expenses for update to authenticated
  using     (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()))
  with check(exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can delete expenses" on expenses for delete to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

-- ===== tasks ("שינוי דיירים" contractor requests) =====
create table if not exists tasks (
  id                 uuid primary key default gen_random_uuid(),
  apartment_id       uuid not null references apartments(id),
  category           text not null check (category in
                        ('kitchen','doors','marble_ceramic','electrical','plumbing','ac','garden_exterior','general')),
  title              text not null,
  description        text,
  status             text not null default 'idea' check (status in ('idea','agreed','done')),
  due_date           date,
  cost               numeric(12,2),
  added_by_member_id uuid not null references members(id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  resolved_at        timestamptz
);
create index if not exists idx_tasks_apartment on tasks(apartment_id, category, status);
alter table tasks enable row level security;

drop policy if exists "family can read tasks" on tasks;
drop policy if exists "family can write tasks" on tasks;
drop policy if exists "family can update tasks" on tasks;
drop policy if exists "family can delete tasks" on tasks;
create policy "family can read tasks" on tasks for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can write tasks" on tasks for insert to authenticated
  with check (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can update tasks" on tasks for update to authenticated
  using     (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()))
  with check(exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can delete tasks" on tasks for delete to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

-- ===== documents (receipts + general apartment docs) =====
create table if not exists documents (
  id                    uuid primary key default gen_random_uuid(),
  apartment_id          uuid not null references apartments(id),
  kind                  text not null check (kind in ('receipt','document')),
  related_expense_id    uuid references expenses(id) on delete set null,
  title                 text,
  storage_path          text not null,
  file_name             text not null,
  mime_type             text,
  size_bytes            bigint,
  uploaded_by_member_id uuid not null references members(id),
  created_at            timestamptz not null default now()
);
create index if not exists idx_documents_apartment on documents(apartment_id, kind);
alter table documents enable row level security;

drop policy if exists "family can read documents" on documents;
drop policy if exists "family can write documents" on documents;
drop policy if exists "family can update documents" on documents;
drop policy if exists "family can delete documents" on documents;
create policy "family can read documents" on documents for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can write documents" on documents for insert to authenticated
  with check (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can update documents" on documents for update to authenticated
  using     (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()))
  with check(exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can delete documents" on documents for delete to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

-- ===== RPC: one-time bootstrap setup (only when members table is empty) =====
create or replace function public.bootstrap_setup(p_members jsonb, p_apartments jsonb)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  m jsonb;
  a jsonb;
begin
  if (select count(*) from members) > 0 then
    raise exception 'ההקמה כבר בוצעה' using errcode = 'P0001';
  end if;
  if (select count(*) from apartments) > 0 then
    raise exception 'ההקמה כבר בוצעה' using errcode = 'P0001';
  end if;

  for m in select * from jsonb_array_elements(p_members)
  loop
    insert into members (full_name, id_last4_hash, sort_order)
    values (m->>'full_name', crypt(m->>'pin', gen_salt('bf')), coalesce((m->>'sort_order')::smallint, 0));
  end loop;

  for a in select * from jsonb_array_elements(p_apartments)
  loop
    insert into apartments (slug, display_name)
    values (a->>'slug', a->>'display_name');
  end loop;
end;
$$;

revoke all on function public.bootstrap_setup(jsonb, jsonb) from public;
grant execute on function public.bootstrap_setup(jsonb, jsonb) to anon, authenticated;

-- ===== RPC: check whether setup has already happened (safe to expose, no PII) =====
create or replace function public.is_setup_done()
returns boolean
language sql
security definer
set search_path = public
as $$
  select (select count(*) from members) > 0;
$$;

revoke all on function public.is_setup_done() from public;
grant execute on function public.is_setup_done() to anon, authenticated;

-- ===== RPC: login with name + PIN =====
create or replace function public.login_with_pin(p_full_name text, p_id_last4 text)
returns table(member_id uuid, display_name text)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_member members%rowtype;
begin
  select * into v_member from members
  where full_name = p_full_name and is_active
  limit 1;

  if v_member.id is null then
    perform pg_sleep(0.4);
    raise exception 'שם או קוד שגויים' using errcode = 'P0001';
  end if;

  if v_member.locked_until is not null and v_member.locked_until > now() then
    raise exception 'יותר מדי ניסיונות, נסו שוב מאוחר יותר' using errcode = 'P0001';
  end if;

  if v_member.id_last4_hash <> crypt(p_id_last4, v_member.id_last4_hash) then
    update members set
      failed_attempts = failed_attempts + 1,
      locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' else locked_until end
    where id = v_member.id;
    raise exception 'שם או קוד שגויים' using errcode = 'P0001';
  end if;

  update members set failed_attempts = 0, locked_until = null where id = v_member.id;

  insert into sessions (auth_uid, member_id, expires_at, last_seen_at)
  values (auth.uid(), v_member.id, now() + interval '90 days', now())
  on conflict (auth_uid) do update
    set member_id = excluded.member_id, expires_at = excluded.expires_at, last_seen_at = now();

  return query select v_member.id, v_member.full_name;
end;
$$;

revoke all on function public.login_with_pin(text, text) from public;
grant execute on function public.login_with_pin(text, text) to anon, authenticated;

-- ===== RPC: list member names for the login picker (no PII beyond first name) =====
create or replace function public.list_member_names()
returns table(full_name text, sort_order smallint)
language sql
security definer
set search_path = public
as $$
  select full_name, sort_order from members where is_active order by sort_order;
$$;

revoke all on function public.list_member_names() from public;
grant execute on function public.list_member_names() to anon, authenticated;

-- ===== RPC: change own PIN (requires active session) =====
create or replace function public.change_own_pin(p_new_pin text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_member_id uuid;
begin
  select member_id into v_member_id from sessions
  where auth_uid = auth.uid() and expires_at > now();

  if v_member_id is null then
    raise exception 'לא מחובר' using errcode = 'P0001';
  end if;

  if p_new_pin !~ '^[0-9]{4}$' then
    raise exception 'קוד חייב להיות 4 ספרות' using errcode = 'P0001';
  end if;

  update members set id_last4_hash = crypt(p_new_pin, gen_salt('bf')) where id = v_member_id;
end;
$$;

revoke all on function public.change_own_pin(text) from public;
grant execute on function public.change_own_pin(text) to anon, authenticated;

-- ===== RPC: touch session (sliding expiration) =====
create or replace function public.touch_session()
returns void
language sql
security definer
set search_path = public
as $$
  update sessions set expires_at = now() + interval '90 days', last_seen_at = now()
  where auth_uid = auth.uid() and expires_at > now();
$$;

revoke all on function public.touch_session() from public;
grant execute on function public.touch_session() to anon, authenticated;

-- ===== RPC: logout (delete own session row) =====
create or replace function public.logout()
returns void
language sql
security definer
set search_path = public
as $$
  delete from sessions where auth_uid = auth.uid();
$$;

revoke all on function public.logout() from public;
grant execute on function public.logout() to anon, authenticated;

-- ===== realtime: let the app live-refresh across devices during a meeting =====
alter publication supabase_realtime add table public.expenses, public.tasks, public.documents;

-- ===== category_deadlines: one deadline per (apartment, category) =====
create table if not exists category_deadlines (
  id           uuid primary key default gen_random_uuid(),
  apartment_id uuid not null references apartments(id),
  category     text not null check (category in
                  ('kitchen','doors','marble_ceramic','electrical','plumbing','ac','garden_exterior','general')),
  deadline     date not null,
  updated_at   timestamptz not null default now(),
  unique(apartment_id, category)
);
alter table category_deadlines enable row level security;

drop policy if exists "family can read deadlines" on category_deadlines;
drop policy if exists "family can write deadlines" on category_deadlines;
drop policy if exists "family can update deadlines" on category_deadlines;
drop policy if exists "family can delete deadlines" on category_deadlines;
create policy "family can read deadlines" on category_deadlines for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can write deadlines" on category_deadlines for insert to authenticated
  with check (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can update deadlines" on category_deadlines for update to authenticated
  using     (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()))
  with check(exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can delete deadlines" on category_deadlines for delete to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

-- ===== contacts: people/suppliers per apartment =====
create table if not exists contacts (
  id                 uuid primary key default gen_random_uuid(),
  apartment_id       uuid not null references apartments(id),
  category           text not null check (category in
                        ('kitchen','doors','marble_ceramic','electrical','plumbing','ac','garden_exterior','general','contractor')),
  name               text not null,
  phone              text,
  notes              text,
  added_by_member_id uuid not null references members(id),
  created_at         timestamptz not null default now()
);
create index if not exists idx_contacts_apartment on contacts(apartment_id, category);
alter table contacts enable row level security;

drop policy if exists "family can read contacts" on contacts;
drop policy if exists "family can write contacts" on contacts;
drop policy if exists "family can update contacts" on contacts;
drop policy if exists "family can delete contacts" on contacts;
create policy "family can read contacts" on contacts for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can write contacts" on contacts for insert to authenticated
  with check (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can update contacts" on contacts for update to authenticated
  using     (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()))
  with check(exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can delete contacts" on contacts for delete to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

-- ===== furniture_items: post-move-in shopping/warranty list =====
create table if not exists furniture_items (
  id                 uuid primary key default gen_random_uuid(),
  apartment_id       uuid not null references apartments(id),
  category           text not null check (category in
                        ('living_room','kitchen','bedrooms','appliances','general')),
  title              text not null,
  store              text,
  price              numeric(12,2),
  purchased          boolean not null default false,
  warranty_until     date,
  notes              text,
  added_by_member_id uuid not null references members(id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists idx_furniture_apartment on furniture_items(apartment_id, category);
alter table furniture_items enable row level security;

drop policy if exists "family can read furniture" on furniture_items;
drop policy if exists "family can write furniture" on furniture_items;
drop policy if exists "family can update furniture" on furniture_items;
drop policy if exists "family can delete furniture" on furniture_items;
create policy "family can read furniture" on furniture_items for select to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can write furniture" on furniture_items for insert to authenticated
  with check (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can update furniture" on furniture_items for update to authenticated
  using     (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()))
  with check(exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));
create policy "family can delete furniture" on furniture_items for delete to authenticated
  using (exists (select 1 from sessions s where s.auth_uid = (select auth.uid()) and s.expires_at > now()));

alter publication supabase_realtime add table public.contacts, public.furniture_items, public.category_deadlines;
