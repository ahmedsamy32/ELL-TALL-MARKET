-- Owner-managed zone pricing for app delivery (without GPS distance)

-- Ensure helper function exists in environments where core schema wasn't applied
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.delivery_zone_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  governorate TEXT NOT NULL,
  city TEXT,
  area TEXT,
  fee NUMERIC(10,2) NOT NULL CHECK (fee >= 0),
  estimated_minutes INTEGER CHECK (estimated_minutes IS NULL OR estimated_minutes > 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT delivery_zone_pricing_unique_scope UNIQUE NULLS NOT DISTINCT (governorate, city, area)
);

CREATE INDEX IF NOT EXISTS idx_delivery_zone_pricing_scope
  ON public.delivery_zone_pricing (governorate, city, area);

CREATE INDEX IF NOT EXISTS idx_delivery_zone_pricing_active
  ON public.delivery_zone_pricing (is_active);

DROP TRIGGER IF EXISTS trg_delivery_zone_pricing_updated_at ON public.delivery_zone_pricing;
CREATE TRIGGER trg_delivery_zone_pricing_updated_at
BEFORE UPDATE ON public.delivery_zone_pricing
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.delivery_zone_pricing ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read active delivery zones" ON public.delivery_zone_pricing;
CREATE POLICY "Anyone can read active delivery zones"
  ON public.delivery_zone_pricing FOR SELECT
  TO authenticated
  USING (is_active = TRUE OR public.is_admin());

DROP POLICY IF EXISTS "Owner admin can manage delivery zones" ON public.delivery_zone_pricing;
CREATE POLICY "Owner admin can manage delivery zones"
  ON public.delivery_zone_pricing FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

INSERT INTO public.delivery_zone_pricing (governorate, city, area, fee, estimated_minutes, is_active, created_by)
SELECT 'القاهرة', NULL, NULL, 25.00, 45, TRUE, auth.uid()
WHERE NOT EXISTS (
  SELECT 1 FROM public.delivery_zone_pricing
  WHERE governorate = 'القاهرة' AND city IS NULL AND area IS NULL
);
