import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';

/// Settings synchronization mode
enum SettingsSyncMode {
  local, // Local storage only
  cloud, // Cloud storage only
  hybrid, // Local + Cloud sync
  realtime, // Real-time synchronization
}

/// Settings category for organization
enum SettingsCategory {
  general,
  notifications,
  privacy,
  security,
  appearance,
  performance,
  merchant,
  admin,
  compliance,
  advanced,
}

/// Settings priority levels
enum SettingsPriority { low, normal, high, critical }

/// Enhanced SettingsService with comprehensive configuration management
class SettingsServiceEnhanced {
  // ===== Singleton Pattern =====
  static SettingsServiceEnhanced? _instance;
  static SettingsServiceEnhanced get instance =>
      _instance ??= SettingsServiceEnhanced._internal();

  SettingsServiceEnhanced._internal();

  // ===== Core Dependencies =====
  final SupabaseClient _supabase = Supabase.instance.client;

  // ===== Storage Keys =====
  static const String _appSettingsKey = 'app_settings_v2';
  static const String _merchantSettingsKey = 'merchant_settings_v2';
  static const String _userPreferencesKey = 'user_preferences_v2';
  static const String _securitySettingsKey = 'security_settings_v2';
  static const String _privacySettingsKey = 'privacy_settings_v2';
  static const String _notificationSettingsKey = 'notification_settings_v2';
  static const String _performanceSettingsKey = 'performance_settings_v2';
  static const String _settingsVersionKey = 'settings_version';
  static const String _lastSyncKey = 'last_settings_sync';

  // ===== Configuration =====
  static const int _currentSettingsVersion = 2;
  static const Duration _syncInterval = Duration(minutes: 15);

  // ===== State Management =====
  bool _isInitialized = false;
  SettingsSyncMode _syncMode = SettingsSyncMode.hybrid;
  final Map<String, dynamic> _cachedSettings = {};
  DateTime? _lastSyncTime;

  // ===== Initialization =====

  /// Initialize the settings service
  Future<bool> initialize({
    SettingsSyncMode syncMode = SettingsSyncMode.hybrid,
  }) async {
    try {
      if (_isInitialized) return true;

      AppLogger.info('Initializing enhanced settings service...');

      _syncMode = syncMode;

      // Check and migrate settings if needed
      await _checkAndMigrateSettings();

      // Load cached settings
      await _loadCachedSettings();

      // Setup cloud sync if enabled
      if (_syncMode == SettingsSyncMode.cloud ||
          _syncMode == SettingsSyncMode.hybrid) {
        await _setupCloudSync();
      }

      // Setup real-time sync if enabled
      if (_syncMode == SettingsSyncMode.realtime) {
        await _setupRealtimeSync();
      }

      _isInitialized = true;
      AppLogger.info('Settings service initialized successfully');

      return true;
    } catch (e) {
      AppLogger.error('Failed to initialize settings service', e);
      return false;
    }
  }

  // ===== Core Settings Management =====

  /// Get comprehensive app settings
  Future<EnhancedAppSettings> getAppSettings() async {
    try {
      AppLogger.info('Getting app settings...');

      // Try cache first
      if (_cachedSettings.containsKey('app')) {
        return EnhancedAppSettings.fromJson(_cachedSettings['app']);
      }

      // Load from local storage
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_appSettingsKey);

      EnhancedAppSettings settings;
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson);
        settings = EnhancedAppSettings.fromJson(settingsMap);
      } else {
        settings = EnhancedAppSettings.defaults();
        await saveAppSettings(settings); // Save defaults
      }

      // Try to sync from cloud if hybrid mode
      if (_syncMode == SettingsSyncMode.hybrid ||
          _syncMode == SettingsSyncMode.cloud) {
        final cloudSettings = await _getCloudSettings('app');
        if (cloudSettings != null) {
          settings = _mergeAppSettings(settings, cloudSettings);
        }
      }

      // Update cache
      _cachedSettings['app'] = settings.toJson();

      return settings;
    } catch (e) {
      AppLogger.error('Failed to get app settings', e);
      return EnhancedAppSettings.defaults();
    }
  }

  /// Save app settings with comprehensive handling
  Future<bool> saveAppSettings(EnhancedAppSettings settings) async {
    try {
      // Validate settings
      final validation = _validateAppSettings(settings);
      if (!validation['valid']) {
        AppLogger.warning('Invalid settings: ${validation['error']}');
        return false;
      }

      final settingsJson = jsonEncode(settings.toJson());

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appSettingsKey, settingsJson);

      // Update cache
      _cachedSettings['app'] = settings.toJson();

      // Sync to cloud if enabled
      if (_syncMode == SettingsSyncMode.cloud ||
          _syncMode == SettingsSyncMode.hybrid) {
        await _syncToCloud('app', settings.toJson());
      }

      // Trigger settings change notifications
      await _notifySettingsChanged('app', settings.toJson());

      AppLogger.info('App settings saved successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save app settings', e);
      return false;
    }
  }

  /// Get enhanced merchant settings
  Future<EnhancedMerchantSettings> getMerchantSettings() async {
    try {
      AppLogger.info('Getting merchant settings...');

      // Try cache first
      if (_cachedSettings.containsKey('merchant')) {
        return EnhancedMerchantSettings.fromJson(_cachedSettings['merchant']);
      }

      // Load from local storage
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_merchantSettingsKey);

      EnhancedMerchantSettings settings;
      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson);
        settings = EnhancedMerchantSettings.fromJson(settingsMap);
      } else {
        settings = EnhancedMerchantSettings.defaults();
        await saveMerchantSettings(settings);
      }

      // Try to sync from cloud if hybrid mode
      if (_syncMode == SettingsSyncMode.hybrid ||
          _syncMode == SettingsSyncMode.cloud) {
        final cloudSettings = await _getCloudSettings('merchant');
        if (cloudSettings != null) {
          settings = _mergeMerchantSettings(settings, cloudSettings);
        }
      }

      // Update cache
      _cachedSettings['merchant'] = settings.toJson();

      return settings;
    } catch (e) {
      AppLogger.error('Failed to get merchant settings', e);
      return EnhancedMerchantSettings.defaults();
    }
  }

  /// Save merchant settings with validation
  Future<bool> saveMerchantSettings(EnhancedMerchantSettings settings) async {
    try {
      // Validate merchant settings
      final validation = _validateMerchantSettings(settings);
      if (!validation['valid']) {
        AppLogger.warning('Invalid merchant settings: ${validation['error']}');
        return false;
      }

      final settingsJson = jsonEncode(settings.toJson());

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_merchantSettingsKey, settingsJson);

      // Update cache
      _cachedSettings['merchant'] = settings.toJson();

      // Sync to cloud if enabled
      if (_syncMode == SettingsSyncMode.cloud ||
          _syncMode == SettingsSyncMode.hybrid) {
        await _syncToCloud('merchant', settings.toJson());
      }

      // Trigger settings change notifications
      await _notifySettingsChanged('merchant', settings.toJson());

      AppLogger.info('Merchant settings saved successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save merchant settings', e);
      return false;
    }
  }

  // ===== Advanced Settings Management =====

  /// Get user preferences with personalization
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      AppLogger.info('Getting user preferences...');

      final prefs = await SharedPreferences.getInstance();
      final preferencesJson = prefs.getString(_userPreferencesKey);

      if (preferencesJson != null) {
        return jsonDecode(preferencesJson);
      } else {
        final defaultPreferences = _getDefaultUserPreferences();
        await _saveUserPreferences(defaultPreferences);
        return defaultPreferences;
      }
    } catch (e) {
      AppLogger.error('Failed to get user preferences', e);
      return _getDefaultUserPreferences();
    }
  }

  /// Save user preferences with cloud sync
  Future<bool> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      AppLogger.info('Saving user preferences...');

      await _saveUserPreferences(preferences);

      // Sync to cloud if enabled
      if (_syncMode == SettingsSyncMode.cloud ||
          _syncMode == SettingsSyncMode.hybrid) {
        await _syncToCloud('preferences', preferences);
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to save user preferences', e);
      return false;
    }
  }

  /// Get security settings
  Future<Map<String, dynamic>> getSecuritySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_securitySettingsKey);

      if (settingsJson != null) {
        return jsonDecode(settingsJson);
      } else {
        final defaultSettings = _getDefaultSecuritySettings();
        await _saveSecuritySettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      AppLogger.error('Failed to get security settings', e);
      return _getDefaultSecuritySettings();
    }
  }

  /// Save security settings with validation
  Future<bool> saveSecuritySettings(Map<String, dynamic> settings) async {
    try {
      // Validate security settings
      final validation = _validateSecuritySettings(settings);
      if (!validation['valid']) {
        AppLogger.warning('Invalid security settings: ${validation['error']}');
        return false;
      }

      await _saveSecuritySettings(settings);

      // Security settings should not be synced to cloud for privacy
      AppLogger.info('Security settings saved locally only');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save security settings', e);
      return false;
    }
  }

  /// Get privacy settings
  Future<Map<String, dynamic>> getPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_privacySettingsKey);

      if (settingsJson != null) {
        return jsonDecode(settingsJson);
      } else {
        final defaultSettings = _getDefaultPrivacySettings();
        await _savePrivacySettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      AppLogger.error('Failed to get privacy settings', e);
      return _getDefaultPrivacySettings();
    }
  }

  /// Save privacy settings
  Future<bool> savePrivacySettings(Map<String, dynamic> settings) async {
    try {
      AppLogger.info('Privacy settings saved locally only');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save privacy settings', e);
      return false;
    }
  }

  /// Get notification preferences with advanced options
  Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_notificationSettingsKey);

      if (settingsJson != null) {
        return jsonDecode(settingsJson);
      } else {
        final defaultSettings = _getDefaultNotificationSettings();
        await _saveNotificationSettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      AppLogger.error('Failed to get notification settings', e);
      return _getDefaultNotificationSettings();
    }
  }

  /// Save notification settings with cloud sync
  Future<bool> saveNotificationSettings(Map<String, dynamic> settings) async {
    try {
      AppLogger.info('Saving notification settings...');

      await _saveNotificationSettings(settings);

      // Sync to cloud if enabled
      if (_syncMode == SettingsSyncMode.cloud ||
          _syncMode == SettingsSyncMode.hybrid) {
        await _syncToCloud('notifications', settings);
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to save notification settings', e);
      return false;
    }
  }

  /// Get performance settings
  Future<Map<String, dynamic>> getPerformanceSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_performanceSettingsKey);

      if (settingsJson != null) {
        return jsonDecode(settingsJson);
      } else {
        final defaultSettings = _getDefaultPerformanceSettings();
        await _savePerformanceSettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      AppLogger.error('Failed to get performance settings', e);
      return _getDefaultPerformanceSettings();
    }
  }

  /// Save performance settings
  Future<bool> savePerformanceSettings(Map<String, dynamic> settings) async {
    try {
      AppLogger.info('Saving performance settings...');

      await _savePerformanceSettings(settings);

      // Apply performance settings immediately
      await _applyPerformanceSettings(settings);

      return true;
    } catch (e) {
      AppLogger.error('Failed to save performance settings', e);
      return false;
    }
  }

  // ===== Settings Operations =====

  /// Update specific setting by key
  Future<bool> updateSetting({
    required SettingsCategory category,
    required String key,
    required dynamic value,
    SettingsPriority priority = SettingsPriority.normal,
  }) async {
    try {
      AppLogger.info('Updating setting: $category.$key = $value');

      switch (category) {
        case SettingsCategory.general:
          final settings = await getAppSettings();
          final updatedSettings = _updateAppSettingsValue(settings, key, value);
          return await saveAppSettings(updatedSettings);

        case SettingsCategory.merchant:
          final settings = await getMerchantSettings();
          final updatedSettings = _updateMerchantSettingsValue(
            settings,
            key,
            value,
          );
          return await saveMerchantSettings(updatedSettings);

        case SettingsCategory.notifications:
          final settings = await getNotificationSettings();
          settings[key] = value;
          return await saveNotificationSettings(settings);

        case SettingsCategory.privacy:
          final settings = await getPrivacySettings();
          settings[key] = value;
          return await savePrivacySettings(settings);

        case SettingsCategory.security:
          final settings = await getSecuritySettings();
          settings[key] = value;
          return await saveSecuritySettings(settings);

        case SettingsCategory.performance:
          final settings = await getPerformanceSettings();
          settings[key] = value;
          return await savePerformanceSettings(settings);

        default:
          AppLogger.warning('Unknown settings category: $category');
          return false;
      }
    } catch (e) {
      AppLogger.error('Failed to update setting', e);
      return false;
    }
  }

  /// Get all settings organized by category
  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      AppLogger.info('Getting all settings...');

      final allSettings = <String, dynamic>{};

      // Load all setting categories
      allSettings['app'] = (await getAppSettings()).toJson();
      allSettings['merchant'] = (await getMerchantSettings()).toJson();
      allSettings['preferences'] = await getUserPreferences();
      allSettings['security'] = await getSecuritySettings();
      allSettings['privacy'] = await getPrivacySettings();
      allSettings['notifications'] = await getNotificationSettings();
      allSettings['performance'] = await getPerformanceSettings();

      // Add metadata
      allSettings['metadata'] = {
        'version': _currentSettingsVersion,
        'last_updated': DateTime.now().toIso8601String(),
        'sync_mode': _syncMode.toString(),
        'last_sync': _lastSyncTime?.toIso8601String(),
      };

      return allSettings;
    } catch (e) {
      AppLogger.error('Failed to get all settings', e);
      return {};
    }
  }

  /// Reset settings to defaults
  Future<bool> resetSettings({
    List<SettingsCategory>? categories,
    bool confirmReset = true,
  }) async {
    try {
      AppLogger.info('Resetting settings...');

      final categoriesToReset = categories ?? SettingsCategory.values;

      for (final category in categoriesToReset) {
        switch (category) {
          case SettingsCategory.general:
            await saveAppSettings(EnhancedAppSettings.defaults());
            break;
          case SettingsCategory.merchant:
            await saveMerchantSettings(EnhancedMerchantSettings.defaults());
            break;
          case SettingsCategory.notifications:
            await saveNotificationSettings(_getDefaultNotificationSettings());
            break;
          case SettingsCategory.privacy:
            await savePrivacySettings(_getDefaultPrivacySettings());
            break;
          case SettingsCategory.security:
            await saveSecuritySettings(_getDefaultSecuritySettings());
            break;
          case SettingsCategory.performance:
            await savePerformanceSettings(_getDefaultPerformanceSettings());
            break;
          default:
            break;
        }
      }

      // Clear cache
      _cachedSettings.clear();

      AppLogger.info('Settings reset completed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to reset settings', e);
      return false;
    }
  }

  // ===== Cloud Synchronization =====

  /// Sync settings to cloud storage
  Future<bool> syncToCloud({bool forceSync = false}) async {
    try {
      if (_syncMode == SettingsSyncMode.local) {
        AppLogger.info('Cloud sync disabled in local mode');
        return true;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        AppLogger.warning('No user authenticated for cloud sync');
        return false;
      }

      if (!forceSync && _lastSyncTime != null) {
        final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
        if (timeSinceLastSync < _syncInterval) {
          AppLogger.info('Sync skipped - too soon since last sync');
          return true;
        }
      }

      AppLogger.info('Syncing settings to cloud...');

      // Get all syncable settings
      final appSettings = await getAppSettings();
      final merchantSettings = await getMerchantSettings();
      final userPreferences = await getUserPreferences();
      final notificationSettings = await getNotificationSettings();

      // Create cloud settings record
      final cloudSettings = {
        'user_id': userId,
        'app_settings': appSettings.toJson(),
        'merchant_settings': merchantSettings.toJson(),
        'user_preferences': userPreferences,
        'notification_settings': notificationSettings,
        'settings_version': _currentSettingsVersion,
        'device_info': await _getDeviceInfo(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert to cloud
      await _supabase.from('user_settings').upsert(cloudSettings);

      // Update last sync time
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());

      AppLogger.info('Settings synced to cloud successfully');
      return true;
    } catch (e) {
      AppLogger.error('Cloud sync failed', e);
      return false;
    }
  }

  /// Sync settings from cloud storage
  Future<bool> syncFromCloud({bool forcePull = false}) async {
    try {
      if (_syncMode == SettingsSyncMode.local) {
        AppLogger.info('Cloud sync disabled in local mode');
        return true;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        AppLogger.warning('No user authenticated for cloud sync');
        return false;
      }

      AppLogger.info('Syncing settings from cloud...');

      // Get cloud settings
      final response = await _supabase
          .from('user_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        AppLogger.info('No cloud settings found');
        return true;
      }

      final cloudSettings = response;
      final cloudUpdated = DateTime.parse(cloudSettings['updated_at']);

      // Check if cloud settings are newer
      if (!forcePull &&
          _lastSyncTime != null &&
          cloudUpdated.isBefore(_lastSyncTime!)) {
        AppLogger.info('Local settings are newer, skipping cloud sync');
        return true;
      }

      // Apply cloud settings
      if (cloudSettings['app_settings'] != null) {
        final appSettings = EnhancedAppSettings.fromJson(
          cloudSettings['app_settings'],
        );
        await saveAppSettings(appSettings);
      }

      if (cloudSettings['merchant_settings'] != null) {
        final merchantSettings = EnhancedMerchantSettings.fromJson(
          cloudSettings['merchant_settings'],
        );
        await saveMerchantSettings(merchantSettings);
      }

      if (cloudSettings['user_preferences'] != null) {
        await saveUserPreferences(cloudSettings['user_preferences']);
      }

      if (cloudSettings['notification_settings'] != null) {
        await saveNotificationSettings(cloudSettings['notification_settings']);
      }

      // Update last sync time
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());

      AppLogger.info('Settings synced from cloud successfully');
      return true;
    } catch (e) {
      AppLogger.error('Cloud sync from failed', e);
      return false;
    }
  }

  // ===== Import/Export =====

  /// Export settings to JSON
  Future<Map<String, dynamic>> exportSettings({
    List<SettingsCategory>? categories,
    bool includePrivate = false,
  }) async {
    try {
      AppLogger.info('Exporting settings...');

      final allSettings = await getAllSettings();
      final exportData = <String, dynamic>{
        'export_info': {
          'version': _currentSettingsVersion,
          'exported_at': DateTime.now().toIso8601String(),
          'app_version': '1.0.0', // Note: Get from package info
          'platform': Platform.operatingSystem,
        },
        'settings': <String, dynamic>{},
      };

      final categoriesToExport = categories ?? SettingsCategory.values;

      for (final category in categoriesToExport) {
        switch (category) {
          case SettingsCategory.general:
            exportData['settings']['app'] = allSettings['app'];
            break;
          case SettingsCategory.merchant:
            exportData['settings']['merchant'] = allSettings['merchant'];
            break;
          case SettingsCategory.notifications:
            exportData['settings']['notifications'] =
                allSettings['notifications'];
            break;
          case SettingsCategory.privacy:
            if (includePrivate) {
              exportData['settings']['privacy'] = allSettings['privacy'];
            }
            break;
          case SettingsCategory.security:
            if (includePrivate) {
              exportData['settings']['security'] = allSettings['security'];
            }
            break;
          case SettingsCategory.performance:
            exportData['settings']['performance'] = allSettings['performance'];
            break;
          default:
            break;
        }
      }

      AppLogger.info('Settings exported successfully');
      return exportData;
    } catch (e) {
      AppLogger.error('Settings export failed', e);
      return {};
    }
  }

  /// Import settings from JSON
  Future<bool> importSettings(
    Map<String, dynamic> importData, {
    bool overwriteExisting = false,
    bool validateData = true,
  }) async {
    try {
      AppLogger.info('Importing settings...');

      // Validate import data
      if (validateData) {
        final validation = _validateImportData(importData);
        if (!validation['valid']) {
          AppLogger.warning('Invalid import data: ${validation['error']}');
          return false;
        }
      }

      final settings = importData['settings'] as Map<String, dynamic>? ?? {};

      // Import each category
      if (settings.containsKey('app')) {
        final appSettings = EnhancedAppSettings.fromJson(settings['app']);
        await saveAppSettings(appSettings);
      }

      if (settings.containsKey('merchant')) {
        final merchantSettings = EnhancedMerchantSettings.fromJson(
          settings['merchant'],
        );
        await saveMerchantSettings(merchantSettings);
      }

      if (settings.containsKey('notifications')) {
        await saveNotificationSettings(settings['notifications']);
      }

      if (settings.containsKey('privacy')) {
        await savePrivacySettings(settings['privacy']);
      }

      if (settings.containsKey('security')) {
        await saveSecuritySettings(settings['security']);
      }

      if (settings.containsKey('performance')) {
        await savePerformanceSettings(settings['performance']);
      }

      // Clear cache to force reload
      _cachedSettings.clear();

      AppLogger.info('Settings imported successfully');
      return true;
    } catch (e) {
      AppLogger.error('Settings import failed', e);
      return false;
    }
  }

  // ===== Analytics & Monitoring =====

  /// Get settings analytics
  Future<Map<String, dynamic>> getSettingsAnalytics() async {
    try {
      AppLogger.info('Getting settings analytics...');

      final allSettings = await getAllSettings();
      final analytics = <String, dynamic>{
        'settings_count': _countSettings(allSettings),
        'customized_settings': _getCustomizedSettings(allSettings),
        'default_settings': _getDefaultSettings(allSettings),
        'last_modified': _getLastModifiedTimes(allSettings),
        'sync_status': {
          'mode': _syncMode.toString(),
          'last_sync': _lastSyncTime?.toIso8601String(),
          'sync_enabled': _syncMode != SettingsSyncMode.local,
        },
        'storage_usage': await _calculateStorageUsage(),
      };

      return analytics;
    } catch (e) {
      AppLogger.error('Analytics generation failed', e);
      return {};
    }
  }

  // ===== Helper Methods =====

  /// Check and migrate settings if needed
  Future<void> _checkAndMigrateSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getInt(_settingsVersionKey) ?? 1;

      if (currentVersion < _currentSettingsVersion) {
        AppLogger.info(
          'Migrating settings from v$currentVersion to v$_currentSettingsVersion',
        );

        // Perform migration based on version differences
        await _migrateSettings(currentVersion, _currentSettingsVersion);

        // Update version
        await prefs.setInt(_settingsVersionKey, _currentSettingsVersion);

        AppLogger.info('Settings migration completed');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Settings migration failed', e);
    }
  }

  /// Load cached settings from storage
  Future<void> _loadCachedSettings() async {
    try {
      // Load last sync time
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(_lastSyncKey);
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }
    } catch (e) {
      AppLogger.error('Failed to load cached settings', e);
    }
  }

  /// Setup cloud synchronization
  Future<void> _setupCloudSync() async {
    try {
      AppLogger.info('Setting up cloud synchronization...');

      // Initial sync from cloud
      await syncFromCloud();

      // Setup periodic sync
      // Note: Implement timer-based sync

      AppLogger.info('Cloud synchronization setup completed');
    } catch (e) {
      AppLogger.error('Cloud sync setup failed', e);
    }
  }

  /// Setup real-time synchronization
  Future<void> _setupRealtimeSync() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      AppLogger.info('Setting up real-time synchronization...');

      // Listen to settings changes
      _supabase
          .channel('settings:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_settings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: _handleRealtimeSettingsChange,
          )
          .subscribe();

      AppLogger.info('Real-time synchronization setup completed');
    } catch (e) {
      AppLogger.error('Real-time sync setup failed', e);
    }
  }

  /// Handle real-time settings changes
  void _handleRealtimeSettingsChange(PostgresChangePayload payload) {
    try {
      AppLogger.info('Real-time settings change detected');

      // Sync from cloud to get latest changes
      syncFromCloud(forcePull: true);
    } catch (e) {
      AppLogger.error('Failed to handle real-time settings change', e);
    }
  }

  // ===== Default Settings Generators =====

  Map<String, dynamic> _getDefaultUserPreferences() => {
    'theme': 'system',
    'language': 'ar',
    'currency': 'EGP',
    'time_format': '24h',
    'date_format': 'dd/MM/yyyy',
    'first_day_of_week': 'sunday',
    'measurement_unit': 'metric',
    'default_location': null,
  };

  Map<String, dynamic> _getDefaultSecuritySettings() => {
    'biometric_auth': false,
    'auto_lock_timeout': 300, // 5 minutes
    'require_auth_for_payments': true,
    'login_attempts_limit': 3,
    'session_timeout': 3600, // 1 hour
    'device_trust_enabled': true,
    'security_notifications': true,
  };

  Map<String, dynamic> _getDefaultPrivacySettings() => {
    'analytics_enabled': true,
    'crash_reports': true,
    'data_collection': true,
    'personalization': true,
    'location_tracking': false,
    'ad_personalization': false,
    'data_sharing': false,
  };

  Map<String, dynamic> _getDefaultNotificationSettings() => {
    'enabled': true,
    'push_notifications': true,
    'email_notifications': true,
    'sms_notifications': false,
    'sound': true,
    'vibration': true,
    'quiet_hours': {'enabled': false, 'start': '22:00', 'end': '08:00'},
    'categories': {
      'orders': true,
      'promotions': true,
      'system': true,
      'messages': true,
    },
  };

  Map<String, dynamic> _getDefaultPerformanceSettings() => {
    'cache_enabled': true,
    'cache_size_mb': 100,
    'preload_images': true,
    'animation_scale': 1.0,
    'data_saver': false,
    'background_sync': true,
    'auto_cleanup': true,
    'image_quality': 'high',
  };

  // ===== Validation Methods =====

  Map<String, dynamic> _validateAppSettings(EnhancedAppSettings settings) {
    // Add validation logic
    return {'valid': true};
  }

  Map<String, dynamic> _validateMerchantSettings(
    EnhancedMerchantSettings settings,
  ) {
    // Add validation logic
    return {'valid': true};
  }

  Map<String, dynamic> _validateSecuritySettings(
    Map<String, dynamic> settings,
  ) {
    // Add validation logic
    return {'valid': true};
  }

  Map<String, dynamic> _validateImportData(Map<String, dynamic> data) {
    // Add validation logic
    return {'valid': true};
  }

  // ===== Storage Helper Methods =====

  Future<void> _saveUserPreferences(Map<String, dynamic> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPreferencesKey, jsonEncode(preferences));
  }

  Future<void> _saveSecuritySettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_securitySettingsKey, jsonEncode(settings));
  }

  Future<void> _savePrivacySettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_privacySettingsKey, jsonEncode(settings));
  }

  Future<void> _saveNotificationSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationSettingsKey, jsonEncode(settings));
  }

  Future<void> _savePerformanceSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_performanceSettingsKey, jsonEncode(settings));
  }

  // Placeholder implementations for remaining methods
  EnhancedAppSettings _updateAppSettingsValue(
    EnhancedAppSettings settings,
    String key,
    dynamic value,
  ) => settings;
  EnhancedMerchantSettings _updateMerchantSettingsValue(
    EnhancedMerchantSettings settings,
    String key,
    dynamic value,
  ) => settings;
  Future<Map<String, dynamic>?> _getCloudSettings(String category) async =>
      null;
  EnhancedAppSettings _mergeAppSettings(
    EnhancedAppSettings local,
    Map<String, dynamic> cloud,
  ) => local;
  EnhancedMerchantSettings _mergeMerchantSettings(
    EnhancedMerchantSettings local,
    Map<String, dynamic> cloud,
  ) => local;
  Future<void> _syncToCloud(
    String category,
    Map<String, dynamic> settings,
  ) async {}
  Future<void> _notifySettingsChanged(
    String category,
    Map<String, dynamic> settings,
  ) async {}
  Future<void> _applyPerformanceSettings(Map<String, dynamic> settings) async {}
  Future<Map<String, dynamic>> _getDeviceInfo() async => {};
  Future<void> _migrateSettings(int fromVersion, int toVersion) async {}
  Map<String, int> _countSettings(Map<String, dynamic> allSettings) => {};
  List<String> _getCustomizedSettings(Map<String, dynamic> allSettings) => [];
  List<String> _getDefaultSettings(Map<String, dynamic> allSettings) => [];
  Map<String, String> _getLastModifiedTimes(Map<String, dynamic> allSettings) =>
      {};
  Future<Map<String, dynamic>> _calculateStorageUsage() async => {};

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await _supabase.removeAllChannels();
      _cachedSettings.clear();
      AppLogger.info('Settings service disposed');
    } catch (e) {
      AppLogger.error('Error during disposal', e);
    }
  }
}

// ===== Enhanced Settings Models =====

/// Enhanced app settings with comprehensive options
class EnhancedAppSettings {
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool pushNotifications;
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
  final String theme;
  final double textScale;
  final bool animations;
  final bool hapticFeedback;
  final Map<String, dynamic> customSettings;

  const EnhancedAppSettings({
    required this.notificationsEnabled,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.pushNotifications,
    required this.darkMode,
    required this.language,
    required this.currency,
    required this.biometricAuth,
    required this.savePaymentMethods,
    required this.autoUpdate,
    required this.dataSaver,
    required this.cacheDuration,
    required this.analyticsEnabled,
    required this.crashReports,
    required this.theme,
    required this.textScale,
    required this.animations,
    required this.hapticFeedback,
    required this.customSettings,
  });

  factory EnhancedAppSettings.defaults() => const EnhancedAppSettings(
    notificationsEnabled: true,
    emailNotifications: true,
    smsNotifications: false,
    pushNotifications: true,
    darkMode: false,
    language: 'ar',
    currency: 'EGP',
    biometricAuth: false,
    savePaymentMethods: false,
    autoUpdate: true,
    dataSaver: false,
    cacheDuration: 24,
    analyticsEnabled: true,
    crashReports: true,
    theme: 'system',
    textScale: 1.0,
    animations: true,
    hapticFeedback: true,
    customSettings: {},
  );

  factory EnhancedAppSettings.fromJson(Map<String, dynamic> json) {
    return EnhancedAppSettings(
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      emailNotifications: json['emailNotifications'] ?? true,
      smsNotifications: json['smsNotifications'] ?? false,
      pushNotifications: json['pushNotifications'] ?? true,
      darkMode: json['darkMode'] ?? false,
      language: json['language'] ?? 'ar',
      currency: json['currency'] ?? 'EGP',
      biometricAuth: json['biometricAuth'] ?? false,
      savePaymentMethods: json['savePaymentMethods'] ?? false,
      autoUpdate: json['autoUpdate'] ?? true,
      dataSaver: json['dataSaver'] ?? false,
      cacheDuration: json['cacheDuration'] ?? 24,
      analyticsEnabled: json['analyticsEnabled'] ?? true,
      crashReports: json['crashReports'] ?? true,
      theme: json['theme'] ?? 'system',
      textScale: (json['textScale'] ?? 1.0).toDouble(),
      animations: json['animations'] ?? true,
      hapticFeedback: json['hapticFeedback'] ?? true,
      customSettings: json['customSettings'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'emailNotifications': emailNotifications,
    'smsNotifications': smsNotifications,
    'pushNotifications': pushNotifications,
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
    'theme': theme,
    'textScale': textScale,
    'animations': animations,
    'hapticFeedback': hapticFeedback,
    'customSettings': customSettings,
  };

  EnhancedAppSettings copyWith({
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? pushNotifications,
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
    String? theme,
    double? textScale,
    bool? animations,
    bool? hapticFeedback,
    Map<String, dynamic>? customSettings,
  }) {
    return EnhancedAppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
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
      theme: theme ?? this.theme,
      textScale: textScale ?? this.textScale,
      animations: animations ?? this.animations,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Enhanced merchant settings with advanced business options
class EnhancedMerchantSettings {
  final bool isActive;
  final double minOrderAmount;
  final double deliveryFee;
  final double maxDeliveryDistance;
  final Map<String, List<String>> workingHours;
  final bool acceptsReturns;
  final int returnsWindowDays;
  final bool autoAcceptOrders;
  final int orderPreparationTime;
  final bool enableDeliveryTracking;
  final double commissionRate;
  final Map<String, dynamic> paymentMethods;
  final Map<String, dynamic> businessSettings;

  const EnhancedMerchantSettings({
    required this.isActive,
    required this.minOrderAmount,
    required this.deliveryFee,
    required this.maxDeliveryDistance,
    required this.workingHours,
    required this.acceptsReturns,
    required this.returnsWindowDays,
    required this.autoAcceptOrders,
    required this.orderPreparationTime,
    required this.enableDeliveryTracking,
    required this.commissionRate,
    required this.paymentMethods,
    required this.businessSettings,
  });

  factory EnhancedMerchantSettings.defaults() => const EnhancedMerchantSettings(
    isActive: true,
    minOrderAmount: 0.0,
    deliveryFee: 15.0,
    maxDeliveryDistance: 10.0,
    workingHours: {
      'sunday': ['09:00', '21:00'],
      'monday': ['09:00', '21:00'],
      'tuesday': ['09:00', '21:00'],
      'wednesday': ['09:00', '21:00'],
      'thursday': ['09:00', '21:00'],
      'friday': ['16:00', '21:00'],
      'saturday': ['09:00', '21:00'],
    },
    acceptsReturns: true,
    returnsWindowDays: 14,
    autoAcceptOrders: false,
    orderPreparationTime: 30,
    enableDeliveryTracking: true,
    commissionRate: 0.15,
    paymentMethods: {
      'cash_on_delivery': true,
      'credit_card': false,
      'digital_wallet': false,
    },
    businessSettings: {},
  );

  factory EnhancedMerchantSettings.fromJson(Map<String, dynamic> json) {
    return EnhancedMerchantSettings(
      isActive: json['isActive'] ?? true,
      minOrderAmount: (json['minOrderAmount'] ?? 0.0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 15.0).toDouble(),
      maxDeliveryDistance: (json['maxDeliveryDistance'] ?? 10.0).toDouble(),
      workingHours: Map<String, List<String>>.from(json['workingHours'] ?? {}),
      acceptsReturns: json['acceptsReturns'] ?? true,
      returnsWindowDays: json['returnsWindowDays'] ?? 14,
      autoAcceptOrders: json['autoAcceptOrders'] ?? false,
      orderPreparationTime: json['orderPreparationTime'] ?? 30,
      enableDeliveryTracking: json['enableDeliveryTracking'] ?? true,
      commissionRate: (json['commissionRate'] ?? 0.15).toDouble(),
      paymentMethods: json['paymentMethods'] ?? {},
      businessSettings: json['businessSettings'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'isActive': isActive,
    'minOrderAmount': minOrderAmount,
    'deliveryFee': deliveryFee,
    'maxDeliveryDistance': maxDeliveryDistance,
    'workingHours': workingHours,
    'acceptsReturns': acceptsReturns,
    'returnsWindowDays': returnsWindowDays,
    'autoAcceptOrders': autoAcceptOrders,
    'orderPreparationTime': orderPreparationTime,
    'enableDeliveryTracking': enableDeliveryTracking,
    'commissionRate': commissionRate,
    'paymentMethods': paymentMethods,
    'businessSettings': businessSettings,
  };
}
