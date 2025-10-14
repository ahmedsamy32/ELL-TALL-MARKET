import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/Profile_model.dart';
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
      Provider.of<SupabaseProvider>(context, listen: false).fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<SupabaseProvider>(context);

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
  Widget _buildStatsRow(SupabaseProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("إجمالي", provider.allUsers.length, Colors.blue),
          _buildStatCard(
            "عملاء",
            provider.allUsers.where((u) => u.role == UserRole.client).length,
            Colors.green,
          ),
          _buildStatCard(
            "تجار",
            provider.allUsers.where((u) => u.role == UserRole.merchant).length,
            Colors.orange,
          ),
          _buildStatCard(
            "كباتن",
            provider.allUsers.where((u) => u.role == UserRole.captain).length,
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
  Widget _buildSearchAndFilterBar(SupabaseProvider provider) {
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
  Widget _buildUsersList(SupabaseProvider provider) {
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
            !(user.fullName?.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ) ??
                false)) {
          return const SizedBox.shrink();
        }
        return _buildUserCard(user);
      },
    );
  }

  List<ProfileModel> _filterUsers(List<ProfileModel> users) {
    if (_selectedFilter == 'all') return users;

    return users.where((user) {
      switch (_selectedFilter) {
        case 'customer':
          return user.role == UserRole.client;
        case 'merchant':
          return user.role == UserRole.merchant;
        case 'captain':
          return user.role == UserRole.captain;
        default:
          return true;
      }
    }).toList();
  }

  /// 🔹 بطاقة المستخدم
  Widget _buildUserCard(ProfileModel user) {
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
          user.fullName ?? 'بدون اسم',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email ?? 'بدون بريد',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              user.phone ?? 'بدون هاتف',
              style: const TextStyle(color: Colors.black45),
            ),
            Chip(
              label: Text(
                _getUserTypeText(user.role),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: _getUserTypeColor(user.role),
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

  String _getUserTypeText(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'عميل';
      case UserRole.merchant:
        return 'تاجر';
      case UserRole.captain:
        return 'كابتن';
      case UserRole.admin:
        return 'مدير';
    }
  }

  Color _getUserTypeColor(UserRole role) {
    switch (role) {
      case UserRole.client:
        return AppColors.primary;
      case UserRole.merchant:
        return AppColors.success;
      case UserRole.captain:
        return AppColors.warning;
      case UserRole.admin:
        return AppColors.danger;
    }
  }

  /// 🔹 تعديل المستخدم
  void _editUser(ProfileModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('تعديل المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                initialValue: user.fullName,
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
  void _toggleUserStatus(ProfileModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(user.isActive ? 'تعطيل المستخدم' : 'تفعيل المستخدم'),
        content: Text(
          'هل أنت متأكد من ${user.isActive ? 'تعطيل' : 'تفعيل'} المستخدم ${user.fullName ?? 'بدون اسم'}؟',
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
