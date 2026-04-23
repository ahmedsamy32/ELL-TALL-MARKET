import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../core/logger.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  late StreamController<bool> _connectionStreamController;
  late Stream<bool> connectionStream;
  bool _isConnected = true; // افترض الاتصال متاح في البداية
  bool hasShownDisconnectionNotice = false; // علم لمرة واحدة
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isConnected => _isConnected;

  /// إعادة تعيين علم الانقطاع (للاستخدام بعد إعادة الاتصال)
  void resetDisconnectionNotice() {
    hasShownDisconnectionNotice = false;
  }

  void initialize() {
    _connectionStreamController = StreamController<bool>.broadcast();
    connectionStream = _connectionStreamController.stream;

    // استمع لتغييرات الاتصال فقط (بدون فحص دوري)
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        _checkConnection(
          results.isNotEmpty ? results.first : ConnectivityResult.none,
        );
      },
      onError: (error) {
        AppLogger.warning('خطأ في مراقبة الاتصال', error);
      },
    );

    // فحص الاتصال الأولي مرة واحدة
    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _checkConnection(
        connectivityResult.isNotEmpty
            ? connectivityResult.first
            : ConnectivityResult.none,
      );
    } catch (e) {
      AppLogger.warning('خطأ في فحص الاتصال الأولي', e);
      // افترض الاتصال متاح إذا حصل خطأ
      _isConnected = true;
    }
  }

  void _checkConnection(ConnectivityResult result) {
    bool wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    // إذا قطع الاتصال، أعد تعيين العلم لعرض الإشعار مرة واحدة
    if (!_isConnected) {
      hasShownDisconnectionNotice = false;
    }

    // بث التغيير فقط إذا حدث تغيير فعلي
    if (wasConnected != _isConnected) {
      _connectionStreamController.add(_isConnected);
      AppLogger.info('حالة الاتصال: ${_isConnected ? '✅ متصل' : '❌ منقطع'}');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionStreamController.close();
  }
}
