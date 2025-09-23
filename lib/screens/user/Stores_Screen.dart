import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/custom_search_bar.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  _StoresScreenState createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'الكل';
  final List<String> _categories = [
    'الكل',
    'سوبرماركت',
    'مطاعم',
    'مقاهي',
    'إلكترونيات',
    'ملابس',
    'أدوات منزلية',
    'صيدلية',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreProvider>(context, listen: false).fetchStores();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 🔍 شريط البحث والتصفية
  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        // شريط البحث
        CustomSearchBar(
          controller: _searchController,
          hintText: 'ابحث عن متجر...',
          onChanged: (value) {
            Provider.of<StoreProvider>(
              context,
              listen: false,
            ).filterStores(value, _selectedCategory);
          },
        ),

        // شريط التصنيفات
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : 'الكل';
                    });
                    Provider.of<StoreProvider>(
                      context,
                      listen: false,
                    ).filterStores(_searchController.text, _selectedCategory);
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: _selectedCategory == category
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 🏪 بطاقة المتجر
  Widget _buildStoreCard(StoreModel store) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.storeDetail, arguments: store);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // صورة المتجر
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: store.imageUrl,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: Icon(Icons.store, size: 50, color: Colors.grey),
                ),
              ),
            ),

            // معلومات المتجر
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المتجر
                  Text(
                    store.name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 4),

                  // التصنيف
                  Text(
                    store.category,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),

                  SizedBox(height: 8),

                  // التقييم ووقت التوصيل
                  Row(
                    children: [
                      // التقييم
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            store.rating.toString(),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ' (${store.reviewCount})',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      Spacer(),

                      // وقت التوصيل
                      Row(
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${store.deliveryTime} دقيقة',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // الحد الأدنى للطلب وتكلفة التوصيل
                  Row(
                    children: [
                      // الحد الأدنى للطلب
                      if (store.minOrder > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 14,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'حد أدنى: ${store.minOrder} ر.س',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),

                      Spacer(),

                      // تكلفة التوصيل
                      Row(
                        children: [
                          Icon(
                            Icons.motorcycle,
                            size: 14,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            store.deliveryFee == 0
                                ? 'توصيل مجاني'
                                : 'توصيل: ${store.deliveryFee} ر.س',
                            style: TextStyle(
                              fontSize: 12,
                              color: store.deliveryFee == 0
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // حالة المتجر
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: store.isOpen ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: store.isOpen ? Colors.green : Colors.red,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          store.isOpen ? 'مفتوح الآن' : 'مغلق',
                          style: TextStyle(
                            color: store.isOpen ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📋 قائمة المتاجر
  Widget _buildStoresList() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        if (storeProvider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل المتاجر...'),
              ],
            ),
          );
        }

        if (storeProvider.filteredStores.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_mall_directory, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'لا توجد متاجر',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'حاول البحث بتصنيف مختلف',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(bottom: 16),
          itemCount: storeProvider.filteredStores.length,
          itemBuilder: (context, index) {
            final store = storeProvider.filteredStores[index];
            return _buildStoreCard(store);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('المتاجر'), centerTitle: true),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildStoresList()),
        ],
      ),
    );
  }
}
