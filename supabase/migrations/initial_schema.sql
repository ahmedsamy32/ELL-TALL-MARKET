-- Enable necessary extensions
create extension if not exists "uuid-ossp";

-- Create enum for user types (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace WHERE t.typname = 'user_type' AND n.nspname = 'public') THEN
    CREATE TYPE user_type AS ENUM ('customer', 'merchant', 'captain', 'admin');
  END IF;
END $$;

-- Create stores table first without FK to profiles (to avoid circular dependency at creation time)
create table if not exists public.stores (
    id uuid default uuid_generate_v4() primary key,
    owner_id uuid, -- FK added after profiles exists
    name text not null,
    description text,
    logo_url text,
    cover_url text,
    address text,
    location jsonb,
    category text,
    rating float default 0,
    rating_count integer default 0,
    is_active boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone
);

-- Create profiles table without FK to stores (add later)
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    name text not null,
    email text unique not null,
    phone text,
    type user_type default 'customer',
    avatar_url text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone,
    is_active boolean default true,
    last_login timestamp with time zone,
    login_count integer default 0,
    store_id uuid, -- FK added after stores exists
    preferred_payment_method text,
    address text,
    constraint proper_email check (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

-- Now add the cross-table foreign keys (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM   pg_constraint c
    JOIN   pg_class t ON c.conrelid = t.oid
    JOIN   pg_namespace n ON n.oid = t.relnamespace
    WHERE  c.conname = 'stores_owner_id_fkey'
    AND    n.nspname = 'public'
    AND    t.relname = 'stores'
  ) THEN
    ALTER TABLE public.stores
      ADD CONSTRAINT stores_owner_id_fkey
      FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM   pg_constraint c
    JOIN   pg_class t ON c.conrelid = t.oid
    JOIN   pg_namespace n ON n.oid = t.relnamespace
    WHERE  c.conname = 'profiles_store_id_fkey'
    AND    n.nspname = 'public'
    AND    t.relname = 'profiles'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_store_id_fkey
      FOREIGN KEY (store_id) REFERENCES public.stores(id);
  END IF;
END$$;

-- Create table for device tokens (for FCM)
create table if not exists public.device_tokens (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references public.profiles(id) on delete cascade,
    token text unique not null,
    platform text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    last_used timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create social auth providers table
create table if not exists public.user_providers (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references public.profiles(id) on delete cascade,
    provider text not null,
    provider_id text not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(provider, provider_id)
);

-- Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.device_tokens enable row level security;
alter table public.user_providers enable row level security;

-- Create policies (idempotent)
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Public profiles are viewable by everyone'
) THEN
  CREATE POLICY "Public profiles are viewable by everyone"
      ON public.profiles FOR SELECT
      USING ( true );
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Users can insert their own profile'
) THEN
  CREATE POLICY "Users can insert their own profile"
      ON public.profiles FOR INSERT
      WITH CHECK ( auth.uid() = id );
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Users can update their own profile'
) THEN
  CREATE POLICY "Users can update their own profile"
      ON public.profiles FOR UPDATE
      USING ( auth.uid() = id );
END IF; END $$;

-- Store policies
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stores' AND policyname='Stores are viewable by everyone'
) THEN
  CREATE POLICY "Stores are viewable by everyone"
      ON public.stores FOR SELECT
      USING ( true );
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stores' AND policyname='Store owners can insert their store'
) THEN
  CREATE POLICY "Store owners can insert their store"
      ON public.stores FOR INSERT
      WITH CHECK ( auth.uid() = owner_id );
END IF; END $$;

DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stores' AND policyname='Store owners can update their store'
) THEN
  CREATE POLICY "Store owners can update their store"
      ON public.stores FOR UPDATE
      USING ( auth.uid() = owner_id );
END IF; END $$;

-- Device token policies
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='device_tokens' AND policyname='Users can manage their own device tokens'
) THEN
  CREATE POLICY "Users can manage their own device tokens"
      ON public.device_tokens FOR ALL
      USING ( auth.uid() = user_id );
END IF; END $$;

-- Social provider policies
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='user_providers' AND policyname='Users can manage their own social providers'
) THEN
  CREATE POLICY "Users can manage their own social providers"
      ON public.user_providers FOR ALL
      USING ( auth.uid() = user_id );
END IF; END $$;

-- Create function to handle new user registration
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, name, email, created_at)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        new.email,
        new.created_at
    );
    return new;
end;
$$ language plpgsql security definer;

-- Create trigger for new user registration
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();
