import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/captain_model.dart';

/// خدمة تقارير الكباتن - تجلب بيانات التحليلات والإحصائيات
class CaptainReportsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// جلب جميع الكباتن مع بيانات البروفايل
  static Future<List<CaptainModel>> getAllCaptains() async {
    try {
      final response = await _supabase
          .from('captains')
          .select('*, profiles(*)')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => CaptainModel.fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في جلب الكباتن', e);
      return [];
    }
  }

  /// جلب إحصائيات عامة (ملخص)
  static Future<Map<String, dynamic>> getOverviewStats() async {
    try {
      // إجمالي الكباتن
      final totalRes = await _supabase
          .from('captains')
          .select('id')
          .count(CountOption.exact);

      // النشطين
      final activeRes = await _supabase
          .from('captains')
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      // المتاحين أونلاين الآن
      final onlineRes = await _supabase
          .from('captains')
          .select('id')
          .eq('is_online', true)
          .eq('is_available', true)
          .count(CountOption.exact);

      // المشغولين
      final busyRes = await _supabase
          .from('captains')
          .select('id')
          .eq('status', 'busy')
          .count(CountOption.exact);

      // المعتمدين
      final verifiedRes = await _supabase
          .from('captains')
          .select('id')
          .eq('verification_status', 'approved')
          .count(CountOption.exact);

      // قيد المراجعة
      final pendingRes = await _supabase
          .from('captains')
          .select('id')
          .eq('verification_status', 'pending')
          .count(CountOption.exact);

      // إجمالي الطلبات المسلمة (من جميع الكباتن)
      final deliveredOrdersRes = await _supabase
          .from('orders')
          .select('id')
          .eq('status', 'delivered')
          .not('captain_id', 'is', null)
          .count(CountOption.exact);

      // إجمالي الطلبات الملغاة
      final cancelledOrdersRes = await _supabase
          .from('orders')
          .select('id')
          .eq('status', 'cancelled')
          .not('captain_id', 'is', null)
          .count(CountOption.exact);

      // إجمالي رسوم التوصيل المكتسبة
      final earningsData = await _supabase
          .from('orders')
          .select('delivery_fee')
          .eq('status', 'delivered')
          .not('captain_id', 'is', null);

      double totalEarnings = 0;
      for (final order in earningsData) {
        totalEarnings += ((order['delivery_fee'] as num?) ?? 0).toDouble();
      }

      // متوسط التقييم العام
      final ratingsData = await _supabase
          .from('captains')
          .select('rating, rating_count')
          .gt('rating_count', 0);

      double avgRating = 0;
      int totalRatings = 0;
      if (ratingsData.isNotEmpty) {
        double weightedSum = 0;
        for (final r in ratingsData) {
          final rating = (r['rating'] as num).toDouble();
          final count = r['rating_count'] as int;
          weightedSum += rating * count;
          totalRatings += count;
        }
        if (totalRatings > 0) avgRating = weightedSum / totalRatings;
      }

      return {
        'totalCaptains': totalRes.count,
        'activeCaptains': activeRes.count,
        'onlineCaptains': onlineRes.count,
        'busyCaptains': busyRes.count,
        'verifiedCaptains': verifiedRes.count,
        'pendingCaptains': pendingRes.count,
        'totalDelivered': deliveredOrdersRes.count,
        'totalCancelled': cancelledOrdersRes.count,
        'totalEarnings': totalEarnings,
        'avgRating': avgRating,
        'totalRatings': totalRatings,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات الملخص', e);
      return {};
    }
  }

  /// جلب أداء كل كابتن (للجدول)
  static Future<List<Map<String, dynamic>>> getCaptainsPerformance() async {
    try {
      // جلب جميع الكباتن مع بروفايلهم
      final captains = await _supabase
          .from('captains')
          .select('*, profiles(full_name, email, phone, avatar_url, is_active)')
          .order('total_deliveries', ascending: false);

      List<Map<String, dynamic>> results = [];

      for (final captain in captains) {
        final captainId = captain['id'] as String;
        final profile = captain['profiles'] as Map<String, dynamic>?;

        // جلب عدد الطلبات المكتملة والملغاة
        final deliveredRes = await _supabase
            .from('orders')
            .select('id, delivery_fee, picked_up_at, delivered_at')
            .eq('captain_id', captainId)
            .eq('status', 'delivered');

        final cancelledRes = await _supabase
            .from('orders')
            .select('id')
            .eq('captain_id', captainId)
            .eq('status', 'cancelled')
            .count(CountOption.exact);

        // حساب إجمالي الأرباح
        double earnings = 0;
        double totalDeliveryMinutes = 0;
        int validTimeOrders = 0;

        for (final order in deliveredRes) {
          earnings += ((order['delivery_fee'] as num?) ?? 0).toDouble();

          final pickedUp = DateTime.tryParse(order['picked_up_at'] ?? '');
          final delivered = DateTime.tryParse(order['delivered_at'] ?? '');
          if (pickedUp != null && delivered != null) {
            totalDeliveryMinutes += delivered
                .difference(pickedUp)
                .inMinutes
                .toDouble();
            validTimeOrders++;
          }
        }

        final avgDeliveryTime = validTimeOrders > 0
            ? totalDeliveryMinutes / validTimeOrders
            : 0.0;

        final totalOrders = deliveredRes.length + cancelledRes.count;
        final completionRate = totalOrders > 0
            ? (deliveredRes.length / totalOrders) * 100
            : 0.0;

        results.add({
          'id': captainId,
          'name': profile?['full_name'] ?? 'بدون اسم',
          'email': profile?['email'] ?? '',
          'phone': profile?['phone'] ?? '',
          'avatarUrl': profile?['avatar_url'],
          'isActive': captain['is_active'] ?? false,
          'isOnline': captain['is_online'] ?? false,
          'status': captain['status'] ?? 'offline',
          'vehicleType': captain['vehicle_type'] ?? 'motorcycle',
          'verificationStatus': captain['verification_status'] ?? 'pending',
          'rating': (captain['rating'] as num?)?.toDouble() ?? 0.0,
          'ratingCount': captain['rating_count'] ?? 0,
          'totalDeliveries': deliveredRes.length,
          'cancelledOrders': cancelledRes.count,
          'totalEarnings': earnings,
          'avgDeliveryTime': avgDeliveryTime,
          'completionRate': completionRate,
          'lastAvailableAt': captain['last_available_at'],
          'createdAt': captain['created_at'],
        });
      }

      return results;
    } catch (e) {
      AppLogger.error('خطأ في جلب أداء الكباتن', e);
      return [];
    }
  }

  /// جلب الأرباح التفصيلية لكابتن محدد
  static Future<List<Map<String, dynamic>>> getCaptainEarningsDetails(
    String captainId,
  ) async {
    try {
      final response = await _supabase
          .from('captain_earnings')
          .select('*, orders(order_number, total_amount, status, created_at)')
          .eq('captain_id', captainId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب أرباح الكابتن', e);
      return [];
    }
  }

  /// جلب تاريخ طلبات كابتن محدد
  static Future<List<Map<String, dynamic>>> getCaptainOrders(
    String captainId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            'id, order_number, status, total_amount, delivery_fee, created_at, delivered_at, picked_up_at, delivery_address',
          )
          .eq('captain_id', captainId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب طلبات الكابتن', e);
      return [];
    }
  }

  /// جلب تعليقات وتقييمات العملاء لكابتن
  static Future<List<Map<String, dynamic>>> getCaptainFeedback(
    String captainId,
  ) async {
    try {
      final response = await _supabase
          .from('deliveries')
          .select(
            'id, customer_rating, customer_feedback, delivered_at, orders(order_number)',
          )
          .eq('captain_id', captainId)
          .not('customer_rating', 'is', null)
          .order('delivered_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب تقييمات الكابتن', e);
      return [];
    }
  }

  /// جلب الكباتن الأكثر نشاطاً (Top Performers)
  static Future<List<Map<String, dynamic>>> getTopPerformers({
    int limit = 10,
    String sortBy = 'deliveries', // deliveries, rating, earnings
  }) async {
    try {
      String orderColumn;
      switch (sortBy) {
        case 'rating':
          orderColumn = 'rating';
          break;
        case 'earnings':
          orderColumn = 'total_earnings';
          break;
        default:
          orderColumn = 'total_deliveries';
      }

      final response = await _supabase
          .from('captains')
          .select(
            'id, rating, rating_count, total_deliveries, total_earnings, is_online, status, vehicle_type, profiles(full_name, avatar_url)',
          )
          .eq('is_active', true)
          .order(orderColumn, ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('خطأ في جلب أفضل الكباتن', e);
      return [];
    }
  }

  /// جلب نشاط الكباتن اليوم
  static Future<Map<String, dynamic>> getTodayActivity() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // طلبات اليوم المسلمة
      final todayDelivered = await _supabase
          .from('orders')
          .select('id, delivery_fee, captain_id')
          .eq('status', 'delivered')
          .not('captain_id', 'is', null)
          .gte('delivered_at', startOfDay.toIso8601String())
          .count(CountOption.exact);

      // أرباح اليوم
      final todayEarningsData = await _supabase
          .from('orders')
          .select('delivery_fee')
          .eq('status', 'delivered')
          .not('captain_id', 'is', null)
          .gte('delivered_at', startOfDay.toIso8601String());

      double todayEarnings = 0;
      for (final order in todayEarningsData) {
        todayEarnings += ((order['delivery_fee'] as num?) ?? 0).toDouble();
      }

      // طلبات اليوم الملغاة
      final todayCancelled = await _supabase
          .from('orders')
          .select('id')
          .eq('status', 'cancelled')
          .not('captain_id', 'is', null)
          .gte('cancelled_at', startOfDay.toIso8601String())
          .count(CountOption.exact);

      // الكباتن المتصلين الآن
      final onlineNow = await _supabase
          .from('captains')
          .select('id')
          .eq('is_online', true)
          .count(CountOption.exact);

      return {
        'todayDelivered': todayDelivered.count,
        'todayEarnings': todayEarnings,
        'todayCancelled': todayCancelled.count,
        'onlineNow': onlineNow.count,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب نشاط اليوم', e);
      return {};
    }
  }
}
