-- Ledger cloud schema (run in Supabase SQL Editor)
-- Purpose: store user-owned ledger accounts and bills with RLS enabled.

create extension if not exists pgcrypto;

create table if not exists public.ledger_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  currency text not null default 'USD',
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ledger_bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid not null references public.ledger_accounts(id) on delete cascade,
  source text,
  source_id text,
  direction text not null check (direction in ('income', 'expense', 'pending')),
  amount_cents bigint not null check (amount_cents >= 0),
  currency text not null default 'USD',
  merchant text,
  memo text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_ledger_bills_user_sourceid_unique
  on public.ledger_bills(user_id, source, source_id)
  where source is not null and source_id is not null;

create index if not exists idx_ledger_accounts_user on public.ledger_accounts(user_id);
create index if not exists idx_ledger_bills_user_occurred_at
  on public.ledger_bills(user_id, occurred_at desc);
create index if not exists idx_ledger_bills_account on public.ledger_bills(account_id);

alter table public.ledger_accounts enable row level security;
alter table public.ledger_bills enable row level security;

drop policy if exists ledger_accounts_select_own on public.ledger_accounts;
drop policy if exists ledger_accounts_insert_own on public.ledger_accounts;
drop policy if exists ledger_accounts_update_own on public.ledger_accounts;
drop policy if exists ledger_accounts_delete_own on public.ledger_accounts;

create policy ledger_accounts_select_own
  on public.ledger_accounts for select
  using (auth.uid() = user_id);

create policy ledger_accounts_insert_own
  on public.ledger_accounts for insert
  with check (auth.uid() = user_id);

create policy ledger_accounts_update_own
  on public.ledger_accounts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy ledger_accounts_delete_own
  on public.ledger_accounts for delete
  using (auth.uid() = user_id);

drop policy if exists ledger_bills_select_own on public.ledger_bills;
drop policy if exists ledger_bills_insert_own on public.ledger_bills;
drop policy if exists ledger_bills_update_own on public.ledger_bills;
drop policy if exists ledger_bills_delete_own on public.ledger_bills;

create policy ledger_bills_select_own
  on public.ledger_bills for select
  using (auth.uid() = user_id);

create policy ledger_bills_insert_own
  on public.ledger_bills for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.ledger_accounts a
      where a.id = account_id
        and a.user_id = auth.uid()
    )
  );

create policy ledger_bills_update_own
  on public.ledger_bills for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.ledger_accounts a
      where a.id = account_id
        and a.user_id = auth.uid()
    )
  );

create policy ledger_bills_delete_own
  on public.ledger_bills for delete
  using (auth.uid() = user_id);

create table if not exists public.ledger_user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  ciphertext text not null,
  encryption_version smallint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ledger_user_profiles enable row level security;

drop policy if exists ledger_user_profiles_select_own on public.ledger_user_profiles;
drop policy if exists ledger_user_profiles_insert_own on public.ledger_user_profiles;
drop policy if exists ledger_user_profiles_update_own on public.ledger_user_profiles;
drop policy if exists ledger_user_profiles_delete_own on public.ledger_user_profiles;

create policy ledger_user_profiles_select_own
  on public.ledger_user_profiles for select
  using (auth.uid() = user_id);

create policy ledger_user_profiles_insert_own
  on public.ledger_user_profiles for insert
  with check (auth.uid() = user_id);

create policy ledger_user_profiles_update_own
  on public.ledger_user_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy ledger_user_profiles_delete_own
  on public.ledger_user_profiles for delete
  using (auth.uid() = user_id);

create table if not exists public.ledger_user_public_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ledger_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ledger_user_admin_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  is_disabled boolean not null default false,
  disabled_reason text,
  updated_at timestamptz not null default now()
);

create table if not exists public.ledger_feedback_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name_snapshot text not null,
  masked_email_snapshot text not null,
  content text not null,
  quota_date_utc8 date not null,
  status text not null default 'pending' check (status in ('pending', 'resolved')),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.ledger_admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.ledger_feedback_submissions
  add column if not exists status text not null default 'pending';
alter table public.ledger_feedback_submissions
  add column if not exists resolved_at timestamptz;
alter table public.ledger_feedback_submissions
  add column if not exists resolved_by uuid references auth.users(id) on delete set null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'ledger_feedback_submissions_status_check'
  ) then
    alter table public.ledger_feedback_submissions
      add constraint ledger_feedback_submissions_status_check
      check (status in ('pending', 'resolved'));
  end if;
end;
$$;

create index if not exists idx_ledger_feedback_user_quota_date
  on public.ledger_feedback_submissions(user_id, quota_date_utc8 desc);

create index if not exists idx_ledger_feedback_status_created_at
  on public.ledger_feedback_submissions(status, created_at desc);

create index if not exists idx_ledger_feedback_user_created_at
  on public.ledger_feedback_submissions(user_id, created_at desc);

create index if not exists idx_ledger_admin_audit_target_created_at
  on public.ledger_admin_audit_logs(target_user_id, created_at desc);

create index if not exists idx_ledger_admin_audit_actor_created_at
  on public.ledger_admin_audit_logs(actor_user_id, created_at desc);

alter table public.ledger_user_public_profiles enable row level security;
alter table public.ledger_admins enable row level security;
alter table public.ledger_user_admin_state enable row level security;
alter table public.ledger_feedback_submissions enable row level security;
alter table public.ledger_admin_audit_logs enable row level security;

drop policy if exists ledger_user_public_profiles_select_own on public.ledger_user_public_profiles;
drop policy if exists ledger_user_public_profiles_insert_own on public.ledger_user_public_profiles;
drop policy if exists ledger_user_public_profiles_update_own on public.ledger_user_public_profiles;
drop policy if exists ledger_user_public_profiles_delete_own on public.ledger_user_public_profiles;

create policy ledger_user_public_profiles_select_own
  on public.ledger_user_public_profiles for select
  using (auth.uid() = user_id);

create policy ledger_user_public_profiles_insert_own
  on public.ledger_user_public_profiles for insert
  with check (auth.uid() = user_id);

create policy ledger_user_public_profiles_update_own
  on public.ledger_user_public_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy ledger_user_public_profiles_delete_own
  on public.ledger_user_public_profiles for delete
  using (auth.uid() = user_id);

drop policy if exists ledger_admins_select_self on public.ledger_admins;

create policy ledger_admins_select_self
  on public.ledger_admins for select
  using (auth.uid() = user_id);

drop policy if exists ledger_feedback_submissions_select_own on public.ledger_feedback_submissions;
drop policy if exists ledger_feedback_submissions_insert_own on public.ledger_feedback_submissions;

create policy ledger_feedback_submissions_select_own
  on public.ledger_feedback_submissions for select
  using (auth.uid() = user_id);

create policy ledger_feedback_submissions_insert_own
  on public.ledger_feedback_submissions for insert
  with check (auth.uid() = user_id);

create or replace function public.mask_email_for_admin(raw_email text)
returns text
language sql
immutable
as $$
  select case
    when raw_email is null or raw_email = '' then ''
    when position('@' in raw_email) <= 1 then raw_email
    else
      left(split_part(raw_email, '@', 1), 1) ||
      repeat('*', greatest(length(split_part(raw_email, '@', 1)) - 2, 1)) ||
      right(split_part(raw_email, '@', 1), 1) ||
      '@' || split_part(raw_email, '@', 2)
  end
$$;

create or replace function public.is_current_admin()
returns boolean
language sql
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.ledger_admins la
    where la.user_id = auth.uid()
      and la.is_active = true
  );
$$;

create or replace function public.write_admin_audit_log(
  p_target_user_id uuid,
  p_action text,
  p_detail jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.ledger_admin_audit_logs (
    actor_user_id,
    target_user_id,
    action,
    detail
  )
  values (
    auth.uid(),
    p_target_user_id,
    p_action,
    coalesce(p_detail, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.write_admin_audit_log(uuid, text, jsonb) from public;

create or replace function public.get_current_user_admin_state()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user auth.users%rowtype;
  v_is_admin boolean;
  v_state public.ledger_user_admin_state%rowtype;
begin
  select *
  into v_user
  from auth.users
  where id = auth.uid();

  if not found then
    return null;
  end if;

  select exists (
    select 1
    from public.ledger_admins la
    where la.user_id = auth.uid()
      and la.is_active = true
  )
  into v_is_admin;

  select *
  into v_state
  from public.ledger_user_admin_state s
  where s.user_id = auth.uid();

  return jsonb_build_object(
    'user_id', v_user.id,
    'email', coalesce(v_user.email, ''),
    'is_admin', coalesce(v_is_admin, false),
    'is_disabled', coalesce(v_state.is_disabled, false),
    'disabled_reason', v_state.disabled_reason
  );
end;
$$;

create or replace function public.admin_list_users(
  page_size int default 20,
  cursor timestamptz default null,
  query text default null,
  role_filter text default 'all',
  disabled_filter text default 'all',
  feedback_filter text default 'all'
)
returns table (
  user_id uuid,
  email text,
  display_name text,
  masked_email text,
  is_admin boolean,
  is_disabled boolean,
  disabled_reason text,
  unresolved_feedback_count int,
  latest_feedback_at timestamptz,
  is_current_user boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_query text := nullif(lower(trim(query)), '');
  v_page_size int := greatest(1, least(coalesce(page_size, 20), 100));
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  return query
  with feedback_stats as (
    select
      lfs.user_id,
      count(*) filter (where lfs.status = 'pending')::int as unresolved_feedback_count,
      max(lfs.created_at) as latest_feedback_at
    from public.ledger_feedback_submissions lfs
    group by lfs.user_id
  )
  select
    u.id as user_id,
    coalesce(u.email, '') as email,
    coalesce(nullif(p.display_name, ''), u.email, '') as display_name,
    public.mask_email_for_admin(coalesce(u.email, '')) as masked_email,
    coalesce(la.is_active, false) as is_admin,
    coalesce(s.is_disabled, false) as is_disabled,
    s.disabled_reason,
    coalesce(fs.unresolved_feedback_count, 0) as unresolved_feedback_count,
    fs.latest_feedback_at,
    u.id = auth.uid() as is_current_user,
    u.created_at
  from auth.users u
  left join public.ledger_user_public_profiles p on p.user_id = u.id
  left join public.ledger_admins la on la.user_id = u.id
  left join public.ledger_user_admin_state s on s.user_id = u.id
  left join feedback_stats fs on fs.user_id = u.id
  where (cursor is null or u.created_at < cursor)
    and (
      v_query is null
      or lower(coalesce(u.email, '')) like '%' || v_query || '%'
      or lower(coalesce(p.display_name, '')) like '%' || v_query || '%'
      or lower(public.mask_email_for_admin(coalesce(u.email, ''))) like '%' || v_query || '%'
    )
    and (
      coalesce(role_filter, 'all') = 'all'
      or (role_filter = 'admin' and coalesce(la.is_active, false) = true)
      or (role_filter = 'user' and coalesce(la.is_active, false) = false)
    )
    and (
      coalesce(disabled_filter, 'all') = 'all'
      or (disabled_filter = 'disabled' and coalesce(s.is_disabled, false) = true)
      or (disabled_filter = 'enabled' and coalesce(s.is_disabled, false) = false)
    )
    and (
      coalesce(feedback_filter, 'all') = 'all'
      or (feedback_filter = 'pending' and coalesce(fs.unresolved_feedback_count, 0) > 0)
      or (feedback_filter = 'resolved' and coalesce(fs.unresolved_feedback_count, 0) = 0)
    )
  order by
    (u.id = auth.uid()) desc,
    coalesce(la.is_active, false) desc,
    u.created_at desc,
    u.id desc
  limit v_page_size;
end;
$$;

create or replace function public.admin_get_user_detail(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user auth.users%rowtype;
  v_public_profile public.ledger_user_public_profiles%rowtype;
  v_admin public.ledger_admins%rowtype;
  v_state public.ledger_user_admin_state%rowtype;
  v_today date := ((now() at time zone 'utc') + interval '8 hours')::date;
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  select *
  into v_user
  from auth.users
  where id = target_user_id;

  if not found then
    raise exception 'user_not_found';
  end if;

  select *
  into v_public_profile
  from public.ledger_user_public_profiles
  where user_id = target_user_id;

  select *
  into v_admin
  from public.ledger_admins
  where user_id = target_user_id;

  select *
  into v_state
  from public.ledger_user_admin_state
  where user_id = target_user_id;

  return jsonb_build_object(
    'user', jsonb_build_object(
      'user_id', v_user.id,
      'email', coalesce(v_user.email, ''),
      'display_name', coalesce(nullif(v_public_profile.display_name, ''), v_user.email, ''),
      'masked_email', public.mask_email_for_admin(coalesce(v_user.email, '')),
      'is_admin', coalesce(v_admin.is_active, false),
      'is_disabled', coalesce(v_state.is_disabled, false),
      'disabled_reason', v_state.disabled_reason,
      'is_current_user', v_user.id = auth.uid(),
      'created_at', v_user.created_at
    ),
    'stats', jsonb_build_object(
      'today_feedback_count', (
        select count(*)::int
        from public.ledger_feedback_submissions f
        where f.user_id = target_user_id
          and f.quota_date_utc8 = v_today
      ),
      'recent_feedback_count', (
        select count(*)::int
        from public.ledger_feedback_submissions f
        where f.user_id = target_user_id
      ),
      'pending_feedback_count', (
        select count(*)::int
        from public.ledger_feedback_submissions f
        where f.user_id = target_user_id
          and f.status = 'pending'
      )
    ),
    'feedbacks', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'user_id', f.user_id,
          'status', f.status,
          'content', f.content,
          'display_name_snapshot', f.display_name_snapshot,
          'masked_email_snapshot', f.masked_email_snapshot,
          'created_at', f.created_at,
          'resolved_at', f.resolved_at,
          'resolved_by', f.resolved_by
        )
        order by f.created_at desc
      )
      from (
        select *
        from public.ledger_feedback_submissions
        where user_id = target_user_id
        order by created_at desc
        limit 20
      ) f
    ), '[]'::jsonb),
    'audit_logs', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', log.id,
          'actor_user_id', log.actor_user_id,
          'target_user_id', log.target_user_id,
          'actor_display_name', coalesce(nullif(actor_profile.display_name, ''), actor_user.email, ''),
          'target_display_name', coalesce(nullif(target_profile.display_name, ''), target_user.email, ''),
          'action', log.action,
          'detail', log.detail,
          'created_at', log.created_at
        )
        order by log.created_at desc
      )
      from (
        select *
        from public.ledger_admin_audit_logs
        where target_user_id = $1
        order by created_at desc
        limit 20
      ) log
      left join auth.users actor_user on actor_user.id = log.actor_user_id
      left join auth.users target_user on target_user.id = log.target_user_id
      left join public.ledger_user_public_profiles actor_profile on actor_profile.user_id = actor_user.id
      left join public.ledger_user_public_profiles target_profile on target_profile.user_id = target_user.id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_grant_role(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  insert into public.ledger_admins (user_id, is_active)
  values (target_user_id, true)
  on conflict (user_id)
  do update set
    is_active = true,
    updated_at = now();

  perform public.write_admin_audit_log(
    target_user_id,
    'grant_admin',
    jsonb_build_object('target_user_id', target_user_id)
  );
end;
$$;

create or replace function public.admin_revoke_role(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_active_admin_count int;
  v_target_is_admin boolean;
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  if auth.uid() = target_user_id then
    raise exception 'cannot_revoke_self';
  end if;

  select coalesce(is_active, false)
  into v_target_is_admin
  from public.ledger_admins
  where user_id = target_user_id;

  if coalesce(v_target_is_admin, false) then
    select count(*)::int
    into v_active_admin_count
    from public.ledger_admins
    where is_active = true;

    if v_active_admin_count <= 1 then
      raise exception 'cannot_revoke_last_admin';
    end if;
  end if;

  update public.ledger_admins
  set
    is_active = false,
    updated_at = now()
  where user_id = target_user_id;

  perform public.write_admin_audit_log(
    target_user_id,
    'revoke_admin',
    jsonb_build_object('target_user_id', target_user_id)
  );
end;
$$;

create or replace function public.admin_disable_user(
  target_user_id uuid,
  reason text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_active_admin_count int;
  v_target_is_admin boolean;
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  if auth.uid() = target_user_id then
    raise exception 'cannot_disable_self';
  end if;

  select coalesce(is_active, false)
  into v_target_is_admin
  from public.ledger_admins
  where user_id = target_user_id;

  if coalesce(v_target_is_admin, false) then
    select count(*)::int
    into v_active_admin_count
    from public.ledger_admins
    where is_active = true;

    if v_active_admin_count <= 1 then
      raise exception 'cannot_disable_last_admin';
    end if;
  end if;

  insert into public.ledger_user_admin_state (
    user_id,
    is_disabled,
    disabled_reason,
    updated_at
  )
  values (
    target_user_id,
    true,
    nullif(trim(reason), ''),
    now()
  )
  on conflict (user_id)
  do update set
    is_disabled = true,
    disabled_reason = excluded.disabled_reason,
    updated_at = now();

  perform public.write_admin_audit_log(
    target_user_id,
    'disable_user',
    jsonb_build_object(
      'target_user_id', target_user_id,
      'reason', nullif(trim(reason), '')
    )
  );
end;
$$;

create or replace function public.admin_restore_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  insert into public.ledger_user_admin_state (
    user_id,
    is_disabled,
    disabled_reason,
    updated_at
  )
  values (
    target_user_id,
    false,
    null,
    now()
  )
  on conflict (user_id)
  do update set
    is_disabled = false,
    disabled_reason = null,
    updated_at = now();

  perform public.write_admin_audit_log(
    target_user_id,
    'restore_user',
    jsonb_build_object('target_user_id', target_user_id)
  );
end;
$$;

create or replace function public.admin_mark_feedback_resolved(feedback_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_target_user_id uuid;
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  update public.ledger_feedback_submissions
  set
    status = 'resolved',
    resolved_at = now(),
    resolved_by = auth.uid()
  where id = feedback_id
    and status <> 'resolved'
  returning user_id into v_target_user_id;

  if v_target_user_id is null then
    select user_id
    into v_target_user_id
    from public.ledger_feedback_submissions
    where id = feedback_id;
  end if;

  if v_target_user_id is null then
    raise exception 'feedback_not_found';
  end if;

  perform public.write_admin_audit_log(
    v_target_user_id,
    'resolve_feedback',
    jsonb_build_object(
      'feedback_id', feedback_id,
      'target_user_id', v_target_user_id
    )
  );
end;
$$;

create or replace function public.admin_list_audit_logs(
  target_user_id uuid default null,
  page_size int default 20,
  cursor timestamptz default null
)
returns table (
  id uuid,
  actor_user_id uuid,
  target_user_id uuid,
  actor_display_name text,
  target_display_name text,
  action text,
  detail jsonb,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_page_size int := greatest(1, least(coalesce(page_size, 20), 100));
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  return query
  select
    log.id,
    log.actor_user_id,
    log.target_user_id,
    coalesce(nullif(actor_profile.display_name, ''), actor_user.email, '') as actor_display_name,
    coalesce(nullif(target_profile.display_name, ''), target_user.email, '') as target_display_name,
    log.action,
    log.detail,
    log.created_at
  from public.ledger_admin_audit_logs log
  left join auth.users actor_user on actor_user.id = log.actor_user_id
  left join auth.users target_user on target_user.id = log.target_user_id
  left join public.ledger_user_public_profiles actor_profile on actor_profile.user_id = actor_user.id
  left join public.ledger_user_public_profiles target_profile on target_profile.user_id = target_user.id
  where ($1 is null or log.target_user_id = $1)
    and ($3 is null or log.created_at < $3)
  order by log.created_at desc, log.id desc
  limit v_page_size;
end;
$$;

grant execute on function public.get_current_user_admin_state() to authenticated;
grant execute on function public.admin_list_users(int, timestamptz, text, text, text, text) to authenticated;
grant execute on function public.admin_get_user_detail(uuid) to authenticated;
grant execute on function public.admin_grant_role(uuid) to authenticated;
grant execute on function public.admin_revoke_role(uuid) to authenticated;
grant execute on function public.admin_disable_user(uuid, text) to authenticated;
grant execute on function public.admin_restore_user(uuid) to authenticated;
grant execute on function public.admin_mark_feedback_resolved(uuid) to authenticated;
grant execute on function public.admin_list_audit_logs(uuid, int, timestamptz) to authenticated;

create or replace function public.admin_dashboard_metrics()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_pending_feedback_count int;
  v_suspicious_user_count int;
  v_total_request_count int;
  v_previous_request_count int;
  v_total_user_count int;
  v_disabled_user_count int;
  v_admin_user_count int;
  v_trend jsonb;
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  select count(*)::int
  into v_pending_feedback_count
  from public.ledger_feedback_submissions
  where status = 'pending';

  select count(*)::int
  into v_suspicious_user_count
  from (
    select user_id
    from public.ledger_feedback_submissions
    where created_at >= now() - interval '24 hours'
    group by user_id
    having count(*) >= 5
        or count(*) filter (where created_at >= now() - interval '1 hour') >= 3
  ) suspicious;

  select count(*)::int
  into v_total_request_count
  from public.ledger_feedback_submissions
  where created_at >= now() - interval '7 days';

  select count(*)::int
  into v_previous_request_count
  from public.ledger_feedback_submissions
  where created_at >= now() - interval '14 days'
    and created_at < now() - interval '7 days';

  select count(*)::int into v_total_user_count from auth.users;
  select count(*)::int into v_disabled_user_count from public.ledger_user_admin_state where is_disabled = true;
  select count(*)::int into v_admin_user_count from public.ledger_admins where is_active = true;

  with days as (
    select generate_series(
      date_trunc('day', now()) - interval '6 days',
      date_trunc('day', now()),
      interval '1 day'
    ) as day_start
  ),
  counts as (
    select
      date_trunc('day', created_at) as day_start,
      count(*)::int as total_count
    from public.ledger_feedback_submissions
    where created_at >= date_trunc('day', now()) - interval '6 days'
    group by date_trunc('day', created_at)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'label', to_char(days.day_start, 'MM-DD'),
        'count', coalesce(counts.total_count, 0)
      )
      order by days.day_start
    ),
    '[]'::jsonb
  )
  into v_trend
  from days
  left join counts on counts.day_start = days.day_start;

  return jsonb_build_object(
    'pending_feedback_count', coalesce(v_pending_feedback_count, 0),
    'suspicious_user_count', coalesce(v_suspicious_user_count, 0),
    'total_request_count', coalesce(v_total_request_count, 0),
    'request_delta', coalesce(v_total_request_count, 0) - coalesce(v_previous_request_count, 0),
    'total_user_count', coalesce(v_total_user_count, 0),
    'disabled_user_count', coalesce(v_disabled_user_count, 0),
    'admin_user_count', coalesce(v_admin_user_count, 0),
    'trend', coalesce(v_trend, '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_list_feedbacks(
  page_size int default 20,
  cursor timestamptz default null,
  query text default null,
  status_filter text default 'all'
)
returns table (
  feedback_id uuid,
  user_id uuid,
  user_display_name text,
  user_email text,
  user_masked_email text,
  status text,
  content text,
  created_at timestamptz,
  resolved_at timestamptz,
  resolved_by uuid
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_query text := nullif(lower(trim(query)), '');
  v_page_size int := greatest(1, least(coalesce(page_size, 20), 100));
begin
  if not public.is_current_admin() then
    raise exception 'forbidden';
  end if;

  return query
  select
    f.id as feedback_id,
    f.user_id,
    coalesce(nullif(p.display_name, ''), u.email, f.display_name_snapshot)::text as user_display_name,
    coalesce(u.email, '')::text as user_email,
    public.mask_email_for_admin(coalesce(u.email, f.masked_email_snapshot, ''))::text as user_masked_email,
    f.status::text as status,
    f.content::text as content,
    f.created_at,
    f.resolved_at,
    f.resolved_by
  from public.ledger_feedback_submissions f
  left join auth.users u on u.id = f.user_id
  left join public.ledger_user_public_profiles p on p.user_id = f.user_id
  where (cursor is null or f.created_at < cursor)
    and (
      v_query is null
      or lower(coalesce(u.email, '')) like '%' || v_query || '%'
      or lower(coalesce(p.display_name, '')) like '%' || v_query || '%'
      or lower(coalesce(f.content, '')) like '%' || v_query || '%'
      or lower(coalesce(f.masked_email_snapshot, '')) like '%' || v_query || '%'
    )
    and (
      coalesce(status_filter, 'all') = 'all'
      or f.status = status_filter
    )
  order by f.created_at desc, f.id desc
  limit v_page_size;
end;
$$;

grant execute on function public.admin_dashboard_metrics() to authenticated;
grant execute on function public.admin_list_feedbacks(int, timestamptz, text, text) to authenticated;
