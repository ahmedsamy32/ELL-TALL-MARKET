-- Required schema additions for ELL TALL MARKET app
-- Safe-guard: create objects only if they don't already exist

-- Extensions for UUID and math
create extension if not exists "uuid-ossp";

-- Ensure profiles has a location field for proximity features
alter table if exists public.profiles
  add column if not exists last_known_location jsonb;

-- Users table (separate from profiles as used by UserService)
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  email text unique,
  phone text,
  avatar_url text,
  created_at timestamptz default now()
);
alter table public.users enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='users' AND policyname='Users are viewable by owner or admin'
) THEN
  CREATE POLICY "Users are viewable by owner or admin"
    ON public.users FOR SELECT
    USING ( auth.uid() = id OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.type = 'admin'
    ));
END IF;
END $$;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='users' AND policyname='Users can manage own row'
) THEN
  CREATE POLICY "Users can manage own row"
    ON public.users FOR ALL
    USING ( auth.uid() = id ) WITH CHECK ( auth.uid() = id );
END IF;
END $$;

-- Categories
create table if not exists public.categories (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  image_url text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz
);
alter table public.categories enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='categories' AND policyname='Categories are viewable by everyone'
) THEN
  CREATE POLICY "Categories are viewable by everyone"
    ON public.categories FOR SELECT USING (true);
END IF;
END $$;

-- Products
create table if not exists public.products (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  price numeric not null,
  sale_price numeric,
  category_id uuid references public.categories(id),
  store_id uuid references public.stores(id) on delete cascade,
  is_available boolean default true,
  images text[],
  stock_quantity integer default 0,
  unit text,
  rating numeric default 0,
  rating_count integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz
);
alter table public.products enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='products' AND policyname='Products are viewable by everyone'
) THEN
  CREATE POLICY "Products are viewable by everyone"
    ON public.products FOR SELECT USING (true);
END IF;
END $$;

-- Orders
create table if not exists public.orders (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id) on delete set null,
  store_id uuid references public.stores(id) on delete set null,
  captain_id uuid references public.profiles(id) on delete set null,
  status text default 'pending',
  total_amount numeric default 0,
  delivery_fee numeric default 0,
  -- Some parts of code use delivery_cost; provide it as well
  delivery_cost numeric default 0,
  discount_amount numeric default 0,
  final_amount numeric default 0,
  delivery_address text,
  -- Keep as text per current model parsing
  delivery_location text,
  -- Structured delivery fields used by DeliveryProvider
  pickup_location jsonb,
  delivery_location_json jsonb,
  delivery_status text,
  scheduled_delivery_time timestamptz,
  payment_status text default 'pending',
  notes text,
  cancellation_reason text,
  payment_collected_at timestamptz,
  payment_transferred_at timestamptz,
  payment_collected_by uuid references public.profiles(id),
  payment_notes text,
  created_at timestamptz default now(),
  updated_at timestamptz
);
alter table public.orders enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='orders' AND policyname='Orders are viewable by owner'
) THEN
  CREATE POLICY "Orders are viewable by owner"
    ON public.orders FOR SELECT USING ( auth.uid() = user_id OR auth.uid() = payment_collected_by );
END IF;
END $$;

-- Order items
create table if not exists public.order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references public.orders(id) on delete cascade,
  product_id uuid references public.products(id),
  quantity integer not null,
  unit_price numeric not null,
  total_price numeric not null,
  notes text
);
alter table public.order_items enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='order_items' AND policyname='Order items are viewable by everyone'
) THEN
  CREATE POLICY "Order items are viewable by everyone"
    ON public.order_items FOR SELECT USING (true);
END IF;
END $$;

-- Coupons
create table if not exists public.coupons (
  id uuid primary key default uuid_generate_v4(),
  store_id uuid references public.stores(id) on delete cascade,
  code text unique not null,
  is_active boolean default true,
  usage_count integer default 0,
  discount_amount numeric,
  discount_percent numeric,
  valid_from timestamptz,
  valid_to timestamptz,
  created_at timestamptz default now()
);
alter table public.coupons enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coupons' AND policyname='Coupons are viewable by everyone'
) THEN
  CREATE POLICY "Coupons are viewable by everyone"
    ON public.coupons FOR SELECT USING (true);
END IF;
END $$;

-- Coupon usages
create table if not exists public.coupon_usages (
  id uuid primary key default uuid_generate_v4(),
  coupon_id uuid references public.coupons(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete cascade,
  discount_amount numeric default 0,
  created_at timestamptz default now()
);
alter table public.coupon_usages enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='coupon_usages' AND policyname='Coupon usages are viewable by owner'
) THEN
  CREATE POLICY "Coupon usages are viewable by owner"
    ON public.coupon_usages FOR SELECT USING (auth.uid() = user_id);
END IF;
END $$;

-- Reviews
create table if not exists public.reviews (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid references public.products(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  images text[],
  created_at timestamptz default now()
);
alter table public.reviews enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='reviews' AND policyname='Reviews are viewable by everyone'
) THEN
  CREATE POLICY "Reviews are viewable by everyone"
    ON public.reviews FOR SELECT USING (true);
END IF;
END $$;

-- Notifications
create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  action text,
  data jsonb,
  is_read boolean default false,
  created_at timestamptz default now()
);
alter table public.notifications enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='notifications' AND policyname='Users can view their notifications'
) THEN
  CREATE POLICY "Users can view their notifications"
    ON public.notifications FOR SELECT USING (auth.uid() = user_id);
END IF;
END $$;

-- Cart items
create table if not exists public.cart_items (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  quantity integer not null,
  created_at timestamptz default now()
);
alter table public.cart_items enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='cart_items' AND policyname='Users can manage their own cart'
) THEN
  CREATE POLICY "Users can manage their own cart"
    ON public.cart_items FOR ALL
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
END IF;
END $$;

-- Returns (basic)
create table if not exists public.returns (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references public.orders(id) on delete cascade,
  reason text,
  status text default 'pending',
  created_at timestamptz default now()
);
alter table public.returns enable row level security;
DO $$ BEGIN
IF NOT EXISTS (
  SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='returns' AND policyname='Users can view their returns'
) THEN
  CREATE POLICY "Users can view their returns"
    ON public.returns FOR SELECT USING (
      EXISTS (SELECT 1 FROM public.orders o WHERE o.id = returns.order_id AND o.user_id = auth.uid())
    );
END IF;
END $$;

-- ============ RPC Functions ============
-- Haversine distance in KM between two lat/lng
create or replace function public.calculate_distance(lat1 double precision, lng1 double precision,
                                                     lat2 double precision, lng2 double precision)
returns double precision language plpgsql immutable as $$
begin
  return 2 * 6371 * asin(
    sqrt(
      pow(sin(radians((lat2 - lat1) / 2)), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians((lng2 - lng1) / 2)), 2)
    )
  );
end; $$;

-- Delivery cost estimation based on distance and parameters
create or replace function public.calculate_delivery_cost(
  pickup_lat double precision,
  pickup_lng double precision,
  delivery_lat double precision,
  delivery_lng double precision,
  base_cost numeric,
  cost_per_km numeric,
  min_cost numeric
) returns numeric language plpgsql stable as $$
declare
  dist double precision;
  cost numeric;
begin
  dist := public.calculate_distance(pickup_lat, pickup_lng, delivery_lat, delivery_lng);
  cost := base_cost + (dist * cost_per_km);
  if cost < min_cost then
    cost := min_cost;
  end if;
  return cost;
end; $$;

-- Nearby stores by location jsonb {lat, lng}
create or replace function public.get_nearby_stores(lat double precision, lng double precision, radius_km double precision)
returns table(id uuid, name text, distance double precision) language plpgsql stable as $$
begin
  return query
  select s.id, s.name,
         public.calculate_distance(
           (s.location->>'lat')::double precision,
           (s.location->>'lng')::double precision,
           lat, lng
         ) as distance
  from public.stores s
  where s.location is not null
    and public.calculate_distance((s.location->>'lat')::double precision,
                                  (s.location->>'lng')::double precision,
                                  lat, lng) <= radius_km
  order by distance asc;
end; $$;

-- Nearby captains by last_known_location on profiles
create or replace function public.get_nearby_captains(lat double precision, lng double precision, radius_km double precision)
returns table(captain_id uuid, distance double precision) language plpgsql stable as $$
begin
  return query
  select p.id as captain_id,
         public.calculate_distance(
           (p.last_known_location->>'lat')::double precision,
           (p.last_known_location->>'lng')::double precision,
           lat, lng
         ) as distance
  from public.profiles p
  where p.type = 'captain'
    and p.last_known_location is not null
    and public.calculate_distance((p.last_known_location->>'lat')::double precision,
                                  (p.last_known_location->>'lng')::double precision,
                                  lat, lng) <= radius_km
  order by distance asc;
end; $$;

-- Increment coupon usage counter
create or replace function public.increment_coupon_usage(coupon_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.coupons set usage_count = coalesce(usage_count,0) + 1 where id = coupon_id;
end; $$;

-- Get product rating
create or replace function public.get_product_rating(product_id uuid)
returns double precision language plpgsql stable as $$
declare avg_rating double precision;
begin
  select avg(r.rating)::double precision into avg_rating from public.reviews r where r.product_id = product_id;
  return coalesce(avg_rating, 0);
end; $$;

-- Update product rating and count
create or replace function public.update_product_rating(product_id uuid)
returns void language plpgsql security definer as $$
declare
  avg_rating numeric;
  cnt integer;
begin
  select avg(r.rating), count(*) into avg_rating, cnt from public.reviews r where r.product_id = product_id;
  update public.products
     set rating = coalesce(avg_rating, 0),
         rating_count = coalesce(cnt, 0),
         updated_at = now()
   where id = product_id;
end; $$;

-- Utility: check if listed tables exist
create or replace function public.check_tables_exist(table_names text[])
returns jsonb language plpgsql stable as $$
declare
  result jsonb := '{}'::jsonb;
  tbl text;
  exists_bool boolean;
begin
  foreach tbl in array table_names loop
    select exists (
      select 1 from information_schema.tables
      where table_schema = 'public' and table_name = tbl
    ) into exists_bool;
    result := result || jsonb_build_object(tbl, exists_bool);
  end loop;
  return result;
end; $$;
