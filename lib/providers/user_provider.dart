import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // ================= Getters =================
  List<UserModel> get users => _filteredUsers.isNotEmpty ? _filteredUsers : _users;
  List<UserModel> get allUsers => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // ================= User Management =================

  Future<void> fetchAllUsers() async {
    _setLoading(true);
    try {
      _users = await _userService.getAllUsers();
      _applyFilters();
      _setError(null);
    } catch (e) {
      _setError('فشل تحميل المستخدمين: ${e.toString()}');
      _users = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      return await _userService.getUserById(userId);
    } catch (e) {
      _setError('فشل تحميل بيانات المستخدم: ${e.toString()}');
      return null;
    }
  }

  Future<bool> addUser(UserModel user, String password) async {
    _setLoading(true);
    try {
      final newUser = await _userService.createUser(user, password);
      if (newUser != null) {
        _users.add(newUser);
        _applyFilters();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل إضافة المستخدم: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUser(UserModel user) async {
    _setLoading(true);
    try {
      final success = await _userService.updateUser(user);
      if (success) {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = user;
          _applyFilters();
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تحديث المستخدم: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteUser(String userId) async {
    _setLoading(true);
    try {
      final success = await _userService.deleteUser(userId);
      if (success) {
        _users.removeWhere((user) => user.id == userId);
        _applyFilters();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل حذف المستخدم: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ================= Filtering & Searching =================

  void searchUsers(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredUsers = [];
    notifyListeners();
  }

  void filterByType(UserType? type) {
    if (type == null) {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users.where((user) => user.type == type).toList();
    }
    notifyListeners();
  }

  void filterByStatus(bool? isActive) {
    if (isActive == null) {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users.where((user) => user.isActive == isActive).toList();
    }
    notifyListeners();
  }

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = _users;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredUsers = _users.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.phone.toLowerCase().contains(query) ||
            _getUserTypeArabic(user.type).contains(query);
      }).toList();
    }
    notifyListeners();
  }

  // ================= User Types Helpers =================

  List<UserModel> get customers => _users.where((user) => user.type == UserType.customer).toList();
  List<UserModel> get merchants => _users.where((user) => user.type == UserType.merchant).toList();
  List<UserModel> get captains => _users.where((user) => user.type == UserType.captain).toList();
  List<UserModel> get admins => _users.where((user) => user.type == UserType.admin).toList();

  List<UserModel> get activeUsers => _users.where((user) => user.isActive).toList();
  List<UserModel> get inactiveUsers => _users.where((user) => !user.isActive).toList();

  String _getUserTypeArabic(UserType type) {
    switch (type) {
      case UserType.customer:
        return 'عميل';
      case UserType.merchant:
        return 'تاجر';
      case UserType.captain:
        return 'كابتن';
      case UserType.admin:
        return 'مسؤول';
    }
  }

  // ================= Statistics =================

  Map<String, int> getUsersStatistics() {
    return {
      'total': _users.length,
      'customers': customers.length,
      'merchants': merchants.length,
      'captains': captains.length,
      'admins': admins.length,
      'active': activeUsers.length,
      'inactive': inactiveUsers.length,
    };
  }

  Map<String, int> getDailyRegistrations() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dailyUsers = _users.where((user) {
      final userDate = DateTime(user.createdAt.year, user.createdAt.month, user.createdAt.day);
      return userDate.isAtSameMomentAs(today);
    }).length;

    return {'today': dailyUsers};
  }

  // ================= User Actions =================

  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    final user = _users.firstWhere((u) => u.id == userId);
    final updatedUser = user.copyWith(isActive: isActive);
    return await updateUser(updatedUser);
  }

  Future<bool> changeUserType(String userId, UserType newType) async {
    final user = _users.firstWhere((u) => u.id == userId);
    final updatedUser = user.copyWith(type: newType);
    return await updateUser(updatedUser);
  }

  Future<bool> updateUserProfile(String userId, {
    required String name,
    required String phone,
    String? avatarUrl,
  }) async {
    final user = _users.firstWhere((u) => u.id == userId);
    final updatedUser = user.copyWith(
      name: name,
      phone: phone,
      avatarUrl: avatarUrl,
    );
    return await updateUser(updatedUser);
  }

  Future<bool> updateUserImage(String userId, File imageFile) async {
    try {
      final imageUrl = await _userService.uploadProfileImage(userId, imageFile);
      if (imageUrl != null) {
        // Update local user model
        final user = await getUserById(userId);
        if (user != null) {
          final index = _users.indexWhere((u) => u.id == userId);
          if (index != -1) {
            _users[index] = user;
            notifyListeners();
          }
        }
        return true;
      }
      return false;
    } catch (e) {
      _setError('فشل تحديث صورة الملف الشخصي: ${e.toString()}');
      return false;
    }
  }

  // ================= Password Management =================

  Future<bool> resetUserPassword(String email) async {
    try {
      return await _userService.resetPassword(email);
    } catch (e) {
      _setError('فشل إعادة تعيين كلمة المرور: ${e.toString()}');
      return false;
    }
  }

  // ================= State Management =================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void refresh() {
    _applyFilters();
    notifyListeners();
  }

  // ================= Validation =================

  bool isEmailUnique(String email, {String? excludeUserId}) {
    return !_users.any((user) =>
    user.email.toLowerCase() == email.toLowerCase() &&
        user.id != excludeUserId
    );
  }

  bool isPhoneUnique(String phone, {String? excludeUserId}) {
    return !_users.any((user) =>
    user.phone == phone &&
        user.id != excludeUserId
    );
  }

  // ================= Export & Import =================

  Future<void> exportUsersToCsv() async {
    // TODO: تنفيذ تصدير البيانات إلى CSV
  }

  Future<void> importUsersFromCsv(String filePath) async {
    // TODO: تنفيذ استيراد البيانات من CSV
  }

  // ================= Listen to Real-time Updates =================

  void listenToUsersUpdates() {
    final channel = _userService.getUsersStream();
    channel.subscribe((status, payload) {
      if (status == 'SUBSCRIBED' && payload != null) {
        fetchAllUsers(); // Refresh the users list when we get an update
      }
    });
  }

  // ================= Cleanup =================

  @override
  void dispose() {
    // تنظيف أي listeners أو streams
    super.dispose();
  }
}