import 'package:flutter/material.dart';
import 'package:ell_tall_market/config/admin_config.dart';

class AdminRegistrationWidget extends StatefulWidget {
  final Function(String? adminCode) onAdminCodeChanged;

  const AdminRegistrationWidget({super.key, required this.onAdminCodeChanged});

  @override
  State<AdminRegistrationWidget> createState() =>
      _AdminRegistrationWidgetState();
}

class _AdminRegistrationWidgetState extends State<AdminRegistrationWidget> {
  final _adminCodeController = TextEditingController();
  bool _showAdminFields = false;
  bool _isValidAdminCode = false;

  @override
  void dispose() {
    _adminCodeController.dispose();
    super.dispose();
  }

  void _checkAdminCode(String code) {
    final isValid = AdminDetectionConfig.isValidAdminCode(code);
    setState(() {
      _isValidAdminCode = isValid;
    });

    widget.onAdminCodeChanged(isValid ? code : null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'تسجيل كأدمن؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _showAdminFields,
                  onChanged: (value) {
                    setState(() {
                      _showAdminFields = value;
                      if (!value) {
                        _adminCodeController.clear();
                        _isValidAdminCode = false;
                        widget.onAdminCodeChanged(null);
                      }
                    });
                  },
                ),
              ],
            ),

            if (_showAdminFields) ...[
              const SizedBox(height: 16),
              const Text(
                'طرق التحديد كأدمن:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // عرض الإيميلات المسموحة
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ الإيميلات المسموحة للأدمن:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...AdminDetectionConfig.adminEmails.map(
                      (email) => Text('• $email'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // حقل الكود السري
              TextFormField(
                controller: _adminCodeController,
                decoration: InputDecoration(
                  labelText: 'الكود السري للأدمن (اختياري)',
                  hintText: 'أدخل الكود السري إذا لم تستخدم إيميل أدمن',
                  prefixIcon: const Icon(Icons.security),
                  suffixIcon: _isValidAdminCode
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _checkAdminCode,
                validator: (value) {
                  if (_showAdminFields && value != null && value.isNotEmpty) {
                    if (!AdminDetectionConfig.isValidAdminCode(value)) {
                      return 'كود غير صحيح';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // معلومات إضافية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ℹ️ ملاحظات:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text('• يمكن التحديد كأدمن بالإيميل المناسب'),
                    Text('• أو باستخدام الكود السري'),
                    Text('• أو بكلمة مرور خاصة'),
                    Text('• الأدمن له صلاحيات كاملة في التطبيق'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
