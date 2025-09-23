import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageHelper {
  // Singleton
  static final StorageHelper _instance = StorageHelper._internal();
  factory StorageHelper() => _instance;
  StorageHelper._internal();

  // Secure Storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  // SharedPreferences Getter
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ================= Secure Storage Methods =================
  Future<void> setSecureValue(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      throw Exception('فشل حفظ القيمة الآمنة: ${e.toString()}');
    }
  }

  Future<String?> getSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      throw Exception('فشل قراءة القيمة الآمنة: ${e.toString()}');
    }
  }

  Future<void> deleteSecureValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      throw Exception('فشل حذف القيمة الآمنة: ${e.toString()}');
    }
  }

  Future<void> clearSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw Exception('فشل مسح التخزين الآمن: ${e.toString()}');
    }
  }

  // ================= Shared Preferences Methods =================
  Future<void> setValue(String key, dynamic value) async {
    try {
      final prefs = await _preferences;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        throw Exception('نوع القيمة غير مدعوم');
      }
    } catch (e) {
      throw Exception('فشل حفظ القيمة: ${e.toString()}');
    }
  }

  Future<dynamic> getValue(String key, {dynamic defaultValue}) async {
    try {
      final prefs = await _preferences;
      return prefs.get(key) ?? defaultValue;
    } catch (e) {
      throw Exception('فشل قراءة القيمة: ${e.toString()}');
    }
  }

  Future<String?> getString(String key, {String? defaultValue}) async {
    try {
      final prefs = await _preferences;
      return prefs.getString(key) ?? defaultValue;
    } catch (e) {
      throw Exception('فشل قراءة النص: ${e.toString()}');
    }
  }

  Future<int?> getInt(String key, {int? defaultValue}) async {
    try {
      final prefs = await _preferences;
      return prefs.getInt(key) ?? defaultValue;
    } catch (e) {
      throw Exception('فشل قراءة الرقم الصحيح: ${e.toString()}');
    }
  }

  Future<double?> getDouble(String key, {double? defaultValue}) async {
    try {
      final prefs = await _preferences;
      return prefs.getDouble(key) ?? defaultValue;
    } catch (e) {
      throw Exception('فشل قراءة الرقم العشري: ${e.toString()}');
    }
  }

  Future<bool?> getBool(String key, {bool? defaultValue}) async {
    try {
      final prefs = await _preferences;
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      throw Exception('فشل قراءة القيمة المنطقية: ${e.toString()}');
    }
  }

  Future<List<String>?> getStringList(String key, {List<String>? defaultValue}) async {
    try {
      final prefs = await _preferences;
      return prefs.getStringList(key) ?? defaultValue;
    } catch (e) {
      throw Exception('فشل قراءة قائمة النصوص: ${e.toString()}');
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      final prefs = await _preferences;
      return prefs.containsKey(key);
    } catch (e) {
      throw Exception('فشل التحقق من وجود المفتاح: ${e.toString()}');
    }
  }

  Future<void> removeValue(String key) async {
    try {
      final prefs = await _preferences;
      await prefs.remove(key);
    } catch (e) {
      throw Exception('فشل حذف القيمة: ${e.toString()}');
    }
  }

  Future<void> clearStorage() async {
    try {
      final prefs = await _preferences;
      await prefs.clear();
    } catch (e) {
      throw Exception('فشل مسح التخزين: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getAllValues() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys();
      final Map<String, dynamic> values = {};

      for (String key in keys) {
        values[key] = prefs.get(key);
      }

      return values;
    } catch (e) {
      throw Exception('فشل قراءة جميع القيم: ${e.toString()}');
    }
  }

  // ================= Complex Data Types =================
  Future<void> setMap(String key, Map<String, dynamic> map) async {
    try {
      final jsonString = json.encode(map);
      await setValue(key, jsonString);
    } catch (e) {
      throw Exception('فشل حفظ الخريطة: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getMap(String key) async {
    try {
      final jsonString = await getString(key);
      if (jsonString != null) {
        return Map<String, dynamic>.from(json.decode(jsonString));
      }
      return null;
    } catch (e) {
      throw Exception('فشل قراءة الخريطة: ${e.toString()}');
    }
  }

  Future<void> setList(String key, List<dynamic> list) async {
    try {
      final jsonString = json.encode(list);
      await setValue(key, jsonString);
    } catch (e) {
      throw Exception('فشل حفظ القائمة: ${e.toString()}');
    }
  }

  Future<List<dynamic>?> getList(String key) async {
    try {
      final jsonString = await getString(key);
      if (jsonString != null) {
        return List<dynamic>.from(json.decode(jsonString));
      }
      return null;
    } catch (e) {
      throw Exception('فشل قراءة القائمة: ${e.toString()}');
    }
  }

  // ================= Authentication Tokens =================
  Future<void> setAuthToken(String token) async {
    await setSecureValue('auth_token', token);
  }

  Future<String?> getAuthToken() async {
    return await getSecureValue('auth_token');
  }

  Future<void> removeAuthToken() async {
    await deleteSecureValue('auth_token');
  }

  // ================= User Data =================
  Future<void> setUserData(Map<String, dynamic> userData) async {
    await setMap('user_data', userData);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    return await getMap('user_data');
  }

  Future<void> removeUserData() async {
    await removeValue('user_data');
  }
}
