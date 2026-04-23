import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/screens/captain/order_delivery_screen.dart';
import 'package:ell_tall_market/utils/captain_order_helpers.dart';

class CaptainMapScreen extends StatefulWidget {
  final List<OrderModel> orders;

  const CaptainMapScreen({super.key, required this.orders});

  @override
  State<CaptainMapScreen> createState() => _CaptainMapScreenState();
}

class _CaptainMapScreenState extends State<CaptainMapScreen> {
  static const int _acceptTimeoutSeconds = CaptainOrderHelpers.slaAcceptSeconds;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  OrderModel? _selectedOrder;
  String _storeDistanceInfo = '';
  String _storeToClientDistanceInfo = '';
  bool _isLoadingLocation = true;
  Timer? _acceptanceTimer;
  int _remainingSeconds = _acceptTimeoutSeconds;
  bool _isAccepting = false;

  List<OrderModel> _singleOrderFeed() {
    if (widget.orders.isEmpty) return const [];

    // أولوية: الطلبات الموجّهة الجديدة التي تحتاج قبول الكابتن
    final pending =
        widget.orders.where((o) => o.status == OrderStatus.pending).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (pending.isNotEmpty) return [pending.first];

    // ثم الطلبات النشطة الحالية (لو الكابتن بالفعل في رحلة تسليم)
    final active =
        widget.orders
            .where(
              (o) =>
                  o.status == OrderStatus.confirmed ||
                  o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.ready ||
                  o.status == OrderStatus.pickedUp ||
                  o.status == OrderStatus.inTransit,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (active.isNotEmpty) return [active.first];

    return [widget.orders.first];
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initMarkers();
  }

  @override
  void didUpdateWidget(covariant CaptainMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تحديث الماركرز عند تغير الطلبات من الـ Provider
    if (widget.orders != oldWidget.orders) {
      _initMarkers();

      final singleFeed = _singleOrderFeed();
      if (singleFeed.isEmpty) {
        _acceptanceTimer?.cancel();
        if (mounted) {
          setState(() => _selectedOrder = null);
        }
        return;
      }

      final nextOrder = singleFeed.first;
      if (_selectedOrder?.id != nextOrder.id) {
        _selectOrder(nextOrder);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تفعيل خدمة الموقع (GPS) لعرض الخريطة'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'يرجى السماح بالوصول للموقع لعرض الطلبات القريبة',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم رفض إذن الموقع نهائياً. يرجى تفعيله من إعدادات الجهاز',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      final singleFeed = _singleOrderFeed();
      if (singleFeed.isNotEmpty && _currentPosition != null) {
        // ✅ اختيار الطلب الموجّه الوحيد
        _selectOrder(singleFeed.first);
        // ✅ ضبط الكاميرا لعرض كل الماركرز
        _fitAllMarkers();
      }
    } catch (e) {
      AppLogger.error('Error getting location', e);
      setState(() => _isLoadingLocation = false);
    }
  }

  /// ✅ ضبط الكاميرا لتشمل كل الماركرز + موقع الكابتن
  void _fitAllMarkers() {
    if (_mapController == null || _markers.isEmpty) return;

    final points = <LatLng>[
      if (_currentPosition != null)
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      ..._markers.map((m) => m.position),
    ];

    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  void _initMarkers() {
    final orders = _singleOrderFeed();
    _markers = orders
        .where((o) => o.deliveryLatitude != null && o.deliveryLongitude != null)
        .map((order) {
          return Marker(
            markerId: MarkerId(order.id),
            position: LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
            infoWindow: InfoWindow(
              title: 'طلب #${order.orderNumber ?? order.id.substring(0, 4)}',
              snippet: order.status.displayName,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              order.status == OrderStatus.delivered
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueRed,
            ),
            onTap: () {
              // لا نعرض قائمة اختيارات: الطلب هنا واحد فقط
            },
          );
        })
        .toSet();

    if (orders.isNotEmpty) {
      final firstOrder = orders.first;
      if (_selectedOrder?.id != firstOrder.id) {
        _selectOrder(firstOrder);
      }
    }

    if (mounted) setState(() {});
  }

  void _selectOrder(OrderModel order) {
    _acceptanceTimer?.cancel();
    setState(() {
      _selectedOrder = order;
      _remainingSeconds = _acceptTimeoutSeconds;

      if (_currentPosition != null) {
        // Distance to Store
        if (order.storeLatitude != null && order.storeLongitude != null) {
          final double storeDistanceM = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            order.storeLatitude!,
            order.storeLongitude!,
          );
          _storeDistanceInfo =
              '${(storeDistanceM / 1000).toStringAsFixed(1)} كم';

          // Store to Client
          if (order.deliveryLatitude != null &&
              order.deliveryLongitude != null) {
            final double s2cM = Geolocator.distanceBetween(
              order.storeLatitude!,
              order.storeLongitude!,
              order.deliveryLatitude!,
              order.deliveryLongitude!,
            );
            _storeToClientDistanceInfo =
                '${(s2cM / 1000).toStringAsFixed(1)} كم';
          }
        }

        // Move camera to the order location
        if (_mapController != null && order.deliveryLatitude != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
              14,
            ),
          );
        }
      }
    });

    if (order.status == OrderStatus.pending) {
      _startTimer();
    }
  }

  void _startTimer() {
    _acceptanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() => _selectedOrder = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('انتهت مهلة قبول الطلب'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _acceptanceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _acceptSelectedOrder() async {
    if (_selectedOrder == null || _isAccepting) return;

    setState(() => _isAccepting = true);

    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final captain = authProvider.currentUserProfile;

    if (captain != null) {
      final success = await orderProvider.acceptOrder(
        _selectedOrder!.id,
        captain.id,
      );
      if (success) {
        _acceptanceTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم قبول الطلب بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OrderDeliveryScreen(orderId: _selectedOrder!.id),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'فشل قبول الطلب. قد يكون تم قبوله من قبل كابتن آخر.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) setState(() => _isAccepting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خريطة التوصيل')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(30.0444, 31.2357), // Default Cairo
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // ✅ ضبط الكاميرا بعد إنشاء الخريطة
              if (_currentPosition != null && _markers.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  _fitAllMarkers();
                });
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            padding: const EdgeInsets.only(
              bottom: 250,
            ), // Space for premium card
          ),

          if (_selectedOrder != null) _buildSelectedOrderPremiumCard(),

          if (_isLoadingLocation)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedOrderPremiumCard() {
    final theme = Theme.of(context);
    final isPending = _selectedOrder!.status == OrderStatus.pending;

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: LinearProgressIndicator(
                  value: _remainingSeconds / _acceptTimeoutSeconds,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _remainingSeconds < 15
                        ? Colors.red
                        : theme.colorScheme.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Icon(
                          Icons.store_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedOrder!.storeName ?? 'متجر غير معروف',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'رقم الطلب: #${_selectedOrder!.orderNumber ?? _selectedOrder!.id.substring(0, 4)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPending)
                        Text(
                          '$_remainingSecondsث',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds < 15
                                ? Colors.red
                                : Colors.grey,
                            fontSize: 18,
                          ),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(
                        Icons.near_me_rounded,
                        'المتجر',
                        _storeDistanceInfo,
                      ),
                      _buildMetric(
                        Icons.inventory_2_rounded,
                        'الطلب',
                        '${_selectedOrder!.totalAmount.toStringAsFixed(0)} ج.م',
                      ),
                      _buildMetric(
                        Icons.straighten_rounded,
                        'للعميل',
                        _storeToClientDistanceInfo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الأجر المتوقع',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${CaptainOrderHelpers.calculateCommission(_selectedOrder!.totalAmount).toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPending)
                        Tooltip(
                          message: 'اضغط لقبول هذا الطلب',
                          child: ElevatedButton(
                            onPressed: _isAccepting
                                ? null
                                : _acceptSelectedOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: _isAccepting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'قبول الطلب',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        )
                      else
                        Tooltip(
                          message: 'عرض تفاصيل الطلب الكاملة',
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDeliveryScreen(
                                    orderId: _selectedOrder!.id,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                            ),
                            label: const Text('عرض التفاصيل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[400]),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value.isEmpty ? '--' : value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
