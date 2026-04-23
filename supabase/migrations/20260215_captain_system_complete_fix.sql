-- ============================================================================
-- Captain System Complete Fix Migration
-- Date: 2026-02-15
-- Description: إصلاح شامل لنظام الكباتن - Schema + RLS + Functions + Indexes
-- ============================================================================

-- ============================================================================
-- 0. Helper Functions
-- ============================================================================

-- إنشاء أو تحديث دالة update_updated_at_column إذا لم تكن موجودة
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 1. توسيع جدول captains (إضافة أعمدة جديدة)
-- ============================================================================

-- إضافة أعمدة الهوية والتواصل
ALTER TABLE captains ADD COLUMN IF NOT EXISTS national_id TEXT;

-- إضافة أعمدة الحالة
ALTER TABLE captains ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE captains ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT true;
ALTER TABLE captains ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE captains ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending' 
  CHECK (verification_status IN ('pending', 'approved', 'rejected'));

-- إضافة أعمدة التقييم والإحصائيات
ALTER TABLE captains ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0;
ALTER TABLE captains ADD COLUMN IF NOT EXISTS total_earnings DECIMAL(10,2) DEFAULT 0;

-- إضافة أعمدة الصور والمستندات
ALTER TABLE captains ADD COLUMN IF NOT EXISTS profile_image_url TEXT;
ALTER TABLE captains ADD COLUMN IF NOT EXISTS license_image_url TEXT;
ALTER TABLE captains ADD COLUMN IF NOT EXISTS vehicle_image_url TEXT;

-- إضافة أعمدة أوقات ومناطق العمل
ALTER TABLE captains ADD COLUMN IF NOT EXISTS working_hours JSONB DEFAULT '{}';
ALTER TABLE captains ADD COLUMN IF NOT EXISTS working_areas JSONB DEFAULT '[]';
ALTER TABLE captains ADD COLUMN IF NOT EXISTS contact_phone TEXT;

-- إضافة بيانات إضافية
ALTER TABLE captains ADD COLUMN IF NOT EXISTS additional_data JSONB DEFAULT '{}';
ALTER TABLE captains ADD COLUMN IF NOT EXISTS last_available_at TIMESTAMPTZ;

-- تحديث CHECK constraint على vehicle_type لإضافة 'truck'
ALTER TABLE captains DROP CONSTRAINT IF EXISTS captains_vehicle_type_check;
ALTER TABLE captains ADD CONSTRAINT captains_vehicle_type_check 
  CHECK (vehicle_type IN ('motorcycle', 'car', 'bicycle', 'truck'));

-- ============================================================================
-- 2. إصلاح جدول orders
-- ============================================================================

-- إضافة أعمدة الإلغاء
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- حذف العمود المكرر assigned_driver_id (إذا كان موجوداً)
ALTER TABLE orders DROP COLUMN IF EXISTS assigned_driver_id;

-- تحديث index على captain_id
DROP INDEX IF EXISTS orders_assigned_driver_id_idx;
CREATE INDEX IF NOT EXISTS idx_orders_captain_id ON orders(captain_id);

-- ============================================================================
-- 3. إنشاء جدول captain_earnings
-- ============================================================================

CREATE TABLE IF NOT EXISTS captain_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  captain_id UUID NOT NULL REFERENCES captains(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  delivery_id UUID REFERENCES deliveries(id) ON DELETE SET NULL,
  amount DECIMAL(10,2) NOT NULL,
  commission_rate DECIMAL(5,2) DEFAULT 10.00,
  commission_amount DECIMAL(10,2),
  net_amount DECIMAL(10,2),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'cancelled')),
  paid_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes لجدول captain_earnings
CREATE INDEX IF NOT EXISTS idx_captain_earnings_captain_id ON captain_earnings(captain_id);
CREATE INDEX IF NOT EXISTS idx_captain_earnings_order_id ON captain_earnings(order_id);
CREATE INDEX IF NOT EXISTS idx_captain_earnings_created_at ON captain_earnings(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_captain_earnings_payment_status ON captain_earnings(payment_status);

-- Trigger لتحديث updated_at
CREATE OR REPLACE TRIGGER update_captain_earnings_updated_at
  BEFORE UPDATE ON captain_earnings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 4. إنشاء/إصلاح جدول driver_locations (PostGIS)
-- ============================================================================

-- التأكد من تفعيل PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- إنشاء الجدول إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS driver_locations (
  driver_id UUID PRIMARY KEY REFERENCES captains(id) ON DELETE CASCADE,
  position geography(point, 4326) NOT NULL,
  heading DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  current_order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Spatial index للبحث الجغرافي السريع
CREATE INDEX IF NOT EXISTS driver_locations_position_gix
  ON driver_locations USING gist(position);

CREATE INDEX IF NOT EXISTS driver_locations_is_available_idx
  ON driver_locations(is_available);

-- إصلاح FK إذا كان يشير إلى profiles بدلاً من captains
ALTER TABLE driver_locations DROP CONSTRAINT IF EXISTS driver_locations_driver_id_fkey;
ALTER TABLE driver_locations ADD CONSTRAINT driver_locations_driver_id_fkey 
  FOREIGN KEY (driver_id) REFERENCES captains(id) ON DELETE CASCADE;

-- إضافة FK على current_order_id إذا لم تكن موجودة
ALTER TABLE driver_locations DROP CONSTRAINT IF EXISTS driver_locations_current_order_id_fkey;
ALTER TABLE driver_locations ADD CONSTRAINT driver_locations_current_order_id_fkey 
  FOREIGN KEY (current_order_id) REFERENCES orders(id) ON DELETE SET NULL;

-- تفعيل RLS على driver_locations
ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;

-- الكابتن يمكنه تحديث/إدراج موقعه فقط
DROP POLICY IF EXISTS "Captain can manage own location" ON driver_locations;
CREATE POLICY "Captain can manage own location"
  ON driver_locations FOR ALL
  TO authenticated
  USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());

-- أي مستخدم مسجل يمكنه رؤية مواقع الكباتن (لتتبع الطلبات)
DROP POLICY IF EXISTS "Authenticated users can view driver locations" ON driver_locations;
CREATE POLICY "Authenticated users can view driver locations"
  ON driver_locations FOR SELECT
  TO authenticated
  USING (true);

-- الأدمن يمكنه إدارة كل المواقع
DROP POLICY IF EXISTS "Admin can manage all driver locations" ON driver_locations;
CREATE POLICY "Admin can manage all driver locations"
  ON driver_locations FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- ============================================================================
-- 5. RLS Policies - إضافة policies للأدمن والتحديثات
-- ============================================================================

-- تفعيل RLS على الجداول
ALTER TABLE captains ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_pricing ENABLE ROW LEVEL SECURITY;
ALTER TABLE captain_earnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

-- Captains Table
DROP POLICY IF EXISTS "Admin can manage all captains" ON captains;
CREATE POLICY "Admin can manage all captains"
  ON captains FOR ALL 
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

DROP POLICY IF EXISTS "Authenticated users can view captains" ON captains;
CREATE POLICY "Authenticated users can view captains"
  ON captains FOR SELECT
  TO authenticated
  USING (true);

-- إضافة WITH CHECK للـ captain update policy
DROP POLICY IF EXISTS "Captain can update own profile" ON captains;
CREATE POLICY "Captain can update own profile"
  ON captains FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Deliveries Table
DROP POLICY IF EXISTS "Merchants can insert deliveries" ON deliveries;
CREATE POLICY "Merchants can insert deliveries"
  ON deliveries FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM stores 
      WHERE stores.merchant_id = auth.uid() 
      AND stores.id = (SELECT store_id FROM orders WHERE orders.id = order_id)
    )
  );

DROP POLICY IF EXISTS "Admin can manage all deliveries" ON deliveries;
CREATE POLICY "Admin can manage all deliveries"
  ON deliveries FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- تحديث captain update policy مع WITH CHECK
DROP POLICY IF EXISTS "Captain can update assigned deliveries" ON deliveries;
CREATE POLICY "Captain can update assigned deliveries"
  ON deliveries FOR UPDATE
  TO authenticated
  USING (captain_id = auth.uid())
  WITH CHECK (captain_id = auth.uid());

-- Delivery Tracking Table
DROP POLICY IF EXISTS "Admin can manage all delivery tracking" ON delivery_tracking;
CREATE POLICY "Admin can manage all delivery tracking"
  ON delivery_tracking FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

DROP POLICY IF EXISTS "Merchants can view delivery tracking" ON delivery_tracking;
CREATE POLICY "Merchants can view delivery tracking"
  ON delivery_tracking FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM deliveries d
      JOIN orders o ON d.order_id = o.id
      JOIN stores s ON o.store_id = s.id
      WHERE d.id = delivery_tracking.delivery_id
      AND s.merchant_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Captain can insert tracking for assigned deliveries" ON delivery_tracking;
CREATE POLICY "Captain can insert tracking for assigned deliveries"
  ON delivery_tracking FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM deliveries 
      WHERE id = delivery_id AND captain_id = auth.uid()
    )
  );

-- Delivery Pricing Table
DROP POLICY IF EXISTS "Admin can manage all delivery pricing" ON delivery_pricing;
CREATE POLICY "Admin can manage all delivery pricing"
  ON delivery_pricing FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- Addresses Table - تحسين captain policy
-- الكابتن يمكنه رؤية عناوين العملاء المرتبطة بطلباته
DROP POLICY IF EXISTS "Captain can view addresses for assigned orders" ON addresses;
CREATE POLICY "Captain can view addresses for assigned orders"
  ON addresses FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.captain_id = auth.uid()
      AND orders.client_id = addresses.client_id
    )
  );

-- Captain Earnings Table
DROP POLICY IF EXISTS "Captain can view own earnings" ON captain_earnings;
CREATE POLICY "Captain can view own earnings"
  ON captain_earnings FOR SELECT
  TO authenticated
  USING (captain_id = auth.uid());

DROP POLICY IF EXISTS "Admin can manage all captain earnings" ON captain_earnings;
CREATE POLICY "Admin can manage all captain earnings"
  ON captain_earnings FOR ALL
  TO authenticated
  USING (auth.jwt() ->> 'role' = 'admin')
  WITH CHECK (auth.jwt() ->> 'role' = 'admin');

-- ============================================================================
-- 6. Indexes الإضافية للأداء
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status);
CREATE INDEX IF NOT EXISTS idx_delivery_tracking_delivery_id ON delivery_tracking(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_tracking_captain_id ON delivery_tracking(captain_id);
CREATE INDEX IF NOT EXISTS idx_captains_is_verified ON captains(is_verified);
CREATE INDEX IF NOT EXISTS idx_captains_is_active ON captains(is_active);
CREATE INDEX IF NOT EXISTS idx_captains_is_available ON captains(is_available);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- ============================================================================
-- 7. Functions الجديدة
-- ============================================================================

-- Function 1: البحث عن الكباتن القريبين باستخدام PostGIS
CREATE OR REPLACE FUNCTION get_nearby_captains(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 10,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  captain_id UUID,
  distance_km DOUBLE PRECISION,
  captain_name TEXT,
  vehicle_type TEXT,
  rating DECIMAL,
  total_deliveries INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS captain_id,
    ST_Distance(
      dl.position::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) / 1000 AS distance_km,
    p.full_name AS captain_name,
    c.vehicle_type,
    c.rating,
    c.total_deliveries
  FROM captains c
  INNER JOIN profiles p ON c.id = p.id
  INNER JOIN driver_locations dl ON c.id = dl.driver_id
  WHERE c.is_active = true
    AND c.is_available = true
    AND c.is_online = true
    AND c.verification_status = 'approved'
    AND ST_DWithin(
      dl.position::geography,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
  ORDER BY distance_km ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function 2: تعيين كابتن لطلب (atomic operation)
CREATE OR REPLACE FUNCTION assign_captain_to_order(
  p_order_id UUID,
  p_captain_id UUID,
  p_delivery_fee DECIMAL DEFAULT 0
)
RETURNS VOID AS $$
DECLARE
  v_pickup_lat DOUBLE PRECISION;
  v_pickup_lng DOUBLE PRECISION;
  v_delivery_lat DOUBLE PRECISION;
  v_delivery_lng DOUBLE PRECISION;
BEGIN
  -- جلب إحداثيات من الطلب مباشرة
  SELECT 
    ST_Y(o.pickup_position::geometry), ST_X(o.pickup_position::geometry),
    o.delivery_latitude, o.delivery_longitude
  INTO v_pickup_lat, v_pickup_lng, v_delivery_lat, v_delivery_lng
  FROM orders o
  WHERE o.id = p_order_id;

  -- تحديث الطلب
  UPDATE orders 
  SET 
    captain_id = p_captain_id,
    status = 'confirmed',
    delivery_fee = p_delivery_fee,
    updated_at = now()
  WHERE id = p_order_id;

  -- إنشاء delivery record
  INSERT INTO deliveries (
    order_id,
    captain_id,
    pickup_latitude,
    pickup_longitude,
    delivery_latitude,
    delivery_longitude,
    status
  ) VALUES (
    p_order_id,
    p_captain_id,
    v_pickup_lat,
    v_pickup_lng,
    v_delivery_lat,
    v_delivery_lng,
    'assigned'
  );

  -- تحديث حالة الكابتن
  UPDATE captains
  SET 
    status = 'busy',
    is_available = false,
    updated_at = now()
  WHERE id = p_captain_id;
END;
$$ LANGUAGE plpgsql;

-- Function 3: تحديث حالة التوصيل (مع auto-earnings)
CREATE OR REPLACE FUNCTION update_delivery_status(
  p_delivery_id UUID,
  p_new_status TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_order_id UUID;
  v_captain_id UUID;
  v_delivery_fee DECIMAL;
BEGIN
  -- جلب بيانات التوصيل
  SELECT order_id, captain_id 
  INTO v_order_id, v_captain_id
  FROM deliveries
  WHERE id = p_delivery_id;

  -- تحديث حالة التوصيل
  UPDATE deliveries
  SET 
    status = p_new_status,
    notes = COALESCE(p_notes, notes),
    picked_up_at = CASE WHEN p_new_status = 'picked_up' THEN now() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE delivered_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN now() ELSE cancelled_at END,
    updated_at = now()
  WHERE id = p_delivery_id;

  -- تحديث حالة الطلب
  UPDATE orders
  SET 
    status = CASE 
      WHEN p_new_status = 'picked_up' THEN 'in_transit'
      WHEN p_new_status = 'delivered' THEN 'delivered'
      WHEN p_new_status = 'cancelled' THEN 'cancelled'
      ELSE status
    END,
    picked_up_at = CASE WHEN p_new_status = 'picked_up' THEN now() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE delivered_at END,
    updated_at = now()
  WHERE id = v_order_id;

  -- إذا تم التوصيل، سجل الأرباح
  IF p_new_status = 'delivered' THEN
    SELECT delivery_fee INTO v_delivery_fee FROM orders WHERE id = v_order_id;
    
    INSERT INTO captain_earnings (
      captain_id,
      order_id,
      delivery_id,
      amount,
      commission_rate,
      commission_amount,
      net_amount,
      payment_status
    ) VALUES (
      v_captain_id,
      v_order_id,
      p_delivery_id,
      v_delivery_fee,
      10.00,
      v_delivery_fee * 0.10,
      v_delivery_fee * 0.90,
      'pending'
    );

    -- تحديث إحصائيات الكابتن
    UPDATE captains
    SET 
      total_deliveries = total_deliveries + 1,
      total_earnings = total_earnings + (v_delivery_fee * 0.90),
      is_available = true,
      status = 'online',
      updated_at = now()
    WHERE id = v_captain_id;
  END IF;

  -- إذا تم الإلغاء، حرر الكابتن
  IF p_new_status = 'cancelled' THEN
    UPDATE captains
    SET 
      is_available = true,
      status = 'online',
      updated_at = now()
    WHERE id = v_captain_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function 4: تحديث موقع الكابتن (sync captains + driver_locations)
CREATE OR REPLACE FUNCTION update_captain_location(
  p_captain_id UUID,
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_heading DOUBLE PRECISION DEFAULT 0,
  p_speed DOUBLE PRECISION DEFAULT 0,
  p_accuracy DOUBLE PRECISION DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
  -- تحديث جدول captains
  UPDATE captains
  SET 
    latitude = p_lat,
    longitude = p_lng,
    last_available_at = now(),
    updated_at = now()
  WHERE id = p_captain_id;

  -- تحديث/إنشاء في driver_locations
  INSERT INTO driver_locations (
    driver_id,
    position,
    heading,
    speed,
    accuracy,
    updated_at
  ) VALUES (
    p_captain_id,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326),
    p_heading,
    p_speed,
    p_accuracy,
    now()
  )
  ON CONFLICT (driver_id) 
  DO UPDATE SET
    position = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326),
    heading = p_heading,
    speed = p_speed,
    accuracy = p_accuracy,
    updated_at = now();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 8. تحديث update_order_status function لدعم cancelled_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_order_status()
RETURNS TRIGGER AS $$
BEGIN
  -- تحديث cancelled_at عند الإلغاء
  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    NEW.cancelled_at = now();
  END IF;

  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 9. تحديث order_details_view لإضافة cancelled_at
-- ============================================================================

DROP VIEW IF EXISTS order_details_view CASCADE;
CREATE VIEW order_details_view AS
SELECT 
  o.id,
  o.order_number,
  o.client_id,
  o.store_id,
  o.status,
  o.total_amount,
  o.delivery_fee,
  o.created_at,
  o.updated_at,
  o.delivered_at,
  o.cancelled_at,
  o.cancellation_reason,
  o.captain_id,
  s.name AS store_name,
  p.full_name AS customer_name,
  c.vehicle_type AS captain_vehicle_type
FROM orders o
LEFT JOIN stores s ON o.store_id = s.id
LEFT JOIN profiles p ON o.client_id = p.id
LEFT JOIN captains c ON o.captain_id = c.id;

-- ============================================================================
-- 10. تعليقات توضيحية
-- ============================================================================

COMMENT ON TABLE captain_earnings IS 'جدول أرباح الكباتن مع العمولات والحالة';
COMMENT ON COLUMN captains.is_available IS 'هل الكابتن متاح لاستلام طلبات جديدة؟';
COMMENT ON COLUMN captains.is_online IS 'هل الكابتن متصل بالتطبيق حالياً؟';
COMMENT ON COLUMN captains.verification_status IS 'حالة التحقق: pending, approved, rejected';
COMMENT ON FUNCTION get_nearby_captains IS 'البحث عن الكباتن القريبين باستخدام PostGIS';
COMMENT ON FUNCTION assign_captain_to_order IS 'تعيين كابتن لطلب بشكل atomic';
COMMENT ON FUNCTION update_delivery_status IS 'تحديث حالة التوصيل مع تسجيل الأرباح تلقائياً';
COMMENT ON FUNCTION update_captain_location IS 'تحديث موقع الكابتن في الجدولين معاً';

-- ============================================================================
-- Migration Complete ✅
-- ============================================================================
