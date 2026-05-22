import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import 'notification_service.dart';

class DeliveryCompanyWalletService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getOrCreateWallet(
    String companyId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_or_create_delivery_company_wallet',
        params: {'p_company_id': companyId},
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first as Map);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error loading delivery office wallet', e);
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getTransactions(
    String companyId,
  ) async {
    try {
      final response = await _supabase
          .from('delivery_company_wallet_transactions')
          .select('id, company_id, order_id, type, amount, notes, created_at')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      AppLogger.error('Error loading delivery office transactions', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTopups({
    String status = 'all',
    String? companyId,
  }) async {
    try {
      var query = _supabase
          .from('delivery_company_wallet_topups')
          .select(
            'id, company_id, amount, receipt_path, instapay_reference, status, notes, created_at, reviewed_at, company:delivery_companies(company_name)',
          );

      if (companyId != null && companyId.trim().isNotEmpty) {
        query = query.eq('company_id', companyId);
      }

      if (status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      AppLogger.error('Error loading delivery office topups', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> adjustWalletBalance({
    required String companyId,
    required double amount,
    required bool isCredit,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'admin_adjust_delivery_company_wallet_balance',
        params: {
          'p_company_id': companyId,
          'p_amount': amount,
          'p_is_credit': isCredit,
          'p_notes': notes,
        },
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          try {
            final companyName = await _getCompanyName(companyId);
            // Find admin id for this company
            final compResp = await _supabase
                .from('delivery_companies')
                .select('admin_id')
                .eq('id', companyId)
                .maybeSingle();
            final adminId = compResp?['admin_id'] as String?;
            if (adminId != null) {
              await NotificationServiceEnhanced.instance
                  .notifyDeliveryOfficeOfWalletAdjustment(
                    adminId: adminId,
                    companyId: companyId,
                    companyName: companyName,
                    amount: amount,
                    isCredit: isCredit,
                    notes: notes,
                  );
            }
          } catch (e) {
            AppLogger.warning(
              '⚠️ Failed to notify delivery office of wallet adjustment',
              e,
            );
          }
        }
        return response;
      }
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      AppLogger.error('Error adjusting delivery company wallet balance', e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<String?> uploadTopupReceipt({
    required String companyId,
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
      final path =
          '$userId/delivery_wallet_receipts/$companyId/$timestamp-$safeFileName';

      await _supabase.storage
          .from('delivery_wallet_receipts')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      return path;
    } on StorageException catch (e) {
      AppLogger.error('Storage error uploading delivery receipt', e);
      rethrow;
    } catch (e) {
      AppLogger.error('Error uploading delivery receipt', e);
      rethrow;
    }
  }

  static Future<bool> submitTopupRequest({
    required String companyId,
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
          .from('delivery_company_wallet_topups')
          .insert({
            'company_id': companyId,
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
        final companyName = await _getCompanyName(companyId);
        if (topupId != null) {
          await NotificationServiceEnhanced.instance
              .notifyAdminOfDeliveryCompanyTopupRequested(
                topupId: topupId,
                companyId: companyId,
                companyName: companyName,
                amount: amount,
              );
        }
      } catch (e) {
        AppLogger.warning('Failed to notify admin of office topup', e);
      }

      return true;
    } catch (e) {
      AppLogger.error('Error creating delivery office topup request', e);
      return false;
    }
  }

  static Future<Map<String, dynamic>> approveTopup({
    required String topupId,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'approve_delivery_company_wallet_topup',
        params: {'p_topup_id': topupId, 'p_notes': notes},
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          await notifyTopupReviewed(topupId, status: 'approved');
        }
        return response;
      }
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      AppLogger.error('Error approving delivery office topup', e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rejectTopup({
    required String topupId,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'reject_delivery_company_wallet_topup',
        params: {'p_topup_id': topupId, 'p_notes': notes},
      );
      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          await notifyTopupReviewed(topupId, status: 'rejected');
        }
        return response;
      }
      return {'success': false, 'error': 'unexpected_response'};
    } catch (e) {
      AppLogger.error('Error rejecting delivery office topup', e);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<String?> createSignedReceiptUrl(String receiptPath) async {
    try {
      final signed = await _supabase.storage
          .from('delivery_wallet_receipts')
          .createSignedUrl(receiptPath, 3600);
      return signed;
    } catch (e) {
      AppLogger.error('Error creating delivery office receipt URL', e);
      return null;
    }
  }

  static Future<void> notifyTopupReviewed(
    String topupId, {
    required String status,
  }) async {
    try {
      final topupResponse = await _supabase
          .from('delivery_company_wallet_topups')
          .select(
            'company_id, amount, company:delivery_companies(company_name, admin_id)',
          )
          .eq('id', topupId)
          .maybeSingle();

      if (topupResponse == null) return;

      final companyId = topupResponse['company_id'] as String?;
      if (companyId == null) return;

      final companyMap = topupResponse['company'] as Map<String, dynamic>?;
      final companyName =
          companyMap?['company_name']?.toString() ?? 'مكتب التوصيل';
      final adminId = companyMap?['admin_id'] as String?;
      final amount = (topupResponse['amount'] as num?)?.toDouble() ?? 0.0;

      if (adminId == null) return;

      await NotificationServiceEnhanced.instance
          .notifyAdminOfDeliveryCompanyTopupReviewed(
            topupId: topupId,
            companyId: companyId,
            companyName: companyName,
            amount: amount,
            status: status,
          );

      await NotificationServiceEnhanced.instance
          .notifyDeliveryOfficeOfTopupStatus(
            adminId: adminId,
            companyId: companyId,
            companyName: companyName,
            topupId: topupId,
            amount: amount,
            status: status,
          );
    } catch (e) {
      AppLogger.warning('Failed to notify office topup review', e);
    }
  }

  static Future<String> _getCompanyName(String companyId) async {
    try {
      final response = await _supabase
          .from('delivery_companies')
          .select('company_name')
          .eq('id', companyId)
          .maybeSingle();
      return response?['company_name'] as String? ?? 'مكتب التوصيل';
    } catch (e) {
      AppLogger.warning('Failed to fetch company name', e);
      return 'مكتب التوصيل';
    }
  }
}
