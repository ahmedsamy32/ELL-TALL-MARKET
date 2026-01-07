import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// نموذج مسودة تسجيل تاجر محلياً (SharedPreferences)
///
/// - يتم استخدامه لحفظ تقدم المستخدم في نموذج التسجيل متعدد الخطوات
/// - لا يحتوي على أي معرفات حساسة؛ البيانات مؤقتة ويمكن مسحها
class MerchantDraft {
  // البيانات الشخصية
  final String? fullName;
  final String? email;
  final String? phone;

  // بيانات المتجر
  final String? storeName;
  final String? storeAddress;
  final String? storeDescription;
  final String? category;
  final String? logoPath; // local file path
  final DateTime updatedAt;

  MerchantDraft({
    this.fullName,
    this.email,
    this.phone,
    this.storeName,
    this.storeAddress,
    this.storeDescription,
    this.category,
    this.logoPath,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// تحويل إلى خريطة JSON قابلة للتخزين
  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'storeName': storeName,
    'storeAddress': storeAddress,
    'storeDescription': storeDescription,
    'category': category,
    'logoPath': logoPath,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// إنشاء مسودة من JSON مع معالجة آمنة للأنواع
  static MerchantDraft fromJson(Map<String, dynamic> json) {
    String? asString(dynamic v) => v is String ? v : null;

    return MerchantDraft(
      fullName: asString(json['fullName']),
      email: asString(json['email']),
      phone: asString(json['phone']),
      storeName: asString(json['storeName']),
      storeAddress: asString(json['storeAddress']),
      storeDescription: asString(json['storeDescription']),
      category: asString(json['category']),
      logoPath: asString(json['logoPath']),
      updatedAt:
          DateTime.tryParse(asString(json['updatedAt']) ?? '') ??
          DateTime.now(),
    );
  }

  /// نسخة جديدة مع تعديلات اختيارية
  MerchantDraft copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? storeName,
    String? storeAddress,
    String? storeDescription,
    String? category,
    String? logoPath,
    DateTime? updatedAt,
  }) {
    return MerchantDraft(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storeDescription: storeDescription ?? this.storeDescription,
      category: category ?? this.category,
      logoPath: logoPath ?? this.logoPath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// يعيد نسخة محدثة للطابع الزمني
  MerchantDraft touch() => copyWith(updatedAt: DateTime.now());

  /// هل جميع الحقول فارغة؟ (باستثناء updatedAt)
  bool get isEmpty =>
      (fullName == null || fullName!.trim().isEmpty) &&
      (email == null || email!.trim().isEmpty) &&
      (phone == null || phone!.trim().isEmpty) &&
      (storeName == null || storeName!.trim().isEmpty) &&
      (storeAddress == null || storeAddress!.trim().isEmpty) &&
      (storeDescription == null || storeDescription!.trim().isEmpty) &&
      (category == null || category!.trim().isEmpty) &&
      (logoPath == null || logoPath!.trim().isEmpty);

  @override
  String toString() =>
      'MerchantDraft(storeName: $storeName, storeAddress: $storeAddress, storeDescription: $storeDescription, category: $category, logoPath: $logoPath, updatedAt: $updatedAt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MerchantDraft &&
        other.fullName == fullName &&
        other.email == email &&
        other.phone == phone &&
        other.storeName == storeName &&
        other.storeAddress == storeAddress &&
        other.storeDescription == storeDescription &&
        other.category == category &&
        other.logoPath == logoPath &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    fullName,
    email,
    phone,
    storeName,
    storeAddress,
    storeDescription,
    category,
    logoPath,
    updatedAt,
  );
}

class MerchantDraftService {
  static const _key = 'merchant_draft_v1';

  /// حفظ المسودة. يعيد true عند النجاح.
  static Future<bool> save(MerchantDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key, jsonEncode(draft.toJson()));
    } catch (_) {
      return false;
    }
  }

  /// تحميل المسودة إن وُجدت، وإلا يعيد null
  static Future<MerchantDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return MerchantDraft.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// تحميل أو إرجاع مسودة فارغة (للراحة في الواجهات)
  static Future<MerchantDraft> loadOrEmpty() async {
    return (await load()) ?? MerchantDraft();
  }

  static Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
