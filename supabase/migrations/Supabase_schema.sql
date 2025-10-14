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
  avatar_url TEXT,
  role TEXT CHECK (role IN ('client', 'merchant', 'captain', 'admin')) DEFAULT 'client',
  fcm_token TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
  FOR SELECT USING (true);

-- 🔧 Auto-create profile when a new auth.user is added
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

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

CREATE POLICY "Merchants manage their store" ON public.merchants
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE TABLE public.stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES public.merchants(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  phone TEXT,
  address TEXT NOT NULL,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  delivery_time INT DEFAULT 30,
  is_open BOOLEAN DEFAULT TRUE,
  delivery_fee DECIMAL(10,2) DEFAULT 0,
  min_order DECIMAL(10,2) DEFAULT 0,
  rating DECIMAL(2,1) DEFAULT 0.0,
  review_count INT DEFAULT 0,
  category TEXT,
  opening_hours JSONB DEFAULT '{}',
  image_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view stores" ON public.stores FOR SELECT USING (true);
CREATE POLICY "Merchant can manage their stores" ON public.stores
  FOR ALL USING (auth.uid() = merchant_id) WITH CHECK (auth.uid() = merchant_id);

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
  image_url TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);

CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  compare_price DECIMAL(10,2),
  cost_price DECIMAL(10,2),
  image_url TEXT,
  category_id UUID REFERENCES public.categories(id),
  in_stock BOOLEAN DEFAULT TRUE,
  stock_quantity INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  tags TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view products" ON public.products FOR SELECT USING (true);
CREATE POLICY "Merchants manage their products" ON public.products
  FOR ALL USING (auth.uid() = (SELECT merchant_id FROM public.stores WHERE stores.id = products.store_id))
  WITH CHECK (auth.uid() = (SELECT merchant_id FROM public.stores WHERE stores.id = products.store_id));

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
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
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

CREATE POLICY "Clients can view their orders" ON public.orders 
FOR SELECT USING (auth.uid() = client_id);

CREATE POLICY "Merchants view store orders" ON public.orders 
FOR SELECT USING (auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_id));

CREATE POLICY "Captains view assigned orders" ON public.orders 
FOR SELECT USING (auth.uid() = captain_id);

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

CREATE POLICY "Anyone can view active coupons" ON public.coupons
FOR SELECT USING (is_active = TRUE);

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
CREATE POLICY "Anyone can view active banners" ON public.banners 
FOR SELECT USING (is_active AND (end_date IS NULL OR end_date > NOW()));

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
-- 🔧 FUNCTIONS & TRIGGERS
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
CREATE TRIGGER update_captains_updated_at BEFORE UPDATE ON public.captains FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_deliveries_updated_at BEFORE UPDATE ON public.deliveries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_coupons_updated_at BEFORE UPDATE ON public.coupons FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- triggers أخرى
CREATE TRIGGER generate_order_number_trigger BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.generate_order_number();
CREATE TRIGGER calculate_cart_item_total_trigger BEFORE INSERT OR UPDATE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION public.calculate_cart_item_total();
CREATE TRIGGER update_cart_totals_trigger AFTER INSERT OR UPDATE OR DELETE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION public.update_cart_totals();

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
-- 📝 SAMPLE DATA
-- ==========================================

-- إضافة بيانات تسعير التوصيل
INSERT INTO public.delivery_pricing (vehicle_type, base_fee, price_per_km, minimum_fee, maximum_fee) VALUES
('motorcycle', 5.00, 2.00, 5.00, 30.00),
('car', 8.00, 3.00, 8.00, 50.00),
('bicycle', 3.00, 1.50, 3.00, 20.00);

-- إضافة كوبونات
INSERT INTO public.coupons (code, description, coupon_type, discount_value, minimum_order_amount, usage_limit) VALUES
('WELCOME10', 'Welcome discount 10%', 'percentage', 10, 25, 100),
('FREESHIP', 'Free delivery', 'free_delivery', 0, 30, 50),
('SAVE5', 'Save 5 USD', 'fixed_amount', 5, 20, 200);