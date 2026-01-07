import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/providers/locale_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/order_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/notification_provider.dart';
import 'package:ell_tall_market/models/order_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/screens/merchant/merchant_products_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_orders_screen.dart';
import 'package:ell_tall_market/screens/common/notifications_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_settings_screen.dart';
import 'package:ell_tall_market/screens/merchant/merchant_coupons_screen.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:shimmer/shimmer.dart';

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
    _handleAuthChange(authProvider.currentUser?.id);
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

  Future<void> _loadData() async {
    // منع التحميل المتكرر
    if (_isInitialized) {
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
      if (profileId == null) {
        try {
          final profileRow = await Supabase.instance.client
              .from('profiles')
              .select('id')
              .eq('user_id', authProvider.currentUser!.id)
              .maybeSingle();
          profileId = profileRow?['id'] as String?;
          AppLogger.info('🔑 ProfileId fallback: $profileId');
        } on PostgrestException catch (e) {
          AppLogger.error('⛔ PostgREST ${e.code}: ${e.message}', e);
        } catch (e) {
          AppLogger.error('❌ فشل جلب البروفايل للمستخدم', e);
        }
      }

      if (profileId != null &&
          merchantProvider.selectedMerchant == null &&
          !merchantProvider.isLoading) {
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
        } else {
          AppLogger.warning('⚠️ لم يتم العثور على معرف المتجر');
        }
      } else {
        // محاولة احتياطية مباشرة عبر جدول merchants
        try {
          if (profileId != null) {
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
          }
        } on PostgrestException catch (e) {
          AppLogger.error('⛔ PostgREST ${e.code}: ${e.message}', e);
        } catch (e) {
          AppLogger.error('❌ فشل محاولة العثور على التاجر احتياطياً', e);
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

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            merchantProvider.selectedMerchant?.storeName ?? 'لوحة تحكم المتجر',
            style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary),
          ),
          centerTitle: true,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
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
                final unreadCount = notificationProvider.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                      tooltip: 'الإشعارات',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: 10,
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
        drawer: _buildDrawer(),
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildDashboardHome(),
              const MerchantProductsScreen(), // استخدام الشاشة الفعلية للمنتجات
              const MerchantOrdersScreen(), // استخدام الشاشة الفعلية للطلبات
              _buildAnalyticsPage(),
              const MerchantSettingsScreen(),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
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
                  final storeId = await _ensureStoreId(merchantProvider);
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
                _buildDrawerItem(0, 'الرئيسية', Icons.dashboard_outlined),
                _buildDrawerItem(1, 'المنتجات', Icons.inventory_2_outlined),
                _buildDrawerItem(2, 'الطلبات', Icons.shopping_cart_outlined),
                _buildDrawerItem(3, 'التقارير', Icons.bar_chart_outlined),
                _buildDrawerItem(4, 'الإعدادات', Icons.settings_outlined),
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
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSelected = _selectedIndex == index;

    return ListTile(
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
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
                onPressed: _loadData,
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
                const SizedBox(height: 24),

                // إجراءات سريعة
                _buildSectionHeader(
                  'إجراءات سريعة',
                  null,
                  textTheme,
                  colorScheme,
                  null,
                ),
                const SizedBox(height: 12),
                _buildQuickActions(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerDashboard(ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
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
      ),
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 80,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
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
          null,
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

  Widget _buildAnalyticsPage() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'صفحة التقارير',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'تحليلات الأداء والمبيعات',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  Widget _buildQuickActions() {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = [
      _buildActionButton(
        'إضافة منتج',
        Icons.add_box_outlined,
        colorScheme.primary,
        colorScheme.onPrimary,
        () {
          Navigator.pushNamed(context, AppRoutes.addEditProduct);
        },
      ),
      _buildActionButton(
        'عرض المنتجات',
        Icons.inventory_2_outlined,
        colorScheme.secondary,
        colorScheme.onSecondary,
        () {
          setState(() => _selectedIndex = 1);
        },
      ),
      _buildActionButton(
        'الطلبات',
        Icons.shopping_cart_outlined,
        colorScheme.tertiary,
        colorScheme.onTertiary,
        () {
          setState(() => _selectedIndex = 2);
        },
      ),
      _buildActionButton(
        'المحفظة',
        Icons.account_balance_wallet_outlined,
        Colors.green,
        Colors.white,
        () {
          Navigator.pushNamed(context, AppRoutes.merchantWallet);
        },
      ),
      _buildActionButton(
        'الكوبونات',
        Icons.local_offer_outlined,
        Colors.orange,
        Colors.white,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MerchantCouponsScreen()),
          );
        },
      ),
      _buildActionButton(
        'الإعدادات',
        Icons.settings_outlined,
        colorScheme.surfaceContainerHighest,
        colorScheme.primary,
        () {
          setState(() => _selectedIndex = 4);
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        final crossAxisCount = isWideScreen ? 6 : 3;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: actions,
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color backgroundColor,
    Color foregroundColor,
    VoidCallback onPressed,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: backgroundColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: foregroundColor, size: 24),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
