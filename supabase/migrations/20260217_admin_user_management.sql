-- =============================================
-- STEP 1: FORCE DROP ALL OLD FUNCTIONS
-- =============================================
DO $$
DECLARE
  r RECORD;
BEGIN
  -- Drop ALL overloads of admin_delete_user
  FOR r IN SELECT oid::regprocedure::text AS sig
           FROM pg_proc WHERE proname = 'admin_delete_user' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
  END LOOP;

  -- Drop ALL overloads of admin_create_user
  FOR r IN SELECT oid::regprocedure::text AS sig
           FROM pg_proc WHERE proname = 'admin_create_user' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
  END LOOP;

  -- Drop ALL overloads of admin_update_user
  FOR r IN SELECT oid::regprocedure::text AS sig
           FROM pg_proc WHERE proname = 'admin_update_user' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
  END LOOP;

  -- Drop ALL overloads of admin_toggle_user_status
  FOR r IN SELECT oid::regprocedure::text AS sig
           FROM pg_proc WHERE proname = 'admin_toggle_user_status' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
  END LOOP;

  -- Drop old password function too
  FOR r IN SELECT oid::regprocedure::text AS sig
           FROM pg_proc WHERE proname = 'admin_update_user_password' AND pronamespace = 'public'::regnamespace
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
  END LOOP;

  RAISE NOTICE 'All old admin functions dropped successfully';
END $$;

-- =============================================
-- STEP 2: Ensure pgcrypto
-- =============================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================
-- FUNCTION 1: admin_create_user
-- =============================================
CREATE FUNCTION public.admin_create_user(
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
  caller_role TEXT;
  new_user_id UUID;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id::text = auth.uid()::text;
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'error', 'Only admins can create users');
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
    new_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    LOWER(TRIM(user_email)), crypt(user_password, gen_salt('bf')), NOW(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('full_name', user_full_name, 'phone', user_phone, 'role', user_role),
    NOW(), NOW(), '', '', '', ''
  );

  INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES (
    gen_random_uuid(), new_user_id, LOWER(TRIM(user_email)),
    jsonb_build_object('sub', new_user_id::text, 'email', LOWER(TRIM(user_email))),
    'email', NOW(), NOW(), NOW()
  );

  INSERT INTO public.profiles (id, full_name, email, phone, role, is_active, password, created_at, updated_at)
  VALUES (new_user_id, user_full_name, LOWER(TRIM(user_email)), user_phone, user_role, true, user_password, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name, email = EXCLUDED.email, phone = EXCLUDED.phone,
    role = EXCLUDED.role, password = EXCLUDED.password, updated_at = NOW();

  RETURN json_build_object('success', true, 'user_id', new_user_id, 'message', 'User created successfully');
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =============================================
-- FUNCTION 2: admin_delete_user
-- =============================================
CREATE FUNCTION public.admin_delete_user(p_user_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  caller_role TEXT;
  target_email TEXT;
  uid TEXT := p_user_id;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id::text = auth.uid()::text;
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'error', 'Only admins can delete users');
  END IF;

  IF uid = auth.uid()::text THEN
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

-- =============================================
-- FUNCTION 3: admin_update_user
-- =============================================
CREATE FUNCTION public.admin_update_user(
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
  caller_role TEXT;
  current_email TEXT;
  uid TEXT := p_user_id;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id::text = auth.uid()::text;
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'error', 'Only admins can update users');
  END IF;

  SELECT email INTO current_email FROM auth.users WHERE id::text = uid;
  IF current_email IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  IF new_email IS NOT NULL AND LOWER(TRIM(new_email)) != current_email THEN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = LOWER(TRIM(new_email)) AND id::text != uid) THEN
      RETURN json_build_object('success', false, 'error', 'Email already in use');
    END IF;
    UPDATE auth.users SET email = LOWER(TRIM(new_email)),
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
        'full_name', COALESCE(new_full_name, raw_user_meta_data->>'full_name'),
        'phone', COALESCE(new_phone, raw_user_meta_data->>'phone'),
        'role', COALESCE(new_role, raw_user_meta_data->>'role')),
      updated_at = NOW() WHERE id::text = uid;
    UPDATE auth.identities SET
      identity_data = identity_data || jsonb_build_object('email', LOWER(TRIM(new_email))),
      provider_id = LOWER(TRIM(new_email)), updated_at = NOW()
    WHERE user_id::text = uid AND provider = 'email';
  ELSE
    UPDATE auth.users SET
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
        'full_name', COALESCE(new_full_name, raw_user_meta_data->>'full_name'),
        'phone', COALESCE(new_phone, raw_user_meta_data->>'phone'),
        'role', COALESCE(new_role, raw_user_meta_data->>'role')),
      updated_at = NOW() WHERE id::text = uid;
  END IF;

  IF new_password IS NOT NULL AND LENGTH(new_password) >= 6 THEN
    UPDATE auth.users SET encrypted_password = crypt(new_password, gen_salt('bf')), updated_at = NOW() WHERE id::text = uid;
  END IF;

  UPDATE public.profiles SET
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

-- =============================================
-- FUNCTION 4: admin_toggle_user_status
-- =============================================
CREATE FUNCTION public.admin_toggle_user_status(p_user_id TEXT, p_active BOOLEAN)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  caller_role TEXT;
  uid TEXT := p_user_id;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id::text = auth.uid()::text;
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'error', 'Only admins can toggle user status');
  END IF;

  IF uid = auth.uid()::text AND p_active = false THEN
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

  RETURN json_build_object('success', true, 'user_id', uid, 'is_active', p_active,
    'message', CASE WHEN p_active THEN 'User activated' ELSE 'User deactivated' END);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- =============================================
-- GRANT permissions
-- =============================================
GRANT EXECUTE ON FUNCTION public.admin_create_user(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_user_status(TEXT, BOOLEAN) TO authenticated;
