-- BA6 AI Stripe Sync Engine integration
-- NOTE: Install the Stripe Sync Engine in the Supabase Dashboard. Synced tables will appear under the stripe.* schema.

create extension if not exists "pgcrypto";

-- Remove legacy/manual Stripe webhook artifacts if present
DROP TABLE IF EXISTS public.stripe_webhook_events CASCADE;
DROP TABLE IF EXISTS public.stripe_webhooks CASCADE;
DROP TABLE IF EXISTS public.webhook_events CASCADE;
DROP FUNCTION IF EXISTS public.handle_stripe_webhook() CASCADE;
DROP FUNCTION IF EXISTS public.process_stripe_webhook() CASCADE;
DROP FUNCTION IF EXISTS public.stripe_webhook_handler() CASCADE;
DROP TRIGGER IF EXISTS stripe_webhook_trigger ON public.stripe_webhooks;

-- Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  avatar_url text,
  plan text default 'free',
  updated_at timestamp with time zone default now()
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS plan text default 'free',
  ADD COLUMN IF NOT EXISTS updated_at timestamp with time zone default now();

-- Wallets
CREATE TABLE IF NOT EXISTS public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  address text unique,
  chain_id integer,
  created_at timestamp with time zone default now()
);

ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS chain_id integer,
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone default now();

-- Usage tracking
CREATE TABLE IF NOT EXISTS public.usage_monthly (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id),
  month_key text,
  text_count integer default 0,
  image_count integer default 0,
  unique(user_id, month_key)
);

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_monthly ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own wallets" ON public.wallets;
DROP POLICY IF EXISTS "Users can insert own wallets" ON public.wallets;
DROP POLICY IF EXISTS "Users can delete own wallets" ON public.wallets;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view own wallets"
  ON public.wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallets"
  ON public.wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Optional but needed for unlinking wallets in-app
CREATE POLICY "Users can delete own wallets"
  ON public.wallets FOR DELETE
  USING (auth.uid() = user_id);

-- Stripe Sync Engine subscription view
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.schemata
    WHERE schema_name = 'stripe'
  ) THEN
    CREATE OR REPLACE VIEW public.subscription_status_all AS
    SELECT
      p.id AS user_id,
      c.email AS customer_email,
      s.id AS subscription_id,
      s.price_id,
      s.status AS subscription_status,
      s.current_period_end
    FROM stripe.subscriptions s
    JOIN stripe.customers c
      ON s.customer_id = c.id
    JOIN public.profiles p
      ON p.email = c.email;

    CREATE OR REPLACE VIEW public.subscription_status AS
    SELECT * FROM public.subscription_status_all
    WHERE user_id = auth.uid();
  END IF;
END $$;
