import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/screens/user/home_screen.dart';

class RouteHelper {
  static MaterialPageRoute<dynamic> generateRoute(UserType userType) {
    // توجيه جميع المستخدمين إلى الشاشة الرئيسية أولاً
    return MaterialPageRoute(builder: (_) => const HomeScreen());
  }

  static void redirectUserBasedOnRole(BuildContext context, UserType userType) {
    if (!context.mounted) return;

    String route;
    switch (userType) {
      case UserType.admin:
        route = '/admin-dashboard';
        break;
      case UserType.merchant:
        route = '/merchant/dashboard';
        break;
      case UserType.captain:
        route = '/captain-dashboard';
        break;
      case UserType.customer:
        route = '/home';
        break;
    }

    // حذف كل الشاشات السابقة في ال stack وتوجيه المستخدم للشاشة المناسبة
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  // دالة للتنقل إلى لوحة التحكم الخاصة بكل مستخدم
  static void navigateToDashboard(BuildContext context, UserType userType) {
    String? route;

    switch (userType) {
      case UserType.admin:
        route = '/admin-dashboard';
        break;
      case UserType.merchant:
        route = '/merchant/dashboard';
        break;
      case UserType.captain:
        route = '/captain-dashboard';
        break;
      case UserType.customer:
        return; // العملاء ليس لديهم لوحة تحكم
    }

    Navigator.pushNamed(context, route);
  }
}
