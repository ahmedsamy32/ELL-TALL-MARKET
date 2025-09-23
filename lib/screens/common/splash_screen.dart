import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart'; // ✅ تصحيح الاستيراد
import 'package:ell_tall_market/utils/app_routes.dart';

import '../../models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
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
    // إضافة طباعة للتشخيص
    debugPrint('🔍 SplashScreen: بدء التحقق من المصادقة...');

    try {
      // التحقق من وجود Provider قبل محاولة الوصول إليه
      final context = this.context;
      if (!context.mounted) {
        debugPrint('❌ SplashScreen: Context غير متصل');
        return;
      }

      debugPrint('🔍 SplashScreen: محاولة الوصول إلى FirebaseAuthProvider...');
      final authProvider = Provider.of<FirebaseAuthProvider>(
        context,
        listen: false,
      );
      debugPrint('✅ SplashScreen: تم العثور على FirebaseAuthProvider بنجاح');

      // نعمل Delay علشان يظهر Splash كويس
      await Future.delayed(Duration(seconds: 2));

      if (!mounted) {
        debugPrint('❌ SplashScreen: Widget غير متصل بعد التأخير');
        return;
      }

      final user = authProvider.user;
      debugPrint(
        '🔍 SplashScreen: المستخدم الحالي: ${user?.email ?? 'لا يوجد مستخدم'}',
      );

      if (user != null) {
        // توجيه المستخدم حسب نوع حسابه
        debugPrint('🔍 SplashScreen: نوع المستخدم: ${user.type}');
        switch (user.type) {
          case UserType.admin:
            debugPrint('🔄 SplashScreen: توجيه إلى لوحة تحكم الأدمن');
            Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
            break;
          case UserType.merchant:
            debugPrint('🔄 SplashScreen: توجيه إلى لوحة تحكم التاجر');
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.merchantDashboard,
            );
            break;
          case UserType.captain:
            debugPrint('🔄 SplashScreen: توجيه إلى لوحة تحكم الكابتن');
            Navigator.pushReplacementNamed(context, AppRoutes.captainDashboard);
            break;
          case UserType.customer:
            debugPrint('🔄 SplashScreen: توجيه إلى الصفحة الرئيسية');
            Navigator.pushReplacementNamed(context, AppRoutes.home);
            break;
        }
      } else {
        // إذا لم يكن هناك مستخدم مسجل، نوجهه لشاشة الأون بورد
        debugPrint('🔄 SplashScreen: لا يوجد مستخدم، توجيه إلى الأون بوردنج');
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SplashScreen: خطأ في _checkAuthAndRedirect: $e');
      debugPrint('📋 StackTrace: $stackTrace');

      // في حالة حدوث خطأ نوجه المستخدم لشاشة الأون بورد
      if (mounted) {
        debugPrint('🔄 SplashScreen: توجيه إلى الأون بوردنج بسبب الخطأ');
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // تغيير الخلفية للأبيض
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // استبدل FlutterLogo باللوجو الخاص بك
            Image.asset(
              'assets/images/icon.png', // مسار اللوجو الخاص بك
              width: 150, // يمكنك تعديل العرض
              height: 150, // يمكنك تعديل الارتفاع
              fit: BoxFit.contain,
            ),
            SizedBox(height: 20),
            Text(
              'التل ماركت',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor, // النص بالأزرق
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Theme.of(context).primaryColor, // اللودر بالأزرق
            ),
          ],
        ),
      ),
    );
  }
}
