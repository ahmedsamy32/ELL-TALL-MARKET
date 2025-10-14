import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = 'current_user_id'; // استبدال بـ ID المستخدم الحقيقي
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).loadUserNotifications(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('الإشعارات'),
        centerTitle: true,
        actions: [
          if (notificationProvider.unreadCount > 0)
            IconButton(
              icon: Icon(Icons.mark_email_read),
              onPressed: () {
                notificationProvider.markAllAsRead('current_user_id');
              },
              tooltip: 'تمييز الكل كمقروء',
            ),
        ],
      ),
      body: _buildNotificationsList(notificationProvider),
    );
  }

  Widget _buildNotificationsList(NotificationProvider provider) {
    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(child: Text(provider.error!));
    }

    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد إشعارات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'سيتم إعلامك عند وجود إشعارات جديدة',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadUserNotifications('current_user_id');
      },
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: provider.notifications.length,
        itemBuilder: (context, index) {
          final notification = provider.notifications[index];
          return _buildNotificationItem(notification, provider);
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        provider.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الإشعار'),
            backgroundColor: Colors.red,
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: notification.isRead
            ? Colors.white
            : AppColors.primary.withAlpha(25),
        child: ListTile(
          leading: _getNotificationIcon(
            notification.type ?? NotificationType.system,
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.body),
              SizedBox(height: 4),
              Text(
                notification.createdAtRelative,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Icon(Icons.circle, size: 8, color: AppColors.primary),
          onTap: () {
            if (!notification.isRead) {
              provider.markAsRead(notification.id);
            }
            _handleNotificationTap(notification);
          },
        ),
      ),
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    late IconData icon;
    late Color color;

    switch (type) {
      case NotificationType.order:
        icon = Icons.shopping_cart;
        color = AppColors.primary;
        break;
      case NotificationType.promotion:
        icon = Icons.local_offer;
        color = AppColors.secondary;
        break;
      case NotificationType.system:
        icon = Icons.info;
        color = AppColors.info;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    // معالجة رابط الإشعار من data
    final actionUrl = notification.data?['actionUrl'] as String?;

    if (actionUrl != null || notification.hasData) {
      // معالجة حسب نوع الإشعار
      switch (notification.type) {
        case NotificationType.order:
          final orderId = notification.data?['orderId'] as String?;
          if (orderId != null) {
            // Navigator.pushNamed(context, AppRoutes.orderTracking, arguments: {'orderId': orderId});
          }
          break;
        case NotificationType.promotion:
          // Navigator.pushNamed(context, AppRoutes.promotions);
          break;
        case NotificationType.system:
        default:
          break;
      }
    }
  }
}
