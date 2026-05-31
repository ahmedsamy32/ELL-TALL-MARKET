import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/services/app_update_service.dart';
import 'package:ell_tall_market/utils/helpers.dart';

import '../../models/profile_model.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndRedirect();
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  Future<void> _checkAuthAndRedirect() async {
    AppLogger.info('🔍 SplashScreen: بدء التحقق من المصادقة...');

    try {
      if (!mounted) {
        AppLogger.warning('❌ SplashScreen: Context غير متصل');
        return;
      }

      AppLogger.info('🔍 SplashScreen: محاولة الوصول إلى authProvider...');
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      AppLogger.info('✅ SplashScreen: تم العثور على authProvider بنجاح');

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) {
        AppLogger.warning('❌ SplashScreen: Widget غير متصل بعد التأخير');
        return;
      }

      final canContinue = await _checkForUpdate();
      if (!canContinue) {
        AppLogger.info('⛔ SplashScreen: تم إيقاف التوجيه بسبب تحديث إجباري');
        return;
      }

      if (!mounted) {
        AppLogger.warning('❌ SplashScreen: Widget غير متصل بعد التحديث');
        return;
      }

      final user = authProvider.currentUserProfile;
      AppLogger.info(
        '🔍 SplashScreen: المستخدم الحالي: ${user?.email ?? 'لا يوجد مستخدم'}',
      );

      if (user != null) {
        AppLogger.info('🔍 SplashScreen: نوع المستخدم: ${user.role}');
        switch (user.role) {
          case UserRole.admin:
            AppLogger.info('🔄 SplashScreen: توجيه إلى لوحة تحكم الأدمن');
            Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
            break;
          case UserRole.deliveryCompanyAdmin:
            AppLogger.info('🔄 SplashScreen: توجيه إلى لوحة شركة التوصيل');
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.deliveryCompanyDashboard,
            );
            break;
          case UserRole.merchant:
            AppLogger.info('🔄 SplashScreen: توجيه إلى لوحة تحكم التاجر');
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.merchantDashboard,
            );
            break;
          case UserRole.captain:
            AppLogger.info('🔄 SplashScreen: توجيه إلى لوحة تحكم الكابتن');
            Navigator.pushReplacementNamed(context, AppRoutes.captainDashboard);
            break;
          case UserRole.client:
            AppLogger.info('🔄 SplashScreen: توجيه إلى الصفحة الرئيسية');
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
        }
      } else {
        AppLogger.info(
          '🔄 SplashScreen: لا يوجد مستخدم، توجيه إلى الأون بوردنج',
        );
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    } catch (e, stackTrace) {
      AppLogger.error('❌ SplashScreen: خطأ في _checkAuthAndRedirect', e);
      AppLogger.info('📋 StackTrace: $stackTrace');

      if (mounted) {
        AppLogger.info('🔄 SplashScreen: توجيه إلى الأون بوردنج بسبب الخطأ');
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    }
  }

  Future<bool> _checkForUpdate() async {
    final prompt = await AppUpdateService.instance.checkForUpdate();
    if (!mounted || prompt == null) return true;

    await _showUpdateDialog(prompt);
    return !prompt.isForce;
  }

  Future<void> _showUpdateDialog(AppUpdatePrompt prompt) async {
    final info = prompt.info;
    final title = info.title ?? 'تحديث جديد متاح';
    final message =
        info.message ??
        'يتوفر تحديث جديد للتطبيق لتحسين الأداء وإضافة ميزات جديدة.';
    final updateUrl = info.updateUrl.trim();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !prompt.isForce,
      builder: (dialogContext) {
        return PopScope(
          canPop: !prompt.isForce,
          child: AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                Text('الإصدار الحالي: ${prompt.currentVersion}'),
                Text('الإصدار الجديد: ${info.latestVersion}'),
              ],
            ),
            actions: [
              if (!prompt.isForce)
                TextButton(
                  onPressed: () async {
                    await AppUpdateService.instance.markDismissed(
                      info.latestVersion,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('لاحقًا'),
                ),
              FilledButton.icon(
                onPressed: updateUrl.isEmpty
                    ? null
                    : () => _openUpdateUrl(updateUrl),
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Text('تحديث الآن'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUpdateUrl(String updateUrl) async {
    try {
      await Helpers.launchURL(updateUrl);
    } catch (e) {
      AppLogger.error('❌ Failed to open update URL', e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحديث')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/icon2.png',
                  width: context.responsive(
                    mobile: 150.0,
                    tablet: 200.0,
                    wide: 250.0,
                  ),
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  'سوق التل',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (_appVersion.isNotEmpty)
            Positioned(
              top: 50,
              right: 20,
              child: Text(
                'إصدار $_appVersion',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
