-- Admin wallet adjustments for stores and delivery companies

ALTER TABLE public.store_wallet_transactions
  DROP CONSTRAINT IF EXISTS store_wallet_transactions_type_check;

ALTER TABLE public.store_wallet_transactions
  ADD CONSTRAINT store_wallet_transactions_type_check
  CHECK (type IN ('deposit', 'commission', 'adjustment'));

CREATE OR REPLACE FUNCTION public.admin_adjust_store_wallet_balance(
  p_store_id UUID,
  p_amount NUMERIC,
  p_is_credit BOOLEAN,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.store_wallets%rowtype;
  v_new_balance NUMERIC;
  v_delta NUMERIC;
  v_notes TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'not_allowed');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  SELECT * INTO v_wallet
  FROM public.store_wallets
  WHERE store_id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.store_wallets (store_id, balance)
    VALUES (p_store_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  v_delta := CASE WHEN p_is_credit THEN p_amount ELSE -p_amount END;
  v_new_balance := v_wallet.balance + v_delta;

  UPDATE public.store_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  v_notes := COALESCE(
    p_notes,
    CASE WHEN p_is_credit THEN 'Admin credit adjustment'
         ELSE 'Admin debit adjustment' END
  );

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
    p_store_id,
    NULL,
    'adjustment',
    p_amount,
    v_wallet.balance,
    v_new_balance,
    v_notes
  );

  IF v_wallet.balance < 0 AND v_new_balance >= 0 THEN
    UPDATE public.stores
    SET is_open = TRUE,
        updated_at = NOW()
    WHERE id = p_store_id
      AND is_active = TRUE;
  END IF;

  IF v_new_balance < -10 THEN
    UPDATE public.stores
    SET is_open = FALSE,
        updated_at = NOW()
    WHERE id = p_store_id
      AND is_open = TRUE;
  END IF;

  RETURN json_build_object('success', true, 'balance', v_new_balance);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_adjust_delivery_company_wallet_balance(
  p_company_id UUID,
  p_amount NUMERIC,
  p_is_credit BOOLEAN,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet public.delivery_company_wallets%rowtype;
  v_new_balance NUMERIC;
  v_delta NUMERIC;
  v_notes TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'not_allowed');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  SELECT * INTO v_wallet
  FROM public.delivery_company_wallets
  WHERE company_id = p_company_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.delivery_company_wallets (company_id, balance)
    VALUES (p_company_id, 0)
    RETURNING * INTO v_wallet;
  END IF;

  v_delta := CASE WHEN p_is_credit THEN p_amount ELSE -p_amount END;
  v_new_balance := v_wallet.balance + v_delta;

  UPDATE public.delivery_company_wallets
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  v_notes := COALESCE(
    p_notes,
    CASE WHEN p_is_credit THEN 'Admin credit adjustment'
         ELSE 'Admin debit adjustment' END
  );

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
    p_company_id,
    NULL,
    'adjustment',
    p_amount,
    v_wallet.balance,
    v_new_balance,
    v_notes
  );

  RETURN json_build_object('success', true, 'balance', v_new_balance);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_adjust_store_wallet_balance(UUID, NUMERIC, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_delivery_company_wallet_balance(UUID, NUMERIC, BOOLEAN, TEXT) TO authenticated;
