-- ==========================================
-- 🔔 Store auto-close notifications (wallet)
-- ==========================================

CREATE OR REPLACE FUNCTION public.notify_store_wallet_auto_closed(
  p_store_id UUID,
  p_balance NUMERIC,
  p_source TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_name TEXT;
BEGIN
  SELECT name INTO v_store_name
  FROM public.stores
  WHERE id = p_store_id;

  IF v_store_name IS NULL THEN
    v_store_name := 'المتجر';
  END IF;

  -- Merchant notification (store scoped)
  INSERT INTO public.notifications (
    store_id,
    title,
    body,
    type,
    target_role,
    data,
    created_at
  ) VALUES (
    p_store_id,
    '⛔ تم إغلاق المتجر مؤقتاً',
    'تم إغلاق المتجر تلقائياً بسبب رصيد المحفظة السالب. يرجى شحن المحفظة لإعادة فتحه. - المصدر: النظام',
    'system',
    'merchant',
    jsonb_build_object(
      'type', 'store_wallet_auto_closed',
      'target_role', 'merchant',
      'store_id', p_store_id,
      'balance', p_balance,
      'source', p_source,
      'source_label', 'النظام',
      'action_url', '/merchant/wallet'
    ),
    NOW()
  );

  -- Admin notifications
  INSERT INTO public.notifications (
    user_id,
    title,
    body,
    type,
    target_role,
    data,
    created_at
  )
  SELECT
    p.id,
    '⛔ متجر تم إغلاقه تلقائياً',
    'تم إغلاق متجر ' || v_store_name || ' تلقائياً بسبب رصيد محفظة سالب. - المصدر: النظام',
    'system',
    'admin',
    jsonb_build_object(
      'type', 'store_wallet_auto_closed',
      'target_role', 'admin',
      'store_id', p_store_id,
      'store_name', v_store_name,
      'balance', p_balance,
      'source', p_source,
      'source_label', 'النظام',
      'action_url', '/admin/users'
    ),
    NOW()
  FROM public.profiles p
  WHERE p.role = 'admin';
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
  v_rows INTEGER;
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
    WHERE id = p_store_id
      AND is_open = TRUE;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows > 0 THEN
      PERFORM public.notify_store_wallet_auto_closed(
        p_store_id,
        v_balance,
        'precheck'
      );
    END IF;

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
  v_rows INTEGER;
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

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows > 0 THEN
      PERFORM public.notify_store_wallet_auto_closed(
        NEW.store_id,
        v_new_balance,
        'commission'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
