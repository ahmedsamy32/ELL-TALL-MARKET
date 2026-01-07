-- ============================================
-- Migration: Enable PostGIS and Nearby Stores
-- ============================================

-- 1. تفعيل PostGIS Extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. إضافة أعمدة الموقع الجغرافي للمتاجر
ALTER TABLE stores 
ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326),
ADD COLUMN IF NOT EXISTS delivery_radius_km NUMERIC DEFAULT 5,
ADD COLUMN IF NOT EXISTS latitude NUMERIC,
ADD COLUMN IF NOT EXISTS longitude NUMERIC;

-- 3. إضافة أعمدة الموقع لعناوين العملاء
ALTER TABLE addresses
ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326),
ADD COLUMN IF NOT EXISTS latitude NUMERIC,
ADD COLUMN IF NOT EXISTS longitude NUMERIC;

-- 4. تحديث location من latitude/longitude للمتاجر الموجودة (آمن مع معالجة الأخطاء)
DO $$
BEGIN
  UPDATE stores 
  SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  WHERE latitude IS NOT NULL 
    AND longitude IS NOT NULL 
    AND location IS NULL;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'تحذير: لم يتم تحديث مواقع المتاجر الموجودة: %', SQLERRM;
END $$;

-- 5. تحديث location من latitude/longitude للعناوين الموجودة (آمن مع معالجة الأخطاء)
DO $$
BEGIN
  UPDATE addresses 
  SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  WHERE latitude IS NOT NULL 
    AND longitude IS NOT NULL 
    AND location IS NULL;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'تحذير: لم يتم تحديث مواقع العناوين الموجودة: %', SQLERRM;
END $$;

-- 6. إنشاء Indexes للأداء
CREATE INDEX IF NOT EXISTS idx_stores_location ON stores USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_addresses_location ON addresses USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_stores_active ON stores(is_active) WHERE is_active = true;

-- 7. Function: البحث عن المتاجر القريبة
CREATE OR REPLACE FUNCTION get_nearby_stores(
  customer_lat NUMERIC,
  customer_lng NUMERIC,
  max_distance_km NUMERIC DEFAULT 20,
  category_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  image_url TEXT,
  rating NUMERIC,
  total_reviews INTEGER,
  delivery_fee NUMERIC,
  min_order_amount NUMERIC,
  distance_km NUMERIC,
  estimated_delivery_time INTEGER,
  is_open BOOLEAN,
  latitude NUMERIC,
  longitude NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id,
    s.name,
    s.description,
    s.image_url,
    s.rating,
    s.total_reviews,
    s.delivery_fee,
    s.min_order_amount,
    ROUND(
      ST_Distance(
        s.location,
        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
      )::NUMERIC / 1000,
      2
    ) AS distance_km,
    -- حساب وقت التوصيل المتوقع (المسافة بالكيلو * 2 دقيقة + 20 دقيقة إعداد)
    ROUND(
      (ST_Distance(
        s.location,
        ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
      ) / 1000 * 2) + 20
    )::INTEGER AS estimated_delivery_time,
    s.is_open,
    s.latitude,
    s.longitude
  FROM stores s
  WHERE s.is_active = true
    AND ST_DWithin(
      s.location,
      ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography,
      LEAST(s.delivery_radius_km, max_distance_km) * 1000
    )
    AND (category_filter IS NULL OR s.category = category_filter)
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- 8. Function: التحقق من إمكانية التوصيل لمتجر معين
CREATE OR REPLACE FUNCTION can_deliver_to_location(
  store_id_param UUID,
  customer_lat NUMERIC,
  customer_lng NUMERIC
)
RETURNS TABLE (
  can_deliver BOOLEAN,
  distance_km NUMERIC,
  estimated_time INTEGER,
  delivery_fee NUMERIC
) AS $$
DECLARE
  store_location GEOGRAPHY;
  store_radius NUMERIC;
  store_fee NUMERIC;
  calculated_distance NUMERIC;
BEGIN
  -- جلب بيانات المتجر
  SELECT location, delivery_radius_km, delivery_fee
  INTO store_location, store_radius, store_fee
  FROM stores
  WHERE id = store_id_param AND is_active = true;

  IF store_location IS NULL THEN
    RETURN QUERY SELECT false, 0::NUMERIC, 0, 0::NUMERIC;
    RETURN;
  END IF;

  -- حساب المسافة
  calculated_distance := ST_Distance(
    store_location,
    ST_SetSRID(ST_MakePoint(customer_lng, customer_lat), 4326)::geography
  ) / 1000;

  -- التحقق من النطاق
  IF calculated_distance <= store_radius THEN
    RETURN QUERY SELECT 
      true,
      ROUND(calculated_distance::NUMERIC, 2),
      ROUND((calculated_distance * 2) + 20)::INTEGER,
      store_fee;
  ELSE
    RETURN QUERY SELECT 
      false,
      ROUND(calculated_distance::NUMERIC, 2),
      0,
      0::NUMERIC;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- 9. Function: المتاجر حسب المنطقة الإدارية (احتياطي)
CREATE OR REPLACE FUNCTION get_stores_by_area(
  governorate_param TEXT,
  city_param TEXT DEFAULT NULL
)
RETURNS SETOF stores AS $$
BEGIN
  RETURN QUERY
  SELECT s.*
  FROM stores s
  WHERE s.is_active = true
    AND s.governorate = governorate_param
    AND (city_param IS NULL OR s.city = city_param)
  ORDER BY s.rating DESC, s.total_reviews DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- 10. Function: تحديث موقع المتجر (يدوياً من Application)
CREATE OR REPLACE FUNCTION sync_store_location(
  store_id_param UUID,
  lat NUMERIC,
  lng NUMERIC
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE stores
  SET 
    latitude = lat,
    longitude = lng,
    location = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
  WHERE id = store_id_param;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- 11. Function: تحديث موقع العنوان (يدوياً من Application)
CREATE OR REPLACE FUNCTION sync_address_location(
  address_id_param UUID,
  lat NUMERIC,
  lng NUMERIC
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE addresses
  SET 
    latitude = lat,
    longitude = lng,
    location = ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
  WHERE id = address_id_param;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- 12. RLS Policies للـ Functions
GRANT EXECUTE ON FUNCTION get_nearby_stores TO authenticated, anon;
GRANT EXECUTE ON FUNCTION can_deliver_to_location TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_stores_by_area TO authenticated, anon;
GRANT EXECUTE ON FUNCTION sync_store_location TO authenticated;
GRANT EXECUTE ON FUNCTION sync_address_location TO authenticated;

-- 13. Comments للتوثيق
COMMENT ON FUNCTION get_nearby_stores IS 'البحث عن المتاجر القريبة من موقع العميل بناءً على PostGIS';
COMMENT ON FUNCTION sync_store_location IS 'تحديث موقع المتجر (latitude, longitude, location) دفعة واحدة';
COMMENT ON FUNCTION sync_address_location IS 'تحديث موقع العنوان (latitude, longitude, location) دفعة واحدة';
COMMENT ON FUNCTION can_deliver_to_location IS 'التحقق من إمكانية توصيل متجر معين لموقع العميل';
COMMENT ON FUNCTION get_stores_by_area IS 'جلب المتاجر حسب المحافظة والمدينة (احتياطي)';
COMMENT ON COLUMN stores.location IS 'الموقع الجغرافي للمتجر (PostGIS Geography)';
COMMENT ON COLUMN stores.delivery_radius_km IS 'نطاق التوصيل بالكيلومتر';
COMMENT ON COLUMN addresses.location IS 'الموقع الجغرافي للعنوان (PostGIS Geography)';

-- 14. تأمين جدول spatial_ref_sys (PostGIS System Table)
ALTER TABLE spatial_ref_sys ENABLE ROW LEVEL SECURITY;

-- 📖 Policy: الجميع يمكنهم قراءة أنظمة الإحداثيات (read-only)
CREATE POLICY "spatial_ref_sys_public_read" ON spatial_ref_sys
  FOR SELECT
  USING (true);

-- 🔒 Policy: منع التعديل من غير المسؤولين (write protection)
CREATE POLICY "spatial_ref_sys_admin_only" ON spatial_ref_sys
  FOR ALL
  USING (false)
  WITH CHECK (false);

COMMENT ON TABLE spatial_ref_sys IS 'جدول نظام PostGIS - يحتوي على أنظمة الإحداثيات المكانية (SRID) - قراءة فقط';
