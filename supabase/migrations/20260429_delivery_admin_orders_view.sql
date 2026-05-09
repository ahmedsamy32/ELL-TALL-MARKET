 -- Allow delivery company admins to view app-delivery orders
-- Scope: delivery_company_admin role + stores.delivery_mode = 'app'

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Delivery admins view app-delivery orders" ON public.orders;
CREATE POLICY "Delivery admins view app-delivery orders" ON public.orders
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'delivery_company_admin'
    )
    AND EXISTS (
      SELECT 1 FROM public.stores s
      WHERE s.id = store_id AND s.delivery_mode = 'app'
    )
  );

DROP POLICY IF EXISTS "Delivery admins update app-delivery orders" ON public.orders;
CREATE POLICY "Delivery admins update app-delivery orders" ON public.orders
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'delivery_company_admin'
    )
    AND EXISTS (
      SELECT 1 FROM public.stores s
      WHERE s.id = store_id AND s.delivery_mode = 'app'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'delivery_company_admin'
    )
    AND EXISTS (
      SELECT 1 FROM public.stores s
      WHERE s.id = store_id AND s.delivery_mode = 'app'
    )
  );
