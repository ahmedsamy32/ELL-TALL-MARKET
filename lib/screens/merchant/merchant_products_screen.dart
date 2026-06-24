import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:provider/provider.dart';
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
  bool _isLoadingData = false;
  String? _storeId;
  String? _errorMessage;
  bool _isInitialized = false;
  Timer? _autoRefreshTimer;
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  // أعداد المنتجات الكلية من قاعدة البيانات
  int _totalActiveCount = 0;
  int _totalInactiveCount = 0;
  int _totalAvailableCount = 0;
  int _totalOutOfStockCount = 0;
  double _totalStockValue = 0.0;

  // الحالات الخاصة بكل تبويب بشكل منفصل
  final List<List<ProductModel>> _tabProducts = [[], [], [], []];
  final List<bool> _tabLoading = [false, false, false, false];
  final List<bool> _tabHasMore = [true, true, true, true];
  final List<int> _tabPages = [1, 1, 1, 1];

  // حالة التحديد المتعدد
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController!.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantProducts();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging) return;
    final index = _tabController!.index;
    // مسح التحديد عند تغيير التبويب
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
    }
    if (_tabProducts[index].isEmpty && _tabHasMore[index]) {
      _loadTabProducts(index);
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
    if (_isLoadingData) return;
    _isLoadingData = true;
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

      AppLogger.info('✅ المستخدم مسجل الدخول: ${authProvider.isLoggedIn}');

      // تحميل بيانات التاجر أولاً إذا لم تكن محملة
      if (authProvider.isLoggedIn && authProvider.currentUser != null) {
        if (authProvider.currentUserProfile == null) {
          AppLogger.info('⏳ لم يتم تحميل بيانات المستخدم بعد');
          return;
        }
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

          // جلب الأعداد الكلية والأسعار للمنتجات من قاعدة البيانات
          await _loadProductCounts(_storeId!);

          // تهيئة/تحديث التبويب النشط فقط وإلغاء تهيئة التبويبات الأخرى
          for (int i = 0; i < 4; i++) {
            if (i != _tabController!.index) {
              _tabProducts[i] = [];
              _tabHasMore[i] = true;
              _tabPages[i] = 1;
            }
          }

          await _loadTabProducts(_tabController!.index, refresh: true, silent: silent);

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
    } finally {
      _isLoadingData = false;
    }
  }

  Future<void> _loadProductCounts(String storeId) async {
    try {
      final supabase = Supabase.instance.client;
      final results = await Future.wait<dynamic>([
        supabase
            .from('products')
            .select('id')
            .eq('store_id', storeId)
            .eq('is_active', true)
            .count(CountOption.exact),
        supabase
            .from('products')
            .select('id')
            .eq('store_id', storeId)
            .eq('is_active', false)
            .count(CountOption.exact),
        supabase
            .from('products')
            .select('id')
            .eq('store_id', storeId)
            .eq('in_stock', true)
            .gt('stock_quantity', 0)
            .count(CountOption.exact),
        supabase
            .from('products')
            .select('id')
            .eq('store_id', storeId)
            .or('in_stock.eq.false,stock_quantity.lte.0')
            .count(CountOption.exact),
        supabase
            .from('products')
            .select('price, stock_quantity')
            .eq('store_id', storeId),
      ]);

      if (mounted) {
        final rawData = results[4];
        final valList = rawData is PostgrestResponse ? rawData.data as List : rawData as List;
        double totalVal = 0.0;
        for (var item in valList) {
          final price = double.tryParse(item['price'].toString()) ?? 0.0;
          final stock = int.tryParse(item['stock_quantity'].toString()) ?? 0;
          totalVal += price * stock;
        }

        setState(() {
          _totalActiveCount = results[0].count;
          _totalInactiveCount = results[1].count;
          _totalAvailableCount = results[2].count;
          _totalOutOfStockCount = results[3].count;
          _totalStockValue = totalVal;
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل أعداد المنتجات الكلية', e);
    }
  }

  Future<void> _loadTabProducts(int tabIndex, {bool refresh = false, bool silent = false}) async {
    if (_storeId == null) return;
    if (_tabLoading[tabIndex] && !refresh) return;

    setState(() {
      _tabLoading[tabIndex] = true;
      if (refresh) {
        _tabPages[tabIndex] = 1;
        _tabHasMore[tabIndex] = true;
        if (!silent) {
          _tabProducts[tabIndex] = [];
        }
      }
    });

    try {
      final int page = _tabPages[tabIndex];
      final int pageSize = 20;
      final int startIndex = (page - 1) * pageSize;

      var query = Supabase.instance.client
          .from('products')
          .select('*, categories(*), stores(*)')
          .eq('store_id', _storeId!);

      if (tabIndex == 0) {
        query = query.eq('is_active', true);
      } else if (tabIndex == 1) {
        query = query.eq('is_active', false);
      } else if (tabIndex == 2) {
        query = query.eq('in_stock', true).gt('stock_quantity', 0);
      } else if (tabIndex == 3) {
        query = query.or('in_stock.eq.false,stock_quantity.lte.0');
      }

      if (_searchQuery.trim().isNotEmpty) {
        query = query.or('name.ilike.%${_searchQuery.trim()}%,description.ilike.%${_searchQuery.trim()}%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(startIndex, startIndex + pageSize - 1);

      final List<ProductModel> fetchedProducts = (response as List)
          .map((data) => ProductModel.fromMap(data))
          .toList();

      if (mounted) {
        setState(() {
          if (refresh) {
            _tabProducts[tabIndex] = fetchedProducts;
          } else {
            _tabProducts[tabIndex].addAll(fetchedProducts);
          }

          if (fetchedProducts.length < pageSize) {
            _tabHasMore[tabIndex] = false;
          }
          _tabPages[tabIndex] = page + 1;
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل منتجات التبويب $tabIndex', e);
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _tabLoading[tabIndex] = false;
        });
      }
    }
  }

  void _reloadAllTabs() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      for (int i = 0; i < 4; i++) {
        _tabProducts[i] = [];
        _tabLoading[i] = false;
        _tabHasMore[i] = true;
        _tabPages[i] = 1;
      }
    });
    if (_storeId != null) {
      _loadProductCounts(_storeId!);
      _loadTabProducts(_tabController!.index, refresh: true);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(productId);
      }
    });
  }

  void _selectAllInCurrentTab() {
    final tabIndex = _tabController!.index;
    final products = _tabProducts[tabIndex];
    setState(() {
      if (_selectedIds.length == products.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(products.map((p) => p.id));
      }
    });
  }

  List<ProductModel> get _selectedProducts {
    final tabIndex = _tabController!.index;
    return _tabProducts[tabIndex]
        .where((p) => _selectedIds.contains(p.id))
        .toList();
  }

  // ---- إجراءات التحديد المتعدد ----

  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('حذف $count منتج'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف $count منتج؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف الكل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoadingStore = true);
    try {
      final ids = List<String>.from(_selectedIds);
      for (final id in ids) {
        await ProductService.deleteProduct(id);
      }
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      _reloadAllTabs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف $count منتج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStore = false);
    }
  }

  Future<void> _bulkSetActive(bool activate) async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final label = activate ? 'تفعيل' : 'إلغاء تفعيل';
    setState(() => _isLoadingStore = true);
    try {
      await Supabase.instance.client
          .from('products')
          .update({'is_active': activate})
          .inFilter('id', List<String>.from(_selectedIds));
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      _reloadAllTabs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم $label $count منتج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإجراء: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStore = false);
    }
  }

  Future<void> _bulkDuplicate() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.content_copy, color: Colors.blue),
            SizedBox(width: 8),
            Text('نسخ $count منتج'),
          ],
        ),
        content: Text('هل تريد إنشاء نسخة من $count منتج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('نسخ الكل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoadingStore = true);
    try {
      final selected = _selectedProducts;
      for (final product in selected) {
        await ProductService.duplicateProduct(product);
      }
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      _reloadAllTabs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نسخ $count منتج بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل النسخ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStore = false);
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
              _reloadAllTabs();
            },
            child: Text('مسح'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _reloadAllTabs();
            },
            child: Text('بحث'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
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
              '${_totalActiveCount + _totalInactiveCount}',
              Icons.inventory_2,
            ),
            Divider(),
            _buildStatRow(
              'منتجات متوفرة',
              '$_totalAvailableCount',
              Icons.check_circle,
              color: Colors.green,
            ),
            Divider(),
            _buildStatRow(
              'منتجات نفذت',
              '$_totalOutOfStockCount',
              Icons.warning,
              color: Colors.red,
            ),
            Divider(),
            _buildStatRow(
              'قيمة المخزون',
              '${_totalStockValue.toStringAsFixed(0)} ج.م',
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
    final merchantProvider = Provider.of<MerchantProvider>(context);
    final theme = Theme.of(context);

    AppLogger.info(
      '🔍 Products Screen State: isLoading=$_isLoadingStore, isInitialized=$_isInitialized',
    );
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
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: _toggleSelectionMode,
                tooltip: 'إلغاء التحديد',
              ),
              title: Text(
                _selectedIds.isEmpty
                    ? 'اختر المنتجات'
                    : 'تم تحديد ${_selectedIds.length}',
              ),
              centerTitle: false,
              backgroundColor: theme.colorScheme.primaryContainer,
              actions: [
                TextButton.icon(
                  onPressed: _selectAllInCurrentTab,
                  icon: Icon(
                    _selectedIds.length ==
                            _tabProducts[_tabController!.index].length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  label: Text(
                    _selectedIds.length ==
                            _tabProducts[_tabController!.index].length
                        ? 'إلغاء الكل'
                        : 'تحديد الكل',
                  ),
                ),
              ],
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('منتجاتي', style: TextStyle(fontSize: 18)),
                  if (_isInitialized)
                    Text(
                      '${_totalActiveCount + _totalInactiveCount} منتج',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
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
                    label: Text('$_totalOutOfStockCount'),
                    isLabelVisible: _totalOutOfStockCount > 0,
                    child: Icon(Icons.analytics_outlined),
                  ),
                  onPressed: _showStatsDialog,
                  tooltip: 'الإحصائيات',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 48,
                  color: theme.colorScheme.surface,
                  child: TabBar(
                    controller: _tabController!,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('فعال'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_totalActiveCount',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onPrimaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('غير فعال'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_totalInactiveCount',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('متوفر'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_totalAvailableCount',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('نفذ'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_totalOutOfStockCount',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.red),
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
                    _buildProductsList(0),
                    _buildProductsList(1),
                    _buildProductsList(2),
                    _buildProductsList(3),
                  ],
                ),
        ),
      ),
      // شريط الإجراءات السفلي عند التحديد المتعدد
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildSelectionActionBar()
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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

  Widget _buildSelectionActionBar() {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // حذف
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'حذف',
              color: Colors.red,
              onTap: _bulkDeleteSelected,
            ),
            Container(width: 1, height: 40, color: theme.dividerColor),
            // تفعيل — يظهر فقط في تبويب "غير فعال" و"متوفر" و"نفذ"
            if (_tabController!.index != 0)
              _buildActionButton(
                icon: Icons.check_circle_outline,
                label: 'تفعيل',
                color: Colors.green,
                onTap: () => _bulkSetActive(true),
              ),
            if (_tabController!.index != 0 && _tabController!.index != 1)
              Container(width: 1, height: 40, color: theme.dividerColor),
            // تعطيل — يظهر فقط في تبويب "فعال" و"متوفر" و"نفذ"
            if (_tabController!.index != 1)
              _buildActionButton(
                icon: Icons.cancel_outlined,
                label: 'تعطيل',
                color: Colors.orange,
                onTap: () => _bulkSetActive(false),
              ),
            Container(width: 1, height: 40, color: theme.dividerColor),
            // نسخ
            _buildActionButton(
              icon: Icons.content_copy_outlined,
              label: 'نسخ',
              color: Colors.blue,
              onTap: _bulkDuplicate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
                isLoading: _isLoadingData,
                width: 180,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildProductsList(int tabIndex) {
    final isLoading = _tabLoading[tabIndex];
    final products = _tabProducts[tabIndex];
    final hasMore = _tabHasMore[tabIndex];

    if (isLoading && products.isEmpty) {
      return _buildShimmerList();
    }

    if (products.isEmpty) {
      return _buildEmptyStateForTab(tabIndex);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          if (!isLoading && hasMore) {
            _loadTabProducts(tabIndex);
          }
        }
        return true;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: _isSelectionMode ? 16 : 80,
        ),
        itemCount: products.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == products.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final product = products[index];
          final isSelected = _selectedIds.contains(product.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEnhancedProductCard(product, isSelected: isSelected),
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateForTab(int tabIndex) {
    final filters = ['active', 'inactive', 'available', 'outOfStock'];
    return _buildEmptyStateForFilter(filters[tabIndex]);
  }

  Widget _buildEmptyStateForFilter(String filter) {
    String message, subMessage;
    IconData icon;

    switch (filter) {
      case 'active':
        icon = Icons.check_circle_outline;
        message = 'لا توجد منتجات مفعلة';
        subMessage = 'قم بتفعيل بعض المنتجات لعرضها للعملاء';
        break;
      case 'inactive':
        icon = Icons.block_outlined;
        message = 'لا توجد منتجات غير مفعلة';
        subMessage = 'جميع المنتجات مفعلة وتظهر للعملاء';
        break;
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
              if (filter == 'active' || filter == 'all') ...[
                const SizedBox(height: 20),
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

  Widget _buildEnhancedProductCard(ProductModel product,
      {bool isSelected = false}) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Card(
        elevation: isSelected ? 0 : 2,
        margin: EdgeInsets.zero,
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleProductSelection(product.id);
            } else {
              Navigator.pushNamed(
                context,
                AppRoutes.addEditProduct,
                arguments: product,
              ).then((_) => _loadMerchantProducts());
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
              });
            }
            _toggleProductSelection(product.id);
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مربع التحديد أو صورة المنتج
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
                    // شارة الحالة أو Checkbox عند التحديد
                    if (_isSelectionMode)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 200),
                              child: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                      size: 36,
                                      key: ValueKey('checked'),
                                    )
                                  : Icon(
                                      Icons.radio_button_unchecked,
                                      color: Colors.white,
                                      size: 36,
                                      key: ValueKey('unchecked'),
                                    ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                product.isAvailable ? Colors.green : Colors.red,
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
                          if (!_isSelectionMode)
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
    try {
      // احذف من قاعدة البيانات مع تأكيد النجاح أو سبب الفشل
      await ProductService.deleteProduct(product.id);

      // حاول حذف الصور من التخزين (غير حاجز)
      await ProductService.deleteProductImages(
        storeId: product.storeId,
        productId: product.id,
      );

      // أنعش قائمة المنتجات لهذا المتجر
      await _loadProductCounts(product.storeId);
      await _loadTabProducts(_tabController!.index, refresh: true);

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
