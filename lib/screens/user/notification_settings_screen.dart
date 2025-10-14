import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إعدادات الإشعارات")),
      body: ListView(
        children: [
          _buildSwitchTile(
            title: "إشعارات الطلبات",
            value: orderNotifications,
            onChanged: (val) => setState(() => orderNotifications = val),
          ),
          _buildSwitchTile(
            title: "إشعارات العروض",
            value: offersNotifications,
            onChanged: (val) => setState(() => offersNotifications = val),
          ),
          _buildSwitchTile(
            title: "إشعارات الأخبار",
            value: newsNotifications,
            onChanged: (val) => setState(() => newsNotifications = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
