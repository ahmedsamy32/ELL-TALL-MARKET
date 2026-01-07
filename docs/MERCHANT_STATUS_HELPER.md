# 🔍 دالة التحقق من حالة التاجر - get_merchant_complete_status

## نظرة عامة

دالة SQL مساعدة للتحقق من اكتمال بيانات التاجر والمتجر في قاعدة البيانات.

---

## 📊 الوصف

```sql
CREATE OR REPLACE FUNCTION public.get_merchant_complete_status(p_user_id UUID)
RETURNS JSONB
```

### المعاملات:
- **p_user_id** (UUID): معرف المستخدم/التاجر المراد فحصه

### القيمة المرجعة:
كائن JSONB يحتوي على:

| الحقل | النوع | الوصف |
|------|------|-------|
| `profile_exists` | boolean | هل سجل البروفايل موجود؟ |
| `merchant_exists` | boolean | هل سجل التاجر موجود؟ |
| `store_exists` | boolean | هل سجل المتجر موجود؟ |
| `user_id` | uuid | معرف المستخدم |
| `is_complete` | boolean | هل جميع السجلات موجودة؟ |
| `profile_data` | jsonb | بيانات البروفايل الكاملة |
| `merchant_data` | jsonb | بيانات التاجر الكاملة |
| `store_data` | jsonb | بيانات المتجر الكاملة |

---

## 🎯 حالات الاستخدام

### 1. التشخيص السريع للمشاكل
```sql
-- فحص حالة تاجر معين
SELECT public.get_merchant_complete_status('a1b2c3d4-...'::uuid);
```

### 2. فحص جميع التجار الناقصين
```sql
-- إيجاد جميع التجار الذين لديهم بيانات ناقصة
SELECT 
  id,
  email,
  (public.get_merchant_complete_status(id)->>'is_complete')::boolean as is_complete
FROM profiles
WHERE role = 'merchant'
  AND (public.get_merchant_complete_status(id)->>'is_complete')::boolean = false;
```

### 3. تقرير شامل عن حالة التجار
```sql
-- إحصائيات التجار
SELECT 
  COUNT(*) as total_merchants,
  COUNT(*) FILTER (WHERE (public.get_merchant_complete_status(id)->>'is_complete')::boolean) as complete_merchants,
  COUNT(*) FILTER (WHERE NOT (public.get_merchant_complete_status(id)->>'is_complete')::boolean) as incomplete_merchants
FROM profiles
WHERE role = 'merchant';
```

---

## 💻 الاستخدام من Flutter

### إنشاء Service Method:

```dart
// lib/services/supabase_service.dart

/// التحقق من اكتمال بيانات التاجر
static Future<Map<String, dynamic>?> getMerchantCompleteStatus(
  String userId,
) async {
  try {
    final response = await _client.rpc(
      'get_merchant_complete_status',
      params: {'p_user_id': userId},
    );

    if (response == null) return null;
    
    return Map<String, dynamic>.from(response);
  } catch (e) {
    AppLogger.error('Get merchant status error', e);
    return null;
  }
}
```

### الاستخدام في Provider:

```dart
// lib/providers/merchant_provider.dart

Future<bool> checkMerchantComplete(String userId) async {
  try {
    final status = await SupabaseService.getMerchantCompleteStatus(userId);
    
    if (status == null) return false;
    
    final isComplete = status['is_complete'] as bool? ?? false;
    
    if (!isComplete) {
      // تحليل المشكلة
      final profileExists = status['profile_exists'] as bool? ?? false;
      final merchantExists = status['merchant_exists'] as bool? ?? false;
      final storeExists = status['store_exists'] as bool? ?? false;
      
      debugPrint('📊 Merchant Status:');
      debugPrint('  Profile: ${profileExists ? "✅" : "❌"}');
      debugPrint('  Merchant: ${merchantExists ? "✅" : "❌"}');
      debugPrint('  Store: ${storeExists ? "✅" : "❌"}');
      
      // يمكنك هنا اتخاذ إجراء بناءً على ما هو مفقود
      if (!merchantExists) {
        // محاولة إنشاء سجل التاجر
        await createMerchantRecord(userId);
      }
    }
    
    return isComplete;
  } catch (e) {
    debugPrint('❌ Error checking merchant status: $e');
    return false;
  }
}
```

### الاستخدام في Deep Link Handler:

```dart
// lib/services/auth_deep_link_handler.dart

static Future<void> _checkAndHandleEmailVerification() async {
  try {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    final userRole = await _getUserRole(currentUser.id);
    
    if (userRole == 'merchant') {
      // التحقق من اكتمال بيانات التاجر
      final status = await SupabaseService.getMerchantCompleteStatus(
        currentUser.id,
      );
      
      final isComplete = status?['is_complete'] as bool? ?? false;
      
      if (!isComplete) {
        debugPrint('⚠️ Merchant data incomplete - redirecting to complete profile');
        // توجيه لاستكمال البيانات
        Navigator.pushReplacementNamed(context, AppRoutes.completeStoreProfile);
      } else {
        debugPrint('✅ Merchant data complete - redirecting to home');
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  } catch (e) {
    debugPrint('❌ Error in verification check: $e');
  }
}
```

---

## 🧪 أمثلة على النتائج

### مثال 1: تاجر مكتمل البيانات
```json
{
  "profile_exists": true,
  "merchant_exists": true,
  "store_exists": true,
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "is_complete": true,
  "profile_data": {
    "id": "a1b2c3d4-...",
    "full_name": "أحمد محمد",
    "email": "ahmed@example.com",
    "phone": "01234567890",
    "role": "merchant"
  },
  "merchant_data": {
    "id": "a1b2c3d4-...",
    "store_name": "متجر أحمد",
    "address": "القاهرة، مصر",
    "store_description": "متجر لبيع المنتجات",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "store_data": {
    "id": "store-uuid-...",
    "merchant_id": "a1b2c3d4-...",
    "name": "متجر أحمد",
    "description": "...",
    "created_at": "2024-01-15T10:30:00Z"
  }
}
```

### مثال 2: تاجر بدون سجل merchant
```json
{
  "profile_exists": true,
  "merchant_exists": false,
  "store_exists": false,
  "user_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "is_complete": false,
  "profile_data": {
    "id": "a1b2c3d4-...",
    "full_name": "محمد علي",
    "email": "mohamed@example.com",
    "role": "merchant"
  },
  "merchant_data": null,
  "store_data": null
}
```

### مثال 3: مستخدم غير موجود
```json
{
  "profile_exists": false,
  "merchant_exists": false,
  "store_exists": false,
  "user_id": "00000000-0000-0000-0000-000000000000",
  "is_complete": false,
  "profile_data": null,
  "merchant_data": null,
  "store_data": null
}
```

---

## 🔒 الأمان

- **SECURITY DEFINER**: الدالة تعمل بصلاحيات المالك (owner) وليس المستخدم الحالي
- **SET search_path = public**: لمنع SQL injection عبر search_path
- تتجاوز RLS policies للقراءة فقط (read-only)
- لا تقوم بأي عمليات كتابة أو تعديل

---

## 📝 ملاحظات

1. **الدالة للقراءة فقط**: لا تقوم بإنشاء أو تعديل أي سجلات
2. **مناسبة للتشخيص**: مثالية لاكتشاف مشاكل التسجيل
3. **يمكن استدعاؤها من Flutter**: عبر `.rpc()` method
4. **تعمل مع جميع المستخدمين**: ليست مقتصرة على التجار فقط

---

## 🎯 حالات الاستخدام الشائعة

### ✅ جيد للاستخدام في:
- صفحات التشخيص (Debug/Admin pages)
- فحص حالة التسجيل بعد email confirmation
- تقارير الـ Backend عن بيانات التجار
- Unit tests للتحقق من نجاح التسجيل

### ❌ تجنب الاستخدام في:
- استدعاءات متكررة في الـ UI (مكلف على قاعدة البيانات)
- كل مرة يتم فيها عرض صفحة (استخدم caching)
- للمستخدمين العاديين (clients) - غير ضروري

---

## 🔄 التكامل مع النظام الحالي

بعد تطبيق migration `update_handle_new_user_trigger.sql`:

1. ✅ الـ trigger يُنشئ السجلات تلقائياً
2. ✅ الدالة تتحقق من نجاح الإنشاء
3. ✅ Flutter يستخدم الدالة للتحقق قبل التوجيه

هذا يضمن تكامل سلس بين:
- **Database Triggers** (الإنشاء التلقائي)
- **Helper Function** (التحقق من الحالة)
- **Flutter App** (اتخاذ القرار بناءً على الحالة)

---

## 📚 مراجع

- [PostgreSQL JSONB Functions](https://www.postgresql.org/docs/current/functions-json.html)
- [Supabase RPC Documentation](https://supabase.com/docs/reference/javascript/rpc)
- [SECURITY DEFINER Best Practices](https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY)
