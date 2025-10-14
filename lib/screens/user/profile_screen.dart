import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/Profile_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/providers/locale_provider.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';

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
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainer,
      ),
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
                  icon: Icons.notifications_outlined,
                  label: 'الإشعارات',
                  color: primary,
                  onTap: () => _showGuestNotificationDialog(context),
                ),
                _DashboardItemData(
                  icon: Icons.language,
                  label: 'اللغة',
                  color: Colors.teal,
                  onTap: () => _showLanguageBottomSheet(context),
                ),
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

    final items = [
      _DashboardItemData(
        icon: Icons.receipt_long,
        label: 'الطلبات',
        color: primary,
        onTap: () => Navigator.pushNamed(context, AppRoutes.orderHistory),
      ),
      _DashboardItemData(
        icon: Icons.assignment_return,
        label: 'المرتجعات',
        color: Colors.deepOrange,
        onTap: () => Navigator.pushNamed(context, AppRoutes.returns),
      ),
      _DashboardItemData(
        icon: Icons.edit,
        label: 'تعديل',
        color: Colors.teal,
        onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
      ),
      _DashboardItemData(
        icon: Icons.location_on,
        label: 'العناوين',
        color: Colors.pinkAccent,
        onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
      ),
      _DashboardItemData(
        icon: Icons.credit_card,
        label: 'الدفع',
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, AppRoutes.paymentMethods),
      ),
      _DashboardItemData(
        icon: Icons.notifications_active_outlined,
        label: 'الإشعارات',
        color: Colors.orange,
        onTap: () => _showNotificationBottomSheet(context),
      ),
      _DashboardItemData(
        icon: Icons.language,
        label: 'اللغة',
        color: Colors.green,
        onTap: () => _showLanguageBottomSheet(context),
      ),
      _DashboardItemData(
        icon: Icons.lock_outline,
        label: 'كلمة المرور',
        color: Colors.brown,
        onTap: () => Navigator.pushNamed(context, AppRoutes.changePassword),
      ),
      _DashboardItemData(
        icon: Icons.store_mall_directory,
        label: 'بع معنا',
        color: Colors.lightBlue,
        onTap: () => Navigator.pushNamed(context, AppRoutes.registerMerchant),
      ),
      _DashboardItemData(
        icon: Icons.logout,
        label: 'خروج',
        color: Colors.redAccent,
        onTap: () => _showLogoutDialog(context, authProvider),
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ProfileHeader(
              user: user,
              colorScheme: colorScheme,
              onEdit: () => _showEditProfileDialog(context, user),
            ),
            const SizedBox(height: 24),
            _StatsBar(colorScheme: colorScheme),
            const SizedBox(height: 24),
            _DashboardGrid(items: items, colorScheme: colorScheme),
          ],
        ),
      ),
    );
  }

  // ---------------- Helper UI ---------------- //
  void _showEditProfileDialog(BuildContext context, ProfileModel user) {
    Navigator.pushNamed(context, AppRoutes.editProfile);
  }

  // (info item helper removed - no longer used after redesign)

  // (Helper classes moved below outside the ProfileScreen class)

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
                        await authProvider.signOut();
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

  // إظهار رسالة للزائر عند محاولة الوصول للإشعارات
  void _showGuestNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_outlined, color: primary),
            SizedBox(width: 8),
            Text('الإشعارات'),
          ],
        ),
        content: const Text(
          'للوصول إلى الإشعارات والاستفادة من جميع المزايا، يرجى تسجيل الدخول أولاً! 🔔',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.login);
            },
            child: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  /// BottomSheet للإشعارات
  void _showNotificationBottomSheet(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final appSettings = settingsProvider.appSettings;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        bool notifEnabled = appSettings.notificationsEnabled;
        bool emailNotif = appSettings.emailNotifications;
        bool smsNotif = appSettings.smsNotifications;
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إعدادات الإشعارات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildNotificationTile(
                  icon: Icons.notifications_rounded,
                  title: 'تفعيل الإشعارات',
                  subtitle: 'استقبال جميع الإشعارات',
                  value: notifEnabled,
                  onChanged: (value) async {
                    setState(() => notifEnabled = value);
                    final newSettings = appSettings.copyWith(
                      notificationsEnabled: value,
                    );
                    await settingsProvider.updateAppSettings(newSettings);
                  },
                ),
                _buildNotificationTile(
                  icon: Icons.email_rounded,
                  title: 'الإشعارات البريدية',
                  subtitle: 'إشعارات عبر البريد الإلكتروني',
                  value: emailNotif,
                  onChanged: (value) async {
                    setState(() => emailNotif = value);
                    final newSettings = appSettings.copyWith(
                      emailNotifications: value,
                    );
                    await settingsProvider.updateAppSettings(newSettings);
                  },
                ),
                _buildNotificationTile(
                  icon: Icons.sms_rounded,
                  title: 'الإشعارات النصية',
                  subtitle: 'إشعارات عبر الرسائل القصيرة',
                  value: smsNotif,
                  onChanged: (value) async {
                    setState(() => smsNotif = value);
                    final newSettings = appSettings.copyWith(
                      smsNotifications: value,
                    );
                    await settingsProvider.updateAppSettings(newSettings);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// BottomSheet لتغيير اللغة
  void _showLanguageBottomSheet(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: Colors.teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'اختر اللغة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Language options
                _buildLanguageTile(
                  flag: '🇸🇦',
                  title: 'العربية',
                  subtitle: 'اللغة العربية',
                  onTap: () {
                    Navigator.pop(context);
                    localeProvider.setLocale('ar');
                  },
                ),
                const SizedBox(height: 12),
                _buildLanguageTile(
                  flag: '🇺🇸',
                  title: 'English',
                  subtitle: 'English Language',
                  onTap: () {
                    Navigator.pop(context);
                    localeProvider.setLocale('en');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageTile({
    required String flag,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Center(
            child: Text(flag, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.shade50,
        border: Border.all(
          color: value ? primary.withValues(alpha: 0.2) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? primary.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: value ? primary : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: primary,
        ),
      ),
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

// ---------------- Profile Header ---------------- //
class _ProfileHeader extends StatelessWidget {
  final ProfileModel user;
  final ColorScheme colorScheme;
  final VoidCallback onEdit;
  const _ProfileHeader({
    required this.user,
    required this.colorScheme,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                // زر التعديل
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton.filled(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    iconSize: 18,
                    padding: const EdgeInsets.all(8),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // اسم المستخدم
            Text(
              user.fullName ?? 'مستخدم',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // معلومات الاتصال
            if (user.email != null)
              Chip(
                avatar: Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
                label: Text(user.email!),
                backgroundColor: colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 13,
                ),
              ),
            if (user.email != null && user.phone != null)
              const SizedBox(height: 8),
            if (user.phone != null)
              Chip(
                avatar: Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
                label: Text(user.phone!),
                backgroundColor: colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Stats Bar ---------------- //
class _StatsBar extends StatelessWidget {
  final ColorScheme colorScheme;
  const _StatsBar({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatsData(Icons.shopping_bag_outlined, 'الطلبات', '15', Colors.blue),
      _StatsData(Icons.star_rate_rounded, 'التقييم', '4.8', Colors.amber),
      _StatsData(Icons.loyalty_rounded, 'النقاط', '250', Colors.green),
    ];

    return Row(
      children: stats.map((stat) {
        return Expanded(
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(stat.icon, size: 28, color: stat.color),
                  const SizedBox(height: 8),
                  Text(
                    stat.value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatsData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatsData(this.icon, this.label, this.value, this.color);
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
