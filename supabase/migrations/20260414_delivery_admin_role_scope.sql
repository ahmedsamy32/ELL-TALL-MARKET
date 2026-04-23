-- Delivery Company Admin Role (scoped permissions)
-- 1) Adds delivery_company_admin to profiles.role CHECK
-- 2) Updates admin_create_user to allow:
--    - owner admin: create any allowed role
--    - delivery_company_admin: create captain only

DO $$
DECLARE
  c RECORD;
BEGIN
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%role%'
  LOOP
    EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_role_check
CHECK (role IN ('client', 'merchant', 'captain', 'admin', 'delivery_company_admin'));

-- Delivery scope mapping (which captains belong to which delivery admin)
CREATE TABLE IF NOT EXISTS public.delivery_admin_captains (
  admin_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  captain_id UUID NOT NULL REFERENCES public.captains(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (admin_id, captain_id)
);

CREATE INDEX IF NOT EXISTS idx_delivery_admin_captains_admin
  ON public.delivery_admin_captains(admin_id);
CREATE INDEX IF NOT EXISTS idx_delivery_admin_captains_captain
  ON public.delivery_admin_captains(captain_id);

ALTER TABLE public.delivery_admin_captains ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner admins manage delivery mapping" ON public.delivery_admin_captains;
CREATE POLICY "Owner admins manage delivery mapping" ON public.delivery_admin_captains
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Delivery admins view own mapping" ON public.delivery_admin_captains;
CREATE POLICY "Delivery admins view own mapping" ON public.delivery_admin_captains
  FOR SELECT TO authenticated
  USING (
    auth.uid() = admin_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'delivery_company_admin'
    )
  );

CREATE OR REPLACE FUNCTION public.admin_create_user(
  user_email TEXT,
  user_password TEXT,
  user_full_name TEXT,
  user_phone TEXT,
  user_role TEXT DEFAULT 'client'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  caller_uid UUID := auth.uid();
  caller_role TEXT;
  new_user_id UUID;
  normalized_role TEXT;
BEGIN
  IF caller_uid IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Failed to check user auth status');
  END IF;

  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = caller_uid;

  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'delivery_company_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only owner admin or delivery admin can create users');
  END IF;

  normalized_role := lower(trim(coalesce(user_role, 'client')));

  IF normalized_role NOT IN ('client', 'merchant', 'captain', 'admin', 'delivery_company_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Invalid role');
  END IF;

  -- Delivery admin is scoped to delivery only: can create captains only
  IF caller_role = 'delivery_company_admin' AND normalized_role <> 'captain' THEN
    RETURN json_build_object('success', false, 'error', 'Delivery admin can create captains only');
  END IF;

  IF LENGTH(TRIM(user_email)) = 0 THEN
    RETURN json_build_object('success', false, 'error', 'Email is required');
  END IF;

  IF LENGTH(user_password) < 6 THEN
    RETURN json_build_object('success', false, 'error', 'Password must be at least 6 characters');
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE email = LOWER(TRIM(user_email))) THEN
    RETURN json_build_object('success', false, 'error', 'Email already registered');
  END IF;

  new_user_id := gen_random_uuid();

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    new_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    LOWER(TRIM(user_email)),
    crypt(user_password, gen_salt('bf')),
    NOW(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('full_name', user_full_name, 'phone', user_phone, 'role', normalized_role),
    NOW(), NOW(), '', '', '', ''
  );

  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES (
    gen_random_uuid(),
    new_user_id,
    LOWER(TRIM(user_email)),
    jsonb_build_object('sub', new_user_id::text, 'email', LOWER(TRIM(user_email))),
    'email', NOW(), NOW(), NOW()
  );

  INSERT INTO public.profiles (id, full_name, email, phone, role, is_active, password, created_at, updated_at)
  VALUES (new_user_id, user_full_name, LOWER(TRIM(user_email)), user_phone, normalized_role, true, user_password, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role,
    password = EXCLUDED.password,
    updated_at = NOW();

  -- Auto-link new captain to the delivery admin who created him.
  IF caller_role = 'delivery_company_admin' AND normalized_role = 'captain' THEN
    INSERT INTO public.delivery_admin_captains(admin_id, captain_id)
    VALUES (caller_uid, new_user_id)
    ON CONFLICT (admin_id, captain_id) DO NOTHING;
  END IF;

  RETURN json_build_object('success', true, 'user_id', new_user_id, 'message', 'User created successfully');
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_user(
  p_user_id TEXT,
  new_full_name TEXT DEFAULT NULL,
  new_email TEXT DEFAULT NULL,
  new_phone TEXT DEFAULT NULL,
  new_role TEXT DEFAULT NULL,
  new_password TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  caller_uid UUID := auth.uid();
  caller_role TEXT;
  current_email TEXT;
  uid TEXT := p_user_id;
  target_role TEXT;
BEGIN
  IF caller_uid IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Failed to check user auth status');
  END IF;

  SELECT role INTO caller_role FROM public.profiles WHERE id = caller_uid;
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'delivery_company_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only owner admin or delivery admin can update users');
  END IF;

  SELECT role INTO target_role FROM public.profiles WHERE id::text = uid;
  IF target_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Delivery admin is scoped to captains only
  IF caller_role = 'delivery_company_admin' THEN
    IF target_role <> 'captain' THEN
      RETURN json_build_object('success', false, 'error', 'Delivery admin can update captains only');
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.delivery_admin_captains dac
      WHERE dac.admin_id = caller_uid
        AND dac.captain_id::text = uid
    ) THEN
      RETURN json_build_object('success', false, 'error', 'Captain is خارج نطاق مسؤول الدليفري');
    END IF;
    IF new_role IS NOT NULL AND lower(trim(new_role)) <> 'captain' THEN
      RETURN json_build_object('success', false, 'error', 'Delivery admin cannot change role from captain');
    END IF;
  END IF;

  SELECT email INTO current_email FROM auth.users WHERE id::text = uid;
  IF current_email IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF new_email IS NOT NULL AND LOWER(TRIM(new_email)) != current_email THEN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = LOWER(TRIM(new_email)) AND id::text != uid) THEN
      RETURN json_build_object('success', false, 'error', 'Email already in use');
    END IF;
    UPDATE auth.users
    SET
      email = LOWER(TRIM(new_email)),
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
        'full_name', COALESCE(new_full_name, raw_user_meta_data->>'full_name'),
        'phone', COALESCE(new_phone, raw_user_meta_data->>'phone'),
        'role', COALESCE(new_role, raw_user_meta_data->>'role')
      ),
      updated_at = NOW()
    WHERE id::text = uid;

    UPDATE auth.identities
    SET
      identity_data = identity_data || jsonb_build_object('email', LOWER(TRIM(new_email))),
      provider_id = LOWER(TRIM(new_email)),
      updated_at = NOW()
    WHERE user_id::text = uid AND provider = 'email';
  ELSE
    UPDATE auth.users
    SET
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
        'full_name', COALESCE(new_full_name, raw_user_meta_data->>'full_name'),
        'phone', COALESCE(new_phone, raw_user_meta_data->>'phone'),
        'role', COALESCE(new_role, raw_user_meta_data->>'role')
      ),
      updated_at = NOW()
    WHERE id::text = uid;
  END IF;

  IF new_password IS NOT NULL AND LENGTH(new_password) >= 6 THEN
    UPDATE auth.users
    SET encrypted_password = crypt(new_password, gen_salt('bf')), updated_at = NOW()
    WHERE id::text = uid;
  END IF;

  UPDATE public.profiles
  SET
    full_name = COALESCE(new_full_name, full_name),
    email = COALESCE(LOWER(TRIM(new_email)), email),
    phone = COALESCE(new_phone, phone),
    role = COALESCE(new_role, role),
    password = COALESCE(new_password, password),
    updated_at = NOW()
  WHERE id::text = uid;

  RETURN json_build_object('success', true, 'user_id', uid, 'message', 'User updated successfully');
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_toggle_user_status(p_user_id TEXT, p_active BOOLEAN)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  caller_uid UUID := auth.uid();
  caller_role TEXT;
  uid TEXT := p_user_id;
  target_role TEXT;
BEGIN
  IF caller_uid IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Failed to check user auth status');
  END IF;

  SELECT role INTO caller_role FROM public.profiles WHERE id = caller_uid;
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'delivery_company_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only owner admin or delivery admin can toggle user status');
  END IF;

  SELECT role INTO target_role FROM public.profiles WHERE id::text = uid;
  IF target_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF caller_role = 'delivery_company_admin' AND target_role <> 'captain' THEN
    RETURN json_build_object('success', false, 'error', 'Delivery admin can toggle captains only');
  END IF;

  IF caller_role = 'delivery_company_admin' AND NOT EXISTS (
    SELECT 1
    FROM public.delivery_admin_captains dac
    WHERE dac.admin_id = caller_uid
      AND dac.captain_id::text = uid
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Captain is خارج نطاق مسؤول الدليفري');
  END IF;

  IF uid = caller_uid::text AND p_active = false THEN
    RETURN json_build_object('success', false, 'error', 'Cannot disable your own account');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id::text = uid) THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF p_active THEN
    UPDATE auth.users SET banned_until = NULL, updated_at = NOW() WHERE id::text = uid;
  ELSE
    UPDATE auth.users SET banned_until = '2999-12-31 23:59:59+00'::timestamptz, updated_at = NOW() WHERE id::text = uid;
    DELETE FROM auth.sessions WHERE user_id::text = uid;
    DELETE FROM auth.refresh_tokens WHERE user_id::text = uid;
  END IF;

  UPDATE public.profiles SET is_active = p_active, updated_at = NOW() WHERE id::text = uid;

  RETURN json_build_object(
    'success', true,
    'user_id', uid,
    'is_active', p_active,
    'message', CASE WHEN p_active THEN 'User activated' ELSE 'User deactivated' END
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  caller_uid UUID := auth.uid();
  caller_role TEXT;
  target_email TEXT;
  uid TEXT := p_user_id;
  target_role TEXT;
BEGIN
  IF caller_uid IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Failed to check user auth status');
  END IF;

  SELECT role INTO caller_role FROM public.profiles WHERE id = caller_uid;
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'delivery_company_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only owner admin or delivery admin can delete users');
  END IF;

  SELECT role INTO target_role FROM public.profiles WHERE id::text = uid;
  IF target_role IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF caller_role = 'delivery_company_admin' AND target_role <> 'captain' THEN
    RETURN json_build_object('success', false, 'error', 'Delivery admin can delete captains only');
  END IF;

  IF caller_role = 'delivery_company_admin' AND NOT EXISTS (
    SELECT 1
    FROM public.delivery_admin_captains dac
    WHERE dac.admin_id = caller_uid
      AND dac.captain_id::text = uid
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Captain is خارج نطاق مسؤول الدليفري');
  END IF;

  IF uid = caller_uid::text THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete your own account');
  END IF;

  SELECT email INTO target_email FROM auth.users WHERE id::text = uid;
  IF target_email IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  DELETE FROM public.profiles WHERE id::text = uid;
  DELETE FROM auth.identities WHERE user_id::text = uid;
  DELETE FROM auth.sessions WHERE user_id::text = uid;
  DELETE FROM auth.refresh_tokens WHERE user_id::text = uid;
  DELETE FROM auth.users WHERE id::text = uid;

  RETURN json_build_object('success', true, 'message', 'User deleted successfully', 'deleted_email', target_email);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_user_status(TEXT, BOOLEAN) TO authenticated;
