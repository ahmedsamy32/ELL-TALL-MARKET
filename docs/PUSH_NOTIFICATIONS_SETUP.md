# 🔔 إعداد Push Notifications (إشعارات حتى لو التطبيق مقفول)

## كيف يشتغل النظام؟

```
إشعار جديد يتحفظ في جدول notifications
         │
         ▼
  Database Trigger (PostgreSQL)
         │
         ▼
  Supabase Edge Function (push-notification)
         │
         ▼
  يجيب FCM tokens من جدول device_tokens
         │
         ▼
  يبعت Push عبر FCM HTTP v1 API
         │
         ▼
  📱 الإشعار يظهر في شريط الإشعارات!
```

---

## الخطوات المطلوبة (مرة واحدة فقط)

### الخطوة 1: Firebase Service Account Key

1. روح على [Firebase Console](https://console.firebase.google.com/)
2. اختار مشروع **ell-tall-market**
3. روح على **Project Settings** → **Service Accounts**
4. اضغط **Generate New Private Key**
5. هيتحمل ملف JSON - احفظه في مكان آمن

---

### الخطوة 2: تثبيت Supabase CLI

```powershell
# Windows (Scoop)
scoop install supabase

# أو npm
npm install -g supabase
```

---

### الخطوة 3: ربط المشروع

```powershell
cd "E:\FlutterProjects\Ell Tall Market"

# تسجيل الدخول
supabase login

# ربط المشروع
supabase link --project-ref ebbkdhmwaawzxbidjynz
```

---

### الخطوة 4: رفع Firebase Service Account كـ Secret

```powershell
# انسخ محتوى ملف الـ JSON واعمله paste كـ secret
# ⚠️ مهم: الملف كله سطر واحد بدون spaces
supabase secrets set FIREBASE_SERVICE_ACCOUNT='محتوى ملف JSON هنا'
```

**أو بطريقة أسهل** - اقرأ من الملف مباشرة:
```powershell
# PowerShell
$json = Get-Content "path/to/firebase-service-account.json" -Raw
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$json"
```

---

### الخطوة 5: رفع Edge Function

```powershell
cd "E:\FlutterProjects\Ell Tall Market"

supabase functions deploy push-notification --project-ref ebbkdhmwaawzxbidjynz
```

---

### الخطوة 6: إعداد Database Trigger

#### الطريقة الأسهل: من Supabase Dashboard

1. روح على [Supabase Dashboard](https://supabase.com/dashboard/project/ebbkdhmwaawzxbidjynz)
2. **Database** → **Webhooks** → **Create Webhook**
3. الإعدادات:
   - **Name:** `push-notification-on-insert`
   - **Table:** `notifications`
   - **Events:** `INSERT`
   - **Type:** `Supabase Edge Function`
   - **Edge Function:** `push-notification`
   - **HTTP Headers:** أضف `Authorization: Bearer {service_role_key}`

#### أو: SQL Editor

1. روح Dashboard → **SQL Editor**
2. الصق محتوى `supabase/migrations/20260206_push_notification_trigger.sql`
3. **مهم:** قبل ما تشغل الـ SQL، لازم تضيف Service Role Key في Vault:

```sql
-- أضف Service Role Key في Vault
SELECT vault.create_secret(
  'service_role_key',
  'YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE'
);
```

4. شغّل الـ SQL

---

### الخطوة 7: اختبار

```sql
-- في SQL Editor: ابعت إشعار تجريبي
INSERT INTO notifications (user_id, title, body, type, data)
VALUES (
  'YOUR_USER_ID_HERE',
  'إشعار تجريبي 🎉',
  'ده إشعار تجريبي من السيرفر',
  'system',
  '{"type": "test", "target_role": "client"}'::jsonb
);
```

---

## ✅ قائمة التحقق

- [ ] Firebase Service Account key متحمل
- [ ] Supabase CLI متثبت
- [ ] المشروع متربط (`supabase link`)
- [ ] الـ Secret متضاف (`FIREBASE_SERVICE_ACCOUNT`)
- [ ] Edge Function مرفوعة (`supabase functions deploy`)
- [ ] Database Trigger/Webhook شغال
- [ ] تم الاختبار بإشعار تجريبي

---

## ملاحظات مهمة

1. **Service Role Key** لا تضعه في الكود أبداً - استخدم Vault أو Dashboard Webhook
2. **الـ Edge Function** بتشتغل تلقائياً - مش محتاج تغير حاجة في كود Flutter
3. **تنظيف التوكنات**: الـ function بتحذف التوكنات الباطلة تلقائياً
4. **التكلفة**: Supabase Free Plan يشمل 500K Edge Function invocations/شهر
