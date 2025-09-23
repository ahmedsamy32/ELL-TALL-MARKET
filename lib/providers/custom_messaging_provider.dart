import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomMessagingProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _messageChannel;

  // ===== إرسال إشعار مخصص =====
  Future<void> sendCustomNotification({
    required String userId,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'action': action,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error sending custom notification: $e');
      rethrow;
    }
  }

  // ===== إرسال إشعار للمتجر =====
  Future<void> sendStoreNotification({
    required String storeId,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      // جلب معرف صاحب المتجر
      final response = await _supabase
          .from('stores')
          .select('owner_id')
          .eq('id', storeId)
          .single();

      await sendCustomNotification(
        userId: response['owner_id'],
        title: title,
        body: body,
        action: action,
        data: data,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error sending store notification: $e');
      rethrow;
    }
  }

  // ===== إرسال إشعار للكابتن =====
  Future<void> sendCaptainNotification({
    required String captainId,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      await sendCustomNotification(
        userId: captainId,
        title: title,
        body: body,
        action: action,
        data: data,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error sending captain notification: $e');
      rethrow;
    }
  }

  // ===== إرسال إشعار لمجموعة من المستخدمين =====
  Future<void> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notifications = userIds.map((userId) => {
        'user_id': userId,
        'title': title,
        'body': body,
        'action': action,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await _supabase.from('notifications').insert(notifications);
    } catch (e) {
      if (kDebugMode) print('❌ Error sending bulk notifications: $e');
      rethrow;
    }
  }

  // ===== إرسال إشعار للمتاجر القريبة =====
  Future<void> sendNearbyStoresNotification({
    required double lat,
    required double lng,
    required double radiusKm,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      // جلب المتاجر القريبة
      final response = await _supabase.rpc('get_nearby_stores', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      });

      if (response != null) {
        final storeIds = (response as List).map((store) => store['id'] as String).toList();

        // جلب معرفات أصحاب المتاجر
        final ownersResponse = await _supabase
            .from('stores')
            .select('owner_id')
            .inFilter('id', storeIds);

        final ownerIds = (ownersResponse as List).map((store) => store['owner_id'] as String).toList();

        // إرسال الإشعارات
        await sendBulkNotifications(
          userIds: ownerIds,
          title: title,
          body: body,
          action: action,
          data: data,
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sending nearby stores notification: $e');
      rethrow;
    }
  }

  // ===== إرسال إشعار للكباتن القريبين =====
  Future<void> sendNearbyCaptainsNotification({
    required double lat,
    required double lng,
    required double radiusKm,
    required String title,
    required String body,
    String? action,
    Map<String, dynamic>? data,
  }) async {
    try {
      // جلب الكباتن القريبين
      final response = await _supabase.rpc('get_nearby_captains', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      });

      if (response != null) {
        final captainIds = (response as List).map((captain) => captain['captain_id'] as String).toList();

        // إرسال الإشعارات
        await sendBulkNotifications(
          userIds: captainIds,
          title: title,
          body: body,
          action: action,
          data: data,
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error sending nearby captains notification: $e');
      rethrow;
    }
  }

  // ===== الاشتراك في تحديثات الرسائل في الوقت الحقيقي =====
  void subscribeToMessages(String userId, Function(Map<String, dynamic>) onMessage) {
    _messageChannel = _supabase
        .channel('messages_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        ..subscribe();
  }

  // ===== إلغاء الاشتراك في تحديثات الرسائل =====
  void unsubscribeFromMessages() {
    _messageChannel?.unsubscribe();
  }

  @override
  void dispose() {
    unsubscribeFromMessages();
    super.dispose();
  }
}
