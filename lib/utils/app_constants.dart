class AppConstants {
  static const String appName = 'التل ماركت';
  static const String appVersion = '1.0.0';

  // Collections
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String categoriesCollection = 'categories';
  static const String ordersCollection = 'orders';
  static const String cartCollection = 'cart';
  static const String reviewsCollection = 'reviews';
  static const String couponsCollection = 'coupons';
  static const String notificationsCollection = 'notifications';

  // Storage paths
  static const String userImagesPath = 'user_images/';
  static const String productImagesPath = 'product_images/';
  static const String categoryImagesPath = 'category_images/';

  // Default values
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const int defaultAnimationDuration = 300;

  // API endpoints (إذا كنت تستخدم REST API)
  static const String baseUrl = 'https://your-api-domain.com/api';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String productsEndpoint = '/products';
  static const String categoriesEndpoint = '/categories';

  // Error messages
  static const String networkError = 'حدث خطأ في الاتصال بالإنترنت';
  static const String serverError = 'حدث خطأ في الخادم';
  static const String unknownError = 'حدث خطأ غير متوقع';
  static const String authError = 'بيانات الدخول غير صحيحة';

  // Success messages
  static const String loginSuccess = 'تم تسجيل الدخول بنجاح';
  static const String registerSuccess = 'تم إنشاء الحساب بنجاح';
  static const String orderSuccess = 'تم تقديم الطلب بنجاح';
}
