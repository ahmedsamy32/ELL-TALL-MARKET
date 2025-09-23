import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ===== تحليلات المتجر =====
  Future<Map<String, dynamic>> getStoreAnalytics(String storeId, {DateTime? startDate, DateTime? endDate}) async {
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
        'total_orders': analytics.fold(0, (sum, item) => sum + (item['total_orders'] as int)),
        'completed_orders': analytics.fold(0, (sum, item) => sum + (item['completed_orders'] as int)),
        'cancelled_orders': analytics.fold(0, (sum, item) => sum + (item['cancelled_orders'] as int)),
        'total_revenue': analytics.fold(0.0, (sum, item) => sum + (item['total_revenue'] as num).toDouble()),
        'daily_stats': analytics,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching store analytics: $e');
      rethrow;
    }
  }

  // ===== تحليلات المستخدم =====
  Future<Map<String, dynamic>> getUserAnalytics(String userId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final query = _supabase
          .from('user_analytics')
          .select()
          .eq('user_id', userId);

      if (startDate != null) {
        query.gte('date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query.lte('date', endDate.toIso8601String());
      }

      final response = await query;
      final analytics = response as List;

      return {
        'total_orders': analytics.fold(0, (sum, item) => sum + (item['total_orders'] as int)),
        'total_spent': analytics.fold(0.0, (sum, item) => sum + (item['total_spent'] as num).toDouble()),
        'daily_stats': analytics,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching user analytics: $e');
      rethrow;
    }
  }

  // ===== تحليلات الكابتن =====
  Future<Map<String, dynamic>> getCaptainAnalytics(String captainId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final query = _supabase
          .from('captain_analytics')
          .select()
          .eq('captain_id', captainId);

      if (startDate != null) {
        query.gte('date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query.lte('date', endDate.toIso8601String());
      }

      final response = await query;
      final analytics = response as List;

      return {
        'total_deliveries': analytics.fold(0, (sum, item) => sum + (item['total_deliveries'] as int)),
        'completed_deliveries': analytics.fold(0, (sum, item) => sum + (item['completed_deliveries'] as int)),
        'cancelled_deliveries': analytics.fold(0, (sum, item) => sum + (item['cancelled_deliveries'] as int)),
        'total_earnings': analytics.fold(0.0, (sum, item) => sum + (item['total_earnings'] as num).toDouble()),
        'daily_stats': analytics,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching captain analytics: $e');
      rethrow;
    }
  }

  // ===== تحديث تحليلات المتجر =====
  Future<void> updateStoreAnalytics(String storeId, {
    int? totalOrders,
    int? completedOrders,
    int? cancelledOrders,
    double? revenue,
  }) async {
    try {
      final date = DateTime.now().toUtc();
      final dateStr = date.toIso8601String().split('T')[0];

      final existing = await _supabase
          .from('store_analytics')
          .select()
          .eq('store_id', storeId)
          .eq('date', dateStr)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('store_analytics')
            .update({
              if (totalOrders != null) 'total_orders': existing['total_orders'] + totalOrders,
              if (completedOrders != null) 'completed_orders': existing['completed_orders'] + completedOrders,
              if (cancelledOrders != null) 'cancelled_orders': existing['cancelled_orders'] + cancelledOrders,
              if (revenue != null) 'total_revenue': existing['total_revenue'] + revenue,
            })
            .eq('store_id', storeId)
            .eq('date', dateStr);
      } else {
        await _supabase
            .from('store_analytics')
            .insert({
              'store_id': storeId,
              'date': dateStr,
              'total_orders': totalOrders ?? 0,
              'completed_orders': completedOrders ?? 0,
              'cancelled_orders': cancelledOrders ?? 0,
              'total_revenue': revenue ?? 0,
            });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating store analytics: $e');
      rethrow;
    }
  }

  // ===== تحديث تحليلات المستخدم =====
  Future<void> updateUserAnalytics(String userId, {
    int? ordersCount,
    double? spent,
  }) async {
    try {
      final date = DateTime.now().toUtc();
      final dateStr = date.toIso8601String().split('T')[0];

      final existing = await _supabase
          .from('user_analytics')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('user_analytics')
            .update({
              if (ordersCount != null) 'total_orders': existing['total_orders'] + ordersCount,
              if (spent != null) 'total_spent': existing['total_spent'] + spent,
            })
            .eq('user_id', userId)
            .eq('date', dateStr);
      } else {
        await _supabase
            .from('user_analytics')
            .insert({
              'user_id': userId,
              'date': dateStr,
              'total_orders': ordersCount ?? 0,
              'total_spent': spent ?? 0,
            });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating user analytics: $e');
      rethrow;
    }
  }

  // ===== تحديث تحليلات الكابتن =====
  Future<void> updateCaptainAnalytics(String captainId, {
    int? totalDeliveries,
    int? completedDeliveries,
    int? cancelledDeliveries,
    double? earnings,
  }) async {
    try {
      final date = DateTime.now().toUtc();
      final dateStr = date.toIso8601String().split('T')[0];

      final existing = await _supabase
          .from('captain_analytics')
          .select()
          .eq('captain_id', captainId)
          .eq('date', dateStr)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('captain_analytics')
            .update({
              if (totalDeliveries != null) 'total_deliveries': existing['total_deliveries'] + totalDeliveries,
              if (completedDeliveries != null) 'completed_deliveries': existing['completed_deliveries'] + completedDeliveries,
              if (cancelledDeliveries != null) 'cancelled_deliveries': existing['cancelled_deliveries'] + cancelledDeliveries,
              if (earnings != null) 'total_earnings': existing['total_earnings'] + earnings,
            })
            .eq('captain_id', captainId)
            .eq('date', dateStr);
      } else {
        await _supabase
            .from('captain_analytics')
            .insert({
              'captain_id': captainId,
              'date': dateStr,
              'total_deliveries': totalDeliveries ?? 0,
              'completed_deliveries': completedDeliveries ?? 0,
              'cancelled_deliveries': cancelledDeliveries ?? 0,
              'total_earnings': earnings ?? 0,
            });
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating captain analytics: $e');
      rethrow;
    }
  }
}
