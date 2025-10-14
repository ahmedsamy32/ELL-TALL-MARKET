import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderTrackingProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  final Map<String, Map<String, dynamic>> _orderTracking = {};
  final bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, dynamic>? getOrderTracking(String orderId) =>
      _orderTracking[orderId];
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Start tracking an order in real-time using official Supabase subscriptions
  Stream<Map<String, dynamic>?> trackOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  /// Update order status (for store owners/captains) using official Supabase methods
  Future<void> updateOrderStatus(
    String orderId,
    String newStatus, {
    String? note,
    Map<String, double>? location,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (note != null) {
        updateData['notes'] = note;
      }

      if (location != null) {
        updateData['location'] = location;
      }

      await _supabase.from('orders').update(updateData).eq('id', orderId);
    } catch (e) {
      _error = 'خطأ في تحديث حالة الطلب: $e';
      notifyListeners();
    }
  }

  /// Get delivery progress percentage
  int getDeliveryProgress(String status) {
    switch (status) {
      case 'pending':
        return 10;
      case 'confirmed':
        return 25;
      case 'preparing':
        return 50;
      case 'ready':
        return 65;
      case 'picked_up':
        return 80;
      case 'delivering':
        return 90;
      case 'delivered':
        return 100;
      default:
        return 0;
    }
  }

  /// Get status display text
  String getStatusDisplayText(String status) {
    switch (status) {
      case 'pending':
        return 'في انتظار التأكيد';
      case 'confirmed':
        return 'تم تأكيد الطلب';
      case 'preparing':
        return 'جاري التحضير';
      case 'ready':
        return 'جاهز للاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'delivering':
        return 'في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}

class CaptainTrackingProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  /// Update captain location (for captains) using official Supabase methods
  Future<void> updateLocation({
    required String captainId,
    required double latitude,
    required double longitude,
    required bool isAvailable,
    String? currentOrderId,
  }) async {
    try {
      await _supabase
          .from('captains')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'is_available': isAvailable,
            'current_order_id': currentOrderId,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', captainId);
    } catch (e) {
      print('خطأ في تحديث موقع الكابتن: $e');
    }
  }

  /// Stream available captains using official Supabase real-time subscriptions
  Stream<List<Map<String, dynamic>>> getAvailableCaptains() {
    return _supabase
        .from('captains')
        .stream(primaryKey: ['id'])
        .eq('is_available', true)
        .order('last_seen', ascending: false);
  }
}

class LiveAnalyticsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _liveAnalytics;
  bool _isLoading = false;

  // Getters
  Map<String, dynamic>? get liveAnalytics => _liveAnalytics;
  bool get isLoading => _isLoading;

  /// Stream live analytics (for admins) using official Supabase real-time subscriptions
  Stream<List<Map<String, dynamic>>> getLiveAnalytics() {
    return _supabase
        .from('analytics')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  /// Update analytics manually using official Supabase methods
  Future<void> updateAnalytics() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Calculate current analytics
      final analytics = await _calculateCurrentAnalytics();

      // Insert or update analytics record
      await _supabase.from('analytics').upsert({
        'id': 'current',
        'data': analytics,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _liveAnalytics = analytics;
    } catch (e) {
      print('خطأ في تحديث التحليلات: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Calculate current analytics from database
  Future<Map<String, dynamic>> _calculateCurrentAnalytics() async {
    try {
      // Get total orders count
      final ordersResponse = await _supabase
          .from('orders')
          .select('id')
          .count();
      final totalOrders = ordersResponse.count;

      // Get today's orders
      final today = DateTime.now();
      final todayStart = DateTime(
        today.year,
        today.month,
        today.day,
      ).toIso8601String();
      final todayOrdersResponse = await _supabase
          .from('orders')
          .select('id, total_amount')
          .gte('created_at', todayStart)
          .count();

      // Get revenue
      final revenueResponse = await _supabase
          .from('orders')
          .select('total_amount')
          .eq('status', 'delivered');

      final totalRevenue = revenueResponse.fold(
        0.0,
        (sum, order) => sum + (order['total_amount'] as num).toDouble(),
      );

      return {
        'total_orders': totalOrders,
        'today_orders': todayOrdersResponse.count,
        'total_revenue': totalRevenue,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('خطأ في حساب التحليلات: $e');
      return {};
    }
  }

  // ===== تحليلات المتجر (مدمجة من analytics_provider) =====
  Future<Map<String, dynamic>> getStoreAnalytics(
    String storeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = _supabase
          .from('store_analytics')
          .select()
          .eq('store_id', storeId);

      if (startDate != null) {
        query.gte('date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query.lte('date', endDate.toIso8601String());
      }

      final response = await query;
      final analytics = response as List;

      return {
        'total_orders': analytics.fold(
          0,
          (sum, item) => sum + (item['total_orders'] as int),
        ),
        'completed_orders': analytics.fold(
          0,
          (sum, item) => sum + (item['completed_orders'] as int),
        ),
        'cancelled_orders': analytics.fold(
          0,
          (sum, item) => sum + (item['cancelled_orders'] as int),
        ),
        'total_revenue': analytics.fold(
          0.0,
          (sum, item) => sum + (item['total_revenue'] as num).toDouble(),
        ),
        'daily_stats': analytics,
      };
    } catch (e) {
      print('خطأ في جلب تحليلات المتجر: $e');
      return {};
    }
  }

  // ===== تحليلات عامة =====
  Future<Map<String, dynamic>> getGeneralAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final ordersQuery = _supabase.from('orders').select();

      if (startDate != null) {
        ordersQuery.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        ordersQuery.lte('created_at', endDate.toIso8601String());
      }

      final orders = await ordersQuery;
      final totalOrders = orders.length;
      final totalRevenue = orders.fold(
        0.0,
        (sum, order) => sum + (order['total_amount'] as num).toDouble(),
      );

      return {
        'total_orders': totalOrders,
        'total_revenue': totalRevenue,
        'average_order_value': totalOrders > 0 ? totalRevenue / totalOrders : 0,
      };
    } catch (e) {
      print('خطأ في جلب التحليلات العامة: $e');
      return {};
    }
  }
}
