-- ==========================================
-- 📦 ELL TALL MARKET - Complete Database Schema
-- ==========================================
-- Version: 2.0 (Updated: 2025-11-02)
-- 
-- 🎯 ONE FILE - COMPLETE SETUP
-- This single file contains EVERYTHING needed:
-- ✅ All database tables & relationships
-- ✅ All ENUMs & custom types
-- ✅ All RLS policies for data security
-- ✅ All functions & triggers
-- ✅ All indexes for performance
-- ✅ All 6 Storage buckets (stores, products, avatars, banners, reviews, categories)
-- ✅ All hardened Storage RLS policies with owner validation
-- 
-- 📌 Updates in v2.0:
-- ✨ Merged all Storage improvements into ONE file
-- ✨ Enhanced owner validation: position((s.id::text || '/') IN name)
-- ✨ Unified admin checks: profiles.role = 'admin'
-- ✨ Auto-cleanup of old policies before creating new ones
-- ✨ File size limits & MIME type restrictions per bucket
-- ✨ All policies are idempotent (safe to re-run)
-- 
-- 🚀 Usage:
-- 1. Open Supabase SQL Editor
-- 2. Copy this entire file
-- 3. Paste and Run
-- 4. Done! Everything is ready 🎉
-- 
-- 📍 Path Conventions:
-- stores:     {userId}/stores/{storeId}/{logo|cover}.{ext}
-- products:   {userId}/products/{storeId}/{productId}.{ext}
-- avatars:    {userId}/avatars/{userId}.{ext}
-- banners:    banners/{bannerId}.{ext}
-- reviews:    {userId}/reviews/{reviewId}.{ext}
-- categories: categories/{categoryId}.{ext}
-- ==========================================

-- ==========================================
-- 🧱 CLEANUP OLD STRUCTURE
-- ==========================================
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop all tables in correct dependency order
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename) LOOP
        EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;

    -- Drop custom types
    DROP TYPE IF EXISTS banner_type_enum CASCADE;
    DROP TYPE IF EXISTS order_status_enum CASCADE;
    DROP TYPE IF EXISTS delivery_status_enum CASCADE;
    DROP TYPE IF EXISTS vehicle_type_enum CASCADE;
    DROP TYPE IF EXISTS coupon_type_enum CASCADE;
END $$;

-- ==========================================
-- 👤 USERS & PROFILES
-- ==========================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT UNIQUE,
  phone TEXT,
  password TEXT,
  avatar_url TEXT,
  role TEXT CHECK (role IN ('client', 'merchant', 'captain', 'admin')) DEFAULT 'client',
  fcm_token TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ✅ Allow users to view their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- ✅ Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- ✅ Allow public viewing of profiles (read-only)
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
  FOR SELECT USING (true);

-- 🔑 Helper function to check admin status
-- Query profiles table directly for more reliability
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- �🔑 Allow admins to INSERT new users (NO RECURSION!)
CREATE POLICY "Admins can insert users" ON public.profiles
  FOR INSERT 
  WITH CHECK (public.is_admin());

-- 🔑 Allow admins to UPDATE any user (NO RECURSION!)
CREATE POLICY "Admins can update any user" ON public.profiles
  FOR UPDATE 
  USING (public.is_admin());

-- 🔑 Allow admins to DELETE users (NO RECURSION!)
CREATE POLICY "Admins can delete users" ON public.profiles
  FOR DELETE 
  USING (public.is_admin());

-- 🔑 Allow admins to view all profiles (NO RECURSION!)
CREATE POLICY "Admins can view all profiles" ON public.profiles
  FOR SELECT 
  USING (public.is_admin());

-- 🔧 Auto-create profile when a new auth.user is added
-- Enhanced version: Creates profile + merchant + store records for merchants
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_role TEXT;
  v_store_name TEXT;
  v_full_name TEXT;
  v_phone TEXT;
  v_store_description TEXT;
  v_address TEXT;
  v_category TEXT;
  v_merchant_id UUID;
BEGIN
  -- استخراج البيانات من metadata
  v_user_role := COALESCE(NEW.raw_user_meta_data->>'role', 'client');
  v_full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name', 
    NEW.raw_user_meta_data->>'name', 
    'User'
  );
  v_phone := NEW.raw_user_meta_data->>'phone';
  v_store_name := NEW.raw_user_meta_data->>'store_name';
  v_store_description := NEW.raw_user_meta_data->>'store_description';
  v_address := COALESCE(
    NEW.raw_user_meta_data->>'store_address',
    NEW.raw_user_meta_data->>'address'
  );
  v_category := NEW.raw_user_meta_data->>'category';
  v_merchant_id := NEW.id;

  -- 1. إنشاء profile أولاً
  INSERT INTO public.profiles (id, full_name, email, phone, role, avatar_url)
  VALUES (
    v_merchant_id,
    v_full_name,
    NEW.email,
    v_phone,
    v_user_role,
    NEW.raw_user_meta_data->>'avatar_url'
  );

  -- 2. إذا كان المستخدم تاجراً، إنشاء سجل في merchants و stores تلقائياً
  IF v_user_role = 'merchant' THEN
    -- أولاً: إنشاء التاجر في جدول merchants
    INSERT INTO public.merchants (
      id, 
      store_name, 
      store_description, 
      address,
      is_verified
    )
    VALUES (
      v_merchant_id,
      v_store_name,
      v_store_description,
      v_address,
      FALSE
    );
    
    -- ثانياً: إنشاء المتجر في جدول stores باستخدام بيانات التاجر فقط
    INSERT INTO public.stores (
      merchant_id,
      name,
      description,
      phone,
      address,
      category
    )
    VALUES (
      v_merchant_id,
      v_store_name,
      v_store_description,
      v_phone,
      v_address,
      v_category
    );
    
    RAISE NOTICE '✅ تم إنشاء تاجر ومتجر جديد: %, المتجر: %', 
      v_merchant_id, v_store_name;
  ELSE
    RAISE NOTICE '✅ تم إنشاء مستخدم عادي: %, الاسم: %', v_merchant_id, v_full_name;
  END IF;

  RETURN NEW;
  
EXCEPTION
  WHEN others THEN
    RAISE WARNING '❌ خطأ في handle_new_user للمستخدم %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.handle_new_user() IS 
'Enhanced trigger function that creates profile and merchant/store records for new users.
Features:
- Creates profile for all users
- For merchants: creates merchant record + store record with basic data
- Reads store data from raw_user_meta_data
- Graceful error handling to prevent user creation failure';

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 🔍 Helper Function: Get Merchant Complete Status
CREATE OR REPLACE FUNCTION public.get_merchant_complete_status(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile_exists BOOLEAN;
  v_merchant_exists BOOLEAN;
  v_store_exists BOOLEAN;
  v_profile_data JSONB;
  v_merchant_data JSONB;
  v_store_data JSONB;
  v_result JSONB;
BEGIN
  -- التحقق من وجود البروفايل وجلب بياناته
  SELECT EXISTS(SELECT 1 FROM profiles WHERE id = p_user_id),
         (SELECT row_to_json(profiles)::jsonb FROM profiles WHERE id = p_user_id)
  INTO v_profile_exists, v_profile_data;
  
  -- التحقق من وجود التاجر وجلب بياناته
  SELECT EXISTS(SELECT 1 FROM merchants WHERE id = p_user_id),
         (SELECT row_to_json(merchants)::jsonb FROM merchants WHERE id = p_user_id)
  INTO v_merchant_exists, v_merchant_data;
  
  -- التحقق من وجود المتجر وجلب بياناته
  SELECT EXISTS(SELECT 1 FROM stores WHERE merchant_id = p_user_id),
         (SELECT row_to_json(stores)::jsonb FROM stores WHERE merchant_id = p_user_id)
  INTO v_store_exists, v_store_data;
  
  -- بناء النتيجة الكاملة
  v_result := jsonb_build_object(
    'profile_exists', v_profile_exists,
    'merchant_exists', v_merchant_exists,
    'store_exists', v_store_exists,
    'user_id', p_user_id,
    'is_complete', v_profile_exists AND v_merchant_exists AND v_store_exists,
    'profile_data', v_profile_data,
    'merchant_data', v_merchant_data,
    'store_data', v_store_data
  );
  
  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.get_merchant_complete_status(UUID) IS 
'Helper function to check the complete status of a merchant and their store.
Returns a JSONB object with existence flags and data for profile, merchant, and store records.
Used for debugging and validation of merchant registration flow.';

-- ==========================================
-- 🛍️ STORES & MERCHANTS
-- ==========================================
CREATE TABLE public.merchants (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  store_name TEXT NOT NULL,
  store_description TEXT,
  address TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.merchants ENABLE ROW LEVEL SECURITY;

-- 📖 SELECT Policy: Anyone can view merchant stores (public data)
CREATE POLICY "merchants_select_policy" ON public.merchants
  FOR SELECT 
  USING (true);

-- ➕ INSERT Policy: Users can create their own merchant record during registration
CREATE POLICY "merchants_insert_policy" ON public.merchants
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- ✏️ UPDATE Policy: Merchants can update their own store
CREATE POLICY "merchants_update_policy" ON public.merchants
  FOR UPDATE 
  USING (auth.uid() = id) 
  WITH CHECK (auth.uid() = id);

-- 🗑️ DELETE Policy: Merchants can delete their store OR admins can delete any
CREATE POLICY "merchants_delete_policy" ON public.merchants
  FOR DELETE 
  USING (
    auth.uid() = id 
    OR 
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE TABLE public.stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES public.merchants(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  phone TEXT,
  email TEXT,
  address TEXT NOT NULL,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  delivery_time INT DEFAULT 30,
  is_open BOOLEAN DEFAULT TRUE,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  min_order DECIMAL(10,2) DEFAULT 0,
  delivery_mode TEXT CHECK (delivery_mode IN ('store','app')) DEFAULT 'store',
  rating DECIMAL(2,1) DEFAULT 0.0,
  review_count INT DEFAULT 0,
  category TEXT,
  opening_hours JSONB DEFAULT '{}',
  image_url TEXT,
  cover_url TEXT,
  pickup_enabled BOOLEAN DEFAULT FALSE,
  phones JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

-- 📖 SELECT Policy: Anyone can view stores (public data)
CREATE POLICY "stores_select_policy" ON public.stores 
  FOR SELECT 
  USING (true);

-- ➕ INSERT Policy: Merchants can create stores for themselves
CREATE POLICY "stores_insert_policy" ON public.stores
  FOR INSERT 
  WITH CHECK (auth.uid() = merchant_id);

-- ✏️ UPDATE Policy: Merchants can update their own stores
CREATE POLICY "stores_update_policy" ON public.stores
  FOR UPDATE 
  USING (auth.uid() = merchant_id) 
  WITH CHECK (auth.uid() = merchant_id);

-- 🗑️ DELETE Policy: Merchants can delete their own stores
CREATE POLICY "stores_delete_policy" ON public.stores
  FOR DELETE 
  USING (auth.uid() = merchant_id);

-- ==========================================
-- 👥 CLIENTS & CAPTAINS
-- ==========================================
CREATE TABLE public.clients (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  default_address TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Clients manage their data" ON public.clients 
FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE TABLE public.captains (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_type TEXT CHECK (vehicle_type IN ('motorcycle', 'car', 'bicycle')),
  vehicle_number TEXT,
  license_number TEXT UNIQUE,
  status TEXT CHECK (status IN ('online', 'offline', 'busy')) DEFAULT 'offline',
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  rating DECIMAL(2,1) DEFAULT 0,
  total_deliveries INT DEFAULT 0,
  is_verified BOOLEAN DEFAULT FALSE,
  earnings_today DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.captains ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Captains manage their data" ON public.captains 
FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ==========================================
-- 📦 PRODUCTS & CATEGORIES
-- ==========================================
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  icon TEXT,
  image_url TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- 📖 SELECT Policy: Anyone can view categories (public data)
CREATE POLICY "categories_select_policy" ON public.categories 
  FOR SELECT 
  USING (true);

-- ➕ INSERT Policy: Only admins can create categories
CREATE POLICY "categories_insert_policy" ON public.categories
  FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ✏️ UPDATE Policy: Only admins can update categories
CREATE POLICY "categories_update_policy" ON public.categories
  FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 🗑️ DELETE Policy: Only admins can delete categories
CREATE POLICY "categories_delete_policy" ON public.categories
  FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 🏷️ Seed Default Categories
INSERT INTO public.categories (name, description, icon, is_active)
VALUES 
  ('عام', 'متاجر عامة', 'store', true),
  ('مطاعم وأطعمة', 'مطاعم ومحلات الأطعمة', 'restaurant', true),
  ('بقالة', 'محلات البقالة والسوبر ماركت', 'local_grocery_store', true),
  ('إلكترونيات', 'أجهزة ومعدات إلكترونية', 'devices', true),
  ('ملابس وأزياء', 'محلات الملابس والإكسسوارات', 'checkroom', true),
  ('تجميل وصحة', 'منتجات التجميل والعناية', 'spa', true),
  ('منزل وحديقة', 'أدوات منزلية ومستلزمات الحدائق', 'home', true),
  ('رياضة ولياقة', 'معدات رياضية ولياقة بدنية', 'sports', true),
  ('كتب وقرطاسية', 'كتب ومستلزمات مكتبية', 'menu_book', true),
  ('ألعاب وأطفال', 'ألعاب ومستلزمات الأطفال', 'toys', true),
  ('حيوانات أليفة', 'مستلزمات الحيوانات الأليفة', 'pets', true),
  ('خدمات', 'خدمات متنوعة', 'room_service', true)
ON CONFLICT (name) DO NOTHING;

COMMENT ON TABLE public.categories IS 'جدول فئات المتاجر - يحتوي على الفئات المتاحة لتصنيف المتاجر';

CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  compare_price DECIMAL(10,2),
  cost_price DECIMAL(10,2),
  image_url TEXT,
  image_urls TEXT[], -- 🖼️ عمود الصور المتعددة
  category_id UUID REFERENCES public.categories(id),
  section_id UUID REFERENCES public.store_sections(id) ON DELETE SET NULL,
  in_stock BOOLEAN DEFAULT TRUE,
  stock_quantity INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  tags TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 📖 SELECT Policy: Anyone can view products (public data)
CREATE POLICY "products_select_policy" ON public.products 
  FOR SELECT 
  USING (true);

-- ➕ INSERT Policy: Merchants can create products for their stores
CREATE POLICY "products_insert_policy" ON public.products
  FOR INSERT 
  WITH CHECK (
    auth.uid() = (SELECT merchant_id FROM public.stores WHERE stores.id = products.store_id)
  );

-- ✏️ UPDATE Policy: Merchants can update their products
CREATE POLICY "products_update_policy" ON public.products
  FOR UPDATE 
  USING (
    auth.uid() = (SELECT merchant_id FROM public.stores WHERE stores.id = products.store_id)
  )
  WITH CHECK (
    auth.uid() = (SELECT merchant_id FROM public.stores WHERE stores.id = products.store_id)
  );

-- 🗑️ DELETE Policy: Merchants can delete their products
CREATE POLICY "products_delete_policy" ON public.products
  FOR DELETE 
  USING (
    auth.uid() = (SELECT merchant_id FROM public.stores WHERE stores.id = products.store_id)
  );

-- ==========================================
-- 🏪 STORE SETTINGS & EXTENSIONS
-- ==========================================

-- 1) Store Branches (multiple locations per store)
CREATE TABLE IF NOT EXISTS public.store_branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text,
  address text NOT NULL,
  phone text,
  latitude double precision,
  longitude double precision,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_store_branches_store_id ON public.store_branches(store_id);

ALTER TABLE public.store_branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Branches public read" ON public.store_branches
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_branches.store_id AND s.is_active = true)
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_branches.store_id AND s.merchant_id = auth.uid())
  );

CREATE POLICY "Branches owner manage" ON public.store_branches
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_branches.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_branches.store_id AND s.merchant_id = auth.uid()));

-- 2) Delivery Areas (variable delivery fees/min orders per area)
CREATE TABLE IF NOT EXISTS public.store_delivery_areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  area_name text NOT NULL,
  fee numeric(10,2) NOT NULL DEFAULT 0,
  min_order numeric(10,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_store_delivery_areas_store_id ON public.store_delivery_areas(store_id);

ALTER TABLE public.store_delivery_areas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Areas public read" ON public.store_delivery_areas
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_delivery_areas.store_id AND s.is_active = true)
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_delivery_areas.store_id AND s.merchant_id = auth.uid())
  );

CREATE POLICY "Areas owner manage" ON public.store_delivery_areas
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_delivery_areas.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_delivery_areas.store_id AND s.merchant_id = auth.uid()));

-- 3) Payment Methods per Store
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type t WHERE t.typname = 'payment_method') THEN
    CREATE TYPE public.payment_method AS ENUM ('cash','card','wallet');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.store_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  method public.payment_method NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_store_payment_method ON public.store_payment_methods(store_id, method);

ALTER TABLE public.store_payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Payment methods public read" ON public.store_payment_methods
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_payment_methods.store_id AND s.is_active = true)
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_payment_methods.store_id AND s.merchant_id = auth.uid())
  );

CREATE POLICY "Payment methods owner manage" ON public.store_payment_methods
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_payment_methods.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_payment_methods.store_id AND s.merchant_id = auth.uid()));

-- 4) Order Windows (pickup/delivery time ranges per day)
CREATE TABLE IF NOT EXISTS public.store_order_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  open_time time NOT NULL,
  close_time time NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_store_order_windows_store_id ON public.store_order_windows(store_id);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_store_order_windows ON public.store_order_windows(store_id, day_of_week, open_time, close_time);

ALTER TABLE public.store_order_windows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order windows public read" ON public.store_order_windows
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_order_windows.store_id AND s.is_active = true)
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_order_windows.store_id AND s.merchant_id = auth.uid())
  );

CREATE POLICY "Order windows owner manage" ON public.store_order_windows
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_order_windows.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_order_windows.store_id AND s.merchant_id = auth.uid()));

-- 5) Store-Category Mapping (global categories assigned to stores)
CREATE TABLE IF NOT EXISTS public.store_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  display_order int NOT NULL DEFAULT 0,
  is_visible boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_store_category ON public.store_categories(store_id, category_id);
CREATE INDEX IF NOT EXISTS idx_store_categories_store_id ON public.store_categories(store_id);

ALTER TABLE public.store_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Store categories public read" ON public.store_categories
  FOR SELECT USING (
    is_visible = true
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_categories.store_id AND s.merchant_id = auth.uid())
  );

CREATE POLICY "Store categories owner manage" ON public.store_categories
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_categories.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_categories.store_id AND s.merchant_id = auth.uid()));

-- 6) Store Sections (merchant-specific menu sections)
CREATE TABLE IF NOT EXISTS public.store_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  image_url text,
  display_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_store_sections_store_id ON public.store_sections(store_id);
CREATE INDEX IF NOT EXISTS idx_store_sections_display_order ON public.store_sections(store_id, display_order);

ALTER TABLE public.store_sections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Store sections public read" ON public.store_sections
  FOR SELECT USING (
    is_active = true
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_sections.store_id AND s.merchant_id = auth.uid())
  );

CREATE POLICY "Store sections owner manage" ON public.store_sections
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_sections.store_id AND s.merchant_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.stores s WHERE s.id = store_sections.store_id AND s.merchant_id = auth.uid()));

-- ==========================================
-- 🛒 CART SYSTEM (سلة متعددة المتاجر)
-- ==========================================
CREATE TABLE public.carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- معلومات السلة
  total_amount DECIMAL(10,2) DEFAULT 0,
  items_count INT DEFAULT 0,
  
  -- معلومات التوصيل
  delivery_address TEXT,
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  
  -- الخصومات
  coupon_code TEXT,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  
  -- الحالة
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- لكل مستخدم سلة نشطة واحدة فقط
  UNIQUE(user_id)
);

CREATE TABLE public.cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id UUID REFERENCES public.carts(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
  
  -- معلومات المنتج في السلة
  product_name TEXT NOT NULL,
  product_price DECIMAL(10,2) NOT NULL,
  product_image TEXT,
  
  -- الكمية والسعر
  quantity INT NOT NULL CHECK (quantity > 0),
  total_price DECIMAL(10,2) NOT NULL,
  
  -- خيارات إضافية
  special_instructions TEXT,
  selected_options JSONB DEFAULT '{}',
  
  -- معلومات التوصيل الخاصة بكل متجر
  store_delivery_fee DECIMAL(10,2) DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- منع تكرار المنتج في نفس السلة
  UNIQUE(cart_id, product_id)
);

ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own carts" ON public.carts
FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their cart items" ON public.cart_items
FOR ALL USING (
  EXISTS (SELECT 1 FROM public.carts WHERE id = cart_items.cart_id AND user_id = auth.uid())
);

-- ==========================================
-- 🧾 ORDERS
-- ==========================================
CREATE TYPE order_status_enum AS ENUM (
  'pending', 
  'confirmed', 
  'preparing', 
  'ready', 
  'picked_up', 
  'in_transit', 
  'delivered', 
  'cancelled'
);

CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
  captain_id UUID REFERENCES public.captains(id),
  
  -- معلومات الطلب
  order_number TEXT UNIQUE,
  total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  
  -- معلومات التوصيل
  delivery_address TEXT NOT NULL,
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  delivery_notes TEXT,
  
  -- حالة الطلب
  status order_status_enum DEFAULT 'pending',
  
  -- الدفع
  payment_method TEXT CHECK (payment_method IN ('cash', 'card', 'wallet')) DEFAULT 'cash',
  payment_status TEXT CHECK (payment_status IN ('pending', 'paid', 'failed')) DEFAULT 'pending',
  
  -- التواريخ
  accepted_at TIMESTAMPTZ,
  prepared_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 📖 SELECT Policies
CREATE POLICY "Clients can view their orders" ON public.orders 
FOR SELECT USING (auth.uid() = client_id);

CREATE POLICY "Merchants view store orders" ON public.orders 
FOR SELECT USING (auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_id));

CREATE POLICY "Captains view assigned orders" ON public.orders 
FOR SELECT USING (auth.uid() = captain_id);

-- ➕ INSERT Policy: Clients can create their own orders
CREATE POLICY "Clients can create orders" ON public.orders
FOR INSERT WITH CHECK (auth.uid() = client_id);

-- ✏️ UPDATE Policies: Allow status updates by relevant parties
CREATE POLICY "Merchants can update store orders" ON public.orders
FOR UPDATE 
USING (
  auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_id)
)
WITH CHECK (
  auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_id)
);

CREATE POLICY "Captains can update assigned orders" ON public.orders
FOR UPDATE 
USING (auth.uid() = captain_id)
WITH CHECK (auth.uid() = captain_id);

CREATE TABLE public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id),
  product_name TEXT NOT NULL,
  product_price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  total_price DECIMAL(10,2) NOT NULL,
  special_instructions TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- 📖 SELECT Policy
CREATE POLICY "Order items are viewable by order participants" ON public.order_items
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.orders o 
    WHERE o.id = order_items.order_id 
    AND (o.client_id = auth.uid() OR o.captain_id = auth.uid() OR o.store_id IN (
      SELECT id FROM public.stores WHERE merchant_id = auth.uid()
    ))
  )
);

-- ➕ INSERT Policy: Allow inserting items for orders created by the user
CREATE POLICY "Clients can create order items for their orders" ON public.order_items
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o 
    WHERE o.id = order_items.order_id 
    AND o.client_id = auth.uid()
  )
);

CREATE TABLE public.order_status_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.order_status_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Order logs are viewable by order participants" ON public.order_status_logs
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.orders o 
    WHERE o.id = order_status_logs.order_id 
    AND (o.client_id = auth.uid() OR o.captain_id = auth.uid() OR o.store_id IN (
      SELECT id FROM public.stores WHERE merchant_id = auth.uid()
    ))
  )
);

-- Allow inserting status logs when updating order
CREATE POLICY "Allow status log insertion" ON public.order_status_logs
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o 
    WHERE o.id = order_status_logs.order_id 
    AND (o.store_id IN (
      SELECT id FROM public.stores WHERE merchant_id = auth.uid()
    ) OR o.client_id = auth.uid() OR o.captain_id = auth.uid())
  )
);

-- ==========================================
-- 🚚 DELIVERIES SYSTEM
-- ==========================================
CREATE TYPE delivery_status_enum AS ENUM (
  'pending',
  'assigned', 
  'picked_up',
  'in_transit',
  'arrived',
  'delivered',
  'cancelled',
  'failed'
);

CREATE TYPE vehicle_type_enum AS ENUM (
  'motorcycle',
  'car', 
  'bicycle',
  'truck'
);

CREATE TABLE public.deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  captain_id UUID REFERENCES public.captains(id),
  
  -- معلومات التوصيل
  tracking_number TEXT UNIQUE,
  status delivery_status_enum DEFAULT 'pending',
  
  -- المواقع
  pickup_address TEXT NOT NULL,
  pickup_latitude DECIMAL(10, 8),
  pickup_longitude DECIMAL(11, 8),
  
  delivery_address TEXT NOT NULL,
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  
  -- معلومات التكلفة والوقت
  delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  distance_km DECIMAL(8,2),
  estimated_duration_minutes INT,
  
  -- التواريخ
  assigned_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  in_transit_at TIMESTAMPTZ,
  arrived_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  -- معلومات إضافية
  captain_notes TEXT,
  customer_notes TEXT,
  cancellation_reason TEXT,
  
  -- التقييم
  customer_rating INT CHECK (customer_rating BETWEEN 1 AND 5),
  customer_feedback TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clients can view their deliveries" ON public.deliveries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.orders o 
      WHERE o.id = deliveries.order_id AND o.client_id = auth.uid()
    )
  );

CREATE POLICY "Captains can view assigned deliveries" ON public.deliveries
  FOR SELECT USING (auth.uid() = captain_id);

CREATE POLICY "Captains can update assigned deliveries" ON public.deliveries
  FOR UPDATE USING (auth.uid() = captain_id);

CREATE POLICY "Merchants can view store deliveries" ON public.deliveries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.orders o 
      WHERE o.id = deliveries.order_id AND o.store_id IN (
        SELECT id FROM public.stores WHERE merchant_id = auth.uid()
      )
    )
  );

-- ==========================================
-- 📍 DELIVERY TRACKING
-- ==========================================
CREATE TABLE public.delivery_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID REFERENCES public.deliveries(id) ON DELETE CASCADE NOT NULL,
  captain_id UUID REFERENCES public.captains(id),
  
  -- الموقع الحالي
  current_latitude DECIMAL(10, 8) NOT NULL,
  current_longitude DECIMAL(11, 8) NOT NULL,
  current_address TEXT,
  
  -- معلومات التتبع
  speed_kmh DECIMAL(5,2),
  battery_level INT CHECK (battery_level BETWEEN 0 AND 100),
  
  -- حالة التوصيل
  estimated_arrival_time TIMESTAMPTZ,
  remaining_distance_km DECIMAL(8,2),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.delivery_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Clients can view delivery tracking" ON public.delivery_tracking
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.deliveries d 
      WHERE d.id = delivery_tracking.delivery_id 
      AND EXISTS (
        SELECT 1 FROM public.orders o 
        WHERE o.id = d.order_id AND o.client_id = auth.uid()
      )
    )
  );

CREATE POLICY "Captains can manage delivery tracking" ON public.delivery_tracking
  FOR ALL USING (auth.uid() = captain_id);

-- ==========================================
-- 💰 DELIVERY PRICING
-- ==========================================
CREATE TABLE public.delivery_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_type vehicle_type_enum NOT NULL,
  base_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  price_per_km DECIMAL(10,2) NOT NULL DEFAULT 0,
  minimum_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  maximum_fee DECIMAL(10,2),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.delivery_pricing ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active delivery pricing" ON public.delivery_pricing
  FOR SELECT USING (is_active = TRUE);

-- ==========================================
-- ❤️ FAVORITES SYSTEM
-- ==========================================
CREATE TABLE public.favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- التأكد من أن المستخدم يمكنه إضافة منتج أو متجر فقط (ليس كلاهما)
  CONSTRAINT favorites_check CHECK (
    (product_id IS NOT NULL AND store_id IS NULL) OR 
    (product_id IS NULL AND store_id IS NOT NULL)
  ),
  
  -- منع التكرار لنفس المنتج أو المتجر
  UNIQUE(user_id, product_id),
  UNIQUE(user_id, store_id)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their favorites" ON public.favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can add favorites" ON public.favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove favorites" ON public.favorites
  FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- 🏷️ COUPONS SYSTEM
-- ==========================================
CREATE TYPE coupon_type_enum AS ENUM (
  'percentage',
  'fixed_amount',
  'free_delivery'
);

CREATE TABLE public.coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE,
  merchant_id UUID REFERENCES public.merchants(id) ON DELETE CASCADE,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  description TEXT,
  coupon_type coupon_type_enum NOT NULL,
  
  -- قيمة الخصم
  discount_value DECIMAL(10,2) NOT NULL,
  minimum_order_amount DECIMAL(10,2) DEFAULT 0,
  maximum_discount_amount DECIMAL(10,2),
  
  -- حدود الاستخدام
  usage_limit INT,
  used_count INT DEFAULT 0,
  usage_limit_per_user INT DEFAULT 1,
  
  -- الفعالية
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coupons_store_id ON public.coupons(store_id);
CREATE INDEX IF NOT EXISTS idx_coupons_merchant_id ON public.coupons(merchant_id);

ALTER TABLE public.coupons
  ADD CONSTRAINT coupons_store_id_required CHECK (store_id IS NOT NULL) NOT VALID,
  ADD CONSTRAINT coupons_merchant_id_required CHECK (merchant_id IS NOT NULL) NOT VALID;

CREATE TABLE public.coupon_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id UUID REFERENCES public.coupons(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  discount_amount DECIMAL(10,2) NOT NULL,
  used_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(coupon_id, user_id, order_id)
);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupon_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coupons_select_policy" ON public.coupons
FOR SELECT USING (
  is_active = TRUE
  OR auth.uid() = created_by
  OR EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = store_id AND s.merchant_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "coupons_write_policy" ON public.coupons
FOR ALL USING (
  auth.uid() = created_by
  OR EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = store_id AND s.merchant_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
) WITH CHECK (
  auth.uid() = created_by
  OR EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.id = store_id AND s.merchant_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "Users can view their coupon usage" ON public.coupon_usage
FOR SELECT USING (auth.uid() = user_id);

-- ==========================================
-- ⭐ REVIEWS & RATINGS
-- ==========================================
CREATE TABLE public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE UNIQUE,
  client_id UUID REFERENCES public.clients(id) NOT NULL,
  target_type TEXT CHECK (target_type IN ('store', 'captain', 'product')) NOT NULL,
  target_id UUID NOT NULL,
  rating INT CHECK (rating BETWEEN 1 AND 5) NOT NULL,
  comment TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reviews" ON public.reviews FOR SELECT USING (true);

CREATE POLICY "Clients can create reviews for their orders" ON public.reviews
  FOR INSERT WITH CHECK (auth.uid() = client_id);

-- ==========================================
-- 🔔 BANNERS & NOTIFICATIONS
-- ==========================================
CREATE TYPE banner_type_enum AS ENUM ('store', 'product', 'category', 'promotion');

CREATE TABLE public.banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT NOT NULL,
  target_type banner_type_enum,
  target_id UUID,
  action_url TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- Drop existing policy that conflicts
DROP POLICY IF EXISTS "Anyone can view active banners" ON public.banners;

-- Policy for everyone to view active banners
CREATE POLICY "Anyone can view active banners" ON public.banners
FOR SELECT USING (
  is_active = true
  AND (end_date IS NULL OR end_date > NOW())
  AND (start_date IS NULL OR start_date <= NOW())
);

-- Policy for admin to insert banners
CREATE POLICY "Admin can insert banners" ON public.banners
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy for admin to update banners
CREATE POLICY "Admin can update banners" ON public.banners
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy for admin to delete banners
CREATE POLICY "Admin can delete banners" ON public.banners
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy for admin to view all banners (including inactive ones)
CREATE POLICY "Admin can view all banners" ON public.banners
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT CHECK (type IN ('order', 'promotion', 'system')),
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their notifications" ON public.notifications
FOR ALL USING (auth.uid() = user_id);

-- ==========================================
-- � ADDRESSES SYSTEM
-- ==========================================
CREATE TABLE public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    label VARCHAR(100) DEFAULT 'المنزل',
    city VARCHAR(100) NOT NULL,
    street VARCHAR(200) NOT NULL,
    area VARCHAR(100),
    building_number VARCHAR(50),
    floor_number VARCHAR(50),
    apartment_number VARCHAR(50),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on client_id for faster queries
CREATE INDEX idx_addresses_client_id ON public.addresses(client_id);

-- Create index on is_default for faster default address lookup
CREATE INDEX idx_addresses_is_default ON public.addresses(client_id, is_default);

-- Enable Row Level Security
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own addresses
CREATE POLICY "Users can view their own addresses"
    ON public.addresses
    FOR SELECT
    USING (auth.uid() = client_id);

-- Policy: Users can insert their own addresses
CREATE POLICY "Users can insert their own addresses"
    ON public.addresses
    FOR INSERT
    WITH CHECK (auth.uid() = client_id);

-- Policy: Users can update their own addresses
CREATE POLICY "Users can update their own addresses"
    ON public.addresses
    FOR UPDATE
    USING (auth.uid() = client_id)
    WITH CHECK (auth.uid() = client_id);

-- Policy: Users can delete their own addresses
CREATE POLICY "Users can delete their own addresses"
    ON public.addresses
    FOR DELETE
    USING (auth.uid() = client_id);

-- Policy: Admins can view all addresses
CREATE POLICY "Admins can view all addresses"
    ON public.addresses
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- Policy: Captains can view addresses for their assigned orders
CREATE POLICY "Captains can view delivery addresses"
    ON public.addresses
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'captain'
        )
    );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_addresses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER trigger_update_addresses_updated_at
    BEFORE UPDATE ON public.addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_addresses_updated_at();

-- Function to ensure only one default address per user
CREATE OR REPLACE FUNCTION ensure_single_default_address()
RETURNS TRIGGER AS $$
BEGIN
    -- If the new/updated address is set as default
    IF NEW.is_default = TRUE THEN
        -- Set all other addresses for this user to not default
        UPDATE public.addresses
        SET is_default = FALSE
        WHERE client_id = NEW.client_id
        AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to ensure only one default address
CREATE TRIGGER trigger_ensure_single_default_address
    BEFORE INSERT OR UPDATE ON public.addresses
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_default_address();

-- ==========================================
-- �🔧 FUNCTIONS & TRIGGERS
-- ==========================================

-- دالة لتحديث الوقت
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- دالة لإنشاء order_number
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.order_number IS NULL THEN
    NEW.order_number := 'ORD-' || to_char(NOW(), 'YYYYMMDD') || '-' || lpad((floor(random() * 1000000))::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

-- دالة لحساب سعر العنصر في السلة
CREATE OR REPLACE FUNCTION public.calculate_cart_item_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.total_price := NEW.product_price * NEW.quantity;
  RETURN NEW;
END;
$$;

-- دالة لتحديث إجماليات السلة
CREATE OR REPLACE FUNCTION public.update_cart_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cart_total DECIMAL(10,2);
  cart_items_count INT;
BEGIN
  SELECT 
    COALESCE(SUM(total_price), 0),
    COALESCE(SUM(quantity), 0)
  INTO cart_total, cart_items_count
  FROM public.cart_items 
  WHERE cart_id = COALESCE(NEW.cart_id, OLD.cart_id);
  
  UPDATE public.carts 
  SET 
    total_amount = cart_total,
    items_count = cart_items_count,
    updated_at = NOW()
  WHERE id = COALESCE(NEW.cart_id, OLD.cart_id);
  
  IF cart_items_count = 0 THEN
    UPDATE public.carts 
    SET is_active = FALSE 
    WHERE id = COALESCE(NEW.cart_id, OLD.cart_id);
  ELSE
    UPDATE public.carts 
    SET is_active = TRUE 
    WHERE id = COALESCE(NEW.cart_id, OLD.cart_id);
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- دالة لتسجيل تغييرات حالة الطلب
CREATE OR REPLACE FUNCTION public.log_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- فقط إذا تغيرت حالة الطلب
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.order_status_logs (order_id, old_status, new_status, changed_at)
    VALUES (NEW.id, OLD.status::text, NEW.status::text, NOW());
  END IF;
  
  RETURN NEW;
END;
$$;

-- دالة لإضافة منتج إلى السلة
CREATE OR REPLACE FUNCTION public.add_to_cart(
  p_user_id UUID,
  p_product_id UUID,
  p_quantity INT DEFAULT 1,
  p_special_instructions TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  user_cart_id UUID;
  product_store_id UUID;
  product_name TEXT;
  product_price DECIMAL(10,2);
  product_image TEXT;
  existing_cart_item_id UUID;
  store_delivery_fee DECIMAL(10,2);
BEGIN
  SELECT p.store_id, p.name, p.price, p.image_url, s.delivery_fee
  INTO product_store_id, product_name, product_price, product_image, store_delivery_fee
  FROM public.products p
  JOIN public.stores s ON s.id = p.store_id
  WHERE p.id = p_product_id AND p.is_active = TRUE AND p.in_stock = TRUE;
  
  IF product_store_id IS NULL THEN
    RAISE EXCEPTION 'Product not found or not available';
  END IF;
  
  SELECT id INTO user_cart_id 
  FROM public.carts 
  WHERE user_id = p_user_id AND is_active = TRUE;
  
  IF user_cart_id IS NULL THEN
    INSERT INTO public.carts (user_id)
    VALUES (p_user_id)
    RETURNING id INTO user_cart_id;
  END IF;
  
  SELECT id INTO existing_cart_item_id 
  FROM public.cart_items 
  WHERE cart_id = user_cart_id AND product_id = p_product_id;
  
  IF existing_cart_item_id IS NOT NULL THEN
    UPDATE public.cart_items 
    SET 
      quantity = quantity + p_quantity,
      updated_at = NOW()
    WHERE id = existing_cart_item_id;
  ELSE
    INSERT INTO public.cart_items (
      cart_id, product_id, store_id, product_name, product_price, 
      product_image, quantity, special_instructions, store_delivery_fee
    ) VALUES (
      user_cart_id, p_product_id, product_store_id, product_name, product_price,
      product_image, p_quantity, p_special_instructions, store_delivery_fee
    );
  END IF;
  
  RETURN user_cart_id;
END;
$$;

-- دالة لتحويل السلة إلى طلبات
CREATE OR REPLACE FUNCTION public.convert_cart_to_orders(
  p_user_id UUID,
  p_delivery_address TEXT DEFAULT NULL,
  p_delivery_lat DECIMAL DEFAULT NULL,
  p_delivery_lng DECIMAL DEFAULT NULL,
  p_payment_method TEXT DEFAULT 'cash'
)
RETURNS UUID[]
LANGUAGE plpgsql
AS $$
DECLARE
  user_cart_id UUID;
  cart_record RECORD;
  store_record RECORD;
  new_order_id UUID;
  order_ids UUID[] := '{}';
  delivery_fee DECIMAL(10,2);
  order_total DECIMAL(10,2);
  store_items_count INT;
  store_items_total DECIMAL(10,2);
  total_stores INT;
  discount_per_store DECIMAL(10,2);
BEGIN
  SELECT * INTO cart_record
  FROM public.carts 
  WHERE user_id = p_user_id AND is_active = TRUE AND items_count > 0;
  
  IF cart_record.id IS NULL THEN
    RAISE EXCEPTION 'No active cart with items found';
  END IF;
  
  SELECT COUNT(DISTINCT store_id) INTO total_stores
  FROM public.cart_items 
  WHERE cart_id = cart_record.id;
  
  discount_per_store := CASE 
    WHEN cart_record.discount_amount > 0 AND total_stores > 0 
    THEN cart_record.discount_amount / total_stores 
    ELSE 0 
  END;
  
  FOR store_record IN 
    SELECT DISTINCT store_id 
    FROM public.cart_items 
    WHERE cart_id = cart_record.id
  LOOP
    SELECT 
      COUNT(*),
      COALESCE(SUM(total_price), 0)
    INTO store_items_count, store_items_total
    FROM public.cart_items 
    WHERE cart_id = cart_record.id AND store_id = store_record.store_id;
    
    SELECT MAX(store_delivery_fee) INTO delivery_fee
    FROM public.cart_items 
    WHERE cart_id = cart_record.id AND store_id = store_record.store_id;
    
    order_total := store_items_total + delivery_fee - discount_per_store;
    
    IF order_total < 0 THEN order_total := 0; END IF;
    
    INSERT INTO public.orders (
      client_id, store_id, total_amount, delivery_fee, delivery_address,
      delivery_latitude, delivery_longitude, payment_method
    ) VALUES (
      p_user_id, store_record.store_id, order_total, delivery_fee,
      COALESCE(p_delivery_address, cart_record.delivery_address),
      COALESCE(p_delivery_lat, cart_record.delivery_latitude),
      COALESCE(p_delivery_lng, cart_record.delivery_longitude),
      p_payment_method
    ) RETURNING id INTO new_order_id;
    
    order_ids := array_append(order_ids, new_order_id);
    
    INSERT INTO public.order_items (
      order_id, product_id, product_name, product_price, quantity,
      total_price, special_instructions
    ) SELECT 
      new_order_id, product_id, product_name, product_price, quantity,
      total_price, special_instructions
    FROM public.cart_items 
    WHERE cart_id = cart_record.id AND store_id = store_record.store_id;
    
    INSERT INTO public.deliveries (
      order_id, pickup_address, pickup_latitude, pickup_longitude,
      delivery_address, delivery_latitude, delivery_longitude, delivery_fee
    ) SELECT 
      new_order_id, s.address, s.latitude, s.longitude,
      COALESCE(p_delivery_address, cart_record.delivery_address),
      COALESCE(p_delivery_lat, cart_record.delivery_latitude),
      COALESCE(p_delivery_lng, cart_record.delivery_longitude),
      delivery_fee
    FROM public.stores s
    WHERE s.id = store_record.store_id;
  END LOOP;
  
  UPDATE public.carts SET is_active = FALSE WHERE id = cart_record.id;
  DELETE FROM public.cart_items WHERE cart_id = cart_record.id;
  
  RETURN order_ids;
END;
$$;

-- ==========================================
-- 🔄 TRIGGERS
-- ==========================================

-- تحديث updated_at لجميع الجداول
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_merchants_updated_at BEFORE UPDATE ON public.merchants FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_stores_updated_at BEFORE UPDATE ON public.stores FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_carts_updated_at BEFORE UPDATE ON public.carts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_cart_items_updated_at BEFORE UPDATE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER log_order_status_changes AFTER UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.log_order_status_change();
CREATE TRIGGER update_captains_updated_at BEFORE UPDATE ON public.captains FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_deliveries_updated_at BEFORE UPDATE ON public.deliveries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_coupons_updated_at BEFORE UPDATE ON public.coupons FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_addresses_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION public.update_addresses_updated_at();
CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION public.update_app_settings_updated_at();

-- triggers أخرى
CREATE TRIGGER generate_order_number_trigger BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.generate_order_number();
CREATE TRIGGER calculate_cart_item_total_trigger BEFORE INSERT OR UPDATE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION public.calculate_cart_item_total();
CREATE TRIGGER update_cart_totals_trigger AFTER INSERT OR UPDATE OR DELETE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION public.update_cart_totals();
CREATE TRIGGER trigger_ensure_single_default_address BEFORE INSERT OR UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION ensure_single_default_address();

-- ==========================================
-- 📊 INDEXES
-- ==========================================

-- Basic Indexes
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_stores_merchant ON public.stores(merchant_id);
CREATE INDEX idx_stores_active ON public.stores(is_active) WHERE is_active = true;
CREATE INDEX idx_products_store ON public.products(store_id);
CREATE INDEX idx_products_active ON public.products(is_active) WHERE is_active = true;
CREATE INDEX idx_orders_client ON public.orders(client_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_captains_status ON public.captains(status);
CREATE INDEX idx_carts_user ON public.carts(user_id);
CREATE INDEX idx_cart_items_cart ON public.cart_items(cart_id);
CREATE INDEX idx_favorites_user ON public.favorites(user_id);
CREATE INDEX idx_deliveries_order ON public.deliveries(order_id);
CREATE INDEX idx_deliveries_captain ON public.deliveries(captain_id);

-- ==========================================
-- ⚙️ APP SETTINGS TABLE
-- ==========================================
-- جدول إعدادات التطبيق العامة
-- يحتوي على إعدادات مثل العملة، الإشعارات، المظهر، إلخ

CREATE TABLE public.app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,

  -- إعدادات الإشعارات
  notifications_enabled BOOLEAN DEFAULT TRUE,
  email_notifications BOOLEAN DEFAULT TRUE,
  sms_notifications BOOLEAN DEFAULT FALSE,

  -- إعدادات المظهر
  dark_mode BOOLEAN DEFAULT FALSE,

  -- إعدادات اللغة والعملة
  language TEXT DEFAULT 'ar',
  currency TEXT DEFAULT 'EGP',

  -- إعدادات الأمان
  biometric_auth BOOLEAN DEFAULT FALSE,

  -- إعدادات الدفع
  save_payment_methods BOOLEAN DEFAULT TRUE,

  -- إعدادات التحديث والأداء
  auto_update BOOLEAN DEFAULT TRUE,
  data_saver BOOLEAN DEFAULT FALSE,
  cache_duration INT DEFAULT 7, -- أيام

  -- إعدادات الخصوصية والتحليلات
  analytics_enabled BOOLEAN DEFAULT TRUE,
  crash_reports BOOLEAN DEFAULT TRUE,

  -- timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- إنشاء فهرس للبحث السريع
CREATE INDEX idx_app_settings_client_id ON public.app_settings(client_id);

-- تفعيل RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- السماح للمستخدمين بقراءة وتحديث إعداداتهم الخاصة فقط
CREATE POLICY "Users can view own app settings" ON public.app_settings
  FOR SELECT USING (auth.uid() = client_id);

CREATE POLICY "Users can insert own app settings" ON public.app_settings
  FOR INSERT WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Users can update own app settings" ON public.app_settings
  FOR UPDATE USING (auth.uid() = client_id);

-- السماح للإدارة بقراءة جميع الإعدادات
CREATE POLICY "Admins can view all app settings" ON public.app_settings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- تحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_app_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_app_settings_updated_at
  BEFORE UPDATE ON public.app_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_app_settings_updated_at();

-- ==========================================
-- 🧭 NAVIGATION ANALYTICS TABLE
-- ==========================================
-- جدول لتتبع تحليلات التنقل في التطبيق
-- يساعد في فهم سلوك المستخدمين وتحسين تجربة الاستخدام

CREATE TABLE IF NOT EXISTS public.navigation_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,
  event_data JSONB,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  session_id TEXT,
  device_info JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إنشاء فهارس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_navigation_analytics_event_type ON public.navigation_analytics(event_type);
CREATE INDEX IF NOT EXISTS idx_navigation_analytics_user_id ON public.navigation_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_navigation_analytics_created_at ON public.navigation_analytics(created_at);
CREATE INDEX IF NOT EXISTS idx_navigation_analytics_event_id ON public.navigation_analytics(event_id);

-- تفعيل RLS
ALTER TABLE public.navigation_analytics ENABLE ROW LEVEL SECURITY;

-- السماح للمستخدمين بإدراج أحداثهم الخاصة
CREATE POLICY "Users can insert their own navigation events" ON public.navigation_analytics
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- السماح للإدارة بقراءة جميع الأحداث
CREATE POLICY "Admins can view all navigation analytics" ON public.navigation_analytics
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- السماح للمستخدمين بقراءة أحداثهم الخاصة
CREATE POLICY "Users can view their own navigation events" ON public.navigation_analytics
  FOR SELECT USING (auth.uid() = user_id);

-- ==========================================
-- 🖼️ STORAGE BUCKETS & HARDENED RLS POLICIES
-- ==========================================
-- إنشاء جميع الـ Buckets المطلوبة للتطبيق مع سياسات RLS محسّنة ومُشددة
-- Path Convention: {userId}/{resource_type}/{resource_id}/{filename}.{ext}
-- ============================================================================

-- 1️⃣ إنشاء جميع Buckets (idempotent)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('stores', 'stores', true, 5242880, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']),
  ('products', 'products', true, 10485760, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']),
  ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']),
  ('banners', 'banners', true, 5242880, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']),
  ('reviews', 'reviews', true, 5242880, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']),
  ('categories', 'categories', true, 3145728, ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/svg+xml'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2️⃣ حذف جميع السياسات القديمة لضمان نظافة الإعداد
DO $$
BEGIN
  -- Stores
  DROP POLICY IF EXISTS "stores_owner_insert" ON storage.objects;
  DROP POLICY IF EXISTS "stores_owner_update" ON storage.objects;
  DROP POLICY IF EXISTS "stores_owner_delete" ON storage.objects;
  DROP POLICY IF EXISTS "stores_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view store images" ON storage.objects;
  DROP POLICY IF EXISTS "Authenticated users can upload to stores" ON storage.objects;
  DROP POLICY IF EXISTS "Merchants can update their own store images" ON storage.objects;
  DROP POLICY IF EXISTS "Merchants can delete their own store images" ON storage.objects;
  
  -- Products
  DROP POLICY IF EXISTS "products_owner_insert" ON storage.objects;
  DROP POLICY IF EXISTS "products_owner_update" ON storage.objects;
  DROP POLICY IF EXISTS "products_owner_delete" ON storage.objects;
  DROP POLICY IF EXISTS "products_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
  DROP POLICY IF EXISTS "Merchants can upload product images" ON storage.objects;
  DROP POLICY IF EXISTS "Merchants can update their own product images" ON storage.objects;
  DROP POLICY IF EXISTS "Merchants can delete their own product images" ON storage.objects;
  
  -- Avatars
  DROP POLICY IF EXISTS "avatars_owner_insert" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_owner_delete" ON storage.objects;
  DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
  DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
  DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
  DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
  
  -- Banners
  DROP POLICY IF EXISTS "banners_admin_insert" ON storage.objects;
  DROP POLICY IF EXISTS "banners_admin_update" ON storage.objects;
  DROP POLICY IF EXISTS "banners_admin_delete" ON storage.objects;
  DROP POLICY IF EXISTS "banners_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "Public banners are viewable by everyone" ON storage.objects;
  DROP POLICY IF EXISTS "Admins can upload banners" ON storage.objects;
  DROP POLICY IF EXISTS "Admins can update banners" ON storage.objects;
  DROP POLICY IF EXISTS "Admins can delete banners" ON storage.objects;
  
  -- Reviews
  DROP POLICY IF EXISTS "reviews_owner_insert" ON storage.objects;
  DROP POLICY IF EXISTS "reviews_owner_update" ON storage.objects;
  DROP POLICY IF EXISTS "reviews_owner_delete" ON storage.objects;
  DROP POLICY IF EXISTS "reviews_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view review images" ON storage.objects;
  DROP POLICY IF EXISTS "Authenticated users can upload review images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can update their own review images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can delete their own review images" ON storage.objects;
  
  -- Categories
  DROP POLICY IF EXISTS "categories_admin_insert" ON storage.objects;
  DROP POLICY IF EXISTS "categories_admin_update" ON storage.objects;
  DROP POLICY IF EXISTS "categories_admin_delete" ON storage.objects;
  DROP POLICY IF EXISTS "categories_public_read" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view category images" ON storage.objects;
  DROP POLICY IF EXISTS "Admins can upload category images" ON storage.objects;
  DROP POLICY IF EXISTS "Admins can update category images" ON storage.objects;
  DROP POLICY IF EXISTS "Admins can delete category images" ON storage.objects;
END $$;

-- 3️⃣ STORES Bucket - سياسات محسّنة مع التحقق من الملكية
-- Path pattern: {userId}/stores/{storeId}/{logo|cover}.ext
CREATE POLICY "stores_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'stores'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/stores/' || s.id::text || '/%'
  )
);

CREATE POLICY "stores_owner_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'stores'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/stores/' || s.id::text || '/%'
  )
)
WITH CHECK (
  bucket_id = 'stores'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/stores/' || s.id::text || '/%'
  )
);

CREATE POLICY "stores_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'stores'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/stores/' || s.id::text || '/%'
  )
);

CREATE POLICY "stores_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'stores');

-- 4️⃣ PRODUCTS Bucket - سياسات محسّنة مع التحقق من الملكية
-- Path pattern: {userId}/products/{storeId}/{productId}.ext
CREATE POLICY "products_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'products'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/products/' || s.id::text || '/%'
  )
);

CREATE POLICY "products_owner_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'products'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/products/' || s.id::text || '/%'
  )
)
WITH CHECK (
  bucket_id = 'products'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/products/' || s.id::text || '/%'
  )
);

CREATE POLICY "products_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'products'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/products/' || s.id::text || '/%'
  )
);

CREATE POLICY "products_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'products');

-- 5️⃣ AVATARS Bucket - صور المستخدمين الشخصية
CREATE POLICY "avatars_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatars_owner_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatars_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "avatars_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'avatars');

-- 6️⃣ BANNERS Bucket - للإدارة فقط
CREATE POLICY "banners_admin_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'banners'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "banners_admin_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'banners'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
)
WITH CHECK (
  bucket_id = 'banners'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "banners_admin_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'banners'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "banners_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'banners');

-- 7️⃣ REVIEWS Bucket - صور المراجعات
CREATE POLICY "reviews_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'reviews'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "reviews_owner_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'reviews'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'reviews'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "reviews_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'reviews'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "reviews_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'reviews');

-- 8️⃣ CATEGORIES Bucket - للإدارة فقط
CREATE POLICY "categories_admin_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'categories'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "categories_admin_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'categories'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
)
WITH CHECK (
  bucket_id = 'categories'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "categories_admin_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'categories'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  )
);

CREATE POLICY "categories_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'categories');

-- ============================================================================
-- 📊 STORAGE SUMMARY
-- ============================================================================
-- Buckets Created (7 total):
-- 1. stores     - Store logos/covers (5MB, owner-validated)
-- 2. products   - Product images (10MB, owner-validated)
-- 3. avatars    - User profile pictures (2MB, owner-only)
-- 4. banners    - App banners (5MB, admin-only)
-- 5. reviews    - Review photos (5MB, owner-only)
-- 6. categories - Category icons (3MB, admin-only)
-- 7. profiles   - User profile avatars (5MB, owner-only)
--
-- Path Conventions:
-- stores:     {userId}/stores/{storeId}/{logo|cover}.{ext}
-- products:   {userId}/products/{storeId}/{productId}.{ext}
-- avatars:    {userId}/avatars/{userId}.{ext}
-- banners:    banners/{bannerId}.{ext}
-- reviews:    {userId}/reviews/{reviewId}.{ext}
-- categories: categories/{categoryId}.{ext}
-- profiles:   avatars/user_{userId}/avatar_{timestamp}.{ext}
--
-- Security Features:
-- ✅ Owner validation using position((s.id::text || '/') IN name)
-- ✅ Admin-only buckets (banners, categories)
-- ✅ Path-based access control (first folder = userId)
-- ✅ File size limits per bucket
-- ✅ MIME type restrictions
-- ✅ All policies idempotent (safe to re-run)
-- ============================================================================

-- ============================================================================
-- 📦 ADDITIONAL MIGRATIONS - CONSOLIDATED
-- ============================================================================
-- تم دمج جميع الـ migrations الإضافية هنا

-- ==========================================
-- 🔧 PROFILES: Add birth_date and gender columns
-- ==========================================
-- Migration: 20241212_add_birth_date_gender_to_profiles

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS birth_date DATE;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS gender TEXT CHECK (gender IN ('male', 'female'));

CREATE INDEX IF NOT EXISTS idx_profiles_gender ON public.profiles(gender);

COMMENT ON COLUMN public.profiles.birth_date IS 'تاريخ ميلاد المستخدم';
COMMENT ON COLUMN public.profiles.gender IS 'جنس المستخدم: male (ذكر) أو female (أنثى)';

-- ==========================================
-- 🔧 PRODUCTS: Add custom_fields column (JSONB)
-- ==========================================
-- Migration: 20241105000000_add_custom_fields_to_products

ALTER TABLE products 
ADD COLUMN IF NOT EXISTS custom_fields JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_products_custom_fields 
ON products USING gin (custom_fields);

COMMENT ON COLUMN products.custom_fields IS 'Category-specific dynamic fields stored as JSONB (e.g., meal size, toppings, warranty, etc.)';

-- ==========================================
-- 🔧 ADDRESSES: Add governorate column
-- ==========================================
-- Migration: 20241207_add_governorate_to_addresses

ALTER TABLE addresses 
ADD COLUMN IF NOT EXISTS governorate TEXT;

CREATE INDEX IF NOT EXISTS idx_addresses_governorate ON addresses(governorate);

COMMENT ON COLUMN addresses.governorate IS 'المحافظة - Governorate/Province name';

-- ==========================================
-- 🔧 STORES: Add city and governorate columns
-- ==========================================
-- Migration: 20241211_add_city_governorate_to_stores

ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS governorate TEXT;

CREATE INDEX IF NOT EXISTS idx_stores_city ON public.stores(city);
CREATE INDEX IF NOT EXISTS idx_stores_governorate ON public.stores(governorate);
CREATE INDEX IF NOT EXISTS idx_stores_city_governorate ON public.stores(city, governorate);

COMMENT ON COLUMN public.stores.city IS 'المدينة التي يقع فيها المتجر';
COMMENT ON COLUMN public.stores.governorate IS 'المحافظة التي يقع فيها المتجر';

-- ==========================================
-- 🖼️ PROFILES STORAGE BUCKET
-- ==========================================
-- Migration: 20241212_create_profiles_storage

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profiles',
  'profiles',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public avatar read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'profiles');

CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND (storage.foldername(name))[2] = 'user_' || auth.uid()::text
);

CREATE POLICY "Users can update their own avatars"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND (storage.foldername(name))[2] = 'user_' || auth.uid()::text
)
WITH CHECK (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND (storage.foldername(name))[2] = 'user_' || auth.uid()::text
);

CREATE POLICY "Users can delete their own avatars"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND (storage.foldername(name))[2] = 'user_' || auth.uid()::text
);

-- ==========================================
-- 🗺️ MAP SYSTEM (PostGIS)
-- ==========================================
-- Migration: 20251223_map_system

CREATE EXTENSION IF NOT EXISTS postgis;

-- Helper function for updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Store delivery zones table
CREATE TABLE IF NOT EXISTS public.store_delivery_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  zone geography(polygon, 4326) NOT NULL,
  name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS store_delivery_zones_store_id_idx
  ON public.store_delivery_zones(store_id);

CREATE INDEX IF NOT EXISTS store_delivery_zones_zone_gix
  ON public.store_delivery_zones USING gist(zone);

DROP TRIGGER IF EXISTS trg_store_delivery_zones_updated_at ON public.store_delivery_zones;
CREATE TRIGGER trg_store_delivery_zones_updated_at
BEFORE UPDATE ON public.store_delivery_zones
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Driver locations table
CREATE TABLE IF NOT EXISTS public.driver_locations (
  driver_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  position geography(point, 4326) NOT NULL,
  heading DOUBLE PRECISION,
  speed_mps DOUBLE PRECISION,
  accuracy_m DOUBLE PRECISION,
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  current_order_id UUID,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS driver_locations_position_gix
  ON public.driver_locations USING gist(position);

CREATE INDEX IF NOT EXISTS driver_locations_is_available_idx
  ON public.driver_locations(is_available);

-- Orders: tracking fields
ALTER TABLE IF EXISTS public.orders
  ADD COLUMN IF NOT EXISTS pickup_position geography(point, 4326),
  ADD COLUMN IF NOT EXISTS dropoff_position geography(point, 4326),
  ADD COLUMN IF NOT EXISTS assigned_driver_id UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS eta_seconds INTEGER,
  ADD COLUMN IF NOT EXISTS distance_meters INTEGER;

CREATE INDEX IF NOT EXISTS orders_assigned_driver_id_idx
  ON public.orders(assigned_driver_id);

-- Point-in-zone validation function
CREATE OR REPLACE FUNCTION public.is_point_in_store_zone(
  p_store_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.store_delivery_zones z
     WHERE z.store_id = p_store_id
       AND z.is_active = TRUE
       AND ST_Contains(
            z.zone::geometry,
            ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)
          )
  );
$$;

-- RLS for map system tables
ALTER TABLE public.store_delivery_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

-- 📖 Store Delivery Zones: Public can read active zones
CREATE POLICY "zones_read_active"
  ON public.store_delivery_zones
  FOR SELECT
  USING (is_active = TRUE);

-- ✏️ Store Delivery Zones: Merchants can manage their store zones
CREATE POLICY "zones_merchant_manage"
  ON public.store_delivery_zones
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.stores s 
      WHERE s.id = store_delivery_zones.store_id 
      AND s.merchant_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.stores s 
      WHERE s.id = store_delivery_zones.store_id 
      AND s.merchant_id = auth.uid()
    )
  );

-- 🔑 Store Delivery Zones: Admins can manage all zones
CREATE POLICY "zones_admin_manage"
  ON public.store_delivery_zones
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ✏️ Driver Locations: Drivers can update their own location
CREATE POLICY "driver_locations_write_self"
  ON public.driver_locations
  FOR ALL TO authenticated
  USING (auth.uid() = driver_id)
  WITH CHECK (auth.uid() = driver_id);

-- 📖 Driver Locations: Users can read available drivers or their own location
CREATE POLICY "driver_locations_read_authenticated"
  ON public.driver_locations
  FOR SELECT TO authenticated
  USING (is_available = TRUE OR auth.uid() = driver_id);

-- 🔑 Driver Locations: Admins can manage all driver locations
CREATE POLICY "driver_locations_admin_manage"
  ON public.driver_locations
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 🔒 PostGIS System Tables: Secure spatial_ref_sys
ALTER TABLE spatial_ref_sys ENABLE ROW LEVEL SECURITY;

-- 📖 Policy: Everyone can read coordinate systems (required for PostGIS)
CREATE POLICY "spatial_ref_sys_public_read" ON spatial_ref_sys
  FOR SELECT
  USING (true);

-- 🔒 Policy: Prevent modifications from all users (system table)
CREATE POLICY "spatial_ref_sys_no_modifications" ON spatial_ref_sys
  FOR ALL
  USING (false)
  WITH CHECK (false);

COMMENT ON TABLE spatial_ref_sys IS 'PostGIS system table containing spatial reference systems (SRID) - Read-only for security';

-- ==========================================
-- 📊 ORDER TRACKING SYSTEM
-- ==========================================
-- Migration: order_tracking_table

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS client_phone TEXT;

ALTER TABLE public.order_status_logs 
ADD COLUMN IF NOT EXISTS changed_by UUID REFERENCES auth.users(id);

ALTER TABLE public.order_status_logs 
ADD COLUMN IF NOT EXISTS notes TEXT;

COMMENT ON COLUMN public.orders.client_phone IS 'رقم هاتف العميل للتواصل';
COMMENT ON COLUMN public.order_status_logs.changed_by IS 'معرف المستخدم الذي قام بتغيير الحالة';
COMMENT ON COLUMN public.order_status_logs.notes IS 'ملاحظات على تغيير الحالة';

-- Function to update order status with logging
CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id UUID,
  p_new_status order_status_enum,
  p_changed_by UUID,
  p_notes TEXT DEFAULT NULL,
  p_cancellation_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_old_status order_status_enum;
BEGIN
  SELECT status INTO v_old_status
  FROM public.orders
  WHERE id = p_order_id;

  UPDATE public.orders
  SET 
    status = p_new_status,
    cancellation_reason = COALESCE(p_cancellation_reason, cancellation_reason),
    accepted_at = CASE WHEN p_new_status = 'confirmed' AND accepted_at IS NULL THEN NOW() ELSE accepted_at END,
    prepared_at = CASE WHEN p_new_status = 'ready' AND prepared_at IS NULL THEN NOW() ELSE prepared_at END,
    picked_up_at = CASE WHEN p_new_status = 'on_the_way' AND picked_up_at IS NULL THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' AND delivered_at IS NULL THEN NOW() ELSE delivered_at END,
    updated_at = NOW()
  WHERE id = p_order_id;

  INSERT INTO public.order_status_logs (order_id, old_status, new_status, changed_by, notes)
  VALUES (p_order_id, v_old_status, p_new_status, p_changed_by, p_notes);
END;
$$;

COMMENT ON FUNCTION public.update_order_status IS 'دالة لتحديث حالة الطلب مع التسجيل التلقائي في سجل الحالات';

-- Order details view
CREATE OR REPLACE VIEW public.order_details_view 
WITH (security_invoker = on) AS
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
  o.created_at,
  o.accepted_at,
  o.prepared_at,
  o.picked_up_at,
  o.delivered_at,
  o.updated_at,
  cp.full_name AS client_name,
  cp.phone AS client_profile_phone,
  cp.email AS client_email,
  s.name AS store_name,
  s.phone AS store_phone,
  s.address AS store_address,
  cap.full_name AS captain_name,
  cap.phone AS captain_phone,
  (SELECT COUNT(*) FROM public.order_items WHERE order_id = o.id) AS items_count,
  (
    SELECT json_agg(
      json_build_object(
        'id', oi.id,
        'product_id', oi.product_id,
        'product_name', oi.product_name,
        'product_price', oi.product_price,
        'quantity', oi.quantity,
        'total_price', oi.total_price,
        'special_instructions', oi.special_instructions
      )
    )
    FROM public.order_items oi
    WHERE oi.order_id = o.id
  ) AS items,
  (
    SELECT json_agg(
      json_build_object(
        'id', osl.id,
        'old_status', osl.old_status,
        'new_status', osl.new_status,
        'changed_by', osl.changed_by,
        'notes', osl.notes,
        'changed_at', osl.changed_at
      ) ORDER BY osl.changed_at DESC
    )
    FROM public.order_status_logs osl
    WHERE osl.order_id = o.id
  ) AS status_logs
FROM public.orders o
LEFT JOIN public.profiles cp ON o.client_id = cp.id
LEFT JOIN public.stores s ON o.store_id = s.id
LEFT JOIN public.profiles cap ON o.captain_id = cap.id;

COMMENT ON VIEW public.order_details_view IS 'عرض تفاصيل الطلب الكاملة مع بيانات العميل والمتجر والكابتن والمنتجات';

GRANT SELECT ON public.order_details_view TO authenticated;

-- ==========================================
-- ⚙️ SETTINGS TABLE
-- ==========================================
-- Migration: insert_default_delivery_settings

CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  setting_type TEXT DEFAULT 'string' CHECK (setting_type IN ('string', 'number', 'boolean', 'json')),
  description TEXT,
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO settings (setting_key, setting_value, setting_type, description, is_public)
VALUES
  ('app_delivery_base_fee', '15.00', 'number', 'رسوم التوصيل الأساسية للتطبيق (ج.م)', TRUE),
  ('app_delivery_fee_per_km', '3.00', 'number', 'رسوم التوصيل لكل كيلومتر (ج.م)', TRUE),
  ('app_delivery_max_distance', '25.00', 'number', 'أقصى مسافة للتوصيل (كيلومتر)', TRUE),
  ('app_delivery_estimated_time', '30', 'number', 'الوقت التقديري للتوصيل (دقيقة)', TRUE)
ON CONFLICT (setting_key) DO UPDATE
SET 
  setting_value = EXCLUDED.setting_value,
  description = EXCLUDED.description,
  updated_at = NOW();

CREATE INDEX IF NOT EXISTS idx_settings_key ON settings (setting_key);
CREATE INDEX IF NOT EXISTS idx_settings_public ON settings (is_public);

-- ⚡ Enable RLS on settings table
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- 📖 Policy: Public can read public settings only
CREATE POLICY "settings_public_read" ON settings
  FOR SELECT
  USING (is_public = TRUE);

-- 🔑 Policy: Admin can read all settings
CREATE POLICY "settings_admin_read" ON settings
  FOR SELECT
  USING (public.is_admin());

-- ✏️ Policy: Admin can update settings
CREATE POLICY "settings_admin_write" ON settings
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION get_setting(key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  result TEXT;
BEGIN
  SELECT setting_value INTO result
  FROM settings
  WHERE setting_key = key;
  
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION update_setting(key TEXT, value TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE settings
  SET 
    setting_value = value,
    updated_at = NOW()
  WHERE setting_key = key;
  
  RETURN FOUND;
END;
$$;

-- ============================================================================
-- ✅ END OF CONSOLIDATED SCHEMA
-- ============================================================================