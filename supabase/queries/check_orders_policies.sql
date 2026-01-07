-- استعلام لعرض جميع سياسات RLS الخاصة بجدول orders
SELECT 
  schemaname AS schema,
  tablename AS table_name,
  policyname AS policy_name,
  permissive,
  roles,
  cmd AS command,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE tablename = 'orders'
ORDER BY policyname;

-- ============================================
-- استعلام بديل لعرض معلومات أكثر تفصيلاً
-- ============================================

SELECT 
  pol.polname AS "اسم السياسة",
  CASE pol.polcmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    WHEN '*' THEN 'ALL'
  END AS "نوع العملية",
  CASE 
    WHEN pol.polroles = '{0}' THEN 'public'
    ELSE array_to_string(
      ARRAY(
        SELECT rolname 
        FROM pg_roles 
        WHERE oid = ANY(pol.polroles)
      ), 
      ', '
    )
  END AS "الأدوار",
  CASE pol.polpermissive
    WHEN true THEN 'PERMISSIVE'
    ELSE 'RESTRICTIVE'
  END AS "النوع",
  pg_get_expr(pol.polqual, pol.polrelid) AS "شرط USING",
  pg_get_expr(pol.polwithcheck, pol.polrelid) AS "شرط WITH CHECK"
FROM pg_policy pol
JOIN pg_class cls ON pol.polrelid = cls.oid
JOIN pg_namespace nsp ON cls.relnamespace = nsp.oid
WHERE cls.relname = 'orders'
  AND nsp.nspname = 'public'
ORDER BY pol.polname;

-- ============================================
-- التحقق من حالة RLS على جدول orders
-- ============================================

SELECT 
  nsp.nspname AS schema,
  cls.relname AS table_name,
  cls.relrowsecurity AS "RLS مفعل",
  cls.relforcerowsecurity AS "RLS إجباري",
  COUNT(pol.polname) AS "عدد السياسات الكلي",
  COUNT(*) FILTER (WHERE pol.polcmd = 'r') AS "عدد سياسات SELECT",
  COUNT(*) FILTER (WHERE pol.polcmd = 'a') AS "عدد سياسات INSERT",
  COUNT(*) FILTER (WHERE pol.polcmd = 'w') AS "عدد سياسات UPDATE",
  COUNT(*) FILTER (WHERE pol.polcmd = 'd') AS "عدد سياسات DELETE",
  COUNT(*) FILTER (WHERE pol.polcmd = '*') AS "عدد سياسات ALL"
FROM pg_class cls
JOIN pg_namespace nsp ON cls.relnamespace = nsp.oid
LEFT JOIN pg_policy pol ON pol.polrelid = cls.oid
WHERE cls.relname = 'orders'
  AND nsp.nspname = 'public'
GROUP BY nsp.nspname, cls.relname, cls.relrowsecurity, cls.relforcerowsecurity;
