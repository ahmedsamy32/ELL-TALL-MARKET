import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  late StreamController<bool> _networkStatusController;
  late Stream<bool> networkStatusStream;

  /// تهيئة مدير الشبكة
  Future<void> initialize() async {
    _networkStatusController = StreamController<bool>.broadcast();
    networkStatusStream = _networkStatusController.stream;

    // فحص الحالة الحالية
    _connectionStatus = await _connectivity.checkConnectivity();
    _networkStatusController.add(_isConnected());

    // الاستماع للتغييرات
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _connectionStatus = results;
      _networkStatusController.add(_isConnected());

      if (kDebugMode) {
        debugPrint(
          '🌐 Network status changed: ${_getConnectionName(results.isNotEmpty ? results.first : ConnectivityResult.none)}',
        );
      }
    });
  }

  /// التحقق من وجود اتصال بالإنترنت
  bool _isConnected() {
    return _connectionStatus.isNotEmpty &&
        !_connectionStatus.contains(ConnectivityResult.none);
  }

  /// الحصول على حالة الاتصال الحالية
  bool get isConnected => _isConnected();

  /// الحصول على نوع الاتصال
  ConnectivityResult get connectionType => _connectionStatus.isNotEmpty
      ? _connectionStatus.first
      : ConnectivityResult.none;

  /// فحص الاتصال الفعلي بالإنترنت (وليس فقط الـ WiFi/Mobile)
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🌐 Internet connectivity check failed: $e');
      }
      return false;
    }
  }

  /// الحصول على اسم نوع الاتصال
  String _getConnectionName(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  /// الحصول على اسم نوع الاتصال الحالي
  String get connectionName => _getConnectionName(
    _connectionStatus.isNotEmpty
        ? _connectionStatus.first
        : ConnectivityResult.none,
  );

  /// إنهاء مدير الشبكة
  void dispose() {
    _networkStatusController.close();
  }

  /// الانتظار حتى يعود الاتصال
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    late StreamSubscription subscription;
    Timer? timer;

    // إعداد timeout
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(false);
      }
    });

    // الاستماع لتغييرات الشبكة
    subscription = networkStatusStream.listen((isConnected) {
      if (isConnected && !completer.isCompleted) {
        timer?.cancel();
        subscription.cancel();
        completer.complete(true);
      }
    });

    return completer.future;
  }

  /// إعادة محاولة العملية عند عودة الاتصال
  Future<T?> retryWhenConnected<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delayBetweenRetries = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (kDebugMode) {
          debugPrint('🔄 Attempting operation ($attempt/$maxRetries)');
        }

        // انتظار الاتصال إذا لم يكن متوفراً
        if (!isConnected) {
          if (kDebugMode) {
            debugPrint('⏳ Waiting for network connection...');
          }
          await waitForConnection();
        }

        // تنفيذ العملية
        final result = await operation();

        if (kDebugMode) {
          debugPrint('✅ Operation completed successfully on attempt $attempt');
        }

        return result;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Operation failed on attempt $attempt: $e');
        }

        if (attempt == maxRetries) {
          if (kDebugMode) {
            debugPrint('💥 All retry attempts exhausted');
          }
          rethrow;
        }

        // انتظار قبل المحاولة التالية
        await Future.delayed(delayBetweenRetries);
      }
    }

    return null;
  }
}
