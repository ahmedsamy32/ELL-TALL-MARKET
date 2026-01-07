import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _keyPrefix = 'search_history_';
  static const int _maxHistoryItems = 10;

  /// حفظ عملية بحث جديدة
  Future<void> saveSearch(String userId, String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';

    // جلب السجل الحالي
    List<String> history = prefs.getStringList(key) ?? [];

    // إزالة البحث إذا كان موجوداً مسبقاً
    history.remove(query.trim());

    // إضافة البحث في البداية
    history.insert(0, query.trim());

    // الاحتفاظ بآخر 10 عمليات بحث فقط
    if (history.length > _maxHistoryItems) {
      history = history.sublist(0, _maxHistoryItems);
    }

    // حفظ السجل المحدث
    await prefs.setStringList(key, history);
  }

  /// جلب سجل البحث
  Future<List<String>> getSearchHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';
    return prefs.getStringList(key) ?? [];
  }

  /// حذف عملية بحث معينة
  Future<void> removeSearch(String userId, String query) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';

    List<String> history = prefs.getStringList(key) ?? [];
    history.remove(query);

    await prefs.setStringList(key, history);
  }

  /// مسح كل سجل البحث
  Future<void> clearHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';
    await prefs.remove(key);
  }
}
