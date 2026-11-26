-- ============================================================================
-- 🛠️ إصلاح سياسات التخزين (Storage RLS) لسلة المنتجات (products bucket)
-- حل مشكلة: new row violates row-level security policy
-- وحل مشكلة: index row requires 63592 bytes, maximum size is 8191
-- ============================================================================

-- 1. التأكد من وجود سلة المنتجات وضبطها كـ Public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'products',
  'products',
  true,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 2. إتاحة قراءة الصور لجميع المستخدمين والزوار
DROP POLICY IF EXISTS "products_public_read" ON storage.objects;
CREATE POLICY "products_public_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'products');

-- 3. السماح برفع الصور للمسؤولين (Admins) والتجار أصحاب المتاجر والمستخدمين المعتمدين
DROP POLICY IF EXISTS "products_owner_insert" ON storage.objects;
CREATE POLICY "products_owner_insert" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'products'
  AND (
    -- أ) الأدمن أو مدير النظام مسموح له الرفع لأي متجر
    public.is_admin()
    OR
    -- ب) التاجر صاحب المتجر
    EXISTS (
      SELECT 1 FROM public.stores s
      WHERE s.merchant_id = auth.uid()
        AND storage.objects.name LIKE '%/' || s.id::text || '/%'
    )
    OR
    -- ج) أي مستخدم موثق يرفع في مجلده الخاص
    (storage.foldername(name))[1] = auth.uid()::text
  )
);

-- 4. السماح بالتعديل (Update)
DROP POLICY IF EXISTS "products_owner_update" ON storage.objects;
CREATE POLICY "products_owner_update" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'products'
  AND (
    public.is_admin()
    OR (storage.foldername(name))[1] = auth.uid()::text
  )
)
WITH CHECK (
  bucket_id = 'products'
  AND (
    public.is_admin()
    OR (storage.foldername(name))[1] = auth.uid()::text
  )
);

-- 5. السماح بالحذف (Delete)
DROP POLICY IF EXISTS "products_owner_delete" ON storage.objects;
CREATE POLICY "products_owner_delete" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'products'
  AND (
    public.is_admin()
    OR (storage.foldername(name))[1] = auth.uid()::text
  )
);
