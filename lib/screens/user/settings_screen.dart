import 'package:flutter/material.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/settings_model.dart';
import 'package:ell_tall_market/providers/locale_provider.dart';
import 'package:ell_tall_market/providers/client_settings_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/screens/user/notification_settings_screen.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClientSettingsProvider>().loadSettings();
    });
  }

  Future<void> _handleRefresh() async {
    await context.read<ClientSettingsProvider>().loadSettings();
  }

  Future<bool> _updateSettings(AppSettingsModel settings) async {
    try {
      await context.read<ClientSettingsProvider>().updateSettings(settings);
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حفظ الإعدادات: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  void _showQuickActionsSheet() {
    final settingsProvider = context.read<ClientSettingsProvider>();
    var sheetSettings = settingsProvider.clientSettings;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> handleToggle(
                AppSettingsModel Function(AppSettingsModel current) buildNew,
              ) async {
                final previous = sheetSettings;
                final next = buildNew(sheetSettings);
                setSheetState(() => sheetSettings = next);
                final success = await _updateSettings(next);
                if (!success && mounted) {
                  setSheetState(() => sheetSettings = previous);
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجراءات سريعة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    /* 
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: sheetSettings.darkMode,
                      title: const Text('الوضع الداكن'),
                      subtitle: const Text('فعّل الثيم الداكن للتطبيق بالكامل'),
                      secondary: const Icon(Icons.dark_mode_rounded),
                      onChanged: (value) => handleToggle(
                        (current) => current.copyWith(darkMode: value),
                      ),
                    ),
                    */
                    /* 
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: sheetSettings.biometricAuth,
                      title: const Text('تسجيل الدخول بالبصمة'),
                      subtitle: const Text('استخدم Face ID أو بصمة الإصبع'),
                      secondary: const Icon(Icons.fingerprint_rounded),
                      onChanged: (value) => handleToggle(
                        (current) => current.copyWith(biometricAuth: value),
                      ),
                    ),
                    */
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: sheetSettings.savePaymentMethods,
                      title: const Text('حفظ طرق الدفع'),
                      subtitle: const Text(
                        'استخدم نفس الطريقة بشكل أسرع في الطلبات',
                      ),
                      secondary: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      onChanged: (value) => handleToggle(
                        (current) =>
                            current.copyWith(savePaymentMethods: value),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: sheetSettings.dataSaver,
                      title: const Text('تفعيل وضع توفير البيانات'),
                      subtitle: const Text(
                        'تقليل تحميل الصور العالية أثناء التصفح',
                      ),
                      secondary: const Icon(Icons.data_saver_on_rounded),
                      onChanged: (value) => handleToggle(
                        (current) => current.copyWith(dataSaver: value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('تم'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final settingsProvider = Provider.of<ClientSettingsProvider>(context);
    final isArabic = localeProvider.locale.languageCode == 'ar';

    final listChildren = <Widget>[
      if (settingsProvider.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildErrorBanner(
            context,
            message: settingsProvider.error!,
            onRetry: _handleRefresh,
          ),
        ),
      _buildSettingItem(
        context,
        title: 'معلومات الحساب',
        onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
      ),
      _buildSettingItem(
        context,
        title: 'عناوين التوصيل',
        onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
      ),
      _buildSettingItem(
        context,
        title: 'الإشعارات',
        trailing: Text(
          settingsProvider.clientSettings.notificationsEnabled
              ? 'مفعلة'
              : 'معطلة',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationSettingsScreen(),
          ),
        ),
      ),
      _buildSettingItem(
        context,
        title: 'معلومات الدفع',
        onTap: () => _showPaymentMethodDialog(context),
      ),
      _buildSettingItem(
        context,
        title: 'اللغة',
        trailing: Text(
          'العربية',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        onTap: () => _showLanguageDialog(context, localeProvider),
      ),
      _buildSettingItem(
        context,
        title: 'الدولة',
        trailing: Text(
          'مصر',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        onTap: () => _showCountryDialog(context),
      ),
    ];

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          centerTitle: true,
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showQuickActionsSheet,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('إجراءات سريعة'),
        ),
        body: ResponsiveCenter(
          maxWidth: 700,
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: colorScheme.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (settingsProvider.isLoading)
                    SizedBox(
                      height: 180,
                      child: AppShimmer.centeredLines(context),
                    )
                  else
                    ...listChildren,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (trailing != null) ...[trailing, const SizedBox(width: 12)],
                Icon(
                  isRTL
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 24,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context, {
    required String message,
    required Future<void> Function() onRetry,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر اللغة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'ar',
                  // ignore: deprecated_member_use
                  groupValue: localeProvider.locale.languageCode,
                  title: const Text('العربية'),
                  subtitle: const Text('Arabic'),
                  secondary: const Icon(Icons.language_rounded),
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    localeProvider.setLocale(value!);
                    Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCountryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختر الدولة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مصر'),
                  subtitle: const Text('Egypt'),
                  leading: const Icon(Icons.public_rounded),
                  onTap: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentMethodDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات الدفع',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الدفع عند الاستلام'),
                  subtitle: const Text('Cash on Delivery'),
                  leading: const Icon(Icons.payments_outlined),
                  onTap: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
