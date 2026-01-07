import 'package:ell_tall_market/providers/locale_provider.dart';

import 'package:flutter/material.dart';
import 'core/logger.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ell_tall_market/config/theme.dart';
import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:ell_tall_market/config/env.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart'; // ✅ Supabase Provider
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/dynamic_ui_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/providers/banner_provider.dart';
import 'package:ell_tall_market/services/network_manager.dart'; // ✅ إضافة مدير الشبكة
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'firebase_options.dart';
import 'services/auth_deep_link_handler.dart';
import 'config/production_config.dart';

// ===== NavigationService =====
class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.error('❌ NavigationService: navigatorState is null');
      return Future.value(null);
    }
    return navigatorState.pushNamed(routeName, arguments: arguments);
  }

  static void goBack() {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.error('❌ NavigationService: navigatorState is null');
      return;
    }
    if (navigatorState.canPop()) {
      navigatorState.pop();
    }
  }

  static Future<dynamic> replaceWith(String routeName, {Object? arguments}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      AppLogger.error('❌ NavigationService: navigatorState is null');
      return Future.value(null);
    }
    return navigatorState.pushReplacementNamed(routeName, arguments: arguments);
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.info('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase with options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (iOS optimized)
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // Get FCM token
  final token = await messaging.getToken();
  AppLogger.info('FCM Token: $token');

  // Initialize Network Manager
  NetworkManager().initialize();
  AppLogger.info('✅ Network Manager initialized');

  // Initialize Supabase according to official docs
  await SupabaseConfig.initialize();

  // Initialize all app services
  await initializeAppServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(
          create: (_) => SupabaseProvider(),
        ), // ✅ Supabase Provider
        ChangeNotifierProxyProvider<SupabaseProvider, CartProvider>(
          create: (context) => CartProvider(
            Provider.of<SupabaseProvider>(
                  context,
                  listen: false,
                ).currentUser?.id ??
                '',
          ),
          update: (context, auth, previousCart) =>
              CartProvider(auth.currentUser?.id ?? ''),
        ),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => MerchantProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DynamicUIProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
        ChangeNotifierProxyProvider<SupabaseProvider, FavoritesProvider>(
          create: (_) => FavoritesProvider(),
          update: (context, auth, previousFavorites) {
            final favoritesProvider = previousFavorites ?? FavoritesProvider();
            favoritesProvider.setAuthProvider(auth);
            // تحميل المفضلة عند تسجيل الدخول
            final currentUser = auth.currentUser;
            if (auth.isLoggedIn && currentUser != null) {
              favoritesProvider.loadUserFavorites(currentUser.id);
            }
            return favoritesProvider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: Env.appName,
          theme: appTheme,
          locale: localeProvider.locale,
          supportedLocales: S.delegate.supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            // Check if the current device locale is supported
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale?.languageCode) {
                return supportedLocale;
              }
            }
            // If the locale of the device is not supported, use the first one
            return supportedLocales.first;
          },
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.generateRoute,
          navigatorKey: NavigationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return SupabaseInitializer(child: child ?? Container());
          },
        );
      },
    );
  }
}

/// Initializes SupabaseProvider according to official documentation
class SupabaseInitializer extends StatefulWidget {
  final Widget child;

  const SupabaseInitializer({super.key, required this.child});

  @override
  State<SupabaseInitializer> createState() => _SupabaseInitializerState();
}

class _SupabaseInitializerState extends State<SupabaseInitializer> {
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Kick off Supabase setup after the first frame to avoid provider rebuilds during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeSupabase();
      }
    });
  }

  Future<void> _initializeSupabase() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      // Initialize SupabaseProvider with short timeout
      final supabaseProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      await supabaseProvider.initialize().timeout(
        Duration(seconds: 3), // تقليل من 10 ثواني إلى 3
        onTimeout: () {
          AppLogger.warning(
            '⚠️ Supabase initialization timeout - continuing anyway',
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      AppLogger.error('❌ Supabase initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while initializing
    if (_isInitializing) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تهيئة التطبيق...'),
              ],
            ),
          ),
        ),
      );
    }

    // Show error if initialization failed (but continue anyway)
    if (_errorMessage != null) {
      // Log error but continue to app
      AppLogger.warning(
        '⚠️ Supabase init had errors but continuing: $_errorMessage',
      );
    }

    // Return the normal app - continue even if there were errors
    return widget.child;
  }
}

// Function to initialize app services (unified)
Future<void> initializeAppServices() async {
  try {
    // Initialize Auth Deep Link Handler for authentication links
    AuthDeepLinkHandler.initialize();
    if (ProductionConfig.shouldShowDebugLogs) {
      AppLogger.info('✅ Auth Deep Link Handler initialized');
    }

    // Initialize Supabase with production-aware timeout
    await SupabaseConfig.initialize();
    if (ProductionConfig.shouldShowDebugLogs) {
      AppLogger.info('✅ Supabase initialized successfully');
    }

    // تعطيل اختبار الاتصال المباشر لتجنب التوقف
    // اختبار سريع في وضع التطوير - معطل مؤقتاً
    // if (kDebugMode) {
    //   try {
    //     await SupabaseConfig.client.from('categories').select('id').limit(1);
    //     debugPrint('✅ Supabase connection test successful');
    //   } catch (e) {
    //     debugPrint('❌ Supabase connection test failed: $e');
    //   }
    // }

    // Test Supabase connection and run schema checks - معطل لتحسين الأداء
    // if (ProductionConfig.shouldRunSchemaChecks) {
    //   await _testSupabaseConnection();
    //   await _runSchemaChecks();
    // }
  } catch (e) {
    if (ProductionConfig.shouldShowDebugLogs) {
      AppLogger.error('❌ Service initialization failed: $e');
      AppLogger.info('📱 App will continue in offline mode');
    }

    // Show user-friendly message in case of connection failure
    _showOfflineMode(e);
  }
}

// Show offline mode notification to user
void _showOfflineMode([dynamic error]) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) {
      String message = '📴 أنت غير متصل بالسيرفر – جاري العمل في وضع أوفلاين';

      // Show error details only in debug mode
      if (ProductionConfig.shouldShowErrorDetails && error != null) {
        message += '\nالتفاصيل: ${error.toString().split('\n').first}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => initializeAppServices(),
          ),
        ),
      );
    }
  });
}
