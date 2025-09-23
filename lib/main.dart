import 'package:ell_tall_market/providers/locale_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ell_tall_market/config/theme.dart';
import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:ell_tall_market/config/env.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart'; // ✅ Firebase Auth Provider
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/dynamic_ui_provider.dart';
import 'package:ell_tall_market/providers/favorites_provider.dart';
import 'package:ell_tall_market/services/connectivity_service.dart'; // ✅ إضافة خدمة الاتصال
import 'package:ell_tall_market/services/network_manager.dart'; // ✅ إضافة مدير الشبكة
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';
import 'firebase_options.dart';
import 'services/supabase_schema_checker.dart';

// ===== NavigationService =====
class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  static void goBack() {
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop();
    }
  }

  static Future<dynamic> replaceWith(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase with options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Get FCM token
  final token = await messaging.getToken();
  if (kDebugMode) {
    print('FCM Token: $token');
  }

  // Check internet connectivity
  await ConnectivityService.checkConnection();

  // Initialize Network Manager
  await NetworkManager().initialize();
  if (kDebugMode) {
    debugPrint('✅ Network Manager initialized');
  }

  // Initialize Supabase (single place)
  try {
    await SupabaseConfig.initialize();
    debugPrint('✅ Supabase and Firebase initialized successfully');

    // Test Supabase connection only if initialization was successful
    await testSupabaseConnection();
  } catch (e) {
    debugPrint('❌ Supabase initialization failed: $e');
    debugPrint('📱 App will continue in offline mode');
  }

  // Run Supabase schema checks and log results (only in debug mode)
  if (kDebugMode) {
    try {
      final checker = SupabaseSchemaChecker(Supabase.instance.client);
      final results = await checker.runAllChecks();
      debugPrint('🔎 Supabase schema check results:');
      debugPrint('Connectivity: ${results['connectivity']}');
      debugPrint('Missing tables: ${results['missingTables']}');
      debugPrint('Missing RPCs: ${results['missingRpcs']}');
      debugPrint('Storage: ${results['storage']}');
    } catch (e) {
      debugPrint('❌ Supabase schema check failed: $e');
      debugPrint('📱 Schema checks skipped - app will continue normally');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(
          create: (_) => FirebaseAuthProvider(),
        ), // ✅ Firebase Auth Provider
        ChangeNotifierProxyProvider<FirebaseAuthProvider, CartProvider>(
          create: (context) => CartProvider(
            Provider.of<FirebaseAuthProvider>(
                  context,
                  listen: false,
                ).user?.id ??
                '',
          ),
          update: (context, auth, previousCart) =>
              CartProvider(auth.user?.id ?? ''),
        ),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DynamicUIProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
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
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
          navigatorKey: NavigationService.navigatorKey,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// Function to test Supabase connection (for development only)
Future<void> testSupabaseConnection() async {
  if (!kDebugMode) return;

  try {
    debugPrint('🔍 Testing Supabase connection...');

    // Test with timeout and connection check
    if (await SupabaseConfig.isConnected()) {
      debugPrint('✅ Supabase connection test successful');
    } else {
      debugPrint('⚠️ Supabase connection test failed - attempting retry...');
      if (await SupabaseConfig.retryConnection()) {
        debugPrint('✅ Supabase connection restored after retry');
      } else {
        debugPrint('❌ Supabase connection could not be established');
      }
    }
  } catch (e) {
    debugPrint('❌ Supabase connection test error: $e');
    if (e.toString().contains('HandshakeException') ||
        e.toString().contains('Connection terminated')) {
      debugPrint('🔧 Connection issue detected - SSL/TLS handshake problem');
      debugPrint(
        '💡 This might be due to network restrictions or firewall settings',
      );
    }
    // Log the error but don't stop the app
  }
}

// Function to initialize app services
Future<void> initializeAppServices() async {
  try {
    await SupabaseConfig.initialize();
    debugPrint('✅ Supabase initialized successfully');

    if (kDebugMode) {
      await testSupabaseConnection();
    }
  } catch (e) {
    debugPrint('❌ Error initializing services: $e');
    rethrow;
  }
}
