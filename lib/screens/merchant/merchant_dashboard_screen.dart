import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/locale_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/services/notification_service.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/screens/merchant/merchant_products_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_orders_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_settings_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_coupons_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_reports_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_help_screen.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/models/notification_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  int _selectedIndex = 0;
  bool _isInitialized = false; // لمنع التحديث المستمر
  String? _storeId; // تخزين معرف المتجر الحالي لتجنب الاستعلام المتكرر

  String? _currentUserId; // لتتبع المستخدم الحالي

  @override
  void initState() {
    super.initState();
    // تحميل البيانات فور توفر المستخدم الحالي بعد أول فريم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      if (authProvider.currentUser?.id != null) {
        _currentUserId = authProvider.currentUser!.id;
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // نراقب تغيّر المستخدم تلقائياً عبر الاستماع للمزوّد
    final authProvider = Provider.of<SupabaseProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleAuthChange(authProvider.currentUser?.id);
    });
  }

  void _handleAuthChange(String? currentUserId) {
    // لو المستخدم اتغير
    if (_currentUserId != currentUserId) {
      if (_currentUserId != null) {
        // مسح بيانات التاجر السابق فوراً
        final merchantProvider = Provider.of<MerchantProvider>(
          context,
          listen: false,
        );
        final productProvider = Provider.of<ProductProvider>(
          context,
          listen: false,
        );

        merchantProvider.clearData();
        productProvider.clearProducts();
      }
      _storeId = null;
      _currentUserId = currentUserId;
      _isInitialized = false;

      // تحميل البيانات الجديدة فور توفر المستخدم
      if (currentUserId != null) {
        Future.microtask(() => _loadData());
      }
    } else if (!_isInitialized && currentUserId != null) {
      // نفس المستخدم لكن البيانات مش محملة
      Future.microtask(() => _loadData());
    }
  }

  Future<void> _loadData({bool force = false}) async {
    // منع التحميل المتكرر
    if (_isInitialized && !force) {
      AppLogger.info('✅ البيانات محملة بالفعل');
      return;
    }

    AppLogger.info('🔄 بدء تحميل بيانات الداشبورد...');

    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final merchantProvider = Provider.of<MerchantProvider>(
      context,
      listen: false,
    );

    // Load merchant data first if not already loaded
    if (authProvider.isLoggedIn && authProvider.currentUser != null) {
      // تأمين profileId حتى لو كان المزوّد لم يحمّله بعد
      String? profileId = authProvider.currentUserProfile?.id;

      if (merchantProvider.selectedMerchant == null &&
          !merchantProvider.isLoading &&
          profileId != null) {
        AppLogger.info('📦 جاري جلب بيانات التاجر عبر profileId...');
        await merchantProvider.fetchMerchantByProfileId(profileId);
      }

      final merchant = merchantProvider.selectedMerchant;

      if (merchant != null) {
        AppLogger.info('✅ تم جلب بيانات التاجر: ${merchant.businessName}');

        final statsCount =
            merchantProvider.selectedMerchantStats?['total_products'];
        if (statsCount is int) {
          productProvider.preloadStoreProductCount(statsCount);
        }

        final storeId = await _ensureStoreId(merchantProvider);

        if (storeId != null) {
          AppLogger.info('🏪 معرف المتجر: $storeId');

          // تحميل عداد المنتجات
          AppLogger.info('📊 جاري جلب عدد المنتجات...');
          await productProvider.fetchStoreProductCount(storeId);
          await productProvider.subscribeToStoreProducts(storeId);
          AppLogger.info(
            '✅ عدد المنتجات: ${productProvider.storeProductCount}',
          );

          // جلب الطلبات
          if (!orderProvider.isLoading) {
            AppLogger.info('📦 جاري جلب الطلبات...');
            await orderProvider.fetchStoreOrders(storeId);
            await orderProvider.subscribeToStoreOrders(storeId);
            AppLogger.info('✅ عدد الطلبات: ${orderProvider.orders.length}');
          }

          // جلب الإشعارات للتاجر
          if (mounted) {
            final notificationProvider = Provider.of<NotificationProvider>(
              context,
              listen: false,
            );
            // استخدام loadStoreNotifications بدلاً من loadUserNotifications
            // لأن إشعارات التاجر محفوظة بـ store_id وليس merchant_id
            await notificationProvider.loadStoreNotifications(storeId);
            AppLogger.info('✅ تم تحميل إشعارات المتجر');

            // تسجيل device token للمتجر (لاستقبال إشعارات الطلبات)
            try {
              await NotificationServiceEnhanced.instance
                  .saveDeviceTokenForStore(storeId);
              AppLogger.info('✅ تم تسجيل device token للمتجر');
            } catch (e) {
              AppLogger.warning('⚠️ فشل تسجيل device token للمتجر', e);
            }
          }
        } else {
          AppLogger.warning('⚠️ لم يتم العثور على معرف المتجر');
        }
      } else {
        // محاولة احتياطية مباشرة عبر جدول merchants
        if (profileId != null) {
          try {
            final mRow = await Supabase.instance.client
                .from('merchants')
                .select('id')
                .eq('id', profileId)
                .maybeSingle();
            final mid = mRow?['id'] as String?;
            if (mid != null) {
              AppLogger.info('🪪 Fallback merchant id: $mid');
              await merchantProvider.fetchMerchantById(mid);
            } else {
              AppLogger.info('ℹ️ لم يتم العثور على صف تاجر احتياطي');
            }
          } on PostgrestException catch (e) {
            AppLogger.error('⛔ PostgREST ${e.code}: ${e.message}', e);
          } catch (e) {
            AppLogger.error('❌ فشل محاولة العثور على التاجر احتياطياً', e);
          }
        }

        if (merchantProvider.selectedMerchant == null) {
          AppLogger.warning('⚠️ لم يتم العثور على بيانات التاجر');
        }
      }

      // تم التحميل بنجاح
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        AppLogger.info('✅ تم تحميل الداشبورد بنجاح');
      }
    } else {
      AppLogger.warning('⚠️ المستخدم غير مسجل دخول');
    }
  }

  Future<String?> _ensureStoreId(MerchantProvider merchantProvider) async {
    if (_storeId != null) return _storeId;
    final merchant = merchantProvider.selectedMerchant;
    if (merchant == null) return null;

    try {
      final storeResponse = await Supabase.instance.client
          .from('stores')
          .select('id')
          .eq('merchant_id', merchant.id)
          .maybeSingle();

      if (storeResponse != null) {
        _storeId = storeResponse['id'] as String?;
      }
    } on PostgrestException catch (e) {
      AppLogger.error('⛔ PostgREST ${e.code}: ${e.message}', e);
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب معرف المتجر', e);
    }

    return _storeId;
  }

  @override
  Widget build(BuildContext context) {
    final merchantProvider = Provider.of<MerchantProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.locale.languageCode == 'ar';
    final isWide = MediaQuery.sizeOf(context).width >= 1200;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) return;

          if (_selectedIndex != 0) {
            setState(() => _selectedIndex = 0);
            return;
          }

          if (context.mounted) {
            Navigator.of(context).pop(result);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !isWide,
            title: Text(
              merchantProvider.selectedMerchant?.storeName ??
                  'لوحة تحكم المتجر',
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              // زر العودة للرئيسية
              IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                },
                tooltip: 'العودة للرئيسية',
              ),
              // إشعارات التاجر
              Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  final unreadCount = notificationProvider
                      .getUnreadCountForRole('merchant');
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => DraggableScrollableSheet(
                              initialChildSize: 0.7,
                              minChildSize: 0.5,
                              maxChildSize: 0.95,
                              builder: (context, scrollController) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                  ),
                                  child: SafeArea(
                                    child: Column(
                                      children: [
                                        // Handle bar
                                        Container(
                                          margin: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        // Header
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.notifications_rounded,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'الإشعارات',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Spacer(),
                                              if (unreadCount > 0)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextButton.icon(
                                                      onPressed: () async {
                                                        // الحصول على storeId
                                                        final merchantProvider =
                                                            Provider.of<
                                                              MerchantProvider
                                                            >(
                                                              context,
                                                              listen: false,
                                                            );
                                                        final storeId =
                                                            await _ensureStoreId(
                                                              merchantProvider,
                                                            );
                                                        if (storeId != null) {
                                                          await notificationProvider
                                                              .markAllAsReadForStore(
                                                                storeId,
                                                              );
                                                        }
                                                      },
                                                      icon: const Icon(
                                                        Icons.mark_email_read,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'قراءة الكل',
                                                      ),
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 8,
                                                            ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) => AlertDialog(
                                                            title: const Text(
                                                              'حذف جميع الإشعارات',
                                                            ),
                                                            content: const Text(
                                                              'هل أنت متأكد من حذف جميع الإشعارات؟',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'إلغاء',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () async {
                                                                  // الحصول على storeId
                                                                  final merchantProvider =
                                                                      Provider.of<
                                                                        MerchantProvider
                                                                      >(
                                                                        context,
                                                                        listen:
                                                                            false,
                                                                      );
                                                                  final storeId =
                                                                      await _ensureStoreId(
                                                                        merchantProvider,
                                                                      );
                                                                  if (storeId !=
                                                                      null) {
                                                                    await notificationProvider
                                                                        .deleteStoreNotifications(
                                                                          storeId,
                                                                        );
                                                                    if (context
                                                                        .mounted) {
                                                                      Navigator.pop(
                                                                        context,
                                                                      );
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        const SnackBar(
                                                                          content: Text(
                                                                            'تم حذف جميع الإشعارات',
                                                                          ),
                                                                          backgroundColor:
                                                                              Colors.red,
                                                                        ),
                                                                      );
                                                                    }
                                                                  }
                                                                },
                                                                child: const Text(
                                                                  'حذق',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 20,
                                                      ),
                                                      tooltip: 'مسح الكل',
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        // Notifications list
                                        Expanded(
                                          child:
                                              _NotificationsBottomSheetContent(
                                                targetRole: 'merchant',
                                                scrollController:
                                                    scrollController,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        tooltip: 'الإشعارات',
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: colorScheme.onError,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          drawer: !isWide ? _buildDrawer() : null,
          body: isWide
              ? Row(
                  children: [
                    _buildMerchantSidebar(colorScheme, textTheme),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildMerchantBody()),
                  ],
                )
              : _buildMerchantBody(),
          bottomNavigationBar: !isWide
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) async {
                    setState(() => _selectedIndex = index);
                    if (index == 1) {
                      // عند فتح تبويب المنتجات، نجلب القائمة الكاملة عند الحاجة فقط
                      final merchantProvider = Provider.of<MerchantProvider>(
                        context,
                        listen: false,
                      );
                      final productProvider = Provider.of<ProductProvider>(
                        context,
                        listen: false,
                      );

                      if (merchantProvider.selectedMerchant != null &&
                          productProvider.products.isEmpty &&
                          !productProvider.isLoading) {
                        try {
                          final storeId = await _ensureStoreId(
                            merchantProvider,
                          );
                          if (storeId != null) {
                            await productProvider.fetchProductsByStore(storeId);
                          }
                        } catch (e) {
                          AppLogger.error(
                            '❌ خطأ في جلب منتجات المتجر عند فتح التبويب',
                            e,
                          );
                        }
                      }
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'الرئيسية',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'المنتجات',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.shopping_cart_outlined),
                      selectedIcon: Icon(Icons.shopping_cart),
                      label: 'الطلبات',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: 'التقارير',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'الإعدادات',
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMerchantBody() {
    return ResponsiveCenter(
      maxWidth: 1000,
      child: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboardHome(),
            const MerchantProductsScreen(),
            const MerchantOrdersScreen(),
            const MerchantReportsScreen(),
            const MerchantSettingsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantSidebar(ColorScheme colorScheme, TextTheme textTheme) {
    final merchantProvider = Provider.of<MerchantProvider>(context);
    final user = Provider.of<SupabaseProvider>(context).currentUserProfile;
    final items = [
      (Icons.dashboard_outlined, Icons.dashboard, 'الرئيسية'),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'المنتجات'),
      (Icons.shopping_cart_outlined, Icons.shopping_cart, 'الطلبات'),
      (Icons.bar_chart_outlined, Icons.bar_chart, 'التقارير'),
      (Icons.settings_outlined, Icons.settings, 'الإعدادات'),
    ];
    return Container(
      width: 240,
      color: colorScheme.surface,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Icon(
                            Icons.store,
                            color: colorScheme.onPrimaryContainer,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchantProvider.selectedMerchant?.storeName ??
                              'المتجر',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'لوحة التاجر',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isSelected ? items[index].$2 : items[index].$1,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        title: Text(
                          items[index].$3,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected ? colorScheme.primary : null,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () => setState(() => _selectedIndex = index),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = Provider.of<SupabaseProvider>(context).currentUserProfile;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              user?.fullName ?? 'التاجر',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              backgroundImage: user?.avatarUrl != null
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null ? const Icon(Icons.store) : null,
            ),
            decoration: BoxDecoration(color: colorScheme.primary),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.add_box_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'إضافة منتج',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.addEditProduct);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'المحفظة',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.merchantWallet);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_offer_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'الكوبونات',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantCouponsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'المساعدة',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MerchantHelpScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHome() {
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final merchantProvider = Provider.of<MerchantProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    AppLogger.info(
      '🔍 Dashboard State: isLoading=${merchantProvider.isLoading}, isInitialized=$_isInitialized',
    );
    AppLogger.info(
      '🔍 Merchant: ${merchantProvider.selectedMerchant?.businessName}',
    );
    AppLogger.info('🔍 Products: ${productProvider.storeProductCount}');
    AppLogger.info('🔍 Orders: ${orderProvider.orders.length}');

    // Show loading if merchant data is being loaded
    if (merchantProvider.isLoading || !_isInitialized) {
      return _buildShimmerDashboard(colorScheme);
    }

    // Show error if merchant data failed to load
    if (merchantProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'فشل تحميل بيانات المتجر',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                merchantProvider.error!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  merchantProvider.clearData();
                  productProvider.clearProducts(resetCount: false);
                  _storeId = null;
                  if (mounted) {
                    setState(() {
                      _isInitialized = false;
                    });
                  }
                  await _loadData(force: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show message if no merchant found
    if (merchantProvider.selectedMerchant == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'لم يتم العثور على متجر',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'لم يتم العثور على متجر مرتبط بهذا الحساب\nيرجى التواصل مع الدعم الفني لإعداد متجرك',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        final crossAxisCount = isWideScreen ? 4 : 2;

        // حساب الإحصائيات
        final pendingOrders = orderProvider.orders
            .where((o) => o.status == OrderStatus.pending)
            .length;
        final activeOrders = orderProvider.orders
            .where(
              (o) =>
                  o.status != OrderStatus.delivered &&
                  o.status != OrderStatus.cancelled,
            )
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            merchantProvider.clearData();
            productProvider.clearProducts(resetCount: false);
            _storeId = null;
            setState(() {
              _isInitialized = false;
            });
            await _loadData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان الترحيب
                _buildWelcomeHeader(merchantProvider, textTheme, colorScheme),
                const SizedBox(height: 24),

                // البطاقات الإحصائية
                _buildStatsGrid(
                  isWideScreen,
                  crossAxisCount,
                  productProvider,
                  orderProvider,
                  pendingOrders,
                  activeOrders,
                  colorScheme,
                ),
                const SizedBox(height: 24),

                // التنبيهات الهامة
                if (pendingOrders > 0)
                  _buildAlertCard(
                    'طلبات جديدة تحتاج للمراجعة',
                    'لديك $pendingOrders ${pendingOrders == 1 ? "طلب جديد" : "طلبات جديدة"} في انتظار الموافقة',
                    Icons.notification_important,
                    colorScheme.primary,
                    () => setState(() => _selectedIndex = 2),
                  ),
                if (pendingOrders > 0) const SizedBox(height: 16),

                // الطلبات الأخيرة
                _buildSectionHeader(
                  'الطلبات الأخيرة',
                  'عرض الكل',
                  textTheme,
                  colorScheme,
                  () => setState(() => _selectedIndex = 2),
                ),
                const SizedBox(height: 12),
                _buildRecentOrders(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerDashboard(ColorScheme colorScheme) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad + 24),
      children: [
        Row(
          children: [
            _shimmerBox(width: 64, height: 64, radius: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: 160, height: 16),
                  const SizedBox(height: 8),
                  _shimmerBox(width: 120, height: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: List.generate(
            4,
            (_) => _shimmerBox(radius: 12, height: 110),
          ),
        ),
        const SizedBox(height: 24),
        _shimmerBox(radius: 12, height: 200),
        const SizedBox(height: 12),
        _shimmerBox(radius: 12, height: 200),
      ],
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 80,
    double radius = 8,
  }) {
    return AppShimmer.wrap(
      context,
      child: AppShimmer.box(
        context,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // رأس الترحيب
  Widget _buildWelcomeHeader(
    MerchantProvider merchantProvider,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final now = DateTime.now();
    String greeting;
    if (now.hour < 12) {
      greeting = 'صباح الخير';
    } else if (now.hour < 18) {
      greeting = 'مساء الخير';
    } else {
      greeting = 'مساء الخير';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          merchantProvider.selectedMerchant?.storeName ?? 'المتجر',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // شبكة الإحصائيات المحسّنة
  Widget _buildStatsGrid(
    bool isWideScreen,
    int crossAxisCount,
    ProductProvider productProvider,
    OrderProvider orderProvider,
    int pendingOrders,
    int activeOrders,
    ColorScheme colorScheme,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isWideScreen ? 1.5 : 1.0,
      children: [
        _buildEnhancedStatCard(
          'المنتجات',
          '${productProvider.storeProductCount}',
          'منتج نشط',
          Icons.inventory_2_outlined,
          colorScheme.primary,
          () => setState(() => _selectedIndex = 1),
        ),
        _buildEnhancedStatCard(
          'الطلبات الجديدة',
          '$pendingOrders',
          'في انتظار الموافقة',
          Icons.schedule_outlined,
          Colors.orange,
          () => setState(() => _selectedIndex = 2),
          showBadge: pendingOrders > 0,
        ),
        _buildEnhancedStatCard(
          'الطلبات النشطة',
          '$activeOrders',
          'قيد التنفيذ',
          Icons.sync_outlined,
          colorScheme.secondary,
          () => setState(() => _selectedIndex = 2),
        ),
        _buildEnhancedStatCard(
          'إجمالي المبيعات',
          _calculateTotalSales().toStringAsFixed(0),
          'طلبات مكتملة',
          Icons.trending_up_outlined,
          Colors.green,
          () => setState(() => _selectedIndex = 3),
        ),
      ],
    );
  }

  // بطاقة إحصائية محسّنة
  Widget _buildEnhancedStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback? onTap, {
    bool showBadge = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (showBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'جديد',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onError,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // رأس القسم مع زر إجراء اختياري
  Widget _buildSectionHeader(
    String title,
    String? actionText,
    TextTheme textTheme,
    ColorScheme colorScheme,
    VoidCallback? onActionPressed,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        if (actionText != null && onActionPressed != null)
          TextButton(
            onPressed: onActionPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionText),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
      ],
    );
  }

  // بطاقة تنبيه
  Widget _buildAlertCard(
    String title,
    String message,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    final orderProvider = Provider.of<OrderProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Get the most recent 5 orders
    final recentOrders = orderProvider.orders.take(5).toList();

    if (recentOrders.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد طلبات حديثة',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ستظهر هنا الطلبات الجديدة',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: List.generate(recentOrders.length, (index) {
          final order = recentOrders[index];
          final isLast = index == recentOrders.length - 1;

          return Column(
            children: [
              _buildOrderListTile(order, colorScheme, textTheme),
              if (!isLast)
                Divider(
                  color: colorScheme.outlineVariant,
                  height: 1,
                  indent: 72,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildOrderListTile(
    OrderModel order,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final statusInfo = _getOrderStatusInfo(order.status, colorScheme);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: statusInfo['backgroundColor'],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusInfo['icon'], color: statusInfo['color'], size: 20),
              const SizedBox(height: 2),
              Text(
                '#${order.id.substring(order.id.length - 4)}',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusInfo['color'],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
      title: Text(
        'طلب ${order.orderNumber ?? "#${order.id.substring(0, 8)}"}',
        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatOrderTime(order.createdAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildOrderStatusChipFromOrder(order),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            order.totalAmount.toStringAsFixed(0),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          Text(
            'ج.م',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: () {
        setState(() => _selectedIndex = 2);
      },
    );
  }

  String _formatOrderTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} ${difference.inDays == 1 ? "يوم" : "أيام"}';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  Map<String, dynamic> _getOrderStatusInfo(
    OrderStatus status,
    ColorScheme colorScheme,
  ) {
    switch (status) {
      case OrderStatus.pending:
        return {
          'color': Colors.orange,
          'backgroundColor': Colors.orange.withValues(alpha: 0.1),
          'icon': Icons.schedule,
        };
      case OrderStatus.confirmed:
        return {
          'color': Colors.blue,
          'backgroundColor': Colors.blue.withValues(alpha: 0.1),
          'icon': Icons.check_circle_outline,
        };
      case OrderStatus.preparing:
        return {
          'color': colorScheme.tertiary,
          'backgroundColor': colorScheme.tertiaryContainer,
          'icon': Icons.restaurant,
        };
      case OrderStatus.ready:
        return {
          'color': Colors.purple,
          'backgroundColor': Colors.purple.withValues(alpha: 0.1),
          'icon': Icons.done_all,
        };
      case OrderStatus.pickedUp:
        return {
          'color': Colors.indigo,
          'backgroundColor': Colors.indigo.withValues(alpha: 0.1),
          'icon': Icons.local_shipping,
        };
      case OrderStatus.inTransit:
        return {
          'color': Colors.indigo,
          'backgroundColor': Colors.indigo.withValues(alpha: 0.1),
          'icon': Icons.local_shipping,
        };
      case OrderStatus.delivered:
        return {
          'color': Colors.green,
          'backgroundColor': Colors.green.withValues(alpha: 0.1),
          'icon': Icons.task_alt,
        };
      case OrderStatus.cancelled:
        return {
          'color': colorScheme.error,
          'backgroundColor': colorScheme.errorContainer,
          'icon': Icons.cancel,
        };
    }
  }

  Widget _buildOrderStatusChipFromOrder(OrderModel order) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color chipColor = colorScheme.primary;
    Color backgroundColor = colorScheme.primaryContainer;

    switch (order.status) {
      case OrderStatus.pending:
        chipColor = Colors.orange;
        backgroundColor = Colors.orange.withValues(alpha: 0.15);
        break;
      case OrderStatus.confirmed:
        chipColor = Colors.blue;
        backgroundColor = Colors.blue.withValues(alpha: 0.15);
        break;
      case OrderStatus.preparing:
        chipColor = colorScheme.tertiary;
        backgroundColor = colorScheme.tertiaryContainer;
        break;
      case OrderStatus.ready:
        chipColor = Colors.purple;
        backgroundColor = Colors.purple.withValues(alpha: 0.15);
        break;
      case OrderStatus.pickedUp:
      case OrderStatus.inTransit:
        chipColor = Colors.indigo;
        backgroundColor = Colors.indigo.withValues(alpha: 0.15);
        break;
      case OrderStatus.delivered:
        chipColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        break;
      case OrderStatus.cancelled:
        chipColor = colorScheme.error;
        backgroundColor = colorScheme.errorContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        order.status.displayName,
        style: textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  double _calculateTotalSales() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // حساب إجمالي المبيعات للطلبات التي تم توصيلها فقط
    return orderProvider.orders
        .where((order) => order.status == OrderStatus.delivered)
        .fold<double>(0.0, (total, order) => total + order.totalAmount);
  }
}

// ===== Bottom Sheet Content Widget =====
class _NotificationsBottomSheetContent extends StatelessWidget {
  final String? targetRole;
  final ScrollController scrollController;

  const _NotificationsBottomSheetContent({
    this.targetRole,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final authProvider = Provider.of<SupabaseProvider>(context);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return _buildLoginRequired();
    }

    if (notificationProvider.isLoading) {
      return AppShimmer.list(context);
    }

    final notifications = notificationProvider.getNotificationsForRole(
      targetRole,
    );

    if (notificationProvider.error != null) {
      return _buildError(notificationProvider, userId);
    }

    if (notifications.isEmpty) {
      return _buildEmpty();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(
          context,
          notification,
          notificationProvider,
        );
      },
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'يرجى تسجيل الدخول',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتسجيل الدخول لعرض الإشعارات',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError(NotificationProvider provider, String userId) {
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
              onPressed: () => provider.loadUserNotifications(
                userId,
                targetRole: 'merchant',
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد إشعارات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم إعلامك عند وجود إشعارات جديدة',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: notification.isRead
            ? Colors.white
            : AppColors.primary.withAlpha(25),
        elevation: notification.isRead ? 1 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: _getNotificationIcon(
            notification.type ?? NotificationType.system,
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                notification.createdAtRelative,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
          onTap: () {
            if (!notification.isRead) {
              provider.markAsRead(notification.id);
            }
            Navigator.pop(context); // Close bottom sheet
            _handleNotificationTap(context, notification);
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
        icon = Icons.shopping_cart_rounded;
        color = AppColors.primary;
        break;
      case NotificationType.promotion:
        icon = Icons.local_offer_rounded;
        color = AppColors.secondary;
        break;
      case NotificationType.system:
        icon = Icons.info_rounded;
        color = AppColors.info;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) {
    final data = notification.data ?? {};

    debugPrint('📬 Tapped Notification: ${notification.title}');
    debugPrint('📊 Notification Type: ${notification.type}');
    debugPrint('📦 Notification Data: $data');

    switch (notification.type) {
      case NotificationType.order:
        _navigateToOrderNotification(context, data);
        break;
      case NotificationType.promotion:
        _navigateToPromotionNotification(context, data);
        break;
      case NotificationType.system:
      default:
        _navigateToSystemNotification(context, data);
        break;
    }
  }

  void _navigateToOrderNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final orderId = data['order_id'] as String?;
    if (orderId != null) {
      // Navigate to merchant orders screen
      // Since we're already in merchant dashboard, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('طلب رقم: ${orderId.substring(0, 8)}...'),
          action: SnackBarAction(
            label: 'عرض',
            onPressed: () {
              // Navigate to orders tab in merchant dashboard
            },
          ),
        ),
      );
    }
  }

  void _navigateToPromotionNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final productId = data['productId'] as String?;
    if (productId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.productDetail,
        arguments: productId,
      );
    }
  }

  void _navigateToSystemNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final actionRoute = data['actionRoute'] as String?;
    if (actionRoute != null) {
      Navigator.pushNamed(context, actionRoute);
    }
  }
}
