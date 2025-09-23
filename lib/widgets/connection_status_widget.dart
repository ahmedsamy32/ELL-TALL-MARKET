import 'package:flutter/material.dart';
import 'package:ell_tall_market/services/connectivity_service.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final Widget child;

  const ConnectionStatusWidget({super.key, required this.child});

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  bool _showingOfflineMessage = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionPeriodically();
  }

  void _checkConnectionPeriodically() {
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        final isConnected = await ConnectivityService.checkConnection();
        if (!isConnected && !_showingOfflineMessage) {
          _showOfflineMessage();
        }
        _checkConnectionPeriodically();
      }
    });
  }

  void _showOfflineMessage() {
    if (!mounted) return;

    setState(() {
      _showingOfflineMessage = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ConnectivityService.getConnectionErrorMessage(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () async {
                final isConnected = await ConnectivityService.checkConnection();
                if (isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
  Widget build(BuildContext context) {
    return widget.child;
  }
}
