-- ==========================================
-- Store wallet policy refresh
-- ==========================================

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

DROP POLICY IF EXISTS "wallet_receipts_owner_insert" ON storage.objects;
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
