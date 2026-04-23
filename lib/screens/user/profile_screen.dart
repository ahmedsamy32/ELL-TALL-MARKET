import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/banner_provider.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/models/banner_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/user_coupons_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();

  static const Color primary = Color(0xFF6A5AE0);
  static const Color accent = Color(0xFFFF9E80);
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEEF1FF), Color(0xFFFFFFFF)],
  );
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ===========================================================================
  // 1. State & Lifecycle
  // ===========================================================================
  bool _didRequestProfileOnce = false;
  bool _didHandleMissingProfileOnce = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();

    // Trigger a single profile fetch when the screen first opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRequestProfileOnce) return;
      _didRequestProfileOnce = true;

      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      if (authProvider.currentUser != null &&
          authProvider.currentUserProfile == null) {
        authProvider.refreshCurrentProfile();
      }
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version; // عرض رقم الإصدار الكامل مثل 1.0.1
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: ResponsiveCenter(
        maxWidth: 700,
        child: Column(
          children: [
            Expanded(
              child: Consumer<SupabaseProvider>(
                builder: (consumerContext, authProvider, child) {
                  final user = authProvider.currentUser;

                  // إذا لم يكن المستخدم مسجل دخوله
                  if (user == null) {
                    return _buildGuestContent(consumerContext);
                  }

                  // إذا كان المستخدم مسجل دخوله
                  // نعرض الواجهة فوراً حتى لو لم يُحمل Profile كاملاً
                  final profile = authProvider.currentUserProfile;

                  // إذا لم يُحمل Profile بعد، لا نعرض بيانات من Auth.
                  // ننتظر بيانات جدول profiles.
                  if (profile == null) {
                    // لو البروفايل مش موجود (اتمسح/لم يتم إنشاؤه) نرجع لواجهة الزائر
                    // وننهي الجلسة لتفادي حالة معلّقة.
                    if (authProvider.isProfileMissing &&
                        !_didHandleMissingProfileOnce) {
                      _didHandleMissingProfileOnce = true;

                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        final localContext = context;
                        if (!mounted) return;

                        final merchantProvider = Provider.of<MerchantProvider>(
                          localContext,
                          listen: false,
                        );
                        final productProvider = Provider.of<ProductProvider>(
                          localContext,
                          listen: false,
                        );
                        final orderProvider = Provider.of<OrderProvider>(
                          localContext,
                          listen: false,
                        );

                        await authProvider.signOut(
                          merchantProvider: merchantProvider,
                          productProvider: productProvider,
                          orderProvider: orderProvider,
                        );

                        if (!localContext.mounted) return;
                        ScaffoldMessenger.of(localContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'لم يتم العثور على بيانات الحساب. يرجى تسجيل الدخول مرة أخرى.',
                            ),
                          ),
                        );
                      });

                      return _buildGuestContent(consumerContext);
                    }

                    return _buildProfileLoading(consumerContext, authProvider);
                  }

                  // إذا كان كل شيء محمل بنجاح
                  return _buildProfileContent(
                    consumerContext,
                    profile,
                    authProvider,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. Loading State UI
  // ===========================================================================
  Widget _buildProfileLoading(
    BuildContext context,
    SupabaseProvider authProvider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppShimmer.wrap(
              context,
              child: AppShimmer.circle(context, size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل بيانات حسابك...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: authProvider.isProfileLoading
                  ? null
                  : () => authProvider.refreshCurrentProfile(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. Guest View UI
  // ===========================================================================
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
            _buildLoginCallToAction(context),
            const SizedBox(height: 12),
            _buildSellWithUsCallToAction(context),
            const SizedBox(height: 32),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 40,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              'نصيحة مهمة',
              style: TextStyle(
                fontSize: 16,
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

  Widget _buildSellWithUsCallToAction(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => Navigator.pushNamed(context, AppRoutes.registerMerchant),
      icon: const Icon(Icons.store_outlined),
      label: const Text('بع معنا'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ===========================================================================
  // 5. Authenticated Profile UI
  // ===========================================================================
  Widget _buildProfileContent(
    BuildContext context,
    ProfileModel user,
    SupabaseProvider authProvider,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Header Section
          _buildProfileHeader(context, user, colorScheme),

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
          _buildMenuSection(context, authProvider),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    ProfileModel user,
    ColorScheme colorScheme,
  ) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: isRTL
            ? [
                // RTL Layout
                _buildUserAvatar(user, colorScheme),
                const SizedBox(width: 12),
                _buildUserInfo(user, colorScheme, isRTL),
                const SizedBox(width: 12),
                _buildSettingsButton(context, colorScheme),
              ]
            : [
                // LTR Layout
                _buildSettingsButton(context, colorScheme),
                const SizedBox(width: 12),
                _buildUserInfo(user, colorScheme, isRTL),
                const SizedBox(width: 12),
                _buildUserAvatar(user, colorScheme),
              ],
      ),
    );
  }

  Widget _buildUserAvatar(ProfileModel user, ColorScheme colorScheme) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      backgroundImage: user.avatarUrl != null
          ? NetworkImage(user.avatarUrl!)
          : null,
      child: user.avatarUrl == null
          ? Text(
              (user.fullName ?? 'م').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  Widget _buildUserInfo(
    ProfileModel user,
    ColorScheme colorScheme,
    bool isRTL,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: isRTL
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            user.fullName ?? 'مستخدم',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            'مصر',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(Icons.settings_outlined, color: colorScheme.onSurface),
        onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
      ),
    );
  }

  // ===========================================================================
  // 6. Menu Items & Navigation
  // ===========================================================================
  Widget _buildMenuSection(
    BuildContext context,
    SupabaseProvider authProvider,
  ) {
    return Padding(
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
            onTap: () => Navigator.pushNamed(context, AppRoutes.orderHistory),
          ),
          _buildMenuItem(
            context,
            icon: Icons.bookmark_border_rounded,
            title: 'القسائم',
            onTap: () => UserCouponsSheet.show(context),
          ),
          _buildMenuItem(
            context,
            icon: Icons.info_outline_rounded,
            title: 'حول التطبيق',
            onTap: () => Navigator.pushNamed(context, AppRoutes.aboutApp),
          ),
          _buildMenuItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية والاسترجاع',
            onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
          ),
          _buildMenuItem(
            context,
            icon: Icons.description_outlined,
            title: 'الشروط والأحكام',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.termsConditions),
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
          if (_appVersion.isNotEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                'إصدار $_appVersion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
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

  // ===========================================================================
  // 7. Action Dialogs & Sheets
  // ===========================================================================
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
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppShimmer.wrap(
                          context,
                          child: AppShimmer.circle(context, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Text('جاري تسجيل الخروج...'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.person_outline_rounded, size: 42),
            ),
            const SizedBox(height: 16),
            Text(
              'أهلاً بك في سوق التل',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تسوق كل شيء من مكان واحد',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
