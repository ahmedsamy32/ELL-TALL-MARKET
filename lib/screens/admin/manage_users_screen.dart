import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/widgets/custom_search_bar.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  _ManageUsersScreenState createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        centerTitle: true,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildStatsRow(authProvider),
          _buildSearchAndFilterBar(authProvider),
          Expanded(child: _buildUsersList(authProvider)),
        ],
      ),
    );
  }

  /// 🔹 بطاقات إحصائيات سريعة
  Widget _buildStatsRow(AuthProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("إجمالي", provider.allUsers.length, Colors.blue),
          _buildStatCard(
            "عملاء",
            provider.allUsers.where((u) => u.type == UserType.customer).length,
            Colors.green,
          ),
          _buildStatCard(
            "تجار",
            provider.allUsers.where((u) => u.type == UserType.merchant).length,
            Colors.orange,
          ),
          _buildStatCard(
            "كباتن",
            provider.allUsers.where((u) => u.type == UserType.captain).length,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 البحث والفلاتر
  Widget _buildSearchAndFilterBar(AuthProvider provider) {
    return AdminSearchBar(
      controller: _searchController,
      hintText: 'ابحث باسم المستخدم أو البريد',
      onChanged: (value) {
        setState(() {}); // تحديث واجهة البحث
      },
      filterChips: [
        _buildFilterChip('الكل', 'all'),
        _buildFilterChip('عملاء', 'customer'),
        _buildFilterChip('تجار', 'merchant'),
        _buildFilterChip('كباتن', 'captain'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == filter,
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  /// 🔹 قائمة المستخدمين
  Widget _buildUsersList(AuthProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.allUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا يوجد مستخدمين', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    final filteredUsers = _filterUsers(provider.allUsers);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        if (_searchController.text.isNotEmpty &&
            !user.name.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            )) {
          return const SizedBox.shrink();
        }
        return _buildUserCard(user);
      },
    );
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    if (_selectedFilter == 'all') return users;

    return users.where((user) {
      switch (_selectedFilter) {
        case 'customer':
          return user.type == UserType.customer;
        case 'merchant':
          return user.type == UserType.merchant;
        case 'captain':
          return user.type == UserType.captain;
        default:
          return true;
      }
    }).toList();
  }

  /// 🔹 بطاقة المستخدم
  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : const AssetImage('assets/images/default_avatar.png')
                    as ImageProvider,
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: const TextStyle(color: Colors.black54)),
            Text(user.phone, style: const TextStyle(color: Colors.black45)),
            Chip(
              label: Text(
                _getUserTypeText(user.type),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: _getUserTypeColor(user.type),
            ),
          ],
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editUser(user),
            ),
            IconButton(
              icon: Icon(
                user.isActive ? Icons.block : Icons.check_circle,
                color: user.isActive ? Colors.red : Colors.green,
              ),
              onPressed: () => _toggleUserStatus(user),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserTypeText(UserType type) {
    switch (type) {
      case UserType.customer:
        return 'عميل';
      case UserType.merchant:
        return 'تاجر';
      case UserType.captain:
        return 'كابتن';
      case UserType.admin:
        return 'مدير';
    }
  }

  Color _getUserTypeColor(UserType type) {
    switch (type) {
      case UserType.customer:
        return AppColors.primary;
      case UserType.merchant:
        return AppColors.success;
      case UserType.captain:
        return AppColors.warning;
      case UserType.admin:
        return AppColors.danger;
    }
  }

  /// 🔹 تعديل المستخدم
  void _editUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('تعديل المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                initialValue: user.name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextFormField(
                initialValue: user.email,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
              ),
              TextFormField(
                initialValue: user.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              // TODO: حفظ التعديلات
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// 🔹 تفعيل / تعطيل المستخدم
  void _toggleUserStatus(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(user.isActive ? 'تعطيل المستخدم' : 'تفعيل المستخدم'),
        content: Text(
          'هل أنت متأكد من ${user.isActive ? 'تعطيل' : 'تفعيل'} المستخدم ${user.name}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            onPressed: () {
              Navigator.pop(context);
              // TODO: تنفيذ تغيير الحالة
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
