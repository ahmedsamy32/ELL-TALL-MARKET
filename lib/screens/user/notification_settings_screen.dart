import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

enum NotificationLevel {
  all, // كل التحديثات
  important, // المهم فقط (افتراضي)
  deliveryOnly, // التوصيل فقط
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool orderNotifications = true;
  bool offersNotifications = true;
  bool newsNotifications = false;
  NotificationLevel _notificationLevel = NotificationLevel.important;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      orderNotifications = prefs.getBool('order_notifications') ?? true;
      offersNotifications = prefs.getBool('offers_notifications') ?? true;
      newsNotifications = prefs.getBool('news_notifications') ?? false;
      final levelIndex = prefs.getInt('notification_level') ?? 1;
      _notificationLevel = NotificationLevel.values[levelIndex];
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveNotificationLevel(NotificationLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_level', level.index);
    setState(() => _notificationLevel = level);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("إعدادات الإشعارات")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("إعدادات الإشعارات")),
      body: ResponsiveCenter(
        maxWidth: 600,
        child: ListView(
          children: [
            // مستوى تفاصيل الإشعارات
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مستوى تفاصيل إشعارات الطلبات',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اختر مستوى التفاصيل التي تريد استقبالها عن حالة طلباتك',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            RadioGroup<NotificationLevel>(
              groupValue: _notificationLevel,
              onChanged: (value) {
                if (value != null) _saveNotificationLevel(value);
              },
              child: Column(
                children: [
                  _buildNotificationLevelTile(
                    title: 'كل التحديثات',
                    subtitle: 'إشعار لكل تغيير في حالة الطلب (6 إشعارات)',
                    value: NotificationLevel.all,
                    icon: Icons.notifications_active,
                  ),
                  _buildNotificationLevelTile(
                    title: 'المهم فقط (موصى به)',
                    subtitle: 'إشعارات ذكية مدمجة (3 إشعارات)',
                    value: NotificationLevel.important,
                    icon: Icons.notifications,
                  ),
                  _buildNotificationLevelTile(
                    title: 'التوصيل فقط',
                    subtitle: 'إشعار واحد عند وصول الطلب',
                    value: NotificationLevel.deliveryOnly,
                    icon: Icons.notifications_none,
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            // إعدادات أخرى
            _buildSwitchTile(
              title: "إشعارات الطلبات",
              subtitle: "تلقي إشعارات عن حالة طلباتك",
              value: orderNotifications,
              onChanged: (val) {
                setState(() => orderNotifications = val);
                _savePreference('order_notifications', val);
              },
            ),
            _buildSwitchTile(
              title: "إشعارات العروض",
              subtitle: "عروض وخصومات من المتاجر",
              value: offersNotifications,
              onChanged: (val) {
                setState(() => offersNotifications = val);
                _savePreference('offers_notifications', val);
              },
            ),
            _buildSwitchTile(
              title: "إشعارات الأخبار",
              subtitle: "أخبار وتحديثات التطبيق",
              value: newsNotifications,
              onChanged: (val) {
                setState(() => newsNotifications = val);
                _savePreference('news_notifications', val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationLevelTile({
    required String title,
    required String subtitle,
    required NotificationLevel value,
    required IconData icon,
  }) {
    final isSelected = _notificationLevel == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Radio<NotificationLevel>(value: value),
      onTap: () => _saveNotificationLevel(value),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}
