import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/services/product_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:ell_tall_market/screens/merchant/template_manager_screen.dart';
import 'package:ell_tall_market/screens/merchant/add_edit_product_screen.dart';
import 'package:ell_tall_market/screens/merchant/import_products_screen.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoadingStore = true;
  String? _storeId;
  String? _errorMessage;
  bool _isInitialized = false;
  Timer? _autoRefreshTimer;
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, available, outOfStock

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController?.addListener(() {
      if (_tabController?.indexIsChanging == true && mounted) {
        setState(() {
          _selectedFilter = _getFilterByIndex(_tabController!.index);
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantProducts();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getFilterByIndex(int index) {
    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'available';
      case 2:
        return 'outOfStock';
      default:
        return 'all';
    }
  }

  // تحديث تلقائي كل دقيقة
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      if (mounted && _isInitialized) {
        _loadMerchantProducts(silent: true);
      }
    });
  }

  Future<void> _loadMerchantProducts({bool silent = false}) async {
    AppLogger.info(
      '🔄 بدء تحميل منتجات التاجر... (silent: $silent, initialized: $_isInitialized)',
    );

    if (!silent) {
      setState(() {
        _isLoadingStore = true;
        _errorMessage = null;
      });
    }

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final merchantProvider = Provider.of<MerchantProvider>(
        context,
        listen: false,
      );
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );

      AppLogger.info('✅ المستخدم مسجل الدخول: ${authProvider.isLoggedIn}');

      // تحميل بيانات التاجر أولاً إذا لم تكن محملة
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        AppLogger.info(
          '👤 معرف المستخدم: ${authProvider.currentUserProfile!.id}',
        );

        // جلب بيانات التاجر دائماً لضمان التحديث
        AppLogger.info('📥 جلب بيانات التاجر...');
        await merchantProvider.fetchMerchantByProfileId(
          authProvider.currentUserProfile!.id,
        );

        // الانتظار قليلاً للتأكد من تحميل البيانات
        await Future.delayed(Duration(milliseconds: 500));

        // الآن جلب المنتجات لمتجر هذا التاجر
        if (merchantProvider.selectedMerchant != null) {
          AppLogger.info(
            '✅ تم العثور على التاجر: ${merchantProvider.selectedMerchant!.id}',
          );
          AppLogger.info(
            '🏪 اسم المتجر: ${merchantProvider.selectedMerchant!.storeName}',
          );

          // الحصول على store_id لهذا التاجر
          final storeResponse = await Supabase.instance.client
              .from('stores')
              .select('id')
              .eq('merchant_id', merchantProvider.selectedMerchant!.id)
              .maybeSingle();

          if (storeResponse == null) {
            AppLogger.warning('❌ لم يتم العثور على متجر للتاجر');
            if (mounted) {
              setState(() {
                _errorMessage = 'لم يتم العثور على متجر لهذا التاجر';
                _isLoadingStore = false;
              });
            }
            return;
          }

          _storeId = storeResponse['id'] as String;
          AppLogger.info('🏪 معرف المتجر: $_storeId');

          // جلب المنتجات لهذا المتجر فقط
          AppLogger.info('📦 جلب المنتجات للمتجر...');
          await productProvider.fetchProductsByStore(_storeId!);
          AppLogger.info('✅ تم جلب ${productProvider.products.length} منتج');

          if (mounted) {
            setState(() {
              _isLoadingStore = false;
              _isInitialized = true;
            });
          }
          AppLogger.info('✅ تم تحميل المنتجات بنجاح');
        } else {
          AppLogger.warning('❌ لم يتم العثور على بيانات التاجر');
          if (mounted) {
            setState(() {
              _errorMessage = 'لم يتم العثور على بيانات التاجر';
              _isLoadingStore = false;
            });
          }
        }
      } else {
        AppLogger.warning('❌ المستخدم غير مسجل الدخول');
        if (mounted) {
          setState(() {
            _errorMessage = 'يرجى تسجيل الدخول أولاً';
            _isLoadingStore = false;
          });
        }
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب منتجات المتجر', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في تحميل المنتجات: $e';
          _isLoadingStore = false;
        });
      }
    }
  }

  Future<void> _duplicateProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_copy, color: Colors.blue),
            SizedBox(width: 8),
            Text('نسخ المنتج'),
          ],
        ),
        content: Text('هل تريد إنشاء نسخة من "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نسخ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoadingStore = true);

    try {
      final duplicated = await ProductService.duplicateProduct(product);

      if (duplicated != null && mounted) {
        // Refresh the list
        await _loadMerchantProducts(silent: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم نسخ المنتج: ${duplicated.name}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'تعديل',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddEditProductScreen(product: duplicated),
                    ),
                  ).then((_) => _loadMerchantProducts());
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل نسخ المنتج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStore = false);
      }
    }
  }

  // دوال مساعدة للإحصائيات
  int _getAvailableCount(List<ProductModel> products) {
    return products.where((p) => p.isAvailable).length;
  }

  int _getOutOfStockCount(List<ProductModel> products) {
    return products.where((p) => !p.isAvailable).length;
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    var filtered = products;

    // تطبيق فلتر البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.description?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (_selectedFilter == 'available') {
      filtered = filtered.where((p) => p.isAvailable).toList();
    } else if (_selectedFilter == 'outOfStock') {
      filtered = filtered.where((p) => !p.isAvailable).toList();
    }

    return filtered;
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('بحث في المنتجات'),
        content: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المنتج أو الوصف...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              Navigator.pop(context);
            },
            child: Text('مسح'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('بحث'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final products = productProvider.products;
    final totalProducts = products.length;
    final available = _getAvailableCount(products);
    final outOfStock = _getOutOfStockCount(products);
    final totalValue = products.fold<double>(
      0,
      (sum, product) => sum + (product.price * product.stock),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text('إحصائيات المنتجات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(
              'إجمالي المنتجات',
              '$totalProducts',
              Icons.inventory_2,
            ),
            Divider(),
            _buildStatRow(
              'منتجات متوفرة',
              '$available',
              Icons.check_circle,
              color: Colors.green,
            ),
            Divider(),
            _buildStatRow(
              'منتجات نفذت',
              '$outOfStock',
              Icons.warning,
              color: Colors.red,
            ),
            Divider(),
            _buildStatRow(
              'قيمة المخزون',
              '${totalValue.toStringAsFixed(0)} ج.م',
              Icons.attach_money,
              color: Colors.blue,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey, size: 20),
        SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14))),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final merchantProvider = Provider.of<MerchantProvider>(context);
    final theme = Theme.of(context);

    AppLogger.info(
      '🔍 Products Screen State: isLoading=$_isLoadingStore, isInitialized=$_isInitialized',
    );
    AppLogger.info('🔍 Products count: ${productProvider.products.length}');
    AppLogger.info(
      '🔍 Merchant: ${merchantProvider.selectedMerchant?.storeName}',
    );

    // التأكد من تهيئة TabController
    if (_tabController == null) {
      return Scaffold(
        appBar: AppBar(title: Text('منتجاتي')),
        body: AppShimmer.centeredLines(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('منتجاتي', style: TextStyle(fontSize: 18)),
            if (_isInitialized)
              Text(
                '${_getFilteredProducts(productProvider.products).length} منتج',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        centerTitle: false,
        actions: [
          // زر البحث
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'بحث',
          ),
          // زر الإحصائيات
          IconButton(
            icon: Badge(
              label: Text('${_getOutOfStockCount(productProvider.products)}'),
              isLabelVisible: _getOutOfStockCount(productProvider.products) > 0,
              child: Icon(Icons.analytics_outlined),
            ),
            onPressed: _showStatsDialog,
            tooltip: 'الإحصائيات',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            height: 48,
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController!,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('الكل'),
                      SizedBox(width: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${productProvider.products.length}',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('متوفر'),
                      SizedBox(width: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_getAvailableCount(productProvider.products)}',
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('نفذ'),
                      SizedBox(width: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_getOutOfStockCount(productProvider.products)}',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: RefreshIndicator(
          notificationPredicate: (notification) {
            // TabBarView nests the vertical ListView(s), so the default
            // depth==0 predicate can prevent refresh from triggering.
            return notification.metrics.axis == Axis.vertical;
          },
          onRefresh: _loadMerchantProducts,
          child: _isLoadingStore
              ? _buildShimmerList()
              : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController!,
                  children: [
                    _buildProductsList(productProvider, 'all'),
                    _buildProductsList(productProvider, 'available'),
                    _buildProductsList(productProvider, 'outOfStock'),
                  ],
                ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Manage Templates Button (Small FAB)
          if (_isInitialized)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.small(
                heroTag: 'import_excel',
                onPressed: () {
                  if (_storeId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ImportProductsScreen(storeId: _storeId!),
                      ),
                    ).then((result) {
                      if (result == true) _loadMerchantProducts();
                    });
                  }
                },
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                tooltip: 'استيراد من Excel',
                child: const Icon(Icons.table_view),
              ),
            ),
          // Manage Templates Button (Small FAB)
          if (_isInitialized)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.small(
                heroTag: 'manage_templates',
                onPressed: () {
                  if (_storeId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TemplateManagerScreen(storeId: _storeId!),
                      ),
                    ).then((_) => _loadMerchantProducts());
                  }
                },
                tooltip: 'إدارة القوالب',
                child: const Icon(Icons.style),
              ),
            ),
          // Main Add Product Button
          FloatingActionButton.extended(
            heroTag: 'add_product',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.addEditProduct,
              ).then((_) => _loadMerchantProducts());
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة منتج'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'حدث خطأ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 20),
              CustomButton(
                text: 'إعادة المحاولة',
                onPressed: _loadMerchantProducts,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    final cs = Theme.of(context).colorScheme;
    return AppShimmer.wrap(
      context,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => Container(
          height: 110,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(ProductProvider provider, String filter) {
    if (provider.isLoading && !_isInitialized) {
      return _buildShimmerList();
    }

    // تطبيق الفلتر
    final filteredProducts = _getFilteredProductsByFilter(
      provider.products,
      filter,
    );

    if (filteredProducts.isEmpty) {
      return _buildEmptyStateForFilter(filter);
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: 80, // مسافة إضافية لزر الإضافة
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildEnhancedProductCard(product),
        );
      },
    );
  }

  List<ProductModel> _getFilteredProductsByFilter(
    List<ProductModel> products,
    String filter,
  ) {
    var filtered = products;

    // تطبيق فلتر البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.description?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (filter == 'available') {
      filtered = filtered.where((p) => p.isAvailable).toList();
    } else if (filter == 'outOfStock') {
      filtered = filtered.where((p) => !p.isAvailable).toList();
    }

    return filtered;
  }

  Widget _buildEmptyStateForFilter(String filter) {
    String message, subMessage;
    IconData icon;

    switch (filter) {
      case 'available':
        icon = Icons.inventory_2_outlined;
        message = 'لا توجد منتجات متوفرة';
        subMessage = 'قم بتحديث المخزون';
        break;
      case 'outOfStock':
        icon = Icons.production_quantity_limits;
        message = 'لا توجد منتجات نفذت';
        subMessage = 'رائع! جميع المنتجات متوفرة';
        break;
      default:
        icon = Icons.inventory;
        message = 'لا توجد منتجات';
        subMessage = 'ابدأ بإضافة منتجك الأول';
    }

    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: Colors.grey.shade300),
              SizedBox(height: 20),
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                subMessage,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              if (filter == 'all') ...[
                SizedBox(height: 20),
                CustomButton(
                  text: 'إضافة منتج جديد',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.addEditProduct,
                    ).then((_) => _loadMerchantProducts());
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedProductCard(ProductModel product) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.addEditProduct,
            arguments: product,
          ).then((_) => _loadMerchantProducts());
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(12),
                      ),
                      color: Colors.grey.shade200,
                      image: product.hasImage
                          ? DecorationImage(
                              image: NetworkImage(product.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.hasImage
                        ? null
                        : Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                  // شارة الحالة
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.stockStatus,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // معلومات المنتج
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 20),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('تعديل'),
                                ],
                              ),
                              onTap: () {
                                final navigator = Navigator.of(context);
                                Future.delayed(Duration.zero, () {
                                  navigator
                                      .pushNamed(
                                        AppRoutes.addEditProduct,
                                        arguments: product,
                                      )
                                      .then((_) => _loadMerchantProducts());
                                });
                              },
                            ),
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.content_copy, size: 18),
                                  SizedBox(width: 8),
                                  Text('نسخ المنتج'),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  _duplicateProduct(product);
                                });
                              },
                            ),
                            PopupMenuItem(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'حذف',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  _showDeleteDialog(product);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        product.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'المخزون: ${product.stock}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Spacer(),
                        Text(
                          product.priceFormatted,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف المنتج'),
        content: Text('هل أنت متأكد من أنك تريد حذف "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(ProductModel product) async {
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    try {
      // احذف من قاعدة البيانات مع تأكيد النجاح أو سبب الفشل
      await ProductService.deleteProduct(product.id);

      // حاول حذف الصور من التخزين (غير حاجز)
      await ProductService.deleteProductImages(
        storeId: product.storeId,
        productId: product.id,
      );

      // أنعش قائمة المنتجات لهذا المتجر
      await productProvider.fetchProductsByStore(product.storeId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المنتج بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حذف المنتج: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
