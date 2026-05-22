import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import 'notification_service.dart';

class StoreWalletService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const double commissionRate = 0.05;

  static Future<Map<String, dynamic>?> getOrCreateWallet(String storeId) async {
    try {
      final response = await _supabase.rpc(
        'get_or_create_store_wallet',
        params: {'p_store_id': storeId},
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error loading store wallet', e);
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getTransactions(
    String storeId,
  ) async {
    try {
      final response = await _supabase
          .from('store_wallet_transactions')
          .select(
            'id, store_id, order_id, type, amount, balance_before, balance_after, notes, created_at',
          )
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      AppLogger.error('❌ Error loading store wallet transactions', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTopups(String storeId) async {
    try {
      final response = await _supabase
          .from('store_wallet_topups')
          .select(
            'id, store_id, amount, receipt_path, instapay_reference, status, notes, created_at, reviewed_at',
          )
          .eq('store_id', storeId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      AppLogger.error('❌ Error loading store wallet topups', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> adjustWalletBalance({
    required String storeId,
    required double amount,
    required bool isCredit,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_adjust_store_wallet_balance',
        params: {
          'p_store_id': storeId,
          'p_amount': amount,
          'p_is_credit': isCredit,
          'p_notes': notes,
        },
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          try {
            final storeName = await _getStoreName(storeId);
            await NotificationServiceEnhanced.instance
                .notifyMerchantOfWalletAdjustment(
                  storeId: storeId,
                  storeName: storeName,
                  amount: amount,
                  isCredit: isCredit,
                  notes: notes,
                );
          } catch (e) {
            AppLogger.warning(
              '⚠️ Failed to notify store of wallet adjustment',
              e,
            );
          }
        }
        return response;
      }
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      AppLogger.error('❌ Error adjusting store wallet balance', e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<String?> uploadTopupReceipt({
    required String storeId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول قبل رفع الصورة');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = fileName.replaceAll(' ', '_');
      final path = '$userId/wallet_receipts/$storeId/$timestamp-$safeFileName';

      await _supabase.storage
          .from('wallet_receipts')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return path;
    } on StorageException catch (e) {
      AppLogger.error('❌ Storage error uploading wallet receipt', e);
      rethrow;
    } catch (e) {
      AppLogger.error('❌ Error uploading wallet receipt', e);
      rethrow;
    }
  }

  static Future<bool> submitTopupRequest({
    required String storeId,
    required double amount,
    required String receiptPath,
    String? instapayReference,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول لإرسال طلب الشحن');
      }
      final response = await _supabase
          .from('store_wallet_topups')
          .insert({
            'store_id': storeId,
            'amount': amount,
            'receipt_path': receiptPath,
            'instapay_reference': instapayReference,
            'notes': notes,
            'requested_by': userId,
          })
          .select('id')
          .single();

      final topupId = response['id']?.toString();

      try {
        final storeName = await _getStoreName(storeId);
        if (topupId != null) {
          await NotificationServiceEnhanced.instance
              .notifyAdminOfTopupRequested(
                topupId: topupId,
                storeId: storeId,
                storeName: storeName,
                amount: amount,
              );
        }
      } catch (e) {
        AppLogger.warning('⚠️ Failed to notify admin of topup request', e);
      }
      return true;
    } catch (e) {
      AppLogger.error('❌ Error creating topup request', e);
      return false;
    }
  }

  static Future<Map<String, dynamic>> approveTopup({
    required String topupId,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'approve_store_wallet_topup',
        params: {'p_topup_id': topupId, 'p_notes': notes},
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          await _notifyTopupReviewed(topupId, status: 'approved');
        }
        return response;
      }
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      AppLogger.error('❌ Error approving topup', e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rejectTopup({
    required String topupId,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'reject_store_wallet_topup',
        params: {'p_topup_id': topupId, 'p_notes': notes},
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          await _notifyTopupReviewed(topupId, status: 'rejected');
        }
        return response;
      }
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      AppLogger.error('❌ Error rejecting topup', e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<String?> createSignedReceiptUrl(String receiptPath) async {
    try {
      final signed = await _supabase.storage
          .from('wallet_receipts')
          .createSignedUrl(receiptPath, 3600);
      return signed;
    } catch (e) {
      AppLogger.error('❌ Error creating signed receipt URL', e);
      return null;
    }
  }

  static Future<String> _getStoreName(String storeId) async {
    try {
      final storeResponse = await _supabase
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();
      return storeResponse?['name'] as String? ?? 'متجر';
    } catch (e) {
      AppLogger.warning('⚠️ Failed to fetch store name', e);
      return 'متجر';
    }
  }

  static Future<void> _notifyTopupReviewed(
    String topupId, {
    required String status,
  }) async {
    try {
      final topupResponse = await _supabase
          .from('store_wallet_topups')
          .select('store_id, amount, store:stores(name)')
          .eq('id', topupId)
          .maybeSingle();

      if (topupResponse == null) return;

      final storeId = topupResponse['store_id'] as String?;
      if (storeId == null) return;

      final storeName =
          (topupResponse['store'] as Map<String, dynamic>?)?['name'] ?? 'متجر';
      final amount = (topupResponse['amount'] as num?)?.toDouble() ?? 0.0;

      await NotificationServiceEnhanced.instance.notifyAdminOfTopupReviewed(
        topupId: topupId,
        storeId: storeId,
        storeName: storeName.toString(),
        amount: amount,
        status: status,
      );

      if (status == 'approved') {
        await NotificationServiceEnhanced.instance.notifyAdminOfTransaction(
          storeId: storeId,
          storeName: storeName.toString(),
          transactionId: topupId,
          transactionType: 'deposit',
          amount: amount,
        );
      }

      await NotificationServiceEnhanced.instance.notifyMerchantOfTopupStatus(
        storeId: storeId,
        topupId: topupId,
        amount: amount,
        status: status,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Failed to notify topup review', e);
    }
  }
}
