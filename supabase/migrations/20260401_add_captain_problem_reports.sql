-- جدول بلاغات مشاكل الكباتن أثناء التوصيل
-- تاريخ: 2026-04-01

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS public.captain_problem_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  captain_id UUID NOT NULL REFERENCES public.captains(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  problem_type TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'in_review', 'resolved', 'dismissed')),
  priority TEXT NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_captain_problem_reports_captain
  ON public.captain_problem_reports(captain_id);

CREATE INDEX IF NOT EXISTS idx_captain_problem_reports_order
  ON public.captain_problem_reports(order_id);

CREATE INDEX IF NOT EXISTS idx_captain_problem_reports_status
  ON public.captain_problem_reports(status);

CREATE INDEX IF NOT EXISTS idx_captain_problem_reports_created_at
  ON public.captain_problem_reports(created_at DESC);

ALTER TABLE public.captain_problem_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Captain can insert own problem reports"
  ON public.captain_problem_reports;
CREATE POLICY "Captain can insert own problem reports"
  ON public.captain_problem_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (captain_id = auth.uid());

DROP POLICY IF EXISTS "Captain can view own problem reports"
  ON public.captain_problem_reports;
CREATE POLICY "Captain can view own problem reports"
  ON public.captain_problem_reports
  FOR SELECT
  TO authenticated
  USING (captain_id = auth.uid());

DROP POLICY IF EXISTS "Admin can manage all captain problem reports"
  ON public.captain_problem_reports;
CREATE POLICY "Admin can manage all captain problem reports"
  ON public.captain_problem_reports
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_captain_problem_reports_updated_at'
  ) THEN
    CREATE TRIGGER trg_captain_problem_reports_updated_at
      BEFORE UPDATE ON public.captain_problem_reports
      FOR EACH ROW
      EXECUTE FUNCTION public.update_updated_at();
  END IF;
END $$;
