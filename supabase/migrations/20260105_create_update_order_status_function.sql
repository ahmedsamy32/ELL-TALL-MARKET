-- 🔧 وظيفة RPC لتحديث حالة الطلب
-- Migration: 20260105_create_update_order_status_function.sql
-- Purpose: Create a secure function to update order status with proper authorization

-- ============================================
-- 📝 وظيفة تحديث حالة الطلب
-- تتحقق من صلاحيات المستخدم قبل التحديث
-- ============================================

-- حذف جميع الوظائف بنفس الاسم بغض النظر عن التوقيع
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT p.oid::regprocedure as func_signature
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'update_order_status'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.func_signature || ' CASCADE';
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id UUID,
  p_new_status TEXT,
  p_cancel_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_user_id UUID;
  v_user_role TEXT;
  v_is_authorized BOOLEAN := FALSE;
  v_result JSON;
BEGIN
  -- الحصول على معرف المستخدم الحالي
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'المستخدم غير مسجل الدخول');
  END IF;

  -- جلب بيانات الطلب
  SELECT o.*, 
         p.role as user_role
  INTO v_order
  FROM public.orders o
  LEFT JOIN public.profiles p ON p.id = v_user_id
  WHERE o.id = p_order_id;

  IF v_order IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'الطلب غير موجود');
  END IF;

  v_user_role := v_order.user_role;

  -- التحقق من الصلاحيات
  -- 1. العميل يمكنه إلغاء طلبه فقط إذا كان pending أو confirmed
  IF v_user_id = v_order.client_id THEN
    IF p_new_status = 'cancelled' AND v_order.status IN ('pending', 'confirmed') THEN
      v_is_authorized := TRUE;
    ELSE
      RETURN json_build_object(
        'success', false, 
        'error', 'العميل يمكنه فقط إلغاء الطلبات في حالة الانتظار أو المؤكدة'
      );
    END IF;
  END IF;

  -- 2. التاجر يمكنه تحديث طلبات متجره
  IF NOT v_is_authorized THEN
    IF EXISTS (
      SELECT 1 FROM public.stores 
      WHERE id = v_order.store_id AND merchant_id = v_user_id
    ) THEN
      v_is_authorized := TRUE;
    END IF;
  END IF;

  -- 3. الكابتن يمكنه تحديث الطلبات المعينة له
  IF NOT v_is_authorized AND v_user_id = v_order.captain_id THEN
    v_is_authorized := TRUE;
  END IF;

  -- 4. المدير يمكنه تحديث أي طلب
  IF NOT v_is_authorized AND v_user_role = 'admin' THEN
    v_is_authorized := TRUE;
  END IF;

  -- إذا لم يكن مصرح له
  IF NOT v_is_authorized THEN
    RETURN json_build_object(
      'success', false, 
      'error', 'ليس لديك صلاحية لتحديث هذا الطلب',
      'user_id', v_user_id,
      'client_id', v_order.client_id,
      'store_id', v_order.store_id,
      'captain_id', v_order.captain_id
    );
  END IF;

  -- تنفيذ التحديث
  UPDATE public.orders
  SET 
    status = p_new_status,
    cancel_reason = COALESCE(p_cancel_reason, cancel_reason),
    updated_at = NOW()
  WHERE id = p_order_id;

  -- جلب الطلب المحدث
  SELECT json_build_object(
    'success', true,
    'order', json_build_object(
      'id', id,
      'status', status,
      'updated_at', updated_at
    )
  )
  INTO v_result
  FROM public.orders
  WHERE id = p_order_id;

  RETURN v_result;
END;
$$;

-- إعطاء صلاحيات التنفيذ للمستخدمين المصادق عليهم
GRANT EXECUTE ON FUNCTION public.update_order_status TO authenticated;

-- ============================================
-- 📌 للتطبيق اليدوي في Supabase Dashboard:
-- ============================================
-- 1. اذهب إلى SQL Editor
-- 2. انسخ والصق الكود أعلاه
-- 3. اضغط Run
-- ============================================
