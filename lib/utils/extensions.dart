import 'package:flutter/material.dart';

// ==== Screens Import ====
// Common
import '../screens/common/splash_screen.dart';
import '../screens/common/onboarding_screen.dart';
// Auth
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
// User
import '../screens/user/home_screen.dart';
import '../screens/user/category_screen.dart';
import '../screens/user/product_detail_screen.dart';
import '../screens/user/cart_screen.dart';
import '../screens/user/checkout_screen.dart';
import '../screens/user/order_history_screen.dart';
import '../screens/user/order_tracking_screen.dart';
import '../screens/user/profile_screen.dart';
// Merchant
import '../screens/merchant/merchant_dashboard_screen.dart';
import '../screens/merchant/merchant_products_screen.dart';
import '../screens/merchant/merchant_orders_screen.dart';
import '../screens/merchant/add_edit_product_screen.dart';
import '../screens/merchant/merchant_wallet_screen.dart';
// Captain
import '../screens/captain/captain_dashboard.Screen.dart';
import '../screens/captain/captain_orders_screen.dart';
import '../screens/captain/order_delivery_screen.dart';
// Admin
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/manage_users_screen.dart';
import '../screens/admin/manage_products_screen.dart';
import '../screens/admin/manage_orders_screen.dart';
import '../screens/admin/manage_categories_screen.dart';
import '../screens/admin/manage_coupons_screen.dart';
import '../screens/admin/app_settings_screen.dart';
import '../screens/admin/dynamic_ui_builder_screen.dart';
import '../screens/admin/analytics_screen.dart';
// Common (additional)
import '../screens/common/search_screen.dart';
import '../screens/common/notifications_screen.dart';

// ==== Models Import ====
import '../models/product_model.dart';

class AppRoutes {
  // ==== Route Names ====
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const category = '/category';
  static const productDetail = '/product-detail';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orderHistory = '/order-history';
  static const orderTracking = '/order-tracking';
  static const profile = '/profile';

  // Merchant
  static const merchantDashboard = '/merchant-dashboard';
  static const merchantProducts = '/merchant-products';
  static const merchantOrders = '/merchant-orders';
  static const addEditProduct = '/add-edit-product';
  static const merchantWallet = '/merchant-wallet';

  // Captain
  static const captainDashboard = '/captain-dashboard';
  static const captainOrders = '/captain-orders';
  static const orderDelivery = '/order-delivery';

  // Admin
  static const adminDashboard = '/admin-dashboard';
  static const manageUsers = '/manage-users';
  static const manageProducts = '/manage-products';
  static const manageOrders = '/manage-orders';
  static const manageCategories = '/manage-categories';
  static const manageCoupons = '/manage-coupons';
  static const appSettings = '/app-settings';
  static const dynamicUIBuilder = '/dynamic-ui-builder';
  static const analytics = '/analytics';

  // Common
  static const search = '/search';
  static const notifications = '/notifications';

  // ==== Route Generator ====
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      // ==== Auth ====
      case splash:
        return MaterialPageRoute(builder: (_) => SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => RegisterScreen());

      // ==== User ====
      case home:
        return MaterialPageRoute(builder: (_) => HomeScreen());
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
        return _errorRoute('Category not provided');
      case productDetail:
        if (args is ProductModel) {
          return MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: args),
          );
        }
        return _errorRoute('Product not provided');
      case cart:
        return MaterialPageRoute(builder: (_) => CartScreen());
      case checkout:
        return MaterialPageRoute(builder: (_) => CheckoutScreen());
      case orderHistory:
        return MaterialPageRoute(builder: (_) => OrderHistoryScreen());
      case orderTracking:
        if (args is Map<String, dynamic>) {
          final String orderId = args['orderId'] ?? '';
          return MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(orderId: orderId),
          );
        }
        return _errorRoute('Order not provided');
      case profile:
        return MaterialPageRoute(builder: (_) => ProfileScreen());

      // ==== Merchant ====
      case merchantDashboard:
        return MaterialPageRoute(
          builder: (_) => const MerchantDashboardScreen(),
        );
      case merchantProducts:
        if (args is Map<String, dynamic>) {
          final String merchantId = args['merchantId'] ?? '';
          final String merchantName = args['merchantName'] ?? '';
          return MaterialPageRoute(
            builder: (_) => MerchantProductsScreen(
              merchantId: merchantId,
              merchantName: merchantName,
            ),
          );
        }
        return _errorRoute('Merchant data not provided');
      case merchantOrders:
        if (args is Map<String, dynamic>) {
          final String merchantId = args['merchantId'] ?? '';
          final String merchantName = args['merchantName'] ?? '';
          return MaterialPageRoute(
            builder: (_) => MerchantOrdersScreen(
              merchantId: merchantId,
              merchantName: merchantName,
            ),
          );
        }
        return _errorRoute('Merchant data not provided');
      case addEditProduct:
        if (args is ProductModel?) {
          return MaterialPageRoute(
            builder: (_) => AddEditProductScreen(product: args),
          );
        }
        return MaterialPageRoute(
          builder: (_) => AddEditProductScreen(product: null),
        );
      case merchantWallet:
        return MaterialPageRoute(builder: (_) => MerchantWalletScreen());

      // ==== Captain ====
      case captainDashboard:
        return MaterialPageRoute(builder: (_) => CaptainDashboard());
      case captainOrders:
        if (args is Map<String, dynamic>) {
          final String captainId = args['captainId'] ?? '';
          final String captainName = args['captainName'] ?? '';
          return MaterialPageRoute(
            builder: (_) => CaptainOrdersScreen(
              captainId: captainId,
              captainName: captainName,
            ),
          );
        }
        return _errorRoute('Captain data not provided');
      case orderDelivery:
        if (args is Map<String, dynamic>) {
          final String orderId = args['orderId'] ?? '';
          return MaterialPageRoute(
            builder: (_) => OrderDeliveryScreen(orderId: orderId),
          );
        }
        return _errorRoute('Order not provided');

      // ==== Admin ====
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => AdminDashboard());
      case manageUsers:
        return MaterialPageRoute(builder: (_) => ManageUsersScreen());
      case manageProducts:
        return MaterialPageRoute(builder: (_) => ManageProductsScreen());
      case manageOrders:
        return MaterialPageRoute(builder: (_) => ManageOrdersScreen());
      case manageCategories:
        return MaterialPageRoute(builder: (_) => ManageCategoriesScreen());
      case manageCoupons:
        return MaterialPageRoute(builder: (_) => ManageCouponsScreen());
      case appSettings:
        return MaterialPageRoute(builder: (_) => AppSettingsScreen());
      case dynamicUIBuilder:
        return MaterialPageRoute(builder: (_) => DynamicUIBuilderScreen());
      case analytics:
        return MaterialPageRoute(builder: (_) => AnalyticsScreen());

      // ==== Common ====
      case search:
        return MaterialPageRoute(builder: (_) => SearchScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => NotificationsScreen());

      default:
        return _errorRoute('Route not found');
    }
  }

  // ==== Error Route ====
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('خطأ')),
        body: Center(child: Text(message)),
      ),
    );
  }

  // ==== Navigation Helpers ====
  static Future<T?> push<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static Future<T?> pushReplacement<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushReplacementNamed(
      context,
      routeName,
      arguments: arguments,
    );
  }

  static void pop(BuildContext context, [Object? result]) {
    Navigator.pop(context, result);
  }

  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }
}
