class AppConstants {
  // App Info
  static const String appName = 'سوق التل';
  static const String appNameEn = 'El Tall Market';
  static const String appVersion = '1.1.8';

  // Database Tables / Collections
  static const String profilesTable = 'profiles';
  static const String storesTable = 'stores';
  static const String productsTable = 'products';
  static const String categoriesTable = 'categories';
  static const String ordersTable = 'orders';
  static const String orderItemsTable = 'order_items';
  static const String couponsTable = 'coupons';
  static const String notificationsTable = 'notifications';
  static const String bannersTable = 'banners';
  static const String captainsTable = 'captains';
  static const String reviewsTable = 'reviews';
  static const String productTemplatesTable = 'product_templates';
  static const String storeWalletTransactionsTable = 'store_wallet_transactions';
  static const String storeWalletTopupsTable = 'store_wallet_topups';
  static const String walletReceiptsTable = 'wallet_receipts';
  static const String deliveryCompaniesTable = 'delivery_companies';
  static const String deliveryOfficesTable = 'delivery_offices';
  static const String deliveryPricesTable = 'delivery_prices';
  static const String systemSettingsTable = 'system_settings';
  static const String storeRatingsTable = 'store_ratings';
  static const String chatsTable = 'chats';
  static const String messagesTable = 'messages';

  // Storage Buckets
  static const String profilesBucket = 'profiles';
  static const String storesBucket = 'stores';
  static const String productsBucket = 'products';
  static const String categoriesBucket = 'categories';
  static const String receiptsBucket = 'receipts';
  static const String bannersBucket = 'banners';
  static const String deliveryBucket = 'delivery';

  // Storage paths
  static const String userImagesPath = 'user_images/';
  static const String productImagesPath = 'product_images/';
  static const String categoryImagesPath = 'category_images/';
  static const String storeLogoPath = 'store_logos/';
  static const String storeCoverPath = 'store_covers/';
  static const String bannerImagesPath = 'banner_images/';

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
