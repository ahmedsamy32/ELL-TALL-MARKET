import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class NotificationsScreen extends StatefulWidget {
  final String? targetRole; // الدور المستهدف (client, merchant, captain, admin)

  const NotificationsScreen({super.key, this.targetRole});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
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
    final notifications = notificationProvider.getNotificationsForRole(
      widget.targetRole,
    );

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              ),
              title: Text('${_selectedIds.length} محدد'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'تحديد الكل',
                  onPressed: () {
                    setState(() {
                      _selectedIds.addAll(notifications.map((n) => n.id));
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.mark_email_read),
                  tooltip: 'تحديد كمقروء',
                  onPressed: () async {
                    for (final id in _selectedIds) {
                      await notificationProvider.markAsRead(id);
                    }
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديد الإشعارات كمقروءة'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف المحدد',
                  onPressed: () {
                    _confirmDeleteSelected(context, notificationProvider);
                  },
                ),
              ],
            )
          : AppBar(
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
                if (notifications.isNotEmpty)
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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _confirmDeleteSelected(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإشعارات المحددة'),
        content: Text('هل أنت متأكد من حذف ${_selectedIds.length} إشعار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final idsToDelete = _selectedIds.toList();
              setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              });
              await provider.deleteNotifications(idsToDelete);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف الإشعارات المحددة'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
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
          leading: _isSelectionMode
              ? Checkbox(
                  value: _selectedIds.contains(notification.id),
                  onChanged: (val) {
                    _toggleSelection(notification.id);
                  },
                )
              : _getNotificationIcon(
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
            if (_isSelectionMode) {
              _toggleSelection(notification.id);
            } else {
              if (!notification.isRead) {
                provider.markAsRead(notification.id);
              }
              _handleNotificationTap(notification);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(notification.id);
              });
            }
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
    final data = Map<String, dynamic>.from(notification.data ?? {});
    data.putIfAbsent('target_role', () => notification.targetRole);
    if (!data.containsKey('type') && notification.type != null) {
      data['type'] = notification.type!.value;
    }

    debugPrint('📬 Tapped Notification: ${notification.title}');
    debugPrint('📊 Notification Type: ${notification.type}');
    debugPrint('📦 Notification Data: $data');

    NotificationServiceEnhanced.instance.handleNotificationAction(data);
  }
}
