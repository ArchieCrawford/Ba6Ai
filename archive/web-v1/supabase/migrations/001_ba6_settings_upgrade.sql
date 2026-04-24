-- BA6 AI Settings + Billing upgrade
-- Run in Supabase SQL editor or via migrations

create extension if not exists "pgcrypto";

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  plan text default 'free',
  stripe_customer_id text,
  stripe_subscription_id text,
  updated_at timestamp with time zone default now()
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists display_name text,
  add column if not exists avatar_url text,
  add column if not exists plan text default 'free',
  add column if not exists stripe_customer_id text,
  add column if not exists stripe_subscription_id text,
  add column if not exists updated_at timestamp with time zone default now();

-- Wallets
create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  address text unique,
  chain_id integer,
  created_at timestamp with time zone default now()
);

alter table public.wallets
  add column if not exists chain_id integer,
  add column if not exists created_at timestamp with time zone default now();

-- Monthly usage
create table if not exists public.usage_monthly (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  month_key text,
  text_count integer default 0,
  image_count integer default 0,
  unique(user_id, month_key)
);

-- Wallet nonces (for signature verification)
create table if not exists public.wallet_nonces (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  nonce text not null,
  created_at timestamp with time zone default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.wallet_nonces enable row level security;
alter table public.usage_monthly enable row level security;

-- Policies
-- Profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Wallets
DROP POLICY IF EXISTS "Users can view own wallets" ON public.wallets;
DROP POLICY IF EXISTS "Users can insert own wallets" ON public.wallets;

CREATE POLICY "Users can view own wallets"
  ON public.wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallets"
  ON public.wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Wallet nonces
DROP POLICY IF EXISTS "Users can view own wallet nonce" ON public.wallet_nonces;
DROP POLICY IF EXISTS "Users can upsert own wallet nonce" ON public.wallet_nonces;

CREATE POLICY "Users can view own wallet nonce"
  ON public.wallet_nonces FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can upsert own wallet nonce"
  ON public.wallet_nonces FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Usage monthly
DROP POLICY IF EXISTS "Users can view own usage monthly" ON public.usage_monthly;
CREATE POLICY "Users can view own usage monthly"
  ON public.usage_monthly FOR SELECT
  USING (auth.uid() = user_id);

-- Keep profile email in sync on new users
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, display_name, avatar_url, updated_at)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'display_name',
    coalesce(new.raw_user_meta_data->>'avatar_url', ''),
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$ language plpgsql security definer;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
