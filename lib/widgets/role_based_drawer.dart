import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/Profile_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

class RoleBasedDrawer extends StatelessWidget {
  const RoleBasedDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUserProfile;

        if (user == null || !authProvider.isLoggedIn) {
          return _buildGuestDrawer(context);
        }

        return _buildAuthenticatedDrawer(context, user);
      },
    );
  }

  // =====================================================
  // Guest Drawer (Not Logged In)
  // =====================================================

  Widget _buildGuestDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 30, color: AppColors.primary),
                ),
                SizedBox(height: 10),
                Text(
                  'مرحباً بك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'قم بتسجيل الدخول للاستفادة من جميع المميزات',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Guest Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerTile(
                  context,
                  title: 'تسجيل الدخول',
                  icon: Icons.login,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.login),
                ),
                _buildDrawerTile(
                  context,
                  title: 'إنشاء حساب',
                  icon: Icons.person_add,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                ),
                const Divider(),
                _buildDrawerTile(
                  context,
                  title: 'الرئيسية',
                  icon: Icons.home,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.home),
                ),
                _buildDrawerTile(
                  context,
                  title: 'البحث',
                  icon: Icons.search,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.search),
                ),
                _buildDrawerTile(
                  context,
                  title: 'المتاجر',
                  icon: Icons.store,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.stores),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Authenticated User Drawer
  // =====================================================

  Widget _buildAuthenticatedDrawer(BuildContext context, ProfileModel user) {
    return Drawer(
      child: Column(
        children: [
          // User Header
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getRoleColor(user.role),
                  _getRoleColor(user.role).withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Icon(
                          _getRoleIcon(user.role),
                          size: 30,
                          color: _getRoleColor(user.role),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  user.fullName ?? 'مستخدم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRoleDisplayName(user.role),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Role-specific dashboard (if not customer)
                if (user.role != UserRole.client) ...[
                  _buildDrawerTile(
                    context,
                    title: _getDashboardTitle(user.role),
                    icon: _getRoleIcon(user.role),
                    isSpecial: true,
                    onTap: () => _navigateToDashboard(context, user.role),
                  ),
                  const Divider(),
                ],

                // Common navigation items
                _buildDrawerTile(
                  context,
                  title: 'الرئيسية',
                  icon: Icons.home,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.home),
                ),
                _buildDrawerTile(
                  context,
                  title: 'المتاجر',
                  icon: Icons.store,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.stores),
                ),
                _buildDrawerTile(
                  context,
                  title: 'السلة',
                  icon: Icons.shopping_cart,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
                ),
                _buildDrawerTile(
                  context,
                  title: 'الملف الشخصي',
                  icon: Icons.person,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                ),

                const Divider(),

                // Settings and logout
                _buildDrawerTile(
                  context,
                  title: 'الإعدادات',
                  icon: Icons.settings,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
                _buildDrawerTile(
                  context,
                  title: 'تسجيل الخروج',
                  icon: Icons.logout,
                  isLogout: true,
                  onTap: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Helper Widgets
  // =====================================================

  Widget _buildDrawerTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isSpecial = false,
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isLogout
            ? Colors.red
            : isSpecial
            ? AppColors.primary
            : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout
              ? Colors.red
              : isSpecial
              ? AppColors.primary
              : Colors.black87,
          fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
      tileColor: isSpecial ? AppColors.primary.withValues(alpha: 0.1) : null,
    );
  }

  // =====================================================
  // Helper Methods
  // =====================================================

  Color _getRoleColor(UserRole userRole) {
    switch (userRole) {
      case UserRole.admin:
        return Colors.red.shade700;
      case UserRole.merchant:
        return Colors.orange.shade700;
      case UserRole.captain:
        return Colors.blue.shade700;
      case UserRole.client:
        return AppColors.primary;
    }
  }

  IconData _getRoleIcon(UserRole userRole) {
    switch (userRole) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.merchant:
        return Icons.store_mall_directory;
      case UserRole.captain:
        return Icons.delivery_dining;
      case UserRole.client:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(UserRole userRole) {
    switch (userRole) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.merchant:
        return 'تاجر';
      case UserRole.captain:
        return 'كابتن';
      case UserRole.client:
        return 'عميل';
    }
  }

  String _getDashboardTitle(UserRole userRole) {
    switch (userRole) {
      case UserRole.admin:
        return 'لوحة تحكم المدير';
      case UserRole.merchant:
        return 'لوحة تحكم التاجر';
      case UserRole.captain:
        return 'لوحة تحكم الكابتن';
      case UserRole.client:
        return 'الملف الشخصي';
    }
  }

  void _navigateToDashboard(BuildContext context, UserRole userRole) {
    String route;
    switch (userRole) {
      case UserRole.admin:
        route = AppRoutes.adminDashboard;
        break;
      case UserRole.merchant:
        route = AppRoutes.merchantDashboard;
        break;
      case UserRole.captain:
        route = AppRoutes.captainDashboard;
        break;
      case UserRole.client:
        route = AppRoutes.profile;
        break;
    }

    Navigator.pushNamed(context, route);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final authProvider = Provider.of<SupabaseProvider>(
                context,
                listen: false,
              );

              await authProvider.signOut();

              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
