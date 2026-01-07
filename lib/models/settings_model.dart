/// App settings model that matches the Supabase user_settings table
/// Following the official Supabase Dart documentation: https://supabase.com/docs/reference/dart/installing
library;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base mixin for common model functionality (if not imported from user_model.dart)
mixin BaseModelMixin {
  String get id;
  DateTime get createdAt;
  DateTime? get updatedAt;

  String get createdAtFormatted =>
      DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  String get updatedAtFormatted => updatedAt != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(updatedAt!)
      : 'لم يتم التحديث';

  static DateTime parseDateTime(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    return DateTime.parse(dateStr.toString());
  }
}

/// Language enum for supported languages
enum AppLanguage { arabic, english }

/// Extension for AppLanguage enum
extension AppLanguageExtension on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.arabic:
        return 'ar';
      case AppLanguage.english:
        return 'en';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.arabic:
        return 'العربية';
      case AppLanguage.english:
        return 'English';
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'ar':
        return AppLanguage.arabic;
      case 'en':
        return AppLanguage.english;
      default:
        return AppLanguage.arabic;
    }
  }
}

/// Currency enum for supported currencies
enum AppCurrency {
  egp, // Egyptian Pound
  sar, // Saudi Riyal
  usd, // US Dollar
}

/// Extension for AppCurrency enum
extension AppCurrencyExtension on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.egp:
        return 'EGP';
      case AppCurrency.sar:
        return 'SAR';
      case AppCurrency.usd:
        return 'USD';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.egp:
        return 'ج.م';
      case AppCurrency.sar:
        return 'ر.س';
      case AppCurrency.usd:
        return '\$';
    }
  }

  String get displayName {
    switch (this) {
      case AppCurrency.egp:
        return 'جنيه مصري';
      case AppCurrency.sar:
        return 'ريال سعودي';
      case AppCurrency.usd:
        return 'دولار أمريكي';
    }
  }

  static AppCurrency fromCode(String code) {
    switch (code) {
      case 'EGP':
        return AppCurrency.egp;
      case 'SAR':
        return AppCurrency.sar;
      case 'USD':
        return AppCurrency.usd;
      default:
        return AppCurrency.egp;
    }
  }
}

/// App settings model that matches the Supabase user_settings table
class AppSettingsModel with BaseModelMixin {
  static const String tableName = 'user_settings';
  static const String schema = 'public';

  @override
  final String id; // UUID PRIMARY KEY DEFAULT gen_random_uuid()
  final String clientId; // UUID REFERENCES clients(id) ON DELETE CASCADE UNIQUE
  final bool notificationsEnabled; // BOOLEAN DEFAULT TRUE
  final bool emailNotifications; // BOOLEAN DEFAULT TRUE
  final bool smsNotifications; // BOOLEAN DEFAULT FALSE
  final bool darkMode; // BOOLEAN DEFAULT FALSE
  final AppLanguage language; // TEXT DEFAULT 'ar'
  final AppCurrency currency; // TEXT DEFAULT 'EGP'
  final bool biometricAuth; // BOOLEAN DEFAULT FALSE
  final bool savePaymentMethods; // BOOLEAN DEFAULT TRUE
  final bool autoUpdate; // BOOLEAN DEFAULT TRUE
  final bool dataSaver; // BOOLEAN DEFAULT FALSE
  final int cacheDuration; // INT DEFAULT 7 (days)
  final bool analyticsEnabled; // BOOLEAN DEFAULT TRUE
  final bool crashReports; // BOOLEAN DEFAULT TRUE

  // Delivery settings (merged from legacy AppSettings)
  final double appDeliveryBaseFee; // رسوم التوصيل الأساسية
  final double appDeliveryFeePerKm; // رسوم لكل كيلومتر
  final double appDeliveryMaxDistance; // أقصى مسافة للتوصيل (كم)
  final int appDeliveryEstimatedTime; // الوقت التقديري للتوصيل (دقائق)

  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;

  const AppSettingsModel({
    required this.id,
    required this.clientId,
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.darkMode = false,
    this.language = AppLanguage.arabic,
    this.currency = AppCurrency.egp,
    this.biometricAuth = false,
    this.savePaymentMethods = true,
    this.autoUpdate = true,
    this.dataSaver = false,
    this.cacheDuration = 7,
    this.analyticsEnabled = true,
    this.crashReports = true,
    this.appDeliveryBaseFee = 15.0,
    this.appDeliveryFeePerKm = 3.0,
    this.appDeliveryMaxDistance = 25.0,
    this.appDeliveryEstimatedTime = 30,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      id: map['id'] as String? ?? '',
      clientId: map['client_id'] as String? ?? '',
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      emailNotifications: map['email_notifications'] as bool? ?? true,
      smsNotifications: map['sms_notifications'] as bool? ?? false,
      darkMode: map['dark_mode'] as bool? ?? false,
      language: AppLanguageExtension.fromCode(
        map['language'] as String? ?? 'ar',
      ),
      currency: AppCurrencyExtension.fromCode(
        map['currency'] as String? ?? 'EGP',
      ),
      biometricAuth: map['biometric_auth'] as bool? ?? false,
      savePaymentMethods: map['save_payment_methods'] as bool? ?? true,
      autoUpdate: map['auto_update'] as bool? ?? true,
      dataSaver: map['data_saver'] as bool? ?? false,
      cacheDuration: map['cache_duration'] as int? ?? 7,
      analyticsEnabled: map['analytics_enabled'] as bool? ?? true,
      crashReports: map['crash_reports'] as bool? ?? true,
      appDeliveryBaseFee:
          (map['app_delivery_base_fee'] as num?)?.toDouble() ?? 15.0,
      appDeliveryFeePerKm:
          (map['app_delivery_fee_per_km'] as num?)?.toDouble() ?? 3.0,
      appDeliveryMaxDistance:
          (map['app_delivery_max_distance'] as num?)?.toDouble() ?? 25.0,
      appDeliveryEstimatedTime:
          map['app_delivery_estimated_time'] as int? ?? 30,
      createdAt: BaseModelMixin.parseDateTime(map['created_at']),
      updatedAt: map['updated_at'] != null
          ? BaseModelMixin.parseDateTime(map['updated_at'])
          : null,
    );
  }

  factory AppSettingsModel.fromSupabase(PostgrestResponse response) {
    final data = response.data as Map<String, dynamic>;
    return AppSettingsModel.fromMap(data);
  }

  factory AppSettingsModel.defaults(String clientId) {
    return AppSettingsModel(
      id: '',
      clientId: clientId,
      createdAt: DateTime.now(),
    );
  }

  factory AppSettingsModel.empty() {
    return AppSettingsModel(id: '', clientId: '', createdAt: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'sms_notifications': smsNotifications,
      'dark_mode': darkMode,
      'language': language.code,
      'currency': currency.code,
      'biometric_auth': biometricAuth,
      'save_payment_methods': savePaymentMethods,
      'auto_update': autoUpdate,
      'data_saver': dataSaver,
      'cache_duration': cacheDuration,
      'analytics_enabled': analyticsEnabled,
      'crash_reports': crashReports,
      'app_delivery_base_fee': appDeliveryBaseFee,
      'app_delivery_fee_per_km': appDeliveryFeePerKm,
      'app_delivery_max_distance': appDeliveryMaxDistance,
      'app_delivery_estimated_time': appDeliveryEstimatedTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toDatabaseMap() {
    // For insert/update operations, exclude auto-generated fields
    return {
      'client_id': clientId,
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'sms_notifications': smsNotifications,
      'dark_mode': darkMode,
      'language': language.code,
      'currency': currency.code,
      'biometric_auth': biometricAuth,
      'save_payment_methods': savePaymentMethods,
      'auto_update': autoUpdate,
      'data_saver': dataSaver,
      'cache_duration': cacheDuration,
      'analytics_enabled': analyticsEnabled,
      'crash_reports': crashReports,
      'app_delivery_base_fee': appDeliveryBaseFee,
      'app_delivery_fee_per_km': appDeliveryFeePerKm,
      'app_delivery_max_distance': appDeliveryMaxDistance,
      'app_delivery_estimated_time': appDeliveryEstimatedTime,
    };
  }

  AppSettingsModel copyWith({
    String? id,
    String? clientId,
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? darkMode,
    AppLanguage? language,
    AppCurrency? currency,
    bool? biometricAuth,
    bool? savePaymentMethods,
    bool? autoUpdate,
    bool? dataSaver,
    int? cacheDuration,
    bool? analyticsEnabled,
    bool? crashReports,
    double? appDeliveryBaseFee,
    double? appDeliveryFeePerKm,
    double? appDeliveryMaxDistance,
    int? appDeliveryEstimatedTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettingsModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      savePaymentMethods: savePaymentMethods ?? this.savePaymentMethods,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      dataSaver: dataSaver ?? this.dataSaver,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReports: crashReports ?? this.crashReports,
      appDeliveryBaseFee: appDeliveryBaseFee ?? this.appDeliveryBaseFee,
      appDeliveryFeePerKm: appDeliveryFeePerKm ?? this.appDeliveryFeePerKm,
      appDeliveryMaxDistance:
          appDeliveryMaxDistance ?? this.appDeliveryMaxDistance,
      appDeliveryEstimatedTime:
          appDeliveryEstimatedTime ?? this.appDeliveryEstimatedTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Update settings with current timestamp
  AppSettingsModel updateSettings({
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? darkMode,
    AppLanguage? language,
    AppCurrency? currency,
    bool? biometricAuth,
    bool? savePaymentMethods,
    bool? autoUpdate,
    bool? dataSaver,
    int? cacheDuration,
    bool? analyticsEnabled,
    bool? crashReports,
    double? appDeliveryBaseFee,
    double? appDeliveryFeePerKm,
    double? appDeliveryMaxDistance,
    int? appDeliveryEstimatedTime,
  }) {
    return copyWith(
      notificationsEnabled: notificationsEnabled,
      emailNotifications: emailNotifications,
      smsNotifications: smsNotifications,
      darkMode: darkMode,
      language: language,
      currency: currency,
      biometricAuth: biometricAuth,
      savePaymentMethods: savePaymentMethods,
      autoUpdate: autoUpdate,
      dataSaver: dataSaver,
      cacheDuration: cacheDuration,
      analyticsEnabled: analyticsEnabled,
      crashReports: crashReports,
      appDeliveryBaseFee: appDeliveryBaseFee,
      appDeliveryFeePerKm: appDeliveryFeePerKm,
      appDeliveryMaxDistance: appDeliveryMaxDistance,
      appDeliveryEstimatedTime: appDeliveryEstimatedTime,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if any notifications are enabled
  bool get hasNotificationsEnabled =>
      notificationsEnabled || emailNotifications || smsNotifications;

  /// Check if privacy features are enabled
  bool get hasPrivacyFeaturesEnabled => !analyticsEnabled || !crashReports;

  /// Check if performance features are enabled
  bool get hasPerformanceFeaturesEnabled => dataSaver || autoUpdate;

  /// Check if security features are enabled
  bool get hasSecurityFeaturesEnabled => biometricAuth;

  /// Get cache duration in days text
  String get cacheDurationText {
    switch (cacheDuration) {
      case 1:
        return 'يوم واحد';
      case 7:
        return 'أسبوع واحد';
      case 30:
        return 'شهر واحد';
      default:
        return '$cacheDuration أيام';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AppSettingsModel(id: $id, language: ${language.code}, currency: ${currency.code})';
  }
}
