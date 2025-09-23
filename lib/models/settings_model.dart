class AppSettings {
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool darkMode;
  final String language;
  final String currency;
  final bool biometricAuth;
  final bool savePaymentMethods;
  final bool autoUpdate;
  final bool dataSaver;
  final int cacheDuration;
  final bool analyticsEnabled;
  final bool crashReports;

  const AppSettings({
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.darkMode = false,
    this.language = 'ar',
    this.currency = 'SAR',
    this.biometricAuth = false,
    this.savePaymentMethods = true,
    this.autoUpdate = true,
    this.dataSaver = false,
    this.cacheDuration = 7,
    this.analyticsEnabled = true,
    this.crashReports = true,
  });

  // Default settings factory constructor
  factory AppSettings.defaults() {
    return const AppSettings();
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'darkMode': darkMode,
      'language': language,
      'currency': currency,
      'biometricAuth': biometricAuth,
      'savePaymentMethods': savePaymentMethods,
      'autoUpdate': autoUpdate,
      'dataSaver': dataSaver,
      'cacheDuration': cacheDuration,
      'analyticsEnabled': analyticsEnabled,
      'crashReports': crashReports,
    };
  }

  // JSON deserialization
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      emailNotifications: json['emailNotifications'] ?? true,
      smsNotifications: json['smsNotifications'] ?? false,
      darkMode: json['darkMode'] ?? false,
      language: json['language'] ?? 'ar',
      currency: json['currency'] ?? 'SAR',
      biometricAuth: json['biometricAuth'] ?? false,
      savePaymentMethods: json['savePaymentMethods'] ?? true,
      autoUpdate: json['autoUpdate'] ?? true,
      dataSaver: json['dataSaver'] ?? false,
      cacheDuration: json['cacheDuration'] ?? 7,
      analyticsEnabled: json['analyticsEnabled'] ?? true,
      crashReports: json['crashReports'] ?? true,
    );
  }

  // Copying with new values
  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? darkMode,
    String? language,
    String? currency,
    bool? biometricAuth,
    bool? savePaymentMethods,
    bool? autoUpdate,
    bool? dataSaver,
    int? cacheDuration,
    bool? analyticsEnabled,
    bool? crashReports,
  }) {
    return AppSettings(
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          notificationsEnabled == other.notificationsEnabled &&
          emailNotifications == other.emailNotifications &&
          smsNotifications == other.smsNotifications &&
          darkMode == other.darkMode &&
          language == other.language &&
          currency == other.currency &&
          biometricAuth == other.biometricAuth &&
          savePaymentMethods == other.savePaymentMethods &&
          autoUpdate == other.autoUpdate &&
          dataSaver == other.dataSaver &&
          cacheDuration == other.cacheDuration &&
          analyticsEnabled == other.analyticsEnabled &&
          crashReports == other.crashReports;

  @override
  int get hashCode =>
      notificationsEnabled.hashCode ^
      emailNotifications.hashCode ^
      smsNotifications.hashCode ^
      darkMode.hashCode ^
      language.hashCode ^
      currency.hashCode ^
      biometricAuth.hashCode ^
      savePaymentMethods.hashCode ^
      autoUpdate.hashCode ^
      dataSaver.hashCode ^
      cacheDuration.hashCode ^
      analyticsEnabled.hashCode ^
      crashReports.hashCode;

  @override
  String toString() {
    return 'AppSettings{notificationsEnabled: $notificationsEnabled, '
        'emailNotifications: $emailNotifications, '
        'smsNotifications: $smsNotifications, '
        'darkMode: $darkMode, '
        'language: $language, '
        'currency: $currency, '
        'biometricAuth: $biometricAuth, '
        'savePaymentMethods: $savePaymentMethods, '
        'autoUpdate: $autoUpdate, '
        'dataSaver: $dataSaver, '
        'cacheDuration: $cacheDuration, '
        'analyticsEnabled: $analyticsEnabled, '
        'crashReports: $crashReports}';
  }
}
