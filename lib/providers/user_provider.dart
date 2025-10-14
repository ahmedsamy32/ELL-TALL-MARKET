/// User Provider
library;

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/Profile_model.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUsers({UserRole? role}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _users = await UserService.getAllUsers(role: role);
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      return await UserService.updateUser(user);
    } catch (e) {
      _error = 'Error: $e';
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      final success = await UserService.deleteUser(userId);
      if (success) {
        _users.removeWhere((u) => u.id == userId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    }
  }
}
