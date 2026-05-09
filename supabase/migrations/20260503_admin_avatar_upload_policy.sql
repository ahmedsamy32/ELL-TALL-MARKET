-- Allow admins to upload avatars for any user in profiles bucket
CREATE POLICY "Admin can upload avatars for any user"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'admin'
  )
);

-- Allow admins to update avatars for any user in profiles bucket
CREATE POLICY "Admin can update avatars for any user"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'admin'
  )
)
WITH CHECK (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'admin'
  )
);

-- Allow admins to delete avatars for any user in profiles bucket
CREATE POLICY "Admin can delete avatars for any user"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'profiles' 
  AND (storage.foldername(name))[1] = 'avatars'
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'admin'
  )
);
