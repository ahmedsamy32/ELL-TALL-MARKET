-- ==========================================
-- 🔧 Fix Orders UPDATE Policy
-- ==========================================
-- التاريخ: 2026-01-02
-- المشكلة: التجار لا يمكنهم تحديث حالة الطلبات بسبب نقص WITH CHECK في policy
-- الحل: إعادة إنشاء policies مع WITH CHECK clause

-- حذف الـ policies القديمة
DROP POLICY IF EXISTS "Merchants can update store orders" ON public.orders;
DROP POLICY IF EXISTS "Captains can update assigned orders" ON public.orders;

-- إنشاء الـ policies الجديدة مع WITH CHECK
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

-- ==========================================
-- ✅ اكتمل التحديث
-- ==========================================
-- الآن يمكن للتجار تحديث حالة طلبات متاجرهم
-- والكباتن يمكنهم تحديث طلباتهم المعينة لهم
