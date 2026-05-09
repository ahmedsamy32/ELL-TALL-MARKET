-- Delivery companies linked to cities

CREATE TABLE IF NOT EXISTS public.delivery_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  company_name TEXT NOT NULL,
  governorate TEXT,
  city TEXT NOT NULL,
  address TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT delivery_companies_unique_city UNIQUE (city, company_name)
);

CREATE INDEX IF NOT EXISTS idx_delivery_companies_city
  ON public.delivery_companies(city);
CREATE INDEX IF NOT EXISTS idx_delivery_companies_admin
  ON public.delivery_companies(admin_id);

ALTER TABLE public.delivery_companies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Delivery companies public read" ON public.delivery_companies;
CREATE POLICY "Delivery companies public read"
  ON public.delivery_companies FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Delivery companies admin manage" ON public.delivery_companies;
CREATE POLICY "Delivery companies admin manage"
  ON public.delivery_companies FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Delivery company admin manage own company" ON public.delivery_companies;
CREATE POLICY "Delivery company admin manage own company"
  ON public.delivery_companies FOR ALL
  TO authenticated
  USING (
    admin_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'delivery_company_admin'
    )
  )
  WITH CHECK (
    admin_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'delivery_company_admin'
    )
  );

DROP TRIGGER IF EXISTS trg_delivery_companies_updated_at ON public.delivery_companies;
CREATE TRIGGER trg_delivery_companies_updated_at
BEFORE UPDATE ON public.delivery_companies
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Delivery company addresses (similar to client addresses)
CREATE TABLE IF NOT EXISTS public.delivery_company_addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES public.delivery_companies(id) ON DELETE CASCADE,
  label VARCHAR(100) DEFAULT 'المكتب',
  address TEXT,
  governorate TEXT,
  city TEXT NOT NULL,
  area TEXT,
  street TEXT NOT NULL,
  building_number TEXT,
  floor_number TEXT,
  apartment_number TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  location GEOGRAPHY(POINT, 4326),
  landmark TEXT,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_company_addresses_company
  ON public.delivery_company_addresses(company_id);
CREATE INDEX IF NOT EXISTS idx_delivery_company_addresses_default
  ON public.delivery_company_addresses(company_id, is_default);

ALTER TABLE public.delivery_company_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Delivery company addresses admin manage" ON public.delivery_company_addresses;
CREATE POLICY "Delivery company addresses admin manage"
  ON public.delivery_company_addresses FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Delivery company admins manage own addresses" ON public.delivery_company_addresses;
CREATE POLICY "Delivery company admins manage own addresses"
  ON public.delivery_company_addresses FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = delivery_company_addresses.company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.delivery_companies dc
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE dc.id = delivery_company_addresses.company_id
        AND dc.admin_id = auth.uid()
        AND p.role = 'delivery_company_admin'
    )
  );

DROP TRIGGER IF EXISTS trg_delivery_company_addresses_updated_at ON public.delivery_company_addresses;
CREATE TRIGGER trg_delivery_company_addresses_updated_at
BEFORE UPDATE ON public.delivery_company_addresses
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.delivery_companies
  ADD COLUMN IF NOT EXISTS address_id UUID REFERENCES public.delivery_company_addresses(id) ON DELETE SET NULL;
