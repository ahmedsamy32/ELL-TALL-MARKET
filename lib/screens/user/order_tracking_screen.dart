import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/captain_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({required this.orderId, super.key});

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeOrder();
    _startLocationUpdates();
  }

  void _initializeOrder() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.getOrderById(widget.orderId);
      orderProvider.startOrderTracking(widget.orderId);
    });
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (_) {
      if (mounted) {
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        orderProvider.updateCaptainLocation(widget.orderId);
      }
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final order = orderProvider.selectedOrder;
        final captain = orderProvider.selectedOrderCaptain;

        return Scaffold(
          appBar: AppBar(
            title: Text('تتبع الطلب #${widget.orderId}'),
            centerTitle: true,
          ),
          body: order == null
              ? Center(child: CircularProgressIndicator())
              : _buildTrackingInfo(order, captain),
        );
      },
    );
  }

  Widget _buildTrackingInfo(OrderModel order, CaptainModel? captain) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // خريطة التتبع
          if (captain?.currentLocation != null)
            SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    captain!.currentLocation!.latitude,
                    captain.currentLocation!.longitude,
                  ),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId('captain'),
                    position: LatLng(
                      captain.currentLocation!.latitude,
                      captain.currentLocation!.longitude,
                    ),
                    infoWindow: InfoWindow(title: 'موقع الكابتن'),
                  ),
                  if (order.shippingAddress.coordinates != null)
                    Marker(
                      markerId: MarkerId('destination'),
                      position: LatLng(
                        order.shippingAddress.coordinates!['lat']!,
                        order.shippingAddress.coordinates!['lng']!,
                      ),
                      infoWindow: InfoWindow(title: 'موقع التوصيل'),
                    ),
                },
                onMapCreated: (controller) => _mapController = controller,
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 50, color: Colors.grey),
                    Text('لم يتم تعيين كابتن بعد'),
                  ],
                ),
              ),
            ),
          SizedBox(height: 24),

          // حالة الطلب
          Text(
            'حالة الطلب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildOrderStatusTimeline(order.status),

          // تفاصيل التوصيل
          if (order.status != OrderStatus.cancelled &&
              order.status != OrderStatus.refunded) ...[
            SizedBox(height: 24),
            Text(
              'تفاصيل التوصيل',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildDeliveryDetails(order),
          ],

          // معلومات الكابتن
          if (captain != null) ...[
            SizedBox(height: 24),
            Text(
              'معلومات الكابتن',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildCaptainInfo(captain),
          ],

          // معلومات إضافية للطلبات الملغاة
          if (order.status == OrderStatus.cancelled &&
              order.cancellationReason != null) ...[
            SizedBox(height: 24),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سبب الإلغاء:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(order.cancellationReason!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryDetails(OrderModel order) {
    final estimatedTime = order.status == OrderStatus.onTheWay
        ? '30-45 دقيقة'
        : 'غير محدد';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.status == OrderStatus.onTheWay)
              Text('الوقت المتوقع للوصول: $estimatedTime'),
            SizedBox(height: 8),
            Text('العنوان: ${order.shippingAddress.formattedAddress}'),
            SizedBox(height: 8),
            Text('رقم الهاتف: ${order.shippingAddress.phone}'),
            if (order.notes?.isNotEmpty == true) ...[
              SizedBox(height: 8),
              Text('ملاحظات: ${order.notes}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainInfo(CaptainModel captain) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(captain.imageUrl),
              onBackgroundImageError: (_, __) => {},
              child: Icon(Icons.person),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    captain.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('كابتن التوصيل'),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      Text('${captain.rating} (${captain.totalRatings} تقييم)'),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.phone),
              onPressed: () => _callCaptain(captain.phone),
              tooltip: 'اتصال بالكابتن',
            ),
            IconButton(
              icon: Icon(Icons.message),
              onPressed: () => _messageCaptain(captain.phone),
              tooltip: 'إرسال رسالة',
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Future<void> _callCaptain(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('لا يمكن الاتصال بالرقم $phone')));
    }
  }

  Future<void> _messageCaptain(String phone) async {
    final url = Uri.parse('sms:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يمكن إرسال رسالة للرقم $phone')),
      );
    }
  }

  Widget _buildOrderStatusTimeline(OrderStatus status) {
    final allStatuses = OrderStatus.values;
    final currentStatusIndex = allStatuses.indexOf(status);

    return Column(
      children: allStatuses.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isCompleted = index <= currentStatusIndex;
        final isCurrent = index == currentStatusIndex;

        return ListTile(
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300],
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          title: Text(
            _getStatusName(status),
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCompleted ? Colors.black : Colors.grey,
            ),
          ),
          subtitle: isCurrent ? Text('جاري التوصيل') : null,
        );
      }).toList(),
    );
  }

  String _getStatusName(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.processing:
        return 'جاري التجهيز';
      case OrderStatus.readyForDelivery:
        return 'جاهز للتوصيل';
      case OrderStatus.assignedToCaptain:
        return 'تم تعيين كابتن';
      case OrderStatus.pickedUp:
        return 'تم الاستلام';
      case OrderStatus.onTheWay:
        return 'في الطريق';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.completed:
        return 'اكتمل الطلب';
      case OrderStatus.cancelled:
        return 'ملغي';
      case OrderStatus.refunded:
        return 'تم الاسترداد';
    }
  }
}
