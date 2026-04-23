import 'package:flutter/material.dart';
import 'package:ell_tall_market/services/network_manager.dart';
import '../core/logger.dart';
import 'dart:async';

/// 🌐 Widget احترافي لمراقبة حالة الاتصال بالإنترنت
///
/// - عرض إشعار انقطاع واحد فقط (لا إزعاج متكرر)
/// - banner محلية فقط عند الحاجة
/// - استمع للتغييرات فقط (بدون فحص دوري)
class ConnectionStatusWidget extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  const ConnectionStatusWidget({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  bool _isConnected = true;
  late Stream<bool> _connectivityStream;
  late StreamSubscription<bool> _subscription;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  void _initializeConnectivity() {
    final networkManager = NetworkManager();

    // الحالة الأولية
    _isConnected = networkManager.isConnected;

    // استمع لتغييرات الاتصال فقط
    _connectivityStream = networkManager.connectionStream;
    _subscription = _connectivityStream.listen(
      (isConnected) {
        if (mounted && isConnected != _isConnected) {
          setState(() {
            _isConnected = isConnected;
          });

          // عرض إشعار واحد فقط عند القطع
          if (!isConnected && !networkManager.hasShownDisconnectionNotice) {
            networkManager.hasShownDisconnectionNotice = true;
            _showDisconnectionNotice();
          }

          // إعادة تعيين العلم عند الاتصال
          if (isConnected) {
            networkManager.resetDisconnectionNotice();
          }

          AppLogger.info("حالة الاتصال: ${isConnected ? '✅ متصل' : '❌ منقطع'}");
        }
      },
      onError: (error) {
        AppLogger.error("خطأ في مراقبة الاتصال", error);
      },
    );
  }

  void _showDisconnectionNotice() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'انقطع الاتصال بالإنترنت. سيحاول التطبيق الاتصال تلقائياً.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // عرض banner محلية فقط إذا كان الاتصال منقطعاً
        if (widget.showBanner && !_isConnected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.red.shade400,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "لا يوجد اتصال بالإنترنت",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
