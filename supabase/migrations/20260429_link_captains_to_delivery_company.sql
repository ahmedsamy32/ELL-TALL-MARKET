-- Link captains to delivery companies

ALTER TABLE public.captains
  ADD COLUMN IF NOT EXISTS delivery_company_id UUID REFERENCES public.delivery_companies(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_captains_delivery_company_id
  ON public.captains(delivery_company_id);

-- Backfill from existing delivery_admin_captains mapping
UPDATE public.captains c
SET delivery_company_id = dc.id
FROM public.delivery_admin_captains dac
JOIN public.delivery_companies dc ON dc.admin_id = dac.admin_id
WHERE c.id = dac.captain_id
  AND c.delivery_company_id IS NULL;

-- Keep delivery_company_id in sync when mapping is created
CREATE OR REPLACE FUNCTION public.sync_captain_company_from_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.captains c
  SET delivery_company_id = dc.id
  FROM public.delivery_companies dc
  WHERE dc.admin_id = NEW.admin_id
    AND c.id = NEW.captain_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_delivery_admin_captains_company ON public.delivery_admin_captains;
CREATE TRIGGER trg_delivery_admin_captains_company
AFTER INSERT ON public.delivery_admin_captains
FOR EACH ROW EXECUTE FUNCTION public.sync_captain_company_from_admin();

-- Restrict captain visibility to own delivery company for delivery admins
DROP POLICY IF EXISTS "Authenticated can view active captains" ON public.captains;
DROP POLICY IF EXISTS "Delivery admins view own captains" ON public.captains;
CREATE POLICY "Delivery admins view own captains" ON public.captains
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = captains.delivery_company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.delivery_admin_captains dac
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dac.admin_id = auth.uid()
        AND dac.captain_id = captains.id
        AND p.role = 'delivery_company_admin'
    )
  );
