-- 🔍 تشخيص مشكلة تحديث الطلبات
-- شغل هذا الاستعلام في Supabase SQL Editor

-- 1. جلب معلومات المستخدم الحالي
SELECT 
  auth.uid() as current_user_id,
  p.role as user_role,
  p.full_name as user_name
FROM public.profiles p
WHERE p.id = auth.uid();

-- 2. جلب المتاجر التي يملكها المستخدم الحالي
SELECT 
  s.id as store_id,
  s.name as store_name,
  s.merchant_id,
  (s.merchant_id = auth.uid()) as is_owner
FROM public.stores s
WHERE s.merchant_id = auth.uid();

-- 3. جلب الطلبات التي يمكن للمستخدم الحالي تحديثها
SELECT 
  o.id as order_id,
  o.status,
  o.store_id,
  o.client_id,
  o.captain_id,
  s.merchant_id,
  (auth.uid() = s.merchant_id) as can_merchant_update,
  (auth.uid() = o.client_id) as is_client,
  (auth.uid() = o.captain_id) as is_captain
FROM public.orders o
LEFT JOIN public.stores s ON s.id = o.store_id
WHERE 
  auth.uid() IN (
    SELECT merchant_id FROM public.stores WHERE stores.id = o.store_id
  )
  OR auth.uid() = o.client_id
  OR auth.uid() = o.captain_id
LIMIT 10;

-- 4. التحقق من سياسات RLS على جدول orders
SELECT 
  policyname,
  cmd,
  qual::text as using_clause,
  with_check::text as with_check_clause
FROM pg_policies 
WHERE tablename = 'orders' AND schemaname = 'public';
