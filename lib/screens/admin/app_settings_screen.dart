import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';
import 'package:ell_tall_market/models/settings_model.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late AppSettingsModel _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = AppSettingsModel.empty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsProvider>(context, listen: false).loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    _currentSettings = settingsProvider.appSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ إعدادات التطبيق'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: SafeArea(
        child: settingsProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildSettingsForm(settingsProvider),
      ),
    );
  }

  Widget _buildSettingsForm(SettingsProvider provider) {
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
                ),
                _buildDropdownSetting(
                  "💰 العملة",
                  _currentSettings.currency.code,
                  ['EGP'],
                  (value) => _updateSetting(
                    currency: AppCurrencyExtension.fromCode(value!),
                  ),
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
              title: "🚚 إعدادات التوصيل",
              children: [
                _buildDeliveryInfoBanner(),
                const SizedBox(height: 12),
                _buildTextFieldSetting(
                  "💰 رسوم التوصيل الأساسية (ج.م)",
                  _currentSettings.appDeliveryBaseFee,
                  (value) => _updateSetting(appDeliveryBaseFee: value),
                ),
                _buildTextFieldSetting(
                  "📏 رسوم لكل كيلومتر (ج.م)",
                  _currentSettings.appDeliveryFeePerKm,
                  (value) => _updateSetting(appDeliveryFeePerKm: value),
                ),
                _buildTextFieldSetting(
                  "🗺️ أقصى مسافة للتوصيل (كم)",
                  _currentSettings.appDeliveryMaxDistance,
                  (value) => _updateSetting(appDeliveryMaxDistance: value),
                ),
                _buildIntFieldSetting(
                  "⏱️ الوقت التقديري للتوصيل (دقيقة)",
                  _currentSettings.appDeliveryEstimatedTime,
                  (value) => _updateSetting(appDeliveryEstimatedTime: value),
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
    ValueChanged<String?> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
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

  Widget _buildTextFieldSetting(
    String title,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final controller = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit),
        ),
        onChanged: (val) {
          final parsed = double.tryParse(val);
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      ),
    );
  }

  Widget _buildIntFieldSetting(
    String title,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final controller = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit),
        ),
        onChanged: (val) {
          final parsed = int.tryParse(val);
          if (parsed != null) {
            onChanged(parsed);
          }
        },
      ),
    );
  }

  Widget _buildDeliveryInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'هذه الإعدادات تُطبق عند اختيار التاجر "توصيل التطبيق".\nيتم حساب رسوم التوصيل تلقائياً بناءً على المسافة.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SettingsProvider provider) {
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
    double? appDeliveryBaseFee,
    double? appDeliveryFeePerKm,
    double? appDeliveryMaxDistance,
    int? appDeliveryEstimatedTime,
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
        appDeliveryBaseFee:
            appDeliveryBaseFee ?? _currentSettings.appDeliveryBaseFee,
        appDeliveryFeePerKm:
            appDeliveryFeePerKm ?? _currentSettings.appDeliveryFeePerKm,
        appDeliveryMaxDistance:
            appDeliveryMaxDistance ?? _currentSettings.appDeliveryMaxDistance,
        appDeliveryEstimatedTime:
            appDeliveryEstimatedTime ??
            _currentSettings.appDeliveryEstimatedTime,
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
    try {
      await Provider.of<SettingsProvider>(
        context,
        listen: false,
      ).updateAppSettings(_currentSettings);
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
                await Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).resetSettings();
                setState(() {});
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
