import 'package:logger/logger.dart' as logger;

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static final _logger = logger.Logger(
    printer: logger.PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.enableLogging) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.enableLogging) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
  }

  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.enableLogging) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.enableLogging) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.enableLogging) {
      _logger.f(message, error: error, stackTrace: stackTrace);
    }
  }

  static void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (AppConfig.enableAnalytics) {
      final message = 'Event: $eventName';
      if (parameters != null) {
        _logger.i('$message - Parameters: $parameters');
      } else {
        _logger.i(message);
      }
    }
  }

  static void logNetworkRequest(String url, String method, {dynamic body, Map<String, dynamic>? headers}) {
    if (AppConfig.enableLogging) {
      _logger.i('Network Request: $method $url');
      if (body != null) {
        _logger.i('Request Body: $body');
      }
      if (headers != null) {
        _logger.i('Request Headers: $headers');
      }
    }
  }

  static void logNetworkResponse(String url, int statusCode, dynamic response) {
    if (AppConfig.enableLogging) {
      _logger.i('Network Response: $statusCode $url');
      _logger.i('Response: $response');
    }
  }

  static void logDatabaseOperation(String operation, String collection, {String? documentId, dynamic data}) {
    if (AppConfig.enableLogging) {
      _logger.i('Database $operation: $collection${documentId != null ? '/$documentId' : ''}');
      if (data != null) {
        _logger.i('Data: $data');
      }
    }
  }

  static void logPerformance(String operation, Duration duration) {
    if (AppConfig.enableLogging) {
      _logger.i('Performance: $operation took ${duration.inMilliseconds}ms');
    }
  }

  static void logMemoryUsage() {
    if (AppConfig.enableLogging) {
      // يمكن إضافة منطق لقياس استخدام الذاكرة
      _logger.i('Memory usage logged');
    }
  }

  static void logAppLifecycle(String state) {
    if (AppConfig.enableLogging) {
      _logger.i('App Lifecycle: $state');
    }
  }

  static void logUserInteraction(String screen, String action, {Map<String, dynamic>? details}) {
    if (AppConfig.enableLogging) {
      _logger.i('User Interaction: $screen - $action');
      if (details != null) {
        _logger.i('Details: $details');
      }
    }
  }

  static void logErrorWithContext(String context, dynamic error, [StackTrace? stackTrace]) {
    if (AppConfig.enableLogging) {
      _logger.e('Error in $context: $error', error: error, stackTrace: stackTrace);
    }
  }

  static void logWarningWithContext(String context, String warning) {
    if (AppConfig.enableLogging) {
      _logger.w('Warning in $context: $warning');
    }
  }

  static void logInfoWithContext(String context, String info) {
    if (AppConfig.enableLogging) {
      _logger.i('Info in $context: $info');
    }
  }
}

// فئة مساعدة للتهيئة
class AppConfig {
  static const bool enableLogging = bool.fromEnvironment('dart.vm.product') == false;
  static const bool enableAnalytics = true;
}