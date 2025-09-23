import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/models/captain_model.dart';

class OrderService {
  final _supabase = Supabase.instance.client;

  // الحصول على تفاصيل طلب محدد
  Future<OrderModel> getOrderById(String orderId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('id', orderId)
        .single();

    return OrderModel.fromMap(response);
  }

  // الحصول على معلومات الكابتن
  Future<CaptainModel> getCaptainById(String captainId) async {
    final response = await _supabase
        .from('captains')
        .select()
        .eq('id', captainId)
        .single();

    return CaptainModel.fromMap(response);
  }

  // تحديث موقع الكابتن
  Future<void> updateCaptainLocation(String captainId, double latitude, double longitude) async {
    await _supabase
        .from('captain_locations')
        .upsert({
          'captain_id': captainId,
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toIso8601String(),
        });
  }

  // الاستماع لتحديثات الطلب
  RealtimeChannel getOrderStream(String orderId) {
    return _supabase
        .channel('order_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: orderId,
          ),
          callback: (payload) {
            // يمكن معالجة التحديثات هنا
          },
        )
        .subscribe();
  }

  // الاستماع لتحديثات موقع الكابتن
  RealtimeChannel getCaptainLocationStream(String captainId) {
    return _supabase
        .channel('captain_location_$captainId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'captain_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'captain_id',
            value: captainId,
          ),
          callback: (payload) {
            // يمكن معالجة التحديثات هنا
          },
        )
        .subscribe();
  }

  // الحصول على طلبات المستخدم
  Future<List<OrderModel>> getUserOrders(String userId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((doc) => OrderModel.fromMap(doc)).toList();
  }

  // الحصول على جميع الطلبات
  Future<List<OrderModel>> getAllOrders() async {
    final response = await _supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((doc) => OrderModel.fromMap(doc)).toList();
  }

  // الحصول على طلبات التاجر
  Future<List<OrderModel>> getMerchantOrders(String merchantId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);

    return (response as List).map((doc) => OrderModel.fromMap(doc)).toList();
  }

  // الحصول على طلبات الكابتن
  Future<List<OrderModel>> getCaptainOrders(String captainId) async {
    final response = await _supabase
        .from('orders')
        .select()
        .eq('captain_id', captainId)
        .order('created_at', ascending: false);

    return (response as List).map((doc) => OrderModel.fromMap(doc)).toList();
  }
}
