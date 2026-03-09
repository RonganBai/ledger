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
