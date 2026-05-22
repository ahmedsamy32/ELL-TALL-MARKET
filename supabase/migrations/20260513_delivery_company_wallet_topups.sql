-- ==========================================
-- 🚚 Delivery company wallet topups
-- ==========================================

CREATE TABLE IF NOT EXISTS public.delivery_company_wallet_topups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES public.delivery_companies(id) ON DELETE CASCADE,
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

CREATE TABLE IF NOT EXISTS public.delivery_company_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES public.delivery_companies(id) ON DELETE CASCADE,
  balance DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (company_id)
);

CREATE TABLE IF NOT EXISTS public.delivery_company_wallet_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.delivery_company_wallets(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES public.delivery_companies(id) ON DELETE CASCADE,
  order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('deposit', 'commission', 'adjustment')),
  amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
  balance_before DECIMAL(12,2) NOT NULL,
  balance_after DECIMAL(12,2) NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_company_wallet_topups_company_id
  ON public.delivery_company_wallet_topups(company_id);
CREATE INDEX IF NOT EXISTS idx_delivery_company_wallet_topups_status
  ON public.delivery_company_wallet_topups(status);
CREATE INDEX IF NOT EXISTS idx_delivery_company_wallet_topups_created_at
  ON public.delivery_company_wallet_topups(created_at);

CREATE INDEX IF NOT EXISTS idx_delivery_company_wallets_company_id
  ON public.delivery_company_wallets(company_id);
CREATE INDEX IF NOT EXISTS idx_delivery_company_wallet_transactions_company_id
  ON public.delivery_company_wallet_transactions(company_id);
CREATE INDEX IF NOT EXISTS idx_delivery_company_wallet_transactions_order_id
  ON public.delivery_company_wallet_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_company_wallet_transactions_created_at
  ON public.delivery_company_wallet_transactions(created_at);

ALTER TABLE public.delivery_company_wallet_topups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_company_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_company_wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Delivery company admins create wallet topups"
  ON public.delivery_company_wallet_topups;
CREATE POLICY "Delivery company admins create wallet topups"
  ON public.delivery_company_wallet_topups
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = delivery_company_wallet_topups.company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
  );

DROP POLICY IF EXISTS "Delivery company admins view own wallet topups"
  ON public.delivery_company_wallet_topups;
CREATE POLICY "Delivery company admins view own wallet topups"
  ON public.delivery_company_wallet_topups
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = delivery_company_wallet_topups.company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
  );

DROP POLICY IF EXISTS "Admins manage delivery company wallet topups"
  ON public.delivery_company_wallet_topups;
CREATE POLICY "Admins manage delivery company wallet topups"
  ON public.delivery_company_wallet_topups
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Delivery company admins view own wallets"
  ON public.delivery_company_wallets;
CREATE POLICY "Delivery company admins view own wallets"
  ON public.delivery_company_wallets
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = delivery_company_wallets.company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
  );

DROP POLICY IF EXISTS "Admins manage delivery company wallets"
  ON public.delivery_company_wallets;
CREATE POLICY "Admins manage delivery company wallets"
  ON public.delivery_company_wallets
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Delivery company admins view own wallet transactions"
  ON public.delivery_company_wallet_transactions;
CREATE POLICY "Delivery company admins view own wallet transactions"
  ON public.delivery_company_wallet_transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = delivery_company_wallet_transactions.company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
  );

DROP POLICY IF EXISTS "Admins manage delivery company wallet transactions"
  ON public.delivery_company_wallet_transactions;
CREATE POLICY "Admins manage delivery company wallet transactions"
  ON public.delivery_company_wallet_transactions
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.get_or_create_delivery_company_wallet(
  p_company_id UUID
)
RETURNS public.delivery_company_wallets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.delivery_company_wallets%rowtype;
BEGIN
  IF NOT (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      WHERE dc.id = p_company_id
        AND dc.admin_id = auth.uid()
    )
  ) THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT * INTO v_wallet
  FROM public.delivery_company_wallets
  WHERE company_id = p_company_id;

  IF NOT FOUND THEN
    INSERT INTO public.delivery_company_wallets (company_id, balance)
    VALUES (p_company_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  RETURN v_wallet;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_delivery_company_wallet_topup(
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
  v_wallet public.delivery_company_wallets%rowtype;
  v_new_balance NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'not_allowed');
  END IF;

  SELECT * INTO v_topup
  FROM public.delivery_company_wallet_topups
  WHERE id = p_topup_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'not_found');
  END IF;

  IF v_topup.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'already_processed');
  END IF;

  SELECT * INTO v_wallet
  FROM public.delivery_company_wallets
  WHERE company_id = v_topup.company_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.delivery_company_wallets (company_id, balance)
    VALUES (v_topup.company_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  v_new_balance := v_wallet.balance + v_topup.amount;

  UPDATE public.delivery_company_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  INSERT INTO public.delivery_company_wallet_transactions (
    wallet_id,
    company_id,
    order_id,
    type,
    amount,
    balance_before,
    balance_after,
    notes
  ) VALUES (
    v_wallet.id,
    v_topup.company_id,
    NULL,
    'deposit',
    v_topup.amount,
    v_wallet.balance,
    v_new_balance,
    'Approved delivery office topup'
  );

  UPDATE public.delivery_company_wallet_topups
  SET status = 'approved',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      notes = COALESCE(p_notes, notes)
  WHERE id = p_topup_id;

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_delivery_company_wallet_topup(
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
  FROM public.delivery_company_wallet_topups
  WHERE id = p_topup_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'not_found');
  END IF;

  IF v_topup.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'already_processed');
  END IF;

  UPDATE public.delivery_company_wallet_topups
  SET status = 'rejected',
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      notes = COALESCE(p_notes, notes)
  WHERE id = p_topup_id;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_delivery_company_wallet(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_delivery_company_wallet_topup(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_delivery_company_wallet_topup(UUID, TEXT) TO authenticated;

-- ----------
-- Storage bucket for delivery office receipts (private)
-- ----------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'delivery_wallet_receipts',
  'delivery_wallet_receipts',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "delivery_wallet_receipts_owner_insert" ON storage.objects;
CREATE POLICY "delivery_wallet_receipts_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'delivery_wallet_receipts'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.delivery_companies dc
    WHERE dc.admin_id = auth.uid()
      AND storage.objects.name LIKE '%/delivery_wallet_receipts/' || dc.id::text || '/%'
  )
);

DROP POLICY IF EXISTS "delivery_wallet_receipts_owner_select" ON storage.objects;
CREATE POLICY "delivery_wallet_receipts_owner_select" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'delivery_wallet_receipts'
  AND (
    public.is_admin()
    OR (
      (storage.foldername(name))[1] = auth.uid()::text
      AND EXISTS (
        SELECT 1 FROM public.delivery_companies dc
        WHERE dc.admin_id = auth.uid()
          AND storage.objects.name LIKE '%/delivery_wallet_receipts/' || dc.id::text || '/%'
      )
    )
  )
);

DROP POLICY IF EXISTS "delivery_wallet_receipts_owner_delete" ON storage.objects;
CREATE POLICY "delivery_wallet_receipts_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'delivery_wallet_receipts'
  AND (
    public.is_admin()
    OR (
      (storage.foldername(name))[1] = auth.uid()::text
      AND EXISTS (
        SELECT 1 FROM public.delivery_companies dc
        WHERE dc.admin_id = auth.uid()
          AND storage.objects.name LIKE '%/delivery_wallet_receipts/' || dc.id::text || '/%'
      )
    )
  )
);
