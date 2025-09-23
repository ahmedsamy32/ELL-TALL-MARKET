import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/config/supabase_config.dart';
import 'package:flutter/foundation.dart';

enum PaymentMethod {
  cashOnDelivery,
}

class PaymentService {
  final _supabase = SupabaseConfig.client;

  // تحصيل المبلغ من قبل الكابتن
  Future<Map<String, dynamic>> collectPayment({
    required String orderId,
    required String captainId,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // تحديث حالة الدفع في الطلب
      await _supabase.from('orders').update({
        'payment_status': PaymentStatus.collected.toString().split('.').last,
        'payment_collected_at': now,
        'payment_collected_by': captainId,
        'payment_notes': notes,
        'updated_at': now,
      }).eq('id', orderId);

      // إضافة سجل في جدول المعاملات المالية
      await _supabase.from('financial_transactions').insert({
        'order_id': orderId,
        'type': 'collection',
        'amount': 0.0, // سيتم تحديثه من قيمة الطلب
        'status': 'completed',
        'collected_by': captainId,
        'collected_at': now,
        'notes': notes,
      });

      return {
        'success': true,
        'message': 'تم تحصيل المبلغ بنجاح',
        'collected_at': now,
      };
    } catch (e) {
      debugPrint('خطأ في تحصيل المبلغ: $e');
      throw Exception('فشل في تحصيل المبلغ');
    }
  }

  // تحويل المبلغ للمتجر
  Future<Map<String, dynamic>> transferToStore({
    required String orderId,
    required String storeId,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // تحديث حالة الدفع في الطلب
      await _supabase.from('orders').update({
        'payment_status': PaymentStatus.transferredToStore.toString().split('.').last,
        'payment_transferred_at': now,
        'status': OrderStatus.completed.toString().split('.').last,
        'updated_at': now,
      }).eq('id', orderId);

      // إضافة سجل في جدول المعاملات المالية
      await _supabase.from('financial_transactions').insert({
        'order_id': orderId,
        'store_id': storeId,
        'type': 'transfer_to_store',
        'amount': 0.0, // سيتم تحديثه من قيمة الطلب
        'status': 'completed',
        'transferred_at': now,
        'notes': notes,
      });

      return {
        'success': true,
        'message': 'تم تحويل المبلغ للمتجر بنجاح',
        'transferred_at': now,
      };
    } catch (e) {
      debugPrint('خطأ في تحويل المبلغ للمتجر: $e');
      throw Exception('فشل في تحويل المبلغ للمتجر');
    }
  }

  // استرجاع المبلغ للعميل
  Future<Map<String, dynamic>> refundPayment({
    required String orderId,
    required String userId,
    String? reason,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // تحديث حالة الدفع في الطلب
      await _supabase.from('orders').update({
        'payment_status': PaymentStatus.refunded.toString().split('.').last,
        'status': OrderStatus.refunded.toString().split('.').last,
        'cancellation_reason': reason,
        'updated_at': now,
      }).eq('id', orderId);

      // إضافة سجل في جدول المعاملات المالية
      await _supabase.from('financial_transactions').insert({
        'order_id': orderId,
        'user_id': userId,
        'type': 'refund',
        'amount': 0.0, // سيتم تحديثه من قيمة الطلب
        'status': 'completed',
        'refunded_at': now,
        'notes': reason,
      });

      return {
        'success': true,
        'message': 'تم استرجاع المبلغ بنجاح',
        'refunded_at': now,
      };
    } catch (e) {
      debugPrint('خطأ في استرجاع المبلغ: $e');
      throw Exception('فشل في استرجاع المبلغ');
    }
  }

  // الحصول على سجل المعاملات المالية للطلب
  Future<List<Map<String, dynamic>>> getOrderTransactions(String orderId) async {
    try {
      final response = await _supabase
          .from('financial_transactions')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('خطأ في جلب سجل المعاملات: $e');
      return [];
    }
  }

  // التحقق من حالة الدفع للطلب
  Future<PaymentStatus> getPaymentStatus(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('payment_status')
          .eq('id', orderId)
          .single();

      return _parsePaymentStatus(response['payment_status']);
    } catch (e) {
      debugPrint('خطأ في التحقق من حالة الدفع: $e');
      throw Exception('فشل في التحقق من حالة الدفع');
    }
  }

  PaymentStatus _parsePaymentStatus(String? status) {
    if (status == null) return PaymentStatus.pending;
    return PaymentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => PaymentStatus.pending,
    );
  }
}

