import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';
import 'package:ell_tall_market/models/settings_model.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late AppSettingsModel _currentSettings;

  // Controllers to avoid rebuilding / focus loss / framework crashes on keystroke
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _supportWebsiteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSettings = AppSettingsModel.empty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppSettingsProvider>(context, listen: false).loadSettings();
    });
  }

  @override
  void dispose() {
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _supportWebsiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<AppSettingsProvider>(context);
    final loadedSettings = settingsProvider.appSettings;

    // Only populate controllers when settings are loaded/changed from database
    if (loadedSettings.id != _currentSettings.id) {
      _currentSettings = loadedSettings;
      _supportEmailController.text = _currentSettings.supportEmail;
      _supportPhoneController.text = _currentSettings.supportPhone;
      _supportWebsiteController.text = _currentSettings.supportWebsite;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ إعدادات التطبيق'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 700,
        child: SafeArea(
          child: settingsProvider.isLoading
              ? AppShimmer.centeredLines(context)
              : _buildSettingsForm(settingsProvider),
        ),
      ),
    );
  }

  Widget _buildSettingsForm(AppSettingsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildCard(
              title: "🔔 الإشعارات",
              children: [
                _buildSwitchSetting(
                  "تفعيل الإشعارات",
                  _currentSettings.notificationsEnabled,
                  (value) => _updateSetting(notificationsEnabled: value),
                ),
                _buildSwitchSetting(
                  "الإشعارات البريدية",
                  _currentSettings.emailNotifications,
                  (value) => _updateSetting(emailNotifications: value),
                ),
                _buildSwitchSetting(
                  "الإشعارات النصية",
                  _currentSettings.smsNotifications,
                  (value) => _updateSetting(smsNotifications: value),
                ),
              ],
            ),

            _buildCard(
              title: "🎨 المظهر",
              children: [
                _buildSwitchSetting(
                  "الوضع الليلي",
                  _currentSettings.darkMode,
                  (value) => _updateSetting(darkMode: value),
                ),
                _buildDropdownSetting(
                  "🌐 اللغة",
                  _currentSettings.language.code,
                  ['ar', 'en'],
                  (value) => _updateSetting(
                    language: AppLanguageExtension.fromCode(value!),
                  ),
                  key: const ValueKey('setting_language'),
                ),
                _buildDropdownSetting(
                  "💰 العملة",
                  _currentSettings.currency.code,
                  ['EGP'],
                  (value) => _updateSetting(
                    currency: AppCurrencyExtension.fromCode(value!),
                  ),
                  key: const ValueKey('setting_currency'),
                ),
              ],
            ),

            _buildCard(
              title: "🔐 الأمان",
              children: [
                _buildSwitchSetting(
                  "المصادقة البيومترية",
                  _currentSettings.biometricAuth,
                  (value) => _updateSetting(biometricAuth: value),
                ),
                _buildSwitchSetting(
                  "حفظ طرق الدفع",
                  _currentSettings.savePaymentMethods,
                  (value) => _updateSetting(savePaymentMethods: value),
                ),
              ],
            ),

            _buildCard(
              title: "⚡ عام",
              children: [
                _buildSwitchSetting(
                  "التحديث التلقائي",
                  _currentSettings.autoUpdate,
                  (value) => _updateSetting(autoUpdate: value),
                ),
                _buildSwitchSetting(
                  "توفير البيانات",
                  _currentSettings.dataSaver,
                  (value) => _updateSetting(dataSaver: value),
                ),
                _buildSliderSetting(
                  "📦 مدة التخزين المؤقت (أيام)",
                  _currentSettings.cacheDuration.toDouble(),
                  1,
                  30,
                  (value) => _updateSetting(cacheDuration: value.toInt()),
                ),
              ],
            ),

            _buildCard(
              title: "📊 التحليلات",
              children: [
                _buildSwitchSetting(
                  "تفعيل التحليلات",
                  _currentSettings.analyticsEnabled,
                  (value) => _updateSetting(analyticsEnabled: value),
                ),
                _buildSwitchSetting(
                  "تقارير الأعطال",
                  _currentSettings.crashReports,
                  (value) => _updateSetting(crashReports: value),
                ),
              ],
            ),

            _buildCard(
              title: "📞 التواصل والدعم",
              children: [
                _buildStringFieldSetting(
                  "📧 البريد الإلكتروني للدعم",
                  _supportEmailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildStringFieldSetting(
                  "📞 رقم الهاتف للدعم",
                  _supportPhoneController,
                  keyboardType: TextInputType.phone,
                ),
                _buildStringFieldSetting(
                  "🌐 موقع الدعم",
                  _supportWebsiteController,
                  keyboardType: TextInputType.url,
                ),
              ],
            ),



            const SizedBox(height: 24),
            _buildActionButtons(provider),
          ],
        ),
      ),
    );
  }

  // 🔹 Widgets Utility

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownSetting(
    String title,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    required Key key,
  }) {
    return ListTile(
      key: key,
      title: Text(title),
      trailing: DropdownButton<String>(
        key: ValueKey('dropdown_${key.toString()}'),
        value: value,
        items: options.map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(_getOptionDisplayName(option)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderSetting(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }



  Widget _buildStringFieldSetting(
    String title,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
      ),
    );
  }



  Widget _buildActionButtons(AppSettingsProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetSettings,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة تعيين'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  // 🔹 Logic

  void _updateSetting({
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? darkMode,
    AppLanguage? language,
    AppCurrency? currency,
    bool? biometricAuth,
    bool? savePaymentMethods,
    bool? autoUpdate,
    bool? dataSaver,
    int? cacheDuration,
    bool? analyticsEnabled,
    bool? crashReports,
    String? supportEmail,
    String? supportPhone,
    String? supportWebsite,
  }) {
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        notificationsEnabled:
            notificationsEnabled ?? _currentSettings.notificationsEnabled,
        emailNotifications:
            emailNotifications ?? _currentSettings.emailNotifications,
        smsNotifications: smsNotifications ?? _currentSettings.smsNotifications,
        darkMode: darkMode ?? _currentSettings.darkMode,
        language: language ?? _currentSettings.language,
        currency: currency ?? _currentSettings.currency,
        biometricAuth: biometricAuth ?? _currentSettings.biometricAuth,
        savePaymentMethods:
            savePaymentMethods ?? _currentSettings.savePaymentMethods,
        autoUpdate: autoUpdate ?? _currentSettings.autoUpdate,
        dataSaver: dataSaver ?? _currentSettings.dataSaver,
        cacheDuration: cacheDuration ?? _currentSettings.cacheDuration,
        analyticsEnabled: analyticsEnabled ?? _currentSettings.analyticsEnabled,
        crashReports: crashReports ?? _currentSettings.crashReports,
        supportEmail: supportEmail ?? _currentSettings.supportEmail,
        supportPhone: supportPhone ?? _currentSettings.supportPhone,
        supportWebsite: supportWebsite ?? _currentSettings.supportWebsite,
      );
    });
  }

  String _getOptionDisplayName(String option) {
    switch (option) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'EGP':
        return 'ج.م';
      default:
        return 'ج.م';
    }
  }

  // 🔹 Actions

  void _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final updatedSettings = _currentSettings.copyWith(
      supportEmail: _supportEmailController.text.trim(),
      supportPhone: _supportPhoneController.text.trim(),
      supportWebsite: _supportWebsiteController.text.trim(),
    );

    try {
      await Provider.of<AppSettingsProvider>(
        context,
        listen: false,
      ).updateAppSettings(updatedSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل حفظ الإعدادات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين الإعدادات'),
        content: const Text(
          'هل تريد إعادة تعيين جميع الإعدادات للقيم الافتراضية؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final provider = Provider.of<AppSettingsProvider>(context, listen: false);
                await provider.resetSettings();
                final loaded = provider.appSettings;
                setState(() {
                  _currentSettings = loaded;
                  _supportEmailController.text = loaded.supportEmail;
                  _supportPhoneController.text = loaded.supportPhone;
                  _supportWebsiteController.text = loaded.supportWebsite;
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم إعادة التعيين بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ فشل إعادة التعيين: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
