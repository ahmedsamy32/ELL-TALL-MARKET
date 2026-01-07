-- ============================================================
-- 🔧 RPC Function: update_order_status
-- تحديث حالة الطلب مع التحقق من الصلاحيات
-- ============================================================
-- 📖 المرجع: https://supabase.com/docs/reference/dart/rpc
-- 
-- 🎯 الاستخدام من Flutter:
--    await supabase.rpc('update_order_status', params: {
--      'p_order_id': orderId,
--      'p_new_status': 'cancelled',
--      'p_changed_by': userId,
--    });
-- ============================================================

-- الخطوة 1: حذف الـ function القديمة إن وُجدت
DROP FUNCTION IF EXISTS public.update_order_status(UUID, TEXT, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.update_order_status(TEXT, UUID, TEXT, TEXT, UUID);

-- الخطوة 2: إنشاء الـ function
CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_changed_by UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_cancellation_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_user_id UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_order RECORD;
  v_result JSON;
BEGIN
  -- التحقق من المدخلات المطلوبة
  IF p_order_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'معرف الطلب مطلوب');
  END IF;
  
  IF p_new_status IS NULL OR p_new_status = '' THEN
    RETURN json_build_object('success', false, 'error', 'الحالة الجديدة مطلوبة');
  END IF;

  -- الحصول على المستخدم الحالي
  v_user_id := COALESCE(p_changed_by, auth.uid());
  
  -- جلب بيانات الطلب
  SELECT id, status, client_id, store_id, captain_id 
  INTO v_order
  FROM public.orders
  WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'الطلب غير موجود');
  END IF;

  v_old_status := v_order.status;

  -- التحقق من الصلاحيات
  -- 1. العميل: يمكنه إلغاء طلبه فقط إذا كان pending أو confirmed
  IF v_user_id = v_order.client_id THEN
    IF p_new_status = 'cancelled' AND v_old_status IN ('pending', 'confirmed') THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  -- 2. التاجر: يمكنه تحديث طلبات متجره
  IF NOT v_is_authorized THEN
    IF EXISTS (
      SELECT 1 FROM public.stores 
      WHERE id = v_order.store_id AND merchant_id = v_user_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  -- 3. الكابتن: يمكنه تحديث الطلبات المعينة له
  IF NOT v_is_authorized AND v_user_id = v_order.captain_id THEN
    v_is_authorized := TRUE;
  END IF;

  -- 4. المدير: يمكنه تحديث أي طلب
  IF NOT v_is_authorized THEN
    IF EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = v_user_id AND role = 'admin'
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  -- إذا لم يكن مصرح له
  IF NOT v_is_authorized THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'ليس لديك صلاحية لتحديث هذا الطلب'
    );
  END IF;

  -- تنفيذ التحديث
  UPDATE public.orders
  SET 
    status = p_new_status,
    cancel_reason = COALESCE(p_cancellation_reason, cancel_reason),
    accepted_at = CASE WHEN p_new_status = 'confirmed' AND accepted_at IS NULL THEN NOW() ELSE accepted_at END,
    prepared_at = CASE WHEN p_new_status = 'ready' AND prepared_at IS NULL THEN NOW() ELSE prepared_at END,
    picked_up_at = CASE WHEN p_new_status = 'picked_up' AND picked_up_at IS NULL THEN NOW() ELSE picked_up_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' AND delivered_at IS NULL THEN NOW() ELSE delivered_at END,
    updated_at = NOW()
  WHERE id = p_order_id;

  -- تسجيل التغيير (اختياري)
  BEGIN
    INSERT INTO public.order_status_logs (order_id, old_status, new_status, changed_by, notes)
    VALUES (p_order_id, v_old_status, p_new_status, v_user_id, p_notes);
  EXCEPTION WHEN OTHERS THEN
    -- تجاهل أخطاء التسجيل
    NULL;
  END;

  -- إرجاع النتيجة
  RETURN json_build_object(
    'success', true,
    'order_id', p_order_id,
    'old_status', v_old_status,
    'new_status', p_new_status
  );
END;
$$;

-- الخطوة 3: إعطاء صلاحيات التنفيذ
GRANT EXECUTE ON FUNCTION public.update_order_status(UUID, TEXT, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_order_status(UUID, TEXT, UUID, TEXT, TEXT) TO anon;

-- ============================================================
-- ✅ اختبار الـ function:
-- SELECT update_order_status(
--   'order-uuid-here'::uuid,
--   'cancelled',
--   'user-uuid-here'::uuid,
--   'تم الإلغاء من التطبيق',
--   'العميل غير متاح'
-- );
-- ============================================================
-- ============================================
