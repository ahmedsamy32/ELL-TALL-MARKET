import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class NotificationsScreen extends StatefulWidget {
  final String? targetRole; // الدور المستهدف (client, merchant, captain, admin)

  const NotificationsScreen({super.key, this.targetRole});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final userId = authProvider.currentUser?.id;

      if (userId != null) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).loadUserNotifications(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<SupabaseProvider>(context);
    final userId = authProvider.currentUser?.id;

    final unreadCount = notificationProvider.getUnreadCountForRole(
      widget.targetRole,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
        actions: [
          if (unreadCount > 0 && userId != null)
            TextButton.icon(
              onPressed: () {
                notificationProvider.markAllAsRead(userId);
              },
              icon: const Icon(Icons.mark_email_read, size: 18),
              label: const Text('قراءة الكل'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          if (notificationProvider
              .getNotificationsForRole(widget.targetRole)
              .isNotEmpty)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف جميع الإشعارات'),
                    content: const Text('هل أنت متأكد من حذف جميع الإشعارات؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () {
                          if (userId != null) {
                            notificationProvider.deleteUserNotifications(
                              userId,
                            );
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف جميع الإشعارات'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                        child: const Text(
                          'حذف',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'مسح الكل',
            ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 700,
        child: SafeArea(
          child: userId == null
              ? _buildLoginRequired()
              : _buildNotificationsList(notificationProvider, userId),
        ),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'يرجى تسجيل الدخول',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'قم بتسجيل الدخول لعرض الإشعارات',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(NotificationProvider provider, String userId) {
    if (provider.isLoading) {
      return AppShimmer.list(context);
    }

    final notifications = provider.getNotificationsForRole(widget.targetRole);

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 80, color: Colors.orange[300]),
              const SizedBox(height: 16),
              const Text(
                'مشكلة في الاتصال',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  provider.loadUserNotifications(userId);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا توجد إشعارات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم إعلامك عند وجود إشعارات جديدة',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await provider.loadUserNotifications(userId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
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
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        provider.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الإشعار'),
            backgroundColor: Colors.red,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
              const SizedBox(height: 4),
              Text(
                notification.createdAtRelative,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : const Icon(Icons.circle, size: 8, color: AppColors.primary),
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
    final data = notification.data ?? {};

    // Debug: اطبع البيانات للتحقق
    debugPrint('📬 Tapped Notification: ${notification.title}');
    debugPrint('📊 Notification Type: ${notification.type}');
    debugPrint('📦 Notification Data: $data');

    switch (notification.type) {
      case NotificationType.order:
        _navigateToOrderNotification(data);
        break;
      case NotificationType.promotion:
        _navigateToPromotionNotification(data);
        break;
      case NotificationType.system:
      default:
        _navigateToSystemNotification(data);
        break;
    }
  }

  /// التنقل لإشعارات الطلبات
  void _navigateToOrderNotification(Map<String, dynamic> data) {
    final orderId = data['orderId'] as String?;
    final orderStatus = data['orderStatus'] as String?;
    final actionType = data['actionType'] as String?;

    if (orderId == null) return;

    // إذا كان الإشعار عن تتبع الطلب
    if (actionType == 'order_tracking' || orderStatus != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.orderTracking,
        arguments: {'orderId': orderId},
      );
    }
    // إذا كان الإشعار عن حالة الطلب
    else if (actionType == 'order_status') {
      Navigator.pushNamed(context, AppRoutes.orderHistory);
    }
    // الحالة الافتراضية
    else {
      Navigator.pushNamed(context, AppRoutes.orderHistory);
    }
  }

  /// التنقل لإشعارات العروض والمنتجات
  void _navigateToPromotionNotification(Map<String, dynamic> data) {
    final productId = data['productId'] as String?;
    final storeId = data['storeId'] as String?;
    final promotionType = data['promotionType'] as String?;

    // إذا كان الإشعار عن منتج محدد
    if (productId != null) {
      _navigateToProduct(productId);
    }
    // إذا كان الإشعار عن متجر محدد
    else if (storeId != null) {
      _navigateToStore(storeId);
    }
    // إذا كان الإشعار عن عرض عام
    else if (promotionType == 'general_promotion') {
      Navigator.pushNamed(context, AppRoutes.home);
    }
    // الحالة الافتراضية
    else {
      Navigator.pushNamed(context, AppRoutes.home);
    }
  }

  /// التنقل لإشعارات النظام
  void _navigateToSystemNotification(Map<String, dynamic> data) {
    final actionType = data['actionType'] as String?;
    final actionRoute = data['actionRoute'] as String?;

    // إذا كان هناك route محدد
    if (actionRoute != null) {
      Navigator.pushNamed(context, actionRoute);
    }
    // إذا كان الإشعار عن رسالة نظام عامة
    else if (actionType == 'general_message') {
      // ابق في الشاشة الحالية
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] as String? ?? 'لديك إشعار جديد'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// التنقل لصفحة تفاصيل المنتج
  void _navigateToProduct(String productId) async {
    try {
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      // البحث عن المنتج في القائمة المحملة
      ProductModel? product;

      if (productProvider.products.isNotEmpty) {
        product = productProvider.products.firstWhere(
          (p) => p.id == productId,
          orElse: () => throw Exception('Product not found'),
        );
      }

      if (product != null) {
        Navigator.pushNamed(
          context,
          AppRoutes.productDetail,
          arguments: product,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على المنتج'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح المنتج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// التنقل لصفحة تفاصيل المتجر
  void _navigateToStore(String storeId) {
    Navigator.pushNamed(
      context,
      AppRoutes.storeDetail,
      arguments: {'storeId': storeId},
    );
  }
}
