import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';

// ===== Screens =====
import 'package:ell_tall_market/screens/auth/login_screen.dart';
import 'package:ell_tall_market/screens/auth/register_screen.dart';
import 'package:ell_tall_market/screens/auth/forgot_password_screen.dart';
import 'package:ell_tall_market/screens/auth/Register_Merchant_Screen.dart';
import 'package:ell_tall_market/screens/auth/change_password_screen.dart';

import 'package:ell_tall_market/screens/user/home_screen.dart';
import 'package:ell_tall_market/screens/user/category_screen.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:ell_tall_market/screens/user/cart_screen.dart';
import 'package:ell_tall_market/screens/user/checkout_screen.dart';
import 'package:ell_tall_market/screens/user/order_history_screen.dart';
import 'package:ell_tall_market/screens/user/order_tracking_screen.dart';
import 'package:ell_tall_market/screens/user/profile_screen.dart';
import 'package:ell_tall_market/screens/user/favorites_screen.dart';
import 'package:ell_tall_market/screens/user/Stores_Screen.dart';
import 'package:ell_tall_market/screens/user/store_detail_Screen.dart';

import 'package:ell_tall_market/screens/merchant/merchant_dashboard_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_products_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_orders_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_wallet_screen.dart';

import 'package:ell_tall_market/screens/captain/captain_orders_screen.dart';
import 'package:ell_tall_market/screens/captain/order_delivery_screen.dart';

import 'package:ell_tall_market/screens/admin/admin_dashboard_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_users_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_products_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_orders_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_categories_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_coupons_screen.dart';
import 'package:ell_tall_market/screens/admin/app_settings_screen.dart';
import 'package:ell_tall_market/screens/admin/dynamic_ui_builder_screen.dart';
import 'package:ell_tall_market/screens/admin/analytics_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_captains_screen.dart';

import 'package:ell_tall_market/screens/common/splash_screen.dart';
import 'package:ell_tall_market/screens/common/onboarding_screen.dart';
import 'package:ell_tall_market/screens/common/search_screen.dart';
import 'package:ell_tall_market/screens/common/notifications_screen.dart';

import '../screens/captain/captain_dashboard_screen.dart';
import '../screens/captain/captain_wallet_screen.dart';
import '../screens/user/Returns_screen.dart';
import '../screens/user/addresses_screen.dart';
import '../screens/user/edit_profile_screen.dart';

class AppRoutes {
  // ===== Route Names =====
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerMerchant = '/register-merchant';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';
  static const String home = '/home';
  static const String category = '/category';
  static const String productDetail = '/product-detail';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderHistory = '/order-history';
  static const String orderTracking = '/order-tracking';
  static const String profile = '/profile';
  static const String favorites = '/favorites';
  static const String stores = '/stores';
  static const String storeDetail = '/store-detail';
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String addresses = '/addresses';
  static const String editProfile = '/edit-profile';
  static const String returns = '/returns';
  static const String paymentMethods = '/payment-methods';

  // مسارات التاجر
  static const String merchantDashboard = '/merchant/dashboard';
  static const String merchantProducts = '/merchant/products';
  static const String addEditProduct = '/add-edit-product';
  static const String merchantOrders = '/merchant/orders';
  static const String merchantWallet = '/merchant/wallet';

  // مسارات المحفظة
  static const String captainWallet = '/captain/wallet';

  // مسارات الكابتن
  static const String captainDashboard = '/captain-dashboard';
  static const String captainOrders = '/captain-orders';
  static const String orderDelivery = '/order-delivery';

  // مسارات المشرف
  static const String adminDashboard = '/admin-dashboard';
  static const String manageUsers = '/manage-users';
  static const String manageProducts = '/manage-products';
  static const String manageOrders = '/manage-orders';
  static const String manageCategories = '/manage-categories';
  static const String manageCoupons = '/manage-coupons';
  static const String appSettings = '/app-settings';
  static const String dynamicUIBuilder = '/dynamic-ui-builder';
  static const String analytics = '/analytics';
  static const String manageCaptains = '/manage-captains';

  // ===== Routes Map =====
  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (_) => SplashScreen(),
      onboarding: (_) => OnboardingScreen(),
      login: (_) => LoginScreen(),
      register: (_) => RegisterScreen(),
      registerMerchant: (_) => RegisterMerchantScreen(),
      forgotPassword: (_) => ForgotPasswordScreen(),
      changePassword: (_) => ChangePasswordScreen(),
      home: (_) => HomeScreen(),
      category: (_) => CategoryScreen(),
      search: (_) => SearchScreen(),
      notifications: (_) => NotificationsScreen(),
      cart: (_) => CartScreen(),
      checkout: (_) => CheckoutScreen(),
      orderHistory: (_) => OrderHistoryScreen(),
      profile: (_) => ProfileScreen(),

      merchantDashboard: (_) => MerchantDashboardScreen(),
      merchantWallet: (_) => MerchantWalletScreen(),

      captainDashboard: (_) => CaptainDashboardScreen(),
      captainWallet: (_) => CaptainWalletScreen(),

      adminDashboard: (_) => AdminDashboardScreen(),
      manageUsers: (_) => ManageUsersScreen(),
      manageProducts: (_) => ManageProductsScreen(),
      manageOrders: (_) => ManageOrdersScreen(),
      manageCategories: (_) => ManageCategoriesScreen(),
      manageCoupons: (_) => ManageCouponsScreen(),
      appSettings: (_) => AppSettingsScreen(),
      dynamicUIBuilder: (_) => DynamicUIBuilderScreen(),
      analytics: (_) => AnalyticsScreen(),
      manageCaptains: (_) => ManageCaptainsScreen(),
      favorites: (_) => FavoritesScreen(),
      editProfile: (_) => EditProfileScreen(),
      addresses: (_) => AddressesScreen(),
      returns: (_) => ReturnsScreen(),
      stores: (_) => StoresScreen(),
      storeDetail: (_) => StoreDetailScreen(),
    };
  }

  // ===== Dynamic Routes =====
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case category:
        if (args is Map<String, dynamic>) {
          final String categoryId = args['id'] ?? '';
          final String categoryName = args['name'] ?? '';
          return MaterialPageRoute(
            builder: (_) => CategoryScreen(
              categoryId: categoryId,
              categoryName: categoryName,
            ),
          );
        }
        return _errorRoute('Category data not provided');

      case productDetail:
        if (args is ProductModel) {
          return MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: args),
          );
        }
        return _errorRoute('Product data not provided');

      case orderTracking:
        if (args is Map<String, dynamic>) {
          final String orderId = args['orderId'] ?? '';
          return MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          );
        }
        return _errorRoute('Order data not provided');

      // ===== Merchant Protected Routes =====
      case merchantProducts:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isMerchant) {
              return MerchantProductsScreen(
                merchantId: authProvider.user!.id,
                merchantName: authProvider.user!.name,
              );
            }
            return _errorScaffold('Merchant not authenticated');
          },
        );

      case merchantOrders:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isMerchant) {
              return MerchantOrdersScreen(
                merchantId: authProvider.user!.id,
                merchantName: authProvider.user!.name,
              );
            }
            return _errorScaffold('Merchant not authenticated');
          },
        );

      // ===== Captain Protected Routes =====
      case captainOrders:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isCaptain) {
              return CaptainOrdersScreen(
                captainId: authProvider.user!.id,
                captainName: authProvider.user!.name,
              );
            }
            return _errorScaffold('Captain not authenticated');
          },
        );

      case orderDelivery:
        if (args is Map<String, dynamic>) {
          final String orderId = args['orderId'] ?? '';
          return MaterialPageRoute(
            builder: (_) => OrderDeliveryScreen(orderId: orderId),
          );
        }
        return _errorRoute('Order data not provided');

      // ===== Admin Protected Routes =====
      case manageUsers:
      case manageProducts:
      case manageOrders:
      case manageCategories:
      case manageCoupons:
      case appSettings:
      case dynamicUIBuilder:
      case analytics:
      case manageCaptains:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isAdmin) {
              // الع��دة إلى الشاشة المطلوبة
              return routes[settings.name]!(context);
            }
            return _errorScaffold('Admin access required');
          },
        );

      default:
        if (routes.containsKey(settings.name)) {
          return MaterialPageRoute(builder: routes[settings.name]!);
        }
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  // ===== Helper Methods =====

  /// بناء شاشة إعادة التوجيه مؤقتة
  static Widget _buildRedirectScreen(BuildContext context, String routeName) {
    // استخدام Future.microtask لتجنب مشاكل السياق
    Future.microtask(() => Navigator.pushReplacementNamed(context, routeName));
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري التوجيه...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// معالجة الأخطاء بطريقة أكثر أناقة
  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => _errorScaffold(message),
      settings: RouteSettings(name: '/error'),
    );
  }

  static Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(
        title: Text('خطأ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.arrow_back),
              label: Text('العودة للرئيسية'),
              onPressed: () {
                // يمكن إضافة navigation logic هنا إذا لزم الأمر
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Navigation Helper Methods =====

  /// تنقل آمن م�� التحقق من المصادقة
  static void navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // التحقق من الشاشات المحمية
    final protectedRoutes = [
      merchantProducts,
      merchantOrders,
      captainOrders,
      manageUsers,
      manageProducts,
      manageOrders,
      manageCategories,
      manageCoupons,
      appSettings,
      dynamicUIBuilder,
      analytics,
      manageCaptains,
    ];

    if (protectedRoutes.contains(routeName) && !authProvider.isLoggedIn) {
      Navigator.pushNamed(context, login);
      return;
    }

    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  /// تنقل مع استبدال الشاشة الحالية
  static void replaceWith(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  /// تنظيف ��ل الشاشات والانتقال لشاشة جديدة
  static void clearAllAndNavigate(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  // ===== Route Guards =====

  /// التحقق من صلاحية الوصول للشاشة
  static bool canAccessRoute(BuildContext context, String routeName) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      return false;
    }

    // تحقق من الصلاحيات حسب نوع المستخدم
    switch (routeName) {
      case merchantProducts:
      case merchantOrders:
      case merchantWallet:
        return authProvider.isMerchant;

      case captainOrders:
      case orderDelivery:
        return authProvider.isCaptain;

      case manageUsers:
      case manageProducts:
      case manageOrders:
      case manageCategories:
      case manageCoupons:
      case appSettings:
      case dynamicUIBuilder:
      case analytics:
      case manageCaptains:
        return authProvider.isAdmin;

      default:
        return true;
    }
  }
}
