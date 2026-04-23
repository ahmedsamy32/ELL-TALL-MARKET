import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/widgets/main_navigation.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ===== Screens =====
import 'package:ell_tall_market/screens/auth/login_screen.dart';
import 'package:ell_tall_market/screens/auth/register_screen.dart';
import 'package:ell_tall_market/screens/auth/reset_password_screen.dart';
import 'package:ell_tall_market/screens/auth/register_merchant_screen.dart';
import 'package:ell_tall_market/screens/auth/email_confirmation_screen.dart';

import 'package:ell_tall_market/screens/user/category_screen.dart';
import 'package:ell_tall_market/screens/user/product_detail_screen.dart';
import 'package:ell_tall_market/screens/user/cart_screen.dart';
import 'package:ell_tall_market/screens/user/checkout_screen.dart';
import 'package:ell_tall_market/screens/user/order_tracking_screen.dart';
import 'package:ell_tall_market/screens/user/store_detail_screen.dart';

import 'package:ell_tall_market/screens/merchant/merchant_dashboard_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_products_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_orders_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_wallet_screen.dart';
import 'package:ell_tall_market/screens/merchant/add_edit_product_screen.dart';

import 'package:ell_tall_market/screens/captain/captain_orders_screen.dart';
import 'package:ell_tall_market/screens/captain/order_delivery_screen.dart';
import 'package:ell_tall_market/screens/captain/delivery_company_dashboard_screen.dart';

import 'package:ell_tall_market/screens/admin/admin_dashboard_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_users_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_products_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_orders_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_categories_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_coupons_screen.dart';
import 'package:ell_tall_market/screens/admin/app_settings_screen.dart';
import 'package:ell_tall_market/screens/admin/dynamic_ui_builder_screen.dart';
import 'package:ell_tall_market/screens/admin/analytics_screen.dart';
import 'package:ell_tall_market/screens/admin/captain_reports_screen.dart';
import 'package:ell_tall_market/screens/admin/manage_banners_screen.dart';
import 'package:ell_tall_market/screens/admin/delivery_zone_pricing_screen.dart';

import 'package:ell_tall_market/screens/common/splash_screen.dart';
import 'package:ell_tall_market/screens/common/onboarding_screen.dart';
import 'package:ell_tall_market/screens/common/search_screen.dart';
import 'package:ell_tall_market/screens/common/notifications_screen.dart';
import 'package:ell_tall_market/screens/common/about_app_screen.dart';
import 'package:ell_tall_market/screens/common/privacy_policy_screen.dart';
import 'package:ell_tall_market/screens/common/terms_conditions_screen.dart';
import 'package:ell_tall_market/screens/user/settings_screen.dart';

import '../screens/captain/captain_dashboard_screen.dart';
import '../screens/captain/captain_wallet_screen.dart';
import '../screens/user/addresses_screen.dart';
import '../screens/user/stores_screen.dart';
import '../screens/user/edit_profile_screen.dart';
import '../screens/user/order_history_screen.dart';

class AppRoutes {
  // ===== Route Names =====
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerMerchant = '/register-merchant';
  static const String emailConfirmation = '/email-confirmation';
  static const String callback = '/callback'; // لمعالجة روابط تأكيد البريد
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
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
  static const String settings = '/settings';
  static const String paymentMethods = '/payment-methods';
  static const String main = '/main'; // New main navigation route

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
  static const String deliveryCompanyDashboard = '/delivery-company-dashboard';

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
  static const String manageBanners = '/manage-banners';
  static const String deliveryZonePricing = '/delivery-zone-pricing';

  // مسارات المعلومات والسياسات
  static const String aboutApp = '/about-app';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsConditions = '/terms-conditions';

  // ===== Routes Map =====
  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (_) => const SplashScreen(),
      onboarding: (_) => const OnboardingScreen(),
      login: (_) => const LoginScreen(),
      register: (_) => const RegisterScreen(),
      registerMerchant: (_) => const RegisterMerchantScreen(),
      resetPassword: (_) => const ResetPasswordScreen(),
      emailConfirmation: (_) => const EmailConfirmationScreen(email: ''),
      callback: (context) => _CallbackScreen(), // معالج روابط تأكيد البريد
      home: (_) => const MainNavigationScreen(initialIndex: 0),
      main: (_) => const MainNavigationScreen(),
      category: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;

        if (args is Map<String, dynamic>) {
          final String? categoryId = args['id'] as String?;
          final String? categoryName = args['name'] as String?;
          return CategoryScreen(
            categoryId: (categoryId ?? '').trim().isEmpty ? null : categoryId,
            categoryName: (categoryName ?? '').trim().isEmpty
                ? null
                : categoryName,
          );
        }

        if (args is CategoryModel) {
          return CategoryScreen(categoryId: args.id, categoryName: args.name);
        }

        return const CategoryScreen();
      },
      search: (_) => const SearchScreen(),
      notifications: (_) => const NotificationsScreen(),
      cart: (_) => const CartScreen(),
      checkout: (_) => const CheckoutScreen(),
      orderHistory: (_) => const OrderHistoryScreen(),
      profile: (_) => const MainNavigationScreen(initialIndex: 3),
      favorites: (_) => const MainNavigationScreen(initialIndex: 2),

      merchantDashboard: (_) => const MerchantDashboardScreen(),
      merchantWallet: (_) => const MerchantWalletScreen(),
      // مهم: استخدم args لتمرير المنتج عند التعديل، وأبقها null عند الإضافة
      addEditProduct: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        final product = args is ProductModel ? args : null;
        return AddEditProductScreen(
          key: ValueKey<String>('addEdit-${product?.id ?? 'new'}'),
          product: product,
        );
      },

      captainDashboard: (_) => const CaptainDashboard(),
      deliveryCompanyDashboard: (_) => const DeliveryCompanyDashboardScreen(),
      captainWallet: (_) => const CaptainWalletScreen(),

      stores: (_) => const StoresScreen(),
      adminDashboard: (_) => const AdminDashboardScreen(),
      manageUsers: (_) => const ManageUsersScreen(),
      manageProducts: (_) => const ManageProductsScreen(),
      manageOrders: (_) => const ManageOrdersScreen(),
      manageCategories: (_) => const ManageCategoriesScreen(),
      manageCoupons: (_) => const ManageCouponsScreen(),
      appSettings: (_) => const AppSettingsScreen(),
      dynamicUIBuilder: (_) => const DynamicUIBuilderScreen(),
      analytics: (_) => const AnalyticsScreen(),
      manageCaptains: (_) => const CaptainReportsScreen(),
      manageBanners: (_) => const ManageBannersScreen(),
      deliveryZonePricing: (_) => const DeliveryZonePricingScreen(),
      editProfile: (_) => const EditProfileScreen(),
      settings: (_) => const SettingsScreen(),
      addresses: (_) => const AddressesScreen(),
      aboutApp: (_) => const AboutAppScreen(),
      privacyPolicy: (_) => const PrivacyPolicyScreen(),
      termsConditions: (_) => const TermsConditionsScreen(),
    };
  }

  // ===== Dynamic Routes =====
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    // معالجة callback routes حتى لو كان فيها query parameters
    final routeName = settings.name ?? '';
    if (routeName.contains('/callback')) {
      return _handleSupabaseAuthCallback(settings);
    }

    switch (settings.name) {
      // ===== Supabase Auth Deep Link Handler =====
      case '/auth/callback':
        return _handleSupabaseAuthCallback(settings);

      // ===== Callback Handler for Direct /callback Routes =====
      case '/callback':
        return _handleSupabaseAuthCallback(settings);

      case category:
        if (args is Map<String, dynamic>) {
          final String categoryId = (args['id'] as String?) ?? '';
          final String categoryName = (args['name'] as String?) ?? '';
          return MaterialPageRoute(
            builder: (_) => CategoryScreen(
              categoryId: categoryId.trim().isEmpty ? null : categoryId,
              categoryName: categoryName.trim().isEmpty ? null : categoryName,
            ),
          );
        }

        if (args is CategoryModel) {
          return MaterialPageRoute(
            builder: (_) =>
                CategoryScreen(categoryId: args.id, categoryName: args.name),
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

      case storeDetail:
        if (args is StoreModel) {
          return MaterialPageRoute(
            builder: (_) => const StoreDetailScreen(),
            settings: RouteSettings(name: storeDetail, arguments: args),
          );
        }
        return _errorRoute('Store data not provided');

      case resetPassword:
        if (args is Map<String, dynamic>) {
          final String? token = args['token'];
          final String? tokenHash = args['token_hash'];
          final String? type = args['type'];
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              token: token,
              tokenHash: tokenHash,
              type: type,
            ),
          );
        }
        // إذا لم توجد معاملات، اعرض الشاشة العادية
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());

      case emailConfirmation:
        if (args is Map<String, dynamic>) {
          final String email = args['email'] ?? '';
          final String? password = args['password'];
          final String? userType = args['userType'];
          return MaterialPageRoute(
            builder: (_) => EmailConfirmationScreen(
              email: email,
              password: password,
              userType: userType,
            ),
          );
        }
        return _errorRoute('Email not provided for confirmation');

      case orderTracking:
        if (args is Map<String, dynamic>) {
          final String? orderId = args['orderId'] as String?;
          final String? orderGroupId = args['orderGroupId'] as String?;
          final String? orderNumber = args['orderNumber'] as String?;
          return MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(
              orderId: orderId,
              orderGroupId: orderGroupId,
              orderNumber: orderNumber,
            ),
          );
        }
        return _errorRoute('Order data not provided');

      // ===== Merchant Protected Routes =====
      case merchantProducts:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<SupabaseProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isMerchant) {
              return const MerchantProductsScreen();
            }
            return _errorScaffold('Merchant not authenticated');
          },
        );

      case merchantOrders:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<SupabaseProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isMerchant) {
              return const MerchantOrdersScreen();
            }
            return _errorScaffold('Merchant not authenticated');
          },
        );

      // ===== Captain Protected Routes =====
      case captainOrders:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<SupabaseProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isCaptain) {
              return CaptainOrdersScreen(
                captainId: authProvider.currentUserProfile!.id,
                captainName:
                    authProvider.currentUserProfile!.fullName ?? 'كابتن',
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

      case deliveryCompanyDashboard:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<SupabaseProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isDeliveryCompanyAdmin || authProvider.isAdmin) {
              return const DeliveryCompanyDashboardScreen();
            }
            return _errorScaffold('Delivery company admin access required');
          },
        );

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
      case deliveryZonePricing:
        return MaterialPageRoute(
          builder: (context) {
            final authProvider = Provider.of<SupabaseProvider>(
              context,
              listen: false,
            );
            if (!authProvider.isLoggedIn) {
              return _buildRedirectScreen(context, login);
            }
            if (authProvider.isAdmin) {
              // العودة إلى الشاشة المطلوبة
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

  /// معالجة روابط Supabase Auth Callback مع منع التسجيل التلقائي
  static MaterialPageRoute _handleSupabaseAuthCallback(RouteSettings settings) {
    try {
      final uri = Uri.parse(settings.name ?? '');
      final queryParams = uri.queryParameters;

      AppLogger.info('🔗 معالجة auth callback: ${settings.name}');
      AppLogger.debug('معاملات URL: $queryParams');

      // استخراج المعاملات من URL (النوع القديم والجديد)
      final accessToken = queryParams['access_token'];
      final refreshToken = queryParams['refresh_token'];
      final code = queryParams['code']; // الكود الجديد لتأكيد البريد
      final type = queryParams['type'];
      final provider = queryParams['provider']; // مثال: google عند OAuth
      final error = queryParams['error'];
      final errorDescription = queryParams['error_description'];

      // ===== معالجة النوع الجديد - Code Exchange (Email Confirmation فقط) =====
      // ملاحظة: عند OAuth قد يأتي code أيضاً، لكن يتم معالجته داخلياً من مكتبة Supabase
      // لذلك نتأكد من عدم وجود provider أو access tokens قبل محاولة التبديل يدوياً
      if (code != null &&
          provider == null &&
          accessToken == null &&
          refreshToken == null) {
        // ✅ إذا كان type موجود (signup/invite) → تأكيد بريد → استبدال يدوي للكود
        // ✅ إذا لم يكن type موجود → OAuth PKCE → Supabase يعالج الكود تلقائياً
        if (type != null && type.isNotEmpty) {
          AppLogger.info('🔄 معالجة رابط تأكيد بريد (code exchange): $code');
          return MaterialPageRoute(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  AppLogger.debug(
                    '🚫 Email confirmation flow (auto sign-in prevention disabled)',
                  );
                } catch (e) {
                  AppLogger.error('خطأ في تعيين علامة منع التسجيل التلقائي', e);
                }
              });
              return _CodeExchangeScreen(code: code);
            },
          );
        }

        // OAuth PKCE: Supabase يستبدل الكود تلقائياً على الويب
        // نعرض شاشة انتظار ونستمع لـ onAuthStateChange
        AppLogger.info(
          '✅ OAuth PKCE callback - في انتظار معالجة Supabase للكود تلقائياً',
        );
        return MaterialPageRoute(builder: (_) => const _OAuthCallbackScreen());
      }

      // معالجة تأكيد البريد من النوع القديم (type=signup)
      if (type == 'signup') {
        return MaterialPageRoute(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                AppLogger.debug('🚫 Email confirmation flow processing');
              } catch (e) {
                AppLogger.error('خطأ في تعيين علامة منع التسجيل التلقائي', e);
              }
            });
            return _emailConfirmedSuccessScreen();
          },
        );
      }

      // في حالة وجود access_token أو provider (OAuth implicit flow)
      // نستخدم شاشة الانتظار بدلاً من LoginScreen لأن الـ subscription ضاع
      if (accessToken != null || provider != null) {
        AppLogger.info(
          '✅ OAuth callback detected (provider=$provider), في انتظار تسجيل الدخول',
        );
        return MaterialPageRoute(builder: (_) => const _OAuthCallbackScreen());
      }

      // معالجة أخطاء الروابط المنتهية الصلاحية أو غير الصالحة
      if (error != null) {
        AppLogger.error('Auth callback error: $error - $errorDescription');

        if (error == 'access_denied' ||
            errorDescription?.contains('expired') == true) {
          // توجه لشاشة تأكيد البريد مع معلومة أن الرابط منتهي الصلاحية
          return MaterialPageRoute(
            builder: (_) => const EmailConfirmationScreen(email: ''),
            settings: RouteSettings(
              name: AppRoutes.emailConfirmation,
              arguments: {
                'email': '',
                'expired_link': true,
                'error_message': 'انتهت صلاحية رابط التأكيد',
              },
            ),
          );
        }
      }

      // في حالة recovery (إعادة تعيين كلمة المرور)
      if (type == 'recovery' && accessToken != null) {
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            token: accessToken,
            tokenHash: refreshToken,
            type: type,
          ),
        );
      }

      // في حالة email confirmation - منع التسجيل التلقائي
      if (type == 'signup') {
        // تعيين علامة تدفق تأكيد البريد لمنع التسجيل التلقائي
        return MaterialPageRoute(
          builder: (context) {
            // Note: Email confirmation handled automatically by Supabase
            return _emailConfirmedSuccessScreen();
          },
        );
      }

      // في حالة عدم وجود معاملات صحيحة
      AppLogger.warning('معاملات auth callback غير صحيحة: $queryParams');
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    } catch (e) {
      // في حالة وجود خطأ في معالجة الرابط
      AppLogger.error('خطأ في معالجة auth callback', e);
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    }
  }

  /// بناء شاشة إعادة التوجيه مؤقتة
  static Widget _buildRedirectScreen(BuildContext context, String routeName) {
    // استخدام Future.microtask لتجنب مشاكل السياق مع فحص mounted
    Future.microtask(() {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, routeName);
      }
    });
    return const Scaffold(
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
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

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
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

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

      case deliveryCompanyDashboard:
        return authProvider.isDeliveryCompanyAdmin || authProvider.isAdmin;

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

  // ===== Supabase Auth Deep Link Helpers =====

  /// معالجة رابط إعادة تعيين كلمة المرور من Supabase
  static void handlePasswordResetLink({
    required BuildContext context,
    required String token,
    String? tokenHash,
    String? type,
  }) {
    Navigator.pushNamed(
      context,
      resetPassword,
      arguments: {
        'token': token,
        'token_hash': tokenHash,
        'type': type ?? 'recovery',
      },
    );
  }

  /// شاشة نجاح تأكيد البريد الإلكتروني مع معالجة أفضل للأخطاء
  static Widget _emailConfirmedSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE3F2FD),
              const Color(0xFFBBDEFB),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // أيقونة النجاح
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green.shade600,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // رسالة النجاح
                  Text(
                    '🎉 تم تأكيد بريدك الإلكتروني بنجاح!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'يمكنك الآن تسجيل الدخول والاستمتاع بخدماتنا',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // زر تسجيل الدخول مع معالجة أفضل للأخطاء
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Builder(
                      builder: (context) => ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            // التحقق من توفر المزود أولاً
                            final authProvider = context.mounted
                                ? Provider.of<SupabaseProvider>(
                                    context,
                                    listen: false,
                                  )
                                : null;

                            if (authProvider == null || !context.mounted) {
                              // إذا لم يكن المزود متاحاً، توجه مباشرة لشاشة تسجيل الدخول
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
                              );
                              return;
                            }

                            // تم إلغاء تسجيل الخروج التلقائي - المستخدم يبقى مسجل دخول
                            // if (authProvider.isLoggedIn) {
                            //   await authProvider.signOut();
                            // }

                            if (!context.mounted) return;

                            // توجه للصفحة الرئيسية مع رسالة نجاح
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.home,
                              (route) => false,
                            );

                            // إظهار رسالة نجاح بعد التوجيه
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✅ تم تأكيد بريدك الإلكتروني بنجاح! مرحباً بك',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            });
                          } catch (e) {
                            // في حالة وجود خطأ، توجه للصفحة الرئيسية
                            AppLogger.error('خطأ في معالجة تأكيد البريد', e);
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.home,
                                (route) => false,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: const Text(
                          'متابعة تسجيل الدخول',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// معالجة deep link من URL مع معالجة أفضل للأخطاء
  static Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    try {
      final path = uri.path;
      final queryParams = uri.queryParameters;

      AppLogger.info('🔗 معالجة deep link: $path');
      AppLogger.debug('معاملات URI: $queryParams');

      // معالجة روابط Supabase Auth - دعم المسارات المختلفة
      if (path.contains('/auth/callback') || path.contains('/callback')) {
        final type = queryParams['type'];
        final accessToken = queryParams['access_token'];
        final refreshToken = queryParams['refresh_token'];
        final code = queryParams['code']; // الكود الجديد
        final error = queryParams['error'];
        final errorDescription = queryParams['error_description'];

        // معالجة النوع الجديد - Code Exchange
        if (code != null) {
          AppLogger.info('🔄 معالجة code exchange من deep link: $code');

          // Note: Email confirmation handled automatically by Supabase
          AppLogger.debug('🚫 Email confirmation code exchange processing');

          // التوجه لشاشة معالجة الكود
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.callback,
            (route) => false,
          );
          return;
        }

        // معالجة أخطاء الروابط المنتهية الصلاحية
        if (error != null) {
          AppLogger.error('Deep link error: $error - $errorDescription');

          if (error == 'access_denied' ||
              errorDescription?.contains('expired') == true) {
            // توجه لشاشة تأكيد البريد مع معلومة أن الرابط منتهي الصلاحية
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.emailConfirmation,
              (route) => false,
              arguments: {
                'email': '',
                'expired_link': true,
                'error_message': 'انتهت صلاحية رابط التأكيد',
              },
            );
            return;
          }
        }

        if (type == 'recovery' && accessToken != null) {
          handlePasswordResetLink(
            context: context,
            token: accessToken,
            tokenHash: refreshToken,
            type: type,
          );
        } else if (type == 'signup') {
          // تأكيد البريد الإلكتروني
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => _emailConfirmedSuccessScreen()),
            (route) => false,
          );
        } else {
          // في حالة عدم وجود معاملات صحيحة، توجه لشاشة تسجيل الدخول
          AppLogger.warning('معاملات deep link غير صحيحة: $queryParams');
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
        }
      }
    } catch (e) {
      // في حالة وجود خطأ في معالجة الرابط
      AppLogger.error('خطأ في معالجة deep link', e);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    }
  }
}

/// شاشة معالجة روابط تأكيد البريد الإلكتروني
class _CallbackScreen extends StatefulWidget {
  @override
  State<_CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<_CallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // الحصول على المعاملات من URL
      final uri = Uri.base;
      final code = uri.queryParameters['code'];

      AppLogger.info('🔗 معالجة رابط callback مع الكود: $code');

      if (code != null) {
        // معالجة callback للحصول على session
        await _handleSupabaseAuthCallback(code);

        if (!mounted) return;

        // التوجه للصفحة الرئيسية مع رسالة نجاح
        if (mounted) {
          navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

          // إظهار رسالة نجاح بعد التوجيه
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text('✅ تم تأكيد بريدك الإلكتروني بنجاح! مرحباً بك'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          });
        }
      } else {
        // لا يوجد كود، توجه للصفحة الرئيسية مع رسالة خطأ
        if (!mounted) return;

        if (mounted) {
          navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text('❌ رابط تأكيد غير صالح'),
                backgroundColor: Colors.red,
              ),
            );
          });
        }
      }
    } catch (e) {
      AppLogger.error('خطأ في معالجة callback', e);

      if (mounted) {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        navigator.pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في معالجة رابط التأكيد: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    }
  }

  Future<void> _handleSupabaseAuthCallback(String code) async {
    try {
      AppLogger.info('🔄 بدء معالجة رابط تأكيد البريد...');

      // استخدام Supabase لمعالجة callback
      await Supabase.instance.client.auth.exchangeCodeForSession(code);

      AppLogger.info('✅ تم تأكيد البريد الإلكتروني بنجاح');

      // إعطاء وقت قصير للمعالجة
      await Future.delayed(Duration(milliseconds: 500));

      // تم إلغاء تسجيل الخروج التلقائي - المستخدم يبقى مسجل دخول
      // await Supabase.instance.client.auth.signOut();
      AppLogger.info('✅ المستخدم سيبقى مسجل دخول');
    } catch (e) {
      AppLogger.error('خطأ في معالجة Supabase callback', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري معالجة رابط التأكيد...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// شاشة انتظار OAuth Callback - تستمع لـ onAuthStateChange وتنتقل حسب الدور
class _OAuthCallbackScreen extends StatefulWidget {
  const _OAuthCallbackScreen();

  @override
  State<_OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<_OAuthCallbackScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _handleOAuthCallback();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleOAuthCallback() {
    // استخدام postFrameCallback للتأكد من أن الـ widget جاهز
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _processOAuthCallback();
    });
  }

  Future<void> _processOAuthCallback() async {
    // ① فحص إذا كان المستخدم مسجل دخوله فعلاً
    if (Supabase.instance.client.auth.currentUser != null) {
      if (!_navigated) _navigateAfterSignIn();
      return;
    }

    // ② على الويب: نستبدل الكود يدوياً من URL (PKCE لا يعالجه SDK تلقائياً)
    if (kIsWeb) {
      final code = Uri.base.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        try {
          AppLogger.info('🔄 OAuth PKCE: جاري استبدال الكود...');
          await Supabase.instance.client.auth.exchangeCodeForSession(code);
          AppLogger.info('✅ تم استبدال الكود بنجاح');
          if (mounted && !_navigated) _navigateAfterSignIn();
          return;
        } catch (e) {
          AppLogger.warning('⚠️ exchangeCodeForSession: $e');
          // الكود ربما استُهلك بالفعل من SDK، نفحص الجلسة مرة أخرى
          if (Supabase.instance.client.auth.currentUser != null) {
            if (mounted && !_navigated) _navigateAfterSignIn();
            return;
          }
          // خطأ حقيقي
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '❌ فشل تسجيل الدخول: ${e.toString().split('\n').first}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    // ③ fallback: الاستماع لـ onAuthStateChange (للموبايل أو إذا لم يوجد كود في URL)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.signedIn &&
          data.session?.user != null &&
          !_navigated) {
        _authSubscription?.cancel();
        if (mounted) _navigateAfterSignIn();
      }
    });

    // ④ timeout بعد 20 ثانية
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && !_navigated) {
        _authSubscription?.cancel();
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏱️ انتهت مهلة تسجيل الدخول. يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _navigateAfterSignIn() async {
    _navigated = true;
    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // جلب الدور من profiles
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final role = profile?['role'] as String?;
      String route;
      switch (role) {
        case 'admin':
          route = AppRoutes.adminDashboard;
          break;
        case 'delivery_company_admin':
          route = AppRoutes.deliveryCompanyDashboard;
          break;
        case 'merchant':
          route = AppRoutes.merchantDashboard;
          break;
        case 'captain':
          route = AppRoutes.captainDashboard;
          break;
        default:
          route = AppRoutes.home;
      }

      AppLogger.info('✅ OAuth تم بنجاح - التوجيه إلى: $route (role=$role)');
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تسجيل الدخول بواسطة جوجل بنجاح!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    } catch (e) {
      AppLogger.error('❌ خطأ في التنقل بعد OAuth', e);
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'جاري تسجيل الدخول بواسطة جوجل...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'لا تغلق هذه الصفحة',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشة خاصة لمعالجة Code Exchange (النوع الجديد)
class _CodeExchangeScreen extends StatefulWidget {
  final String code;

  const _CodeExchangeScreen({required this.code});

  @override
  State<_CodeExchangeScreen> createState() => _CodeExchangeScreenState();
}

class _CodeExchangeScreenState extends State<_CodeExchangeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleCodeExchange();
    });
  }

  Future<void> _handleCodeExchange() async {
    try {
      AppLogger.info('🔄 بدء معالجة code exchange: ${widget.code}');

      // معالجة code exchange مع Supabase
      await Supabase.instance.client.auth
          .exchangeCodeForSession(widget.code)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('exchangeCodeForSession timeout');
            },
          );

      AppLogger.info('✅ تم تأكيد البريد الإلكتروني بنجاح');

      // إعطاء وقت قصير للمعالجة
      await Future.delayed(Duration(milliseconds: 500));

      // تم إلغاء تسجيل الخروج التلقائي - المستخدم يبقى مسجل دخول
      // await Supabase.instance.client.auth.signOut();
      AppLogger.info('✅ المستخدم سيبقى مسجل دخول');

      // التوجه للصفحة الرئيسية مع رسالة نجاح
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

      // إظهار رسالة نجاح بعد التوجيه
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تأكيد بريدك الإلكتروني بنجاح! مرحباً بك'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      });
    } catch (e) {
      AppLogger.error('خطأ في معالجة code exchange', e);

      // معالجة خاصة لخطأ flow state
      String errorMessage = '❌ خطأ في معالجة رابط التأكيد';
      if (e is TimeoutException) {
        errorMessage =
            '⏳ الاتصال استغرق وقتاً طويلاً. تأكد من الشبكة ثم أعد المحاولة';
      } else if (e.toString().contains('HandshakeException')) {
        errorMessage =
            '🔐 تعذر إنشاء اتصال آمن مع الخادم. تحقق من الإنترنت أو جرب شبكة أخرى';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('_NativeSocket')) {
        errorMessage =
            '🌐 تعذر الوصول إلى خادم Supabase. تحقق من الشبكة أو إعدادات DNS ثم أعد المحاولة';
      } else if (e.toString().contains('flow_state_not_found')) {
        errorMessage = '⏱️ انتهت صلاحية رابط التأكيد. يرجى المحاولة مرة أخرى';
      } else if (e.toString().contains('invalid flow state')) {
        errorMessage = '🔄 رابط التأكيد غير صالح. يرجى تسجيل الدخول مرة أخرى';
      }

      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);

        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تأكيد البريد الإلكتروني'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'جاري تأكيد بريدك الإلكتروني...',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'لا تغلق هذه الشاشة',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
