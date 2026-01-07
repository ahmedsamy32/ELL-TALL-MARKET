-- 🔧 إضافة سياسة لسماح العملاء بإلغاء طلباتهم
-- Migration: 20260105_add_client_order_cancel_policy.sql
-- Purpose: Allow clients to cancel their own orders (only pending/confirmed orders)

-- ============================================
-- 📝 ملاحظة مهمة:
-- هذه السياسة تسمح للعملاء بتحديث حقل status فقط
-- إلى قيمة 'cancelled' للطلبات في حالة pending أو confirmed
-- ============================================

-- إضافة سياسة للعملاء لإلغاء طلباتهم
CREATE POLICY "Clients can cancel their pending orders" ON public.orders
FOR UPDATE 
USING (
  -- العميل يملك الطلب
  auth.uid() = client_id
  -- الطلب في حالة قابلة للإلغاء
  AND status IN ('pending', 'confirmed')
)
WITH CHECK (
  -- العميل يملك الطلب
  auth.uid() = client_id
  -- الحالة الجديدة هي 'cancelled' فقط
  AND status = 'cancelled'
);

-- ============================================
-- 📌 للتطبيق اليدوي في Supabase Dashboard:
-- ============================================
-- 1. اذهب إلى SQL Editor
-- 2. انسخ والصق الكود أعلاه
-- 3. اضغط Run
-- ============================================
