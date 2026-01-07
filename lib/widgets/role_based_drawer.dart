import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/screens/admin/app_settings_screen.dart';

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
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerLow,
              ],
            ),
          ),
          child: Column(
            children: [
              // Modern Guest Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'أهلاً بك في التل ماركت',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'قم بتسجيل الدخول للاستفادة من جميع المميزات',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Guest Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Auth Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.1),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildModernDrawerTile(
                            context,
                            title: 'تسجيل الدخول',
                            icon: Icons.login_rounded,
                            color: AppColors.primary,
                            subtitle: 'الدخول إلى حسابك',
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.login),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _buildModernDrawerTile(
                            context,
                            title: 'إنشاء حساب جديد',
                            icon: Icons.person_add_rounded,
                            color: Colors.green,
                            subtitle: 'انضم إلينا الآن',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.register,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Navigation Section
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildModernDrawerTile(
                            context,
                            title: 'الرئيسية',
                            icon: Icons.home_rounded,
                            color: Colors.blue,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.home),
                          ),
                          _buildModernDrawerTile(
                            context,
                            title: 'البحث عن المنتجات',
                            icon: Icons.search_rounded,
                            color: Colors.purple,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.search),
                          ),
                          _buildModernDrawerTile(
                            context,
                            title: 'استكشف المتاجر',
                            icon: Icons.store_rounded,
                            color: Colors.orange,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.stores),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // Authenticated User Drawer
  // =====================================================

  Widget _buildAuthenticatedDrawer(BuildContext context, ProfileModel user) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerLow,
              ],
            ),
          ),
          child: Column(
            children: [
              // Modern User Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getRoleColor(user.role),
                      _getRoleColor(user.role).withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _getRoleColor(user.role).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with Status Badge
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? Icon(
                                    _getRoleIcon(user.role),
                                    size: 40,
                                    color: _getRoleColor(user.role),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getRoleIcon(user.role),
                              size: 14,
                              color: _getRoleColor(user.role),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // User Name
                    Text(
                      user.fullName ?? 'مستخدم',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRoleIcon(user.role),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getRoleDisplayName(user.role),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Role-specific dashboard (if not customer)
                    if (user.role != UserRole.client) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getRoleColor(user.role).withValues(alpha: 0.15),
                              _getRoleColor(user.role).withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _getRoleColor(
                              user.role,
                            ).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getRoleColor(
                                user.role,
                              ).withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _navigateToDashboard(context, user.role),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(user.role),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getRoleColor(
                                            user.role,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _getRoleIcon(user.role),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getDashboardTitle(user.role),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: _getRoleColor(user.role),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'إدارة حسابك وأعمالك',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: _getRoleColor(user.role),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Main Navigation Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildModernDrawerTile(
                            context,
                            title: 'الرئيسية',
                            icon: Icons.home_rounded,
                            color: Colors.blue,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.home),
                          ),
                          _buildModernDrawerTile(
                            context,
                            title: 'استكشف المتاجر',
                            icon: Icons.store_rounded,
                            color: Colors.purple,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.stores),
                          ),
                          _buildModernDrawerTile(
                            context,
                            title: 'سلة التسوق',
                            icon: Icons.shopping_cart_rounded,
                            color: Colors.orange,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.cart),
                          ),
                          _buildModernDrawerTile(
                            context,
                            title: 'الملف الشخصي',
                            icon: Icons.person_rounded,
                            color: Colors.teal,
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.profile),
                          ),
                        ],
                      ),
                    ),

                    // Settings and Account Section
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildModernDrawerTile(
                            context,
                            title: 'الإعدادات',
                            icon: Icons.settings_rounded,
                            color: Colors.blueGrey,
                            subtitle: 'تخصيص التطبيق',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppSettingsScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showLogoutDialog(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.logout_rounded,
                                        color: Colors.red,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'تسجيل الخروج',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'الخروج من الحساب',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // Helper Widgets
  // =====================================================

  Widget _buildModernDrawerTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close drawer
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
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
        return 'مستخدم';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'تسجيل الخروج',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final authProvider = Provider.of<SupabaseProvider>(
                context,
                listen: false,
              );

              // Get all providers to clear their data on sign out
              final merchantProvider = Provider.of<MerchantProvider>(
                context,
                listen: false,
              );
              final productProvider = Provider.of<ProductProvider>(
                context,
                listen: false,
              );
              final orderProvider = Provider.of<OrderProvider>(
                context,
                listen: false,
              );

              await authProvider.signOut(
                merchantProvider: merchantProvider,
                productProvider: productProvider,
                orderProvider: orderProvider,
              );

              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
