import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/core/supabase_helper.dart';

class AdminNotificationService {
  final _supabase = SupabaseHelper.instance.client;

  Future<void> notifyAdminOfTransaction({
    required String storeId,
    required String transactionId,
    required String transactionType,
    required double amount,
  }) async {
    final notification = NotificationModel(
      id: transactionId,
      userId: 'admin', // Admin user ID
      title: 'معاملة مالية جديدة',
      message: 'تم إجراء معاملة $transactionType بقيمة $amount ريال للمتجر $storeId',
      type: NotificationType.payment,
      data: {
        'storeId': storeId,
        'transactionId': transactionId,
        'amount': amount,
        'type': transactionType,
      },
      isRead: false,
      createdAt: DateTime.now(),
    );

    await _supabase.from('notifications').insert(notification.toJson());
  }
}
