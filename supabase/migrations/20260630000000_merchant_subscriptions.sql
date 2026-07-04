-- ==========================================
-- 📦 SOUQ EL TAL (ELTAL MARKET)
-- 💳 MERCHANT SUBSCRIPTION & WALLET SYSTEM
-- ==========================================
-- Migration Version: 20260630000000
-- Description: Adds subscription_tiers, updates merchants, creates wallet_transactions,
--              and registers all automated trigger functions for billing, blocking, and cancellations.

-- Drop existing triggers that might conflict or reference columns to be updated
DROP TRIGGER IF EXISTS trigger_on_new_order ON public.orders CASCADE;
DROP TRIGGER IF EXISTS trg_merchant_status_change ON public.merchants CASCADE;
DROP TRIGGER IF EXISTS trg_order_cancellation_rules ON public.orders CASCADE;

-- Drop foreign keys and tables to ensure clean rebuild
ALTER TABLE public.merchants DROP CONSTRAINT IF EXISTS merchants_current_tier_id_fkey CASCADE;
DROP TABLE IF EXISTS public.wallet_transactions CASCADE;
DROP TABLE IF EXISTS public.subscription_tiers CASCADE;

-- 1️⃣ الخطوة الأولى: إنشاء جدول الباقات وإضافتها للسيستم
CREATE TABLE public.subscription_tiers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    monthly_price DECIMAL(10, 2) NOT NULL CHECK (monthly_price >= 0),
    included_orders INT NOT NULL, -- القيمة (-1) تعني أوردرات لا محدودة
    overlimit_fee_per_order DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (overlimit_fee_per_order >= 0),
    max_overlimit_orders INT NOT NULL DEFAULT 0
);

-- إدخال بيانات الباقات الثلاثة في السيستم
INSERT INTO public.subscription_tiers (name, monthly_price, included_orders, overlimit_fee_per_order, max_overlimit_orders) 
VALUES
  ('Basic', 150.00, 30, 7.00, 10),
  ('Pro', 450.00, 100, 5.00, 25),
  ('Unlimited', 900.00, -1, 0.00, 0)
ON CONFLICT (name) DO UPDATE SET
  monthly_price = EXCLUDED.monthly_price,
  included_orders = EXCLUDED.included_orders,
  overlimit_fee_per_order = EXCLUDED.overlimit_fee_per_order,
  max_overlimit_orders = EXCLUDED.max_overlimit_orders;

-- 2️⃣ الخطوة الثانية: تحديث جدول التجار الحاليين (merchants)
ALTER TABLE public.merchants 
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT CHECK (status IN ('active', 'suspended', 'closed')) DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS wallet_balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS current_tier_id INT,
  ADD COLUMN IF NOT EXISTS package_expiry_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS remaining_orders INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS overlimit_orders_count INT NOT NULL DEFAULT 0;

-- ربط التجار بجدول الباقات
ALTER TABLE public.merchants
  ADD CONSTRAINT merchants_current_tier_id_fkey
  FOREIGN KEY (current_tier_id) REFERENCES public.subscription_tiers(id) ON DELETE SET NULL;

-- Populate 'name' with 'store_name' for existing records if 'name' is null (deferred compile via dynamic SQL to prevent parser errors)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'merchants' AND column_name = 'name'
  ) THEN
    EXECUTE '
      UPDATE public.merchants
      SET name = store_name
      WHERE name IS NULL AND store_name IS NOT NULL
    ';
  END IF;
END $$;

-- Alter Orders Table to Add merchant_id Column for Flutter app compatibility
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES public.merchants(id) ON DELETE SET NULL;

-- Populate merchant_id for existing orders using stores relation (deferred compile via dynamic SQL to prevent parser errors)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'merchant_id'
  ) THEN
    EXECUTE '
      UPDATE public.orders o
      SET merchant_id = s.merchant_id
      FROM public.stores s
      WHERE o.store_id = s.id AND o.merchant_id IS NULL
    ';
  END IF;
END $$;

-- إنشاء جدول لتسجيل حركات المحفظة (شحن / خصم)
-- ملاحظة: تم تعديل merchant_id ليكون UUID للتوافق مع جدول التجار الأساسي
CREATE TABLE public.wallet_transactions (
    id SERIAL PRIMARY KEY,
    merchant_id UUID NOT NULL REFERENCES public.merchants(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    type VARCHAR(10) NOT NULL CHECK (type IN ('credit', 'debit')), -- credit = شحن ، debit = خصم
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- إنشاء الفهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_merchant_id ON public.wallet_transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchants_status_expiry ON public.merchants(status, package_expiry_date);
CREATE INDEX IF NOT EXISTS idx_merchants_tier ON public.merchants(current_tier_id);

-- تمكين الـ RLS لحماية الجداول الجديدة
ALTER TABLE public.subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- سياسات الحماية لباقات الاشتراك
DROP POLICY IF EXISTS "Anyone can view subscription tiers" ON public.subscription_tiers;
CREATE POLICY "Anyone can view subscription tiers" ON public.subscription_tiers
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Only admins can modify subscription tiers" ON public.subscription_tiers;
CREATE POLICY "Only admins can modify subscription tiers" ON public.subscription_tiers
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- سياسات الحماية لجدول حركات المحفظة
DROP POLICY IF EXISTS "Merchants can view own wallet transactions" ON public.wallet_transactions;
CREATE POLICY "Merchants can view own wallet transactions" ON public.wallet_transactions
  FOR SELECT USING (
    auth.uid() = merchant_id
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- 3️⃣ الخطوة الثالثة: العقل المفكر (Trigger) 🧠
-- تم تحسين الدالة لجلب معرف التاجر ديناميكياً من جدول المتاجر لتجنب أي مشاكل تجميع
CREATE OR REPLACE FUNCTION public.process_merchant_order_logic()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_merchant_id UUID;
    v_merchant_status VARCHAR(50);
    v_wallet_balance DECIMAL(10, 2);
    v_tier_id INT;
    v_remaining_orders INT;
    v_overlimit_count INT;
    v_expiry TIMESTAMP;
    v_included_orders INT;
    v_overlimit_fee DECIMAL(10, 2);
    v_max_overlimit INT;
BEGIN
    -- جلب معرف التاجر المرتبط بالمتجر
    SELECT merchant_id INTO v_merchant_id
    FROM public.stores
    WHERE id = NEW.store_id;

    IF v_merchant_id IS NULL THEN
        RAISE EXCEPTION 'المتجر غير موجود أو غير مرتبط بتاجر';
    END IF;

    -- تلقائياً قم بتحديث حقل merchant_id في الطلب للتوافق مع التطبيق
    NEW.merchant_id := v_merchant_id;

    -- 1. جلب بيانات التاجر الحالية من السيستم (مع قفل السجل لمنع التعارض والسباق)
    SELECT status, wallet_balance, current_tier_id, remaining_orders, overlimit_orders_count, package_expiry_date
    INTO v_merchant_status, v_wallet_balance, v_tier_id, v_remaining_orders, v_overlimit_count, v_expiry
    FROM merchants WHERE id = v_merchant_id FOR UPDATE;

    -- 2. الفحص الأولي: لو المحل موقوف ارفض الأوردر
    IF v_merchant_status = 'suspended' OR v_merchant_status = 'closed' THEN
        RAISE EXCEPTION 'المحل موقوف حالياً ولا يمكنه استقبال طلبات جديدة';
    END IF;

    -- 3. فحص تاريخ انتهاء الصلاحية (30 يوم)
    IF v_expiry IS NOT NULL AND v_expiry < NOW() THEN
        UPDATE merchants SET status = 'suspended', updated_at = NOW() WHERE id = v_merchant_id;
        RAISE EXCEPTION 'انتهت صلاحية باقة المحل (30 يوم)، يرجى التجديد لتفعيل الحساب';
    END IF;

    -- 4. جلب شروط وقواعد الباقة المشترك فيها التاجر
    IF v_tier_id IS NULL THEN
        RAISE EXCEPTION 'التاجر غير مشترك في أي باقة حالياً';
    END IF;

    SELECT included_orders, overlimit_fee_per_order, max_overlimit_orders
    INTO v_included_orders, v_overlimit_fee, v_max_overlimit
    FROM subscription_tiers WHERE id = v_tier_id;

    -- 5. تطبيق منطق الباقة اللامحدودة (Unlimited)
    IF v_included_orders = -1 THEN
        RETURN NEW; -- مرر الأوردر فوراً بدون أي خصومات
    END IF;

    -- 6. تطبيق منطق الباقات المحدودة (Basic & Pro)
    IF v_remaining_orders > 0 THEN
        -- استهلاك أوردر عادي من الباقة ونقص العداد بمقدار 1
        UPDATE merchants 
        SET remaining_orders = remaining_orders - 1,
            updated_at = NOW()
        WHERE id = v_merchant_id;
        
        RETURN NEW;
    ELSE
        -- الباقة الأساسية انتهت.. الدخول في نظام الأوردر الإضافي بالقطعة
        
        -- أ. فحص هل التاجر عدى السقف المسموح بيه للأوردرات الزيادة؟
        IF v_overlimit_count >= v_max_overlimit THEN
            UPDATE merchants SET status = 'suspended', updated_at = NOW() WHERE id = v_merchant_id;
            RAISE EXCEPTION 'وصل المحل للحد الأقصى من الطلبات الإضافية، يرجى ترقية الباقة';
        END IF;

        -- ب. فحص هل محفظته فيها فلوس تغطي تمن الأوردر الزيادة (7 أو 5 جنيه)؟
        IF v_wallet_balance < v_overlimit_fee THEN
            UPDATE merchants SET status = 'suspended', updated_at = NOW() WHERE id = v_merchant_id;
            RAISE EXCEPTION 'رصيد المحفظة غير كافٍ لتغطية رسوم الأوردر الإضافي، تم إيقاف المتجر مؤقتاً';
        END IF;

        -- ج. الخصم من المحفظة وتحديث العدادات
        UPDATE merchants 
        SET wallet_balance = wallet_balance - v_overlimit_fee,
            overlimit_orders_count = overlimit_orders_count + 1,
            updated_at = NOW()
        WHERE id = v_merchant_id;

        -- تسجيل حركة الخصم في جدول المحفظة للشفافية مع التاجر
        INSERT INTO wallet_transactions (merchant_id, amount, type, description)
        VALUES (v_merchant_id, v_overlimit_fee, 'debit', 'خصم رسوم أوردر إضافي فوق الباقة');

        RETURN NEW;
    END IF;
END;
$$;

-- ربط الدالة بجدول الطلبات لتعمل تلقائياً قبل إدخال أي أوردر جديد
DROP TRIGGER IF EXISTS trigger_on_new_order ON public.orders;
CREATE TRIGGER trigger_on_new_order
BEFORE INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.process_merchant_order_logic();


-- 4️⃣ مشغل إضافي لتحديث المتاجر عند تغيير حالة التاجر (لحجب المحل تلقائياً)
CREATE OR REPLACE FUNCTION public.handle_merchant_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IN ('suspended', 'closed') THEN
    UPDATE public.stores
    SET is_active = FALSE,
        is_open = FALSE,
        updated_at = NOW()
    WHERE merchant_id = NEW.id;
  ELSIF NEW.status = 'active' AND OLD.status != 'active' THEN
    UPDATE public.stores
    SET is_active = TRUE,
        is_open = TRUE,
        updated_at = NOW()
    WHERE merchant_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_merchant_status_change ON public.merchants;
CREATE TRIGGER trg_merchant_status_change
  AFTER UPDATE OF status ON public.merchants
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_merchant_status_change();


-- 5️⃣ مشغل إضافي لقوانين إلغاء الطلبات (لحماية النظام من الاحتيال)
CREATE OR REPLACE FUNCTION public.check_order_cancellation_rules()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_role TEXT;
  v_merchant_id UUID;
BEGIN
  -- جلب معرّف التاجر
  v_merchant_id := OLD.merchant_id;
  IF v_merchant_id IS NULL THEN
    SELECT merchant_id INTO v_merchant_id
    FROM public.stores
    WHERE id = OLD.store_id;
  END IF;

  -- جلب دور المستخدم الحالي
  SELECT role INTO v_user_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    IF auth.uid() = v_merchant_id OR v_user_role = 'merchant' THEN
      -- منع إلغاء الطلب إذا كان بالفعل مع الكابتن
      IF OLD.status IN ('picked_up', 'in_transit', 'delivered') THEN
        RAISE EXCEPTION 'Action Unauthorized: Order is already with the driver.';
      END IF;

      -- منع التاجر من الإلغاء في غير حالتي الانتظار أو القبول
      IF OLD.status NOT IN ('pending', 'confirmed') THEN
        RAISE EXCEPTION 'Action Unauthorized: Merchant can only cancel orders in pending or accepted status.';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_cancellation_rules ON public.orders;
CREATE TRIGGER trg_order_cancellation_rules
  BEFORE UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.check_order_cancellation_rules();


-- 6️⃣ وظيفة الفحص الدوري وإيقاف الاشتراكات المنتهية (لجدولتها في الخلفية)
CREATE OR REPLACE FUNCTION public.check_and_suspend_expired_merchants()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.merchants m
  SET status = 'suspended',
      updated_at = NOW()
  FROM public.subscription_tiers t
  WHERE m.current_tier_id = t.id
    AND m.status = 'active'
    AND (
      (m.package_expiry_date IS NOT NULL AND m.package_expiry_date < NOW())
      OR (
        m.remaining_orders <= 0
        AND m.wallet_balance <= 0
        AND t.included_orders != -1
      )
    );
END;
$$;
