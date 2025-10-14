import 'package:flutter/material.dart';
import 'package:ell_tall_market/services/network_manager.dart';
import '../core/logger.dart';
import 'dart:async';

/// 🌐 Widget شامل لعرض ومراقبة حالة الاتصال بالإنترنت
///
/// يجمع بين الوظائف البسيطة والمتقدمة في مكان واحد
class ConnectionStatusWidget extends StatefulWidget {
  final Widget child;
  final bool showToast;
  final bool showBanner;
  final Duration updateInterval;

  const ConnectionStatusWidget({
    super.key,
    required this.child,
    this.showToast = true,
    this.showBanner = true,
    this.updateInterval = const Duration(seconds: 5),
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  bool _isConnected = true;
  bool _showingOfflineMessage = false;
  late Stream<bool> _connectivityStream;
  late StreamSubscription<bool> _subscription;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  void _initializeConnectivity() {
    final networkManager = NetworkManager();

    // فحص أولي للحالة
    _isConnected = networkManager.isConnected;

    // مراقبة التغييرات
    _connectivityStream = networkManager.connectionStream;
    _subscription = _connectivityStream.listen(
      (isConnected) {
        if (mounted && isConnected != _isConnected) {
          setState(() {
            _isConnected = isConnected;
          });

          if (widget.showToast) {
            _showConnectivityToast(isConnected);
          }

          AppLogger.debug(
            "تغيير حالة الاتصال إلى: ${isConnected ? 'متصل' : 'منقطع'}",
          );
        }
      },
      onError: (error) {
        AppLogger.error("خطأ في مراقبة الاتصال", error);
      },
    );

    // الفحص الدوري
    _checkConnectionPeriodically();
  }

  void _checkConnectionPeriodically() {
    Future.delayed(widget.updateInterval, () async {
      if (mounted) {
        final networkManager = NetworkManager();
        final isConnected = networkManager.isConnected;

        // عرض رسالة انقطاع الاتصال
        if (!isConnected && !_showingOfflineMessage && !widget.showBanner) {
          _showOfflineMessage();
        }

        _checkConnectionPeriodically();
      }
    });
  }

  void _showConnectivityToast(bool isConnected) {
    if (!mounted) return;

    Color backgroundColor;
    IconData icon;
    String message;

    if (isConnected) {
      backgroundColor = Colors.green;
      icon = Icons.wifi;
      message = "تم استعادة الاتصال بالإنترنت";
    } else {
      backgroundColor = Colors.red;
      icon = Icons.wifi_off;
      message = "انقطع الاتصال بالإنترنت";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showOfflineMessage() {
    if (!mounted) return;

    setState(() {
      _showingOfflineMessage = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () {
                final networkManager = NetworkManager();
                final isConnected = networkManager.isConnected;
                if (isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.white),
                          SizedBox(width: 8),
                          Text('تم استعادة الاتصال بالإنترنت'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
        )
        .closed
        .then((_) {
          if (mounted) {
            setState(() {
              _showingOfflineMessage = false;
            });
          }
        });
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
        if (widget.showBanner && !_isConnected) _buildConnectivityBanner(),
      ],
    );
  }

  Widget _buildConnectivityBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.red.shade400,
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                IconButton(
                  onPressed: () {
                    final networkManager = NetworkManager();
                    setState(() {
                      _isConnected = networkManager.isConnected;
                    });
                  },
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                  tooltip: "إعادة فحص الاتصال",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔧 Widget مبسط لعرض أيقونة حالة الاتصال فقط
class ConnectivityIndicator extends StatefulWidget {
  final EdgeInsetsGeometry? padding;
  final double iconSize;

  const ConnectivityIndicator({super.key, this.padding, this.iconSize = 20});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _initializeStatus();
  }

  Future<void> _initializeStatus() async {
    try {
      final networkManager = NetworkManager();
      final isConnected = networkManager.isConnected;
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    } catch (e) {
      AppLogger.error("خطأ في فحص حالة الاتصال", e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String tooltip;

    if (_isConnected) {
      color = Colors.green;
      icon = Icons.wifi;
      tooltip = "متصل بالإنترنت";
    } else {
      color = Colors.red;
      icon = Icons.wifi_off;
      tooltip = "غير متصل بالإنترنت";
    }

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: widget.iconSize),
      ),
    );
  }
}

/// 📊 Widget لعرض تشخيص مفصل للاتصال (للمطورين)
class ConnectivityDiagnosticsWidget extends StatefulWidget {
  const ConnectivityDiagnosticsWidget({super.key});

  @override
  State<ConnectivityDiagnosticsWidget> createState() =>
      _ConnectivityDiagnosticsWidgetState();
}

class _ConnectivityDiagnosticsWidgetState
    extends State<ConnectivityDiagnosticsWidget> {
  Map<String, dynamic>? _diagnostics;
  bool _isRunning = false;

  Future<void> _runDiagnostics() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _diagnostics = null;
    });

    try {
      // تشخيص شامل للاتصال باستخدام NetworkManager
      final networkManager = NetworkManager();
      final isConnected = networkManager.isConnected;

      final diagnostics = {
        'basic_connectivity': isConnected,
        'internet_access': isConnected,
        'current_status': isConnected ? 'متصل' : 'منقطع',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'completed',
      };

      if (mounted) {
        setState(() {
          _diagnostics = diagnostics;
        });
      }
    } catch (e) {
      AppLogger.error("خطأ في تشغيل التشخيصات", e);
      if (mounted) {
        setState(() {
          _diagnostics = {'error': e.toString(), 'status': 'failed'};
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.network_check, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'تشخيص الاتصال الشامل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isRunning ? null : _runDiagnostics,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_diagnostics == null && _isRunning)
              const Center(child: CircularProgressIndicator())
            else if (_diagnostics != null)
              _buildDiagnosticsResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDiagnosticItem(
          'الاتصال الأساسي',
          _diagnostics!['basic_connectivity'],
          Icons.signal_cellular_alt,
        ),
        _buildDiagnosticItem(
          'الوصول للإنترنت',
          _diagnostics!['internet_access'],
          Icons.public,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الحالة الحالية: ${_diagnostics!['current_status']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'وقت الفحص: ${_formatTimestamp(_diagnostics!['timestamp'])}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        if (_diagnostics!['error'] != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'خطأ: ${_diagnostics!['error']}',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiagnosticItem(String label, bool? value, IconData icon) {
    Color color;
    IconData statusIcon;

    if (value == null) {
      color = Colors.grey;
      statusIcon = Icons.help_outline;
    } else if (value) {
      color = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else {
      color = Colors.red;
      statusIcon = Icons.error_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Icon(statusIcon, size: 18, color: color),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
