import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/core/logger.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  Map<String, String> _storeNames = {};
  Map<String, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      _loadMetadata();
    });
  }

  Future<void> _loadMetadata() async {
    try {
      final supabase = Supabase.instance.client;
      final storesRes = await supabase.from('stores').select('id, name');
      final categoriesRes =
          await supabase.from('categories').select('id, name');

      final sMap = <String, String>{};
      for (final s in storesRes) {
        if (s['id'] != null && s['name'] != null) {
          sMap[s['id'].toString()] = s['name'].toString();
        }
      }

      final cMap = <String, String>{};
      for (final c in categoriesRes) {
        if (c['id'] != null && c['name'] != null) {
          cMap[c['id'].toString()] = c['name'].toString();
        }
      }

      if (mounted) {
        setState(() {
          _storeNames = sMap;
          _categoryNames = cMap;
        });
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب بيانات المتاجر والفئات', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addProduct(),
            tooltip: 'إضافة منتج',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: SafeArea(
          child: Column(
            children: [
              _buildStatsRow(productProvider),
              _buildSearchAndFilterBar(),
              Expanded(child: _buildProductsList(productProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ProductProvider provider) {
    final stats = [
      _PStatInfo("الكل", provider.products.length, Icons.inventory_2_rounded, [
        const Color(0xFF667eea),
        const Color(0xFF764ba2),
      ]),
      _PStatInfo(
        "متوفر",
        provider.products.where((p) => p.stock > 0).length,
        Icons.check_circle_rounded,
        [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      ),
      _PStatInfo(
        "غير متوفر",
        provider.products.where((p) => p.stock == 0).length,
        Icons.remove_shopping_cart_rounded,
        [const Color(0xFFf5576c), const Color(0xFFf093fb)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: stats.map((stat) {
          return Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + stats.indexOf(stat) * 100),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: stat.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: stat.colors[0].withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stat.icon,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stat.value.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return AdminSearchBar(
      controller: _searchController,
      hintText: 'ابحث باسم المنتج',
      onChanged: (_) => setState(() {}),
      filterChips: [
        _buildFilterChip('الكل', 'all'),
        _buildFilterChip('متوفر', 'inStock'),
        _buildFilterChip('غير متوفر', 'outOfStock'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = filter),
        selectedColor: const Color(0xFF667eea),
        backgroundColor: Colors.grey.shade100,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        elevation: isSelected ? 2 : 0,
        shadowColor: const Color(0xFF667eea).withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildProductsList(ProductProvider provider) {
    if (provider.isLoading) {
      return AppShimmer.list(context);
    }

    if (provider.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد منتجات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'اضغط + لإضافة منتج جديد',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final filteredProducts = _filterProducts(provider.products);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        if (_searchController.text.isNotEmpty &&
            !product.name.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            )) {
          return const SizedBox.shrink();
        }
        return _buildProductCard(product, index);
      },
    );
  }

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    switch (_selectedFilter) {
      case 'inStock':
        return products.where((p) => p.stock > 0).toList();
      case 'outOfStock':
        return products.where((p) => p.stock == 0).toList();
      default:
        return products;
    }
  }

  Widget _buildProductCard(ProductModel product, int index) {
    final inStock = product.stock > 0;
    final gradient = inStock
        ? [const Color(0xFF43e97b), const Color(0xFF38f9d7)]
        : [const Color(0xFFf5576c), const Color(0xFFf093fb)];

    final storeName = _storeNames[product.storeId] ?? 'متجر غير محدد';
    final categoryName = product.categoryId != null
        ? (_categoryNames[product.categoryId] ?? '')
        : '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _editProduct(product),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _editProduct(product),
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            image:
                                product.imageUrl != null &&
                                    product.imageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(product.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : const DecorationImage(
                                    image: AssetImage(
                                      'assets/images/default_product.png',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomRight: Radius.circular(14),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              size: 13,
                              color: Color(0xFF667eea),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                storeName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF667eea),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (categoryName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.category_outlined,
                                size: 13,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF667eea,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                product.priceFormatted,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF667eea),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: gradient[0].withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                inStock
                                    ? "متوفر (${product.stock})"
                                    : "غير متوفر",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: gradient[0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildActionBtn(
                    Icons.edit_rounded,
                    const Color(0xFF4facfe),
                    () => _editProduct(product),
                  ),
                  const SizedBox(width: 6),
                  _buildActionBtn(
                    Icons.delete_rounded,
                    Colors.red.shade400,
                    () => _deleteProduct(product),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  void _addProduct() {
    Uint8List? newImageBytes;
    String? newFileName;
    bool isSaving = false;

    // البحث عن متجر "سوق التل" كخيار افتراضي أول
    String? selectedStoreId;
    for (final entry in _storeNames.entries) {
      if (entry.value.contains('سوق التل') || entry.value.contains('التل')) {
        selectedStoreId = entry.key;
        break;
      }
    }
    if (selectedStoreId == null && _storeNames.isNotEmpty) {
      selectedStoreId = _storeNames.keys.first;
    }

    String? selectedCategoryId;
    if (_categoryNames.isNotEmpty) {
      selectedCategoryId = _categoryNames.keys.first;
    }

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'إضافة منتج جديد',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // اختيار صورة المنتج
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (file != null) {
                        final bytes = await file.readAsBytes();
                        setDialogState(() {
                          newImageBytes = bytes;
                          newFileName = file.name;
                        });
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            image: newImageBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(newImageBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : const DecorationImage(
                                    image: AssetImage(
                                      'assets/images/default_product.png',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF43e97b),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_a_photo_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اضغط لاختيار صورة المنتج',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // اختيار المتجر (مع افتراضي سوق التل)
                  if (_storeNames.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedStoreId,
                      decoration: InputDecoration(
                        labelText: 'المتجر التابع له المنتج *',
                        prefixIcon: const Icon(Icons.storefront_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _storeNames.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedStoreId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // اختيار الفئة
                  if (_categoryNames.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'فئة المنتج',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _categoryNames.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المنتج *',
                      prefixIcon: const Icon(Icons.shopping_bag_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'السعر (ج.م) *',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: stockCtrl,
                    decoration: InputDecoration(
                      labelText: 'الكمية / المخزون *',
                      prefixIcon: const Icon(Icons.inventory_2_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'وصف المنتج (اختياري)',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade600)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);
                          final provider = Provider.of<ProductProvider>(
                            context,
                            listen: false,
                          );

                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                          final storeId = selectedStoreId;

                          if (name.isEmpty || price == null || storeId == null || storeId.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('الرجاء إدخال اسم المنتج، السعر، وتحديد المتجر'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            final productId = const Uuid().v4();
                            String? imageUrl;

                            if (newImageBytes != null) {
                              final supabase = Supabase.instance.client;
                              final ext =
                                  (newFileName ?? 'jpg').split('.').last;
                              final filePath =
                                  'products/${productId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

                              await supabase.storage
                                  .from('products')
                                  .uploadBinary(
                                    filePath,
                                    newImageBytes!,
                                    fileOptions: const FileOptions(
                                      upsert: true,
                                    ),
                                  );

                              imageUrl = supabase.storage
                                  .from('products')
                                  .getPublicUrl(filePath);
                            }

                            final newProduct = ProductModel(
                              id: productId,
                              storeId: storeId,
                              categoryId: selectedCategoryId,
                              name: name,
                              description: descCtrl.text.trim().isNotEmpty
                                  ? descCtrl.text.trim()
                                  : null,
                              price: price,
                              stockQuantity: stock,
                              inStock: stock > 0,
                              isActive: true,
                              imageUrl: imageUrl,
                              createdAt: DateTime.now(),
                            );

                            final success = await provider.addProduct(newProduct);

                            if (navigator.mounted) {
                              navigator.pop();
                            }

                            if (mounted) {
                              final storeName = _storeNames[storeId] ?? 'المتجر';
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'تم إضافة المنتج بنجاح وتعيينه لـ ($storeName)'
                                        : 'تعذر إضافة المنتج',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            AppLogger.error('❌ خطأ في إضافة المنتج الجديد', e);
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('حدث خطأ أثناء إضافة المنتج'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('حفظ وإضافة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editProduct(ProductModel product) {
    Uint8List? newImageBytes;
    String? newFileName;
    bool isSaving = false;

    String? selectedStoreId = product.storeId;
    String? selectedCategoryId = product.categoryId;

    final nameCtrl = TextEditingController(text: product.name);
    final priceCtrl = TextEditingController(text: product.price.toString());
    final stockCtrl = TextEditingController(text: product.stockQuantity.toString());
    final descCtrl = TextEditingController(text: product.description ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'تعديل المنتج',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // صورة المنتج مع زر اختيار صورة جديدة
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (file != null) {
                        final bytes = await file.readAsBytes();
                        setDialogState(() {
                          newImageBytes = bytes;
                          newFileName = file.name;
                        });
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            image: newImageBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(newImageBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (product.imageUrl != null &&
                                        product.imageUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(product.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : const DecorationImage(
                                        image: AssetImage(
                                          'assets/images/default_product.png',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اضغط على الصورة لتغييرها',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // اختيار المتجر
                  if (_storeNames.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _storeNames.containsKey(selectedStoreId)
                          ? selectedStoreId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'المتجر التابع له',
                        prefixIcon: const Icon(Icons.storefront_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _storeNames.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedStoreId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // اختيار الفئة
                  if (_categoryNames.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _categoryNames.containsKey(selectedCategoryId)
                          ? selectedCategoryId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'الفئة',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _categoryNames.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المنتج',
                      prefixIcon: const Icon(Icons.shopping_bag_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'السعر (ج.م)',
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockCtrl,
                    decoration: InputDecoration(
                      labelText: 'الكمية / المخزون',
                      prefixIcon: const Icon(Icons.inventory_2_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'وصف المنتج',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade600)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);
                          final provider = Provider.of<ProductProvider>(
                            context,
                            listen: false,
                          );

                          setDialogState(() => isSaving = true);
                          try {
                            String finalImageUrl = product.imageUrl ?? '';

                            if (newImageBytes != null) {
                              final supabase = Supabase.instance.client;
                              final ext =
                                  (newFileName ?? 'jpg').split('.').last;
                              final filePath =
                                  'products/${product.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

                              await supabase.storage
                                  .from('products')
                                  .uploadBinary(
                                    filePath,
                                    newImageBytes!,
                                    fileOptions: const FileOptions(
                                      upsert: true,
                                    ),
                                  );

                              finalImageUrl = supabase.storage
                                  .from('products')
                                  .getPublicUrl(filePath);
                            }

                            final updatedName = nameCtrl.text.trim();
                            final updatedPrice =
                                double.tryParse(priceCtrl.text.trim()) ??
                                    product.price;
                            final updatedStock =
                                int.tryParse(stockCtrl.text.trim()) ??
                                    product.stockQuantity;

                            final updatedProduct = product.copyWith(
                              storeId: selectedStoreId ?? product.storeId,
                              categoryId: selectedCategoryId ?? product.categoryId,
                              name: updatedName.isNotEmpty
                                  ? updatedName
                                  : product.name,
                              description: descCtrl.text.trim().isNotEmpty
                                  ? descCtrl.text.trim()
                                  : product.description,
                              price: updatedPrice,
                              stockQuantity: updatedStock,
                              inStock: updatedStock > 0,
                              imageUrl: finalImageUrl,
                              updatedAt: DateTime.now(),
                            );

                            final success =
                                await provider.updateProduct(updatedProduct);

                            if (navigator.mounted) {
                              navigator.pop();
                            }

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'تم تحديث المنتج بنجاح'
                                        : 'تعذر تحديث المنتج',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            AppLogger.error('❌ خطأ في تحديث المنتج والصورة', e);
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('حدث خطأ أثناء حفظ المنتج'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('حفظ', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteProduct(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red.shade400,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'حذف المنتج',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text('هل أنت متأكد من حذف المنتج "${product.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade300],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final provider =
                    Provider.of<ProductProvider>(context, listen: false);
                final success = await provider.deleteProduct(product.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'تم حذف المنتج بنجاح'
                            : 'تعذر حذف المنتج',
                      ),
                      backgroundColor:
                          success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PStatInfo {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> colors;
  const _PStatInfo(this.title, this.value, this.icon, this.colors);
}
