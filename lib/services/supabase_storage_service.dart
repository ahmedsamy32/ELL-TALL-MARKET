import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/config/supabase_config.dart';

class SupabaseStorageService {
  final _client = SupabaseConfig.client;

  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    try {
      if (kDebugMode) debugPrint('📤 [SupabaseStorageService] جاري رفع الملف: $path');

      await _client.storage.from(bucket).upload(path, file);
      final url = _client.storage.from(bucket).getPublicUrl(path);

      if (kDebugMode) debugPrint('✅ [SupabaseStorageService] تم رفع الملف بنجاح: $url');
      return url;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseStorageService] فشل رفع الملف: $e');
      return null;
    }
  }

  Future<bool> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      if (kDebugMode) debugPrint('🗑️ [SupabaseStorageService] جاري حذف الملف: $path');

      await _client.storage.from(bucket).remove([path]);

      if (kDebugMode) debugPrint('✅ [SupabaseStorageService] تم حذف الملف بنجاح');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseStorageService] فشل حذف الملف: $e');
      return false;
    }
  }

  Future<String?> uploadAvatar(String userId, File file) async {
    final path = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadFile(bucket: 'avatars', path: path, file: file);
  }

  Future<String?> uploadProductImage(String productId, File file) async {
    final path = 'products/$productId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadFile(bucket: 'products', path: path, file: file);
  }

  Future<String?> uploadStoreImage(String storeId, File file) async {
    final path = 'store_images/$storeId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadFile(bucket: 'store_images', path: path, file: file);
  }

  String? getPublicUrl(String bucket, String path) {
    try {
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [SupabaseStorageService] خطأ في الحصول على الرابط العام: $e');
      return null;
    }
  }
}
