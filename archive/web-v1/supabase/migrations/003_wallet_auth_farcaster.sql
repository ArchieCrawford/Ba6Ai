-- BA6 AI Web3 wallet auth + Farcaster identity support

-- Remove legacy nonce storage if present
DROP TABLE IF EXISTS public.wallet_nonces CASCADE;

-- Profiles: add wallet + Farcaster fields
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS wallet_login_provider text,
  ADD COLUMN IF NOT EXISTS wallet_address text,
  ADD COLUMN IF NOT EXISTS farcaster_fid text,
  ADD COLUMN IF NOT EXISTS farcaster_username text;

-- Wallets table (ensure web3 auth compatible schema)
CREATE TABLE IF NOT EXISTS public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  address text unique,
  chain_id text,
  created_at timestamp with time zone default now()
);

ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS chain_id text,
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone default now();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'wallets'
      AND column_name = 'chain_id'
      AND data_type IN ('integer', 'bigint', 'smallint')
  ) THEN
    ALTER TABLE public.wallets
      ALTER COLUMN chain_id TYPE text USING chain_id::text;
  END IF;
END $$;

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

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

CREATE POLICY "Users can delete own wallets"
  ON public.wallets FOR DELETE
  USING (auth.uid() = user_id);
