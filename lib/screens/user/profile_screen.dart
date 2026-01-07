import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/banner_provider.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/models/banner_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color primary = Color(0xFF6A5AE0);
  static const Color accent = Color(0xFFFF9E80);
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEF1FF), Color(0xFFFFFFFF)],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: Consumer<SupabaseProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.currentUser;

                // إذا لم يكن المستخدم مسجل دخوله
                if (user == null) {
                  return _buildGuestContent(context);
                }

                // إذا كان المستخدم مسجل دخوله
                // نعرض الواجهة فوراً حتى لو لم يُحمل Profile كاملاً
                final profile = authProvider.currentUserProfile;

                // إذا لم يُحمل Profile بعد، نستخدم بيانات User الأساسية
                if (profile == null) {
                  // إنشاء Profile مؤقت من بيانات User
                  final tempProfile = ProfileModel(
                    id: user.id,
                    email: user.email,
                    fullName:
                        user.userMetadata?['full_name'] ??
                        user.email?.split('@')[0] ??
                        'مستخدم',
                    phone: user.phone,
                    role: UserRole.client,
                    createdAt:
                        DateTime.tryParse(user.createdAt) ?? DateTime.now(),
                  );

                  return _buildProfileContent(
                    context,
                    tempProfile,
                    authProvider,
                  );
                }

                // إذا كان كل شيء محمل بنجاح
                return _buildProfileContent(context, profile, authProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Guest View ---------------- //
  Widget _buildGuestContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _GuestHeader(colorScheme: colorScheme),
            const SizedBox(height: 24),
            _buildGuestInfoCard(colorScheme),
            const SizedBox(height: 24),
            _DashboardGrid(
              colorScheme: colorScheme,
              items: [
                _DashboardItemData(
                  icon: Icons.store,
                  label: 'بع معنا',
                  color: Colors.green,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.registerMerchant),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildLoginCallToAction(context),
          ],
        ),
      ),
    );
  }

  // بناء كارت المعلومات للزائر
  Widget _buildGuestInfoCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 48,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              'نصيحة مهمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'سجّل دخولك لتتابع طلباتك وتستفيد من المزايا الحصرية مثل النقاط والعروض الخاصة!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSecondaryContainer,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء زر الدعوة للتسجيل
  Widget _buildLoginCallToAction(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
      icon: const Icon(Icons.login_rounded),
      label: const Text('تسجيل الدخول أو إنشاء حساب'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    ProfileModel user,
    SupabaseProvider authProvider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Header Section
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: isRTL
                  ? [
                      // RTL: Avatar, Name, Spacer, Settings
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                (user.fullName ?? 'م')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName ?? 'مستخدم',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مصر',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: colorScheme.onSurface,
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.settings),
                        ),
                      ),
                    ]
                  : [
                      // LTR: settings icon left, then user info + avatar
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: colorScheme.onSurface,
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.settings),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            user.fullName ?? 'مستخدم',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'مصر',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                (user.fullName ?? 'م')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ],
            ),
          ),

          // Promotional Banner (Dynamic)
          Consumer<BannerProvider>(
            builder: (context, bannerProvider, child) {
              // Find family/promotion banner
              BannerModel? familyBanner;
              try {
                familyBanner = bannerProvider.activeBanners.firstWhere(
                  (b) =>
                      b.targetType == BannerType.promotion &&
                      (b.description?.contains('عائلة') ?? false),
                );
              } catch (e) {
                // If no family banner found, try to get first promotion banner
                try {
                  familyBanner = bannerProvider.activeBanners.firstWhere(
                    (b) => b.targetType == BannerType.promotion,
                  );
                } catch (e) {
                  familyBanner = null;
                }
              }

              // If no banner found, hide the section
              if (familyBanner == null) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.all(16),
                height: 180,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B3FF2), Color(0xFF6B2FE8)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Decorative Circle
                    Positioned(
                      left: -50,
                      top: -30,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    // Image on the left
                    Positioned(
                      left: 16,
                      bottom: 0,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Stack(
                          children: [
                            // Display banner image if available
                            if (familyBanner.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  familyBanner.imageUrl,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.family_restroom_rounded,
                                        size: 60,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              Center(
                                child: Icon(
                                  Icons.family_restroom_rounded,
                                  size: 60,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            // PRO Badge
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B3FF2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'PRO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Text on the right
                    Positioned(
                      right: 20,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: 160,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              familyBanner.title,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              familyBanner.description ??
                                  'توصيل مجاني وعروض حصرية للجميع',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // Navigate to action URL if available
                                if (familyBanner!.actionUrl != null &&
                                    familyBanner.actionUrl!.isNotEmpty) {
                                  Navigator.pushNamed(
                                    context,
                                    familyBanner.actionUrl!,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF7B3FF2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'جرب مجاناً',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Menu Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.card_giftcard_rounded,
                  title: 'مكافآت',
                  trailing: '0 نقاط',
                  onTap: () {},
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.receipt_long_rounded,
                  title: 'طلباتي السابقة',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.orderHistory),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.bookmark_border_rounded,
                  title: 'القسائم',
                  trailing: '1',
                  onTap: () {},
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: 'احصل على المساعدة',
                  onTap: () {},
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: 'حول التطبيق',
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  context,
                  icon: Icons.store_outlined,
                  title: 'بع معنا',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.registerMerchant),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  titleColor: Colors.red,
                  onTap: () => _showLogoutDialog(context, authProvider),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailing,
    Color? trailingColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Row(
              children: isRTL
                  ? [
                      // RTL: icon+text right, trailing, chevron left
                      Icon(
                        icon,
                        size: 24,
                        color: titleColor ?? colorScheme.onSurface,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: titleColor ?? colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                trailingColor?.withValues(alpha: 0.1) ??
                                colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            trailing,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: trailingColor ?? colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 24,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ]
                  : [
                      // LTR: icon, spacing, text, trailing badge, chevron right
                      Icon(
                        icon,
                        size: 24,
                        color: titleColor ?? colorScheme.onSurface,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: titleColor ?? colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                trailingColor?.withValues(alpha: 0.1) ??
                                colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            trailing,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: trailingColor ?? colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 24,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Helper UI ---------------- //

  void _showLogoutDialog(BuildContext context, SupabaseProvider authProvider) {
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            content: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('جاري تسجيل الخروج...'),
                      ],
                    ),
                  )
                : const Text(
                    'هل أنت متأكد من أنك تريد تسجيل الخروج من حسابك؟\n\nستحتاج لتسجيل الدخول مرة أخرى للوصول إلى حسابك.',
                    style: TextStyle(height: 1.4),
                  ),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);

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
                        if (!context.mounted) return;
                        if (Navigator.canPop(context)) Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= Outside Helper Classes ================= //

// ---------------- Data Model for Dashboard Items ---------------- //
class _DashboardItemData {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DashboardItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ---------------- Dashboard Grid ---------------- //
class _DashboardGrid extends StatelessWidget {
  final List<_DashboardItemData> items;
  final ColorScheme colorScheme;
  const _DashboardGrid({required this.items, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _DashboardTile(
          data: item,
          index: index,
          colorScheme: colorScheme,
        );
      },
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItemData data;
  final int index;
  final ColorScheme colorScheme;

  const _DashboardTile({
    required this.data,
    required this.index,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: data.color, size: 32),
              const SizedBox(height: 8),
              Text(
                data.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Guest Header ---------------- //
class _GuestHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  const _GuestHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.person_outline_rounded, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'أهلاً بك في سوق التل',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تسوق كل شيء من مكان واحد',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
