-- Migration: Add captain auto-creation to handle_new_user trigger
-- Created: 2026-02-17
-- Purpose: Fix missing captain records when captain users register

-- =========================================
-- 0. Create get_nearby_available_orders RPC function
-- =========================================
CREATE OR REPLACE FUNCTION get_nearby_available_orders(
  captain_lat DOUBLE PRECISION,
  captain_lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 10.0
)
RETURNS TABLE (
  id UUID,
  client_id UUID,
  store_id UUID,
  captain_id UUID,
  order_group_id UUID,
  total_amount DECIMAL,
  delivery_fee DECIMAL,
  tax_amount DECIMAL,
  delivery_address TEXT,
  delivery_latitude DECIMAL,
  delivery_longitude DECIMAL,
  delivery_notes TEXT,
  status TEXT,
  payment_method TEXT,
  payment_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id,
    o.client_id,
    o.store_id,
    o.captain_id,
    o.order_group_id,
    o.total_amount,
    o.delivery_fee,
    o.tax_amount,
    o.delivery_address,
    o.delivery_latitude,
    o.delivery_longitude,
    o.delivery_notes,
    o.status,
    o.payment_method,
    o.payment_status,
    o.notes,
    o.created_at,
    o.updated_at,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(o.delivery_longitude, o.delivery_latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(captain_lng, captain_lat), 4326)::geography
    ) / 1000 AS distance_km
  FROM orders o
  WHERE o.captain_id IS NULL
    AND o.status IN ('confirmed', 'ready')
    AND o.delivery_latitude IS NOT NULL
    AND o.delivery_longitude IS NOT NULL
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(o.delivery_longitude, o.delivery_latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(captain_lng, captain_lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC;
END;
$$;

COMMENT ON FUNCTION get_nearby_available_orders IS 'Returns available orders near a captain location within specified radius';

-- =========================================
-- 1. Update handle_new_user trigger to create captain records
-- =========================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_role TEXT;
  v_store_name TEXT;
  v_full_name TEXT;
  v_phone TEXT;
  v_store_description TEXT;
  v_governorate TEXT;
  v_city TEXT;
  v_area TEXT;
  v_street TEXT;
  v_landmark TEXT;
  v_address TEXT;
  v_latitude DOUBLE PRECISION;
  v_longitude DOUBLE PRECISION;
  v_category TEXT;
  v_user_id UUID;
BEGIN
  -- Ensure this trigger can write to RLS-protected tables during signup.
  PERFORM set_config('row_security', 'off', true);

  v_user_id := NEW.id;

  RAISE LOG '[handle_new_user] start user_id=%, email=%', v_user_id, NEW.email;

  v_user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'client');
  v_full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    'User'
  );
  v_phone := NEW.raw_user_meta_data->>'phone';
  v_store_name := NEW.raw_user_meta_data->>'store_name';
  v_store_description := NEW.raw_user_meta_data->>'store_description';
  v_governorate := NEW.raw_user_meta_data->>'store_governorate';
  v_city := NEW.raw_user_meta_data->>'store_city';
  v_area := NEW.raw_user_meta_data->>'store_area';
  v_street := NEW.raw_user_meta_data->>'store_street';
  v_landmark := NEW.raw_user_meta_data->>'store_landmark';
  v_latitude := NULLIF(NEW.raw_user_meta_data->>'store_latitude', '')::double precision;
  v_longitude := NULLIF(NEW.raw_user_meta_data->>'store_longitude', '')::double precision;
  v_address := COALESCE(
    NULLIF(NEW.raw_user_meta_data->>'store_address', ''),
    NULLIF(NEW.raw_user_meta_data->>'address', ''),
    concat_ws('، ', NULLIF(v_governorate,''), NULLIF(v_city,''), NULLIF(v_area,''), NULLIF(v_street,''), NULLIF(v_landmark,''))
  );
  v_category := NEW.raw_user_meta_data->>'category';

  -- STRICT validation for merchants
  IF v_user_role = 'merchant' THEN
    IF COALESCE(NULLIF(v_store_name, ''), '') = '' THEN
      RAISE EXCEPTION 'merchant_store_name_required';
    END IF;
  END IF;

  -- Create profile for all users
  INSERT INTO public.profiles (id, full_name, email, phone, role, avatar_url)
  VALUES (
    v_user_id,
    v_full_name,
    NEW.email,
    v_phone,
    v_user_role,
    NEW.raw_user_meta_data->>'avatar_url'
  );

  -- For merchants: create merchant + store
  IF v_user_role = 'merchant' THEN
    INSERT INTO public.merchants (
      id,
      store_name,
      store_description,
      address,
      latitude,
      longitude,
      is_verified
    )
    VALUES (
      v_user_id,
      v_store_name,
      v_store_description,
      v_address,
      v_latitude,
      v_longitude,
      FALSE
    );

    INSERT INTO public.stores (
      merchant_id,
      name,
      description,
      phone,
      governorate,
      city,
      area,
      street,
      landmark,
      address,
      latitude,
      longitude,
      category
    )
    VALUES (
      v_user_id,
      v_store_name,
      v_store_description,
      v_phone,
      v_governorate,
      v_city,
      v_area,
      v_street,
      v_landmark,
      v_address,
      v_latitude,
      v_longitude,
      v_category
    );
  END IF;

  -- ✅ NEW: For captains, create captain record
  IF v_user_role = 'captain' THEN
    INSERT INTO public.captains (
      id,
      status,
      is_online,
      is_available,
      is_active,
      verification_status,
      contact_phone
    )
    VALUES (
      v_user_id,
      'offline',
      FALSE,
      TRUE,
      TRUE,
      'pending',
      v_phone
    );
    
    RAISE LOG '[handle_new_user] Created captain record for user_id=%', v_user_id;
  END IF;

  -- ✅ NEW: For clients, create client record
  IF v_user_role = 'client' THEN
    INSERT INTO public.clients (
      id
    )
    VALUES (
      v_user_id
    );
    
    RAISE LOG '[handle_new_user] Created client record for user_id=%', v_user_id;
  END IF;

  RETURN NEW;

EXCEPTION
  WHEN others THEN
    RAISE LOG '[handle_new_user] FAILED user_id=%, email=%, err=%', NEW.id, NEW.email, SQLERRM;
    RAISE;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS 
'Enhanced trigger function that creates profile and role-specific records for new users.
Features:
- Creates profile for all users
- For merchants: creates merchant record + store record
- For captains: creates captain record with default values
- For clients: creates client record
- Reads metadata from raw_user_meta_data
- Graceful error handling';

-- =========================================
-- 2. Backfill: Create missing captain records for existing captain profiles
-- =========================================
INSERT INTO public.captains (
  id,
  status,
  is_online,
  is_available,
  is_active,
  verification_status,
  contact_phone,
  created_at
)
SELECT 
  p.id,
  'offline',
  FALSE,
  TRUE,
  TRUE,
  'pending',
  p.phone,
  p.created_at
FROM public.profiles p
LEFT JOIN public.captains c ON p.id = c.id
WHERE p.role = 'captain' 
  AND c.id IS NULL;

-- ===Backfill: Create missing client records for existing client profiles
-- =========================================
INSERT INTO public.clients (
  id,
  created_at
)
SELECT 
  p.id,
  p.created_at
FROM public.profiles p
LEFT JOIN public.clients c ON p.id = c.id
WHERE p.role = 'client' 
  AND c.id IS NULL;

-- =========================================
-- 4. Log the results
-- =========================================
-- 4. Log the results
-- =========================================
DO $$
DECLARE
  v_captain_count INTEGER;
  v_client_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_captain_count
  FROM public.profiles p
  INNER JOIN public.captains c ON p.id = c.id
  WHERE p.role = 'captain';
  
  SELECT COUNT(*) INTO v_client_count
  FROM public.profiles p
  INNER JOIN public.clients c ON p.id = c.id
  WHERE p.role = 'client';
  
  RAISE NOTICE '✅ Captain records created/verified. Total captains: %', v_captain_count;
  RAISE NOTICE '✅ Client records created/verified. Total clients: %', v_client_count;
END $$;

-- =========================================
-- 5. Security Fixes from Database Linter
-- =========================================

-- Fix 1: Ensure order_details_view uses SECURITY INVOKER (not DEFINER)
-- This ensures RLS policies of the querying user are enforced, not the creator's
DROP VIEW IF EXISTS public.order_details_view CASCADE;
CREATE OR REPLACE VIEW public.order_details_view 
WITH (security_invoker = true) AS
SELECT 
  o.id,
  o.order_number,
  o.client_id,
  o.store_id,
  o.captain_id,
  o.status,
  o.total_amount,
  o.delivery_fee,
  o.tax_amount,
  o.delivery_address,
  o.delivery_latitude,
  o.delivery_longitude,
  o.delivery_notes,
  o.client_phone,
  o.payment_method,
  o.payment_status,
  o.cancellation_reason,
  o.cancelled_at,
  o.created_at,
  o.accepted_at,
  o.updated_at,
  c.full_name AS client_name,
  c.phone AS client_phone_profile,
  s.name AS store_name,
  s.address AS store_address,
  s.phone AS store_phone,
  cap.contact_phone AS captain_phone,
  p_cap.full_name AS captain_name
FROM orders o
LEFT JOIN profiles c ON o.client_id = c.id
LEFT JOIN stores s ON o.store_id = s.id
LEFT JOIN captains cap ON o.captain_id = cap.id
LEFT JOIN profiles p_cap ON cap.id = p_cap.id;

COMMENT ON VIEW public.order_details_view IS 'Order details view with SECURITY INVOKER - enforces RLS of querying user';
GRANT SELECT ON public.order_details_view TO authenticated;

-- Fix 2: PostGIS spatial_ref_sys table RLS
-- Note: This is a PostGIS system table owned by postgres superuser
-- We cannot modify it directly. If it appears in linter warnings,
-- it can be safely ignored as it's a read-only reference table
-- or excluded from PostgREST API exposure in the Supabase dashboard settings.

-- =========================================
-- Migration Complete
-- =========================================
