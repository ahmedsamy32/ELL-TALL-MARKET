import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/auth_provider.dart';
import 'package:ell_tall_market/models/user_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/providers/locale_provider.dart';
import 'package:ell_tall_market/widgets/edit_profile_dialog.dart';
import 'package:ell_tall_market/providers/settings_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Welcome message and login button
                const SizedBox(height: 32),
                const Text(
                  'أهلاً بك في سوق التل',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'تسوق كل شيء من مكان واحد',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.login),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('تسجيل الدخول أو التسجيل'),
                ),
                const SizedBox(height: 32),
                // Settings section (notifications, language)
                _buildCard([
                  _buildMenuItem(
                    icon: Icons.notifications,
                    title: 'الإشعارات',
                    onTap: () => _showNotificationBottomSheet(context),
                  ),
                  _buildMenuItem(
                    icon: Icons.language,
                    title: 'اللغة',
                    onTap: () => _showLanguageBottomSheet(context),
                  ),
                ]),
                const SizedBox(height: 16),
                // "بع معنا" section
                _buildCard([
                  _buildMenuItem(
                    icon: Icons.store,
                    title: 'بع معنا',
                    color: Colors.green,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.registerMerchant,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
      body: SafeArea(child: _buildProfileContent(context, user, authProvider)),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserModel user,
    AuthProvider authProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildUserInfo(user, context),
          const SizedBox(height: 24),

          /// الطلبات والمرتجعات
          _buildCard([
            _buildMenuItem(
              icon: Icons.receipt_long,
              title: 'جميع الطلبات',
              onTap: () => Navigator.pushNamed(context, AppRoutes.orderHistory),
            ),
            _buildMenuItem(
              icon: Icons.assignment_return,
              title: 'المرتجعات',
              onTap: () => Navigator.pushNamed(context, AppRoutes.returns),
            ),
          ]),

          const SizedBox(height: 16),

          /// تعديل البيانات، العناوين، طرق الدفع
          _buildCard([
            _buildMenuItem(
              icon: Icons.edit,
              title: 'تعديل البيانات',
              onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
            ),
            _buildMenuItem(
              icon: Icons.location_on,
              title: 'عناويني',
              onTap: () => Navigator.pushNamed(context, AppRoutes.addresses),
            ),
            _buildMenuItem(
              icon: Icons.credit_card,
              title: 'طرق الدفع',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.paymentMethods),
            ),
          ]),

          const SizedBox(height: 16),

          /// الإشعارات واللغة
          _buildCard([
            _buildMenuItem(
              icon: Icons.notifications,
              title: 'الإشعارات',
              onTap: () => _showNotificationBottomSheet(context),
            ),
            _buildMenuItem(
              icon: Icons.language,
              title: 'اللغة',
              onTap: () => _showLanguageBottomSheet(context),
            ),
            _buildMenuItem(
              icon: Icons.lock,
              title: 'تغيير كلمة المرور',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.changePassword),
            ),
          ]),

          const SizedBox(height: 16),

          /// بيع معنا وتسجيل الخروج
          _buildCard([
            _buildMenuItem(
              icon: Icons.store,
              title: 'بع معنا',
              color: Colors.green,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.registerMerchant),
            ),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              color: Colors.red,
              onTap: () => _showLogoutDialog(context, authProvider),
            ),
          ]),
        ],
      ),
    );
  }

  /// معلومات المستخدم
  Widget _buildUserInfo(UserModel user, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditProfileDialog(context, user),
                  tooltip: 'تعديل الصورة والبيانات',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(user.email),
            const SizedBox(height: 8),
            Text(user.phone),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem('الطلبات', '15'),
                _buildInfoItem('التقييمات', '4.8'),
                _buildInfoItem('النقاط', '250'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
  }

  Widget _buildInfoItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(child: Column(children: children));
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: isLoading
                ? const Center(child: CircularProgressIndicator())
                : const Text('هل أنت متأكد من أنك تريد تسجيل الخروج؟'),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);
                        await authProvider.logout();
                        if (Navigator.canPop(context)) Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        );
                      },
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
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
                SwitchListTile(
                  title: const Text('تفعيل الإشعارات'),
                  value: notifEnabled,
                  onChanged: (value) async {
                    setState(() => notifEnabled = value);
                    final newSettings = appSettings.copyWith(
                      notificationsEnabled: value,
                    );
                    await settingsProvider.updateAppSettings(newSettings);
                  },
                ),
                SwitchListTile(
                  title: const Text('الإشعارات البريدية'),
                  value: emailNotif,
                  onChanged: (value) async {
                    setState(() => emailNotif = value);
                    final newSettings = appSettings.copyWith(
                      emailNotifications: value,
                    );
                    await settingsProvider.updateAppSettings(newSettings);
                  },
                ),
                SwitchListTile(
                  title: const Text('الإشعار��ت النصية'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر اللغة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: const Text('العربية'),
                onTap: () {
                  Navigator.pop(context);
                  localeProvider.setLocale('ar');
                },
              ),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  Navigator.pop(context);
                  localeProvider.setLocale('en');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
