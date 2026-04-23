-- Migration: Add admin function to update user password
-- Created: 2026-02-17
-- Description: Creates a secure RPC function for admins to update user passwords

-- =========================================
-- 0. Enable pgcrypto extension if not exists
-- =========================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================
-- 1. Create function to update user password (Admin only)
-- =========================================

CREATE OR REPLACE FUNCTION public.admin_update_user_password(
  target_user_id UUID,
  new_password TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with the privileges of the function owner
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  result JSON;
BEGIN
  -- Get the role of the calling user
  SELECT role INTO caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  -- Check if caller is an admin
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can update user passwords'
      USING HINT = 'You must be an admin to perform this operation';
  END IF;

  -- Validate password length
  IF LENGTH(new_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters'
      USING HINT = 'Please provide a stronger password';
  END IF;

  -- Update the user's password in auth.users
  -- Note: This requires the service role, which SECURITY DEFINER provides
  UPDATE auth.users
  SET 
    encrypted_password = crypt(new_password, gen_salt('bf')),
    updated_at = NOW()
  WHERE id = target_user_id;

  -- Check if update was successful
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found'
      USING HINT = 'The specified user ID does not exist';
  END IF;

  -- Return success response
  result := json_build_object(
    'success', true,
    'message', 'Password updated successfully',
    'user_id', target_user_id,
    'updated_at', NOW()
  );

  RETURN result;

EXCEPTION
  WHEN OTHERS THEN
    -- Return error response
    result := json_build_object(
      'success', false,
      'error', SQLERRM,
      'user_id', target_user_id
    );
    RETURN result;
END;
$$;

-- =========================================
-- 2. Grant execute permission to authenticated users
-- =========================================

GRANT EXECUTE ON FUNCTION public.admin_update_user_password(UUID, TEXT) TO authenticated;

-- =========================================
-- 3. Add comment for documentation
-- =========================================

COMMENT ON FUNCTION public.admin_update_user_password(UUID, TEXT) IS 
'Allows admin users to securely update passwords for other users. 
Validates admin role and password strength before updating.
Returns JSON with success status and details.';
