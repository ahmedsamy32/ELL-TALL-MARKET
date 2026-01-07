import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

import '../../models/profile_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndRedirect();
    });
  }

  Future<void> _checkAuthAndRedirect() async {
    AppLogger.info('🔍 SplashScreen: بدء التحقق من المصادقة...');

    try {
      final context = this.context;
      if (!context.mounted) {
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

      if (!context.mounted) {
        AppLogger.warning('❌ SplashScreen: Widget غير متصل بعد التأخير');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/icon.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            Text(
              'التل ماركت',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
}
