-- ==========================================
-- 💼 STORE WALLETS, TRANSACTIONS, AND TOPUPS
-- ==========================================

-- ----------
-- Tables
-- ----------
CREATE TABLE IF NOT EXISTS public.store_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  balance DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (store_id)
);

CREATE TABLE IF NOT EXISTS public.store_wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.store_wallets(id) ON DELETE CASCADE,
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'commission')),
  amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
  balance_before DECIMAL(12,2) NOT NULL,
  balance_after DECIMAL(12,2) NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.store_wallet_topups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  receipt_path TEXT,
  instapay_reference TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  requested_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------
-- Indexes
-- ----------
CREATE INDEX IF NOT EXISTS idx_store_wallets_store_id ON public.store_wallets(store_id);
CREATE INDEX IF NOT EXISTS idx_store_wallet_transactions_store_id ON public.store_wallet_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_store_wallet_transactions_order_id ON public.store_wallet_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_store_wallet_transactions_created_at ON public.store_wallet_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_store_wallet_topups_store_id ON public.store_wallet_topups(store_id);
CREATE INDEX IF NOT EXISTS idx_store_wallet_topups_status ON public.store_wallet_topups(status);
CREATE INDEX IF NOT EXISTS idx_store_wallet_topups_created_at ON public.store_wallet_topups(created_at);

-- ----------
-- RLS
-- ----------
ALTER TABLE public.store_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_wallet_topups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Merchants view own store wallets" ON public.store_wallets;
CREATE POLICY "Merchants view own store wallets" ON public.store_wallets
FOR SELECT USING (
  auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_wallets.store_id)
);

DROP POLICY IF EXISTS "Admins manage store wallets" ON public.store_wallets;
CREATE POLICY "Admins manage store wallets" ON public.store_wallets
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Merchants view own store wallet transactions" ON public.store_wallet_transactions;
CREATE POLICY "Merchants view own store wallet transactions" ON public.store_wallet_transactions
FOR SELECT USING (
  auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_wallet_transactions.store_id)
);

DROP POLICY IF EXISTS "Admins manage store wallet transactions" ON public.store_wallet_transactions;
CREATE POLICY "Admins manage store wallet transactions" ON public.store_wallet_transactions
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Merchants can create topups" ON public.store_wallet_topups;
CREATE POLICY "Merchants can create topups" ON public.store_wallet_topups
FOR INSERT WITH CHECK (
  auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_wallet_topups.store_id)
);

DROP POLICY IF EXISTS "Merchants view own topups" ON public.store_wallet_topups;
CREATE POLICY "Merchants view own topups" ON public.store_wallet_topups
FOR SELECT USING (
  auth.uid() IN (SELECT merchant_id FROM public.stores WHERE stores.id = store_wallet_topups.store_id)
);

DROP POLICY IF EXISTS "Admins manage topups" ON public.store_wallet_topups;
CREATE POLICY "Admins manage topups" ON public.store_wallet_topups
FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ----------
-- Functions
-- ----------
CREATE OR REPLACE FUNCTION public.get_or_create_store_wallet(p_store_id UUID)
RETURNS public.store_wallets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.store_wallets%rowtype;
BEGIN
  IF NOT (public.is_admin() OR auth.uid() IN (
    SELECT merchant_id FROM public.stores WHERE id = p_store_id
  )) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT * INTO v_wallet
  FROM public.store_wallets
  WHERE store_id = p_store_id;

  IF NOT FOUND THEN
    INSERT INTO public.store_wallets (store_id, balance)
    VALUES (p_store_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  RETURN v_wallet;
END;
$$;

CREATE OR REPLACE FUNCTION public.can_store_wallet_cover(
  p_store_id UUID,
  p_total_amount NUMERIC,
  p_delivery_fee NUMERIC DEFAULT 0,
  p_tax_amount NUMERIC DEFAULT 0
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_delivery_mode TEXT;
  v_commission_base NUMERIC;
  v_commission_amount NUMERIC;
  v_balance NUMERIC;
  v_is_open BOOLEAN;
  v_is_active BOOLEAN;
BEGIN
  SELECT delivery_mode, is_open, is_active
  INTO v_delivery_mode, v_is_open, v_is_active
  FROM public.stores
  WHERE id = p_store_id;

  IF v_delivery_mode IS NULL THEN
    RETURN FALSE;
  END IF;

  IF v_is_open IS NOT TRUE OR v_is_active IS NOT TRUE THEN
    RETURN FALSE;
  END IF;

  IF v_delivery_mode = 'store' THEN
    v_commission_base := COALESCE(p_total_amount, 0);
  ELSE
    v_commission_base := COALESCE(p_total_amount, 0)
      - COALESCE(p_delivery_fee, 0)
      - COALESCE(p_tax_amount, 0);
  END IF;

  IF v_commission_base < 0 THEN
    v_commission_base := 0;
  END IF;

  v_commission_amount := ROUND(v_commission_base * 0.05, 2);

  IF v_commission_amount = 0 THEN
    RETURN TRUE;
  END IF;

  SELECT balance INTO v_balance
  FROM public.store_wallets
  WHERE store_id = p_store_id;

  IF v_balance IS NULL THEN
    INSERT INTO public.store_wallets (store_id, balance)
    VALUES (p_store_id, 0)
    RETURNING balance INTO v_balance;
  END IF;

  IF v_balance < -10 THEN
    UPDATE public.stores
    SET is_open = FALSE,
        updated_at = NOW()
    WHERE id = p_store_id;
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_store_wallet_commission()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_delivery_mode TEXT;
  v_commission_base NUMERIC;
  v_commission_amount NUMERIC;
  v_wallet public.store_wallets%rowtype;
  v_new_balance NUMERIC;
BEGIN
  SELECT delivery_mode INTO v_delivery_mode
  FROM public.stores
  WHERE id = NEW.store_id;

  IF v_delivery_mode IS NULL THEN
    RAISE EXCEPTION 'STORE_NOT_FOUND';
  END IF;

  IF v_delivery_mode = 'store' THEN
    v_commission_base := COALESCE(NEW.total_amount, 0);
  ELSE
    v_commission_base := COALESCE(NEW.total_amount, 0)
      - COALESCE(NEW.delivery_fee, 0)
      - COALESCE(NEW.tax_amount, 0);
  END IF;

  IF v_commission_base < 0 THEN
    v_commission_base := 0;
  END IF;

  v_commission_amount := ROUND(v_commission_base * 0.05, 2);

  IF v_commission_amount = 0 THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_wallet
  FROM public.store_wallets
  WHERE store_id = NEW.store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.store_wallets (store_id, balance)
    VALUES (NEW.store_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  v_new_balance := v_wallet.balance - v_commission_amount;

  UPDATE public.store_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  INSERT INTO public.store_wallet_transactions (
    wallet_id,
    store_id,
    order_id,
    type,
    amount,
    balance_before,
    balance_after,
    notes
  ) VALUES (
    v_wallet.id,
    NEW.store_id,
    NEW.id,
    'commission',
    v_commission_amount,
    v_wallet.balance,
    v_new_balance,
    'Auto commission on order creation'
  );

  IF v_new_balance < -10 THEN
    UPDATE public.stores
    SET is_open = FALSE,
        updated_at = NOW()
    WHERE id = NEW.store_id
      AND is_open = TRUE;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_store_wallet_topup(
  p_topup_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_topup RECORD;
  v_wallet public.store_wallets%rowtype;
  v_new_balance NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'not_allowed');
  END IF;

  SELECT * INTO v_topup
  FROM public.store_wallet_topups
  WHERE id = p_topup_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'not_found');
  END IF;

  IF v_topup.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'already_processed');
  END IF;

  SELECT * INTO v_wallet
  FROM public.store_wallets
  WHERE store_id = v_topup.store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.store_wallets (store_id, balance)
    VALUES (v_topup.store_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  v_new_balance := v_wallet.balance + v_topup.amount;

  UPDATE public.store_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  INSERT INTO public.store_wallet_transactions (
    wallet_id,
    store_id,
    order_id,
    type,
    amount,
    balance_before,
    balance_after,
    notes
  ) VALUES (
    v_wallet.id,
    v_topup.store_id,
    NULL,
    'deposit',
    v_topup.amount,
    v_wallet.balance,
    v_new_balance,
    'Approved topup request'
  );

  UPDATE public.store_wallet_topups
  SET status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      notes = COALESCE(p_notes, notes)
  WHERE id = p_topup_id;

  IF v_wallet.balance < 0 AND v_new_balance >= 0 THEN
    UPDATE public.stores
    SET is_open = TRUE,
        updated_at = NOW()
    WHERE id = v_topup.store_id
      AND is_active = TRUE;
  END IF;

  RETURN json_build_object('success', true, 'balance', v_new_balance);
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_store_open_for_orders()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_open BOOLEAN;
  v_is_active BOOLEAN;
BEGIN
  SELECT is_open, is_active
  INTO v_is_open, v_is_active
  FROM public.stores
  WHERE id = NEW.store_id;

  IF v_is_open IS NOT TRUE OR v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'STORE_CLOSED';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.prevent_store_open_without_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  IF NEW.is_open IS TRUE AND (OLD.is_open IS DISTINCT FROM TRUE) THEN
    SELECT balance INTO v_balance
    FROM public.store_wallets
    WHERE store_id = NEW.id;

    IF v_balance IS NULL THEN
      v_balance := 0;
    END IF;

    IF v_balance < 0 THEN
      RAISE EXCEPTION 'STORE_WALLET_NEGATIVE';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_store_wallet_topup(
  p_topup_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_topup RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'not_allowed');
  END IF;

  SELECT * INTO v_topup
  FROM public.store_wallet_topups
  WHERE id = p_topup_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'not_found');
  END IF;

  IF v_topup.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'already_processed');
  END IF;

  UPDATE public.store_wallet_topups
  SET status = 'rejected',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      notes = COALESCE(p_notes, notes)
  WHERE id = p_topup_id;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_store_wallet(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_store_wallet_cover(UUID, NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_store_wallet_topup(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_store_wallet_topup(UUID, TEXT) TO authenticated;

-- ----------
-- Trigger for commission deduction
-- ----------
DROP TRIGGER IF EXISTS trg_store_wallet_commission ON public.orders;
CREATE TRIGGER trg_store_wallet_commission
AFTER INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.apply_store_wallet_commission();

DROP TRIGGER IF EXISTS trg_store_open_before_order ON public.orders;
CREATE TRIGGER trg_store_open_before_order
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.ensure_store_open_for_orders();

DROP TRIGGER IF EXISTS trg_store_wallet_open_guard ON public.stores;
CREATE TRIGGER trg_store_wallet_open_guard
BEFORE UPDATE OF is_open ON public.stores
FOR EACH ROW EXECUTE FUNCTION public.prevent_store_open_without_balance();

-- ----------
-- Storage bucket for topup receipts (private)
-- ----------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'wallet_receipts',
  'wallet_receipts',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE POLICY "wallet_receipts_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'wallet_receipts'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.stores s
    WHERE s.merchant_id = auth.uid()
      AND storage.objects.name LIKE '%/wallet_receipts/' || s.id::text || '/%'
  )
);

DROP POLICY IF EXISTS "wallet_receipts_owner_select" ON storage.objects;
CREATE POLICY "wallet_receipts_owner_select" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'wallet_receipts'
  AND (
    public.is_admin()
    OR (
      (storage.foldername(name))[1] = auth.uid()::text
      AND EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.merchant_id = auth.uid()
          AND storage.objects.name LIKE '%/wallet_receipts/' || s.id::text || '/%'
      )
    )
  )
);

DROP POLICY IF EXISTS "wallet_receipts_owner_delete" ON storage.objects;
CREATE POLICY "wallet_receipts_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'wallet_receipts'
  AND (
    public.is_admin()
    OR (
      (storage.foldername(name))[1] = auth.uid()::text
      AND EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.merchant_id = auth.uid()
          AND storage.objects.name LIKE '%/wallet_receipts/' || s.id::text || '/%'
      )
    )
  )
);
