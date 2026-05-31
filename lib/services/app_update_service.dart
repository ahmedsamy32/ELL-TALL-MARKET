import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logger.dart';

class AppUpdateInfo {
  final String platform;
  final String latestVersion;
  final String? minSupportedVersion;
  final String updateUrl;
  final String? title;
  final String? message;
  final bool forceUpdate;
  final bool isActive;

  const AppUpdateInfo({
    required this.platform,
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.updateUrl,
    required this.title,
    required this.message,
    required this.forceUpdate,
    required this.isActive,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> map) {
    return AppUpdateInfo(
      platform: map['platform'] as String? ?? 'android',
      latestVersion: map['latest_version'] as String? ?? '',
      minSupportedVersion: map['min_supported_version'] as String?,
      updateUrl: map['update_url'] as String? ?? '',
      title: map['title'] as String?,
      message: map['message'] as String?,
      forceUpdate: map['force_update'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class AppUpdatePrompt {
  final AppUpdateInfo info;
  final String currentVersion;
  final bool isForce;

  const AppUpdatePrompt({
    required this.info,
    required this.currentVersion,
    required this.isForce,
  });
}

class AppUpdateService {
  static AppUpdateService? _instance;
  static AppUpdateService get instance =>
      _instance ??= AppUpdateService._internal();

  AppUpdateService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _dismissedVersionKey = 'app_update_dismissed_version';

  Future<AppUpdateInfo?> fetchLatestUpdate() async {
    try {
      final platform = _resolvePlatform();
      final row = await _supabase
          .from('app_updates')
          .select()
          .eq('platform', platform)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) {
        final fallback = await _supabase
            .from('app_updates')
            .select()
            .eq('platform', 'all')
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (fallback == null) return null;
        return AppUpdateInfo.fromMap(Map<String, dynamic>.from(fallback));
      }

      return AppUpdateInfo.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      AppLogger.error('❌ Failed to fetch app update info', e);
      return null;
    }
  }

  Future<AppUpdatePrompt?> checkForUpdate() async {
    try {
      final info = await fetchLatestUpdate();
      if (info == null || !info.isActive) return null;

      final latestVersion = info.latestVersion.trim();
      if (latestVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      if (_compareVersions(currentVersion, latestVersion) >= 0) {
        return null;
      }

      final bool isForce =
          info.forceUpdate ||
          (info.minSupportedVersion != null &&
              info.minSupportedVersion!.trim().isNotEmpty &&
              _compareVersions(
                    currentVersion,
                    info.minSupportedVersion!.trim(),
                  ) <
                  0);

      if (!isForce) {
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getString(_dismissedVersionKey);
        if (dismissed != null && dismissed == latestVersion) {
          return null;
        }
      }

      return AppUpdatePrompt(
        info: info,
        currentVersion: currentVersion,
        isForce: isForce,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to check for app update', e);
      return null;
    }
  }

  Future<void> markDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  int _compareVersions(String a, String b) {
    final aParts = _parseVersionParts(a);
    final bParts = _parseVersionParts(b);
    final maxLen = max(aParts.length, bParts.length);
    for (var i = 0; i < maxLen; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal != bVal) return aVal.compareTo(bVal);
    }
    return 0;
  }

  List<int> _parseVersionParts(String version) {
    final clean = version.split(RegExp(r'[+\-]')).first;
    return clean.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }
}
