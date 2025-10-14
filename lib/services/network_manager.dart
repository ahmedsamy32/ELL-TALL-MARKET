import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  late StreamController<bool> _connectionStreamController;
  late Stream<bool> connectionStream;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void initialize() {
    _connectionStreamController = StreamController<bool>.broadcast();
    connectionStream = _connectionStreamController.stream;

    // استمع لتغييرات الاتصال
    Connectivity().onConnectivityChanged.listen((result) {
      _checkConnection(result.first);
    });

    // فحص الاتصال الأولي
    _checkInitialConnection();
  }

  Future<void> _checkInitialConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _checkConnection(connectivityResult.first);
  }

  void _checkConnection(ConnectivityResult result) {
    bool wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    if (wasConnected != _isConnected) {
      _connectionStreamController.add(_isConnected);
    }
  }

  void dispose() {
    _connectionStreamController.close();
  }
}
