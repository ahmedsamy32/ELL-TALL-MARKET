-- Add support contact fields to app_settings
ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS support_email TEXT DEFAULT 'support@elltall.com',
  ADD COLUMN IF NOT EXISTS support_phone TEXT DEFAULT '+20 123 456 7890',
  ADD COLUMN IF NOT EXISTS support_website TEXT DEFAULT 'https://www.elltall.com';
