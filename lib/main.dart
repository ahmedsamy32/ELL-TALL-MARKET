import 'dart:async';

// Flutter Core
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Firebase & Supabase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// State Management
import 'package:provider/provider.dart';

// Configuration
import 'config/env.dart';
import 'config/theme.dart';
import 'config/supabase_config.dart';
import 'config/production_config.dart';
import 'firebase_options.dart';

// Core & Utils
import 'core/logger.dart';
import 'utils/app_routes.dart';

// Services
import 'services/network_manager.dart';
import 'services/auth_deep_link_handler.dart';
import 'services/notification_service.dart';

// Providers
import 'providers/locale_provider.dart';
import 'providers/supabase_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/category_provider.dart';
import 'providers/order_provider.dart';
import 'providers/merchant_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/client_settings_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/dynamic_ui_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/store_provider.dart';
import 'providers/user_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/location_provider.dart';

// Widgets
import 'widgets/app_shimmer.dart';
import 'widgets/network_manager_widget.dart';

// Localization
import 'generated/l10n.dart';

// -----------------------------------------------------------------------------
// SERVICES & UTILITIES
// -----------------------------------------------------------------------------

/// Service providing global access to navigation state and common navigation methods.
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

/// Handler for Firebase Messaging background messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.info('Handling a background message: ${message.messageId}');
}

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------

Future<void> main() async {
  // Global Error Handling: Capture Flutter-specific errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      '❌ Flutter Error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };

  // Global Error Handling: Capture asynchronous platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('❌ Platform Error: $error', error, stack);
    return true;
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialization: Load Environments
    await dotenv.load(fileName: ".env");

    // 2. Initialization: Firebase Services
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) {
      // تسجيل background handler فقط هنا
      // باقي الإعدادات (permission, token, listeners) تتم في NotificationServiceEnhanced.initialize()
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } else {
      AppLogger.info('Running on Web: Skipping FCM setup for now');
    }

    // 3. Initialization: App Services & Managers
    NetworkManager().initialize();
    AppLogger.info('✅ Network Manager initialized');

    // Consolidated Supabase initialization
    await SupabaseConfig.initialize();

    // Unified Service Initialization
    await initializeAppServices();

    runApp(
      MultiProvider(
        providers: [
          // Basic State Providers
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => SupabaseProvider()),

          // Dependent Data Providers (ProxyProvider)
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
          ChangeNotifierProxyProvider<SupabaseProvider, FavoritesProvider>(
            create: (_) => FavoritesProvider(),
            update: (context, auth, previousFavorites) {
              final favoritesProvider =
                  previousFavorites ?? FavoritesProvider();
              favoritesProvider.setAuthProvider(auth);
              final currentUser = auth.currentUser;
              if (auth.isLoggedIn && currentUser != null) {
                favoritesProvider.loadUserFavorites(currentUser.id);
              }
              return favoritesProvider;
            },
          ),

          // Core Feature Providers
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider(create: (_) => StoreProvider()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => MerchantProvider()),
          ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
          ChangeNotifierProvider(create: (_) => ClientSettingsProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => DynamicUIProvider()),
          ChangeNotifierProvider(create: (_) => BannerProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    AppLogger.error('💥 Fatal initialization error: $e', e, stack);

    // Final Fallback: Error Recovery Screen
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'حدث خطأ أثناء تشغيل التطبيق',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => main(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
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
}

// -----------------------------------------------------------------------------
// APP CORE WIDGET
// -----------------------------------------------------------------------------

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
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale?.languageCode) {
                return supportedLocale;
              }
            }
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

// -----------------------------------------------------------------------------
// INITIALIZATION WIDGETS
// -----------------------------------------------------------------------------

/// Widget responsible for lazy initialization of Supabase after the app builds.
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

      final supabaseProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      await supabaseProvider.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          AppLogger.warning('⚠️ Supabase init timeout - continuing anyway');
        },
      );

      if (mounted) {
        setState(() => _isInitializing = false);
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
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppShimmer.wrap(
                context,
                child: AppShimmer.circle(context, size: 44),
              ),
              const SizedBox(height: 16),
              const Text('جاري تهيئة التطبيق...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      AppLogger.warning('⚠️ Supabase init errors: $_errorMessage');
    }

    return ConnectionStatusWidget(showBanner: true, child: widget.child);
  }
}

// -----------------------------------------------------------------------------
// SERVICE INITIALIZATION HELPERS
// -----------------------------------------------------------------------------

/// Unified application service initialization.
Future<void> initializeAppServices() async {
  try {
    AuthDeepLinkHandler.initialize();
    if (ProductionConfig.shouldShowDebugLogs) {
      AppLogger.info('✅ Auth Deep Link Handler initialized');
    }

    // Initialize notification service (FCM + local notifications)
    if (!kIsWeb) {
      final notifReady = await NotificationServiceEnhanced.instance
          .initialize();
      if (ProductionConfig.shouldShowDebugLogs) {
        AppLogger.info(
          notifReady
              ? '✅ Notification service initialized'
              : '⚠️ Notification service initialization failed',
        );
      }
    }
  } catch (e) {
    if (ProductionConfig.shouldShowDebugLogs) {
      AppLogger.error('❌ Service initialization failed: $e');
      AppLogger.info('📱 App will continue in offline mode');
    }
    _showOfflineMode(e);
  }
}

/// Utility for showing offline status to the user.
void _showOfflineMode([dynamic error]) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      AppLogger.warning('⚠️ Navigator context unavailable for offline notice');
      return;
    }

    String message = '📴 أنت غير متصل بالسيرفر – جاري العمل في وضع أوفلاين';
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
  });
}
