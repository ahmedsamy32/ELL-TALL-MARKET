import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ell_tall_market/providers/product_provider.dart';
import 'package:ell_tall_market/providers/cart_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/store_provider.dart';
import 'package:ell_tall_market/models/store_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/services/coupon_service.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/widgets/product_card.dart';
import 'package:flutter/services.dart';
import 'package:ell_tall_market/core/logger.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  String _selectedCategory = 'الكل';
  String? _coverUrl; // رابط صورة الغلاف من Storage
  bool _coverLookupDone = false;
  StoreModel? _store;
  String? _routeError;
  bool _didLoadStoreArgs = false;
  Future<List<Map<String, dynamic>>>? _sectionsFuture;
  Future<StoreDetailBundle>? _detailBundleFuture;
  Future<List<CouponModel>>? _couponsFuture;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadStoreArgs) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! StoreModel) {
      setState(() {
        _routeError =
            'لم يتم العثور على بيانات المتجر\nالنوع المستلم: ${args?.runtimeType}';
        _didLoadStoreArgs = true;
      });
      return;
    }

    final store = args;
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    final sectionsFuture = storeProvider.fetchStoreSections(store.id);
    final detailFuture = storeProvider.fetchStoreDetailBundle(
      store.id,
      merchantId: store.merchantId,
    );

    setState(() {
      _store = store;
      _sectionsFuture = sectionsFuture;
      _detailBundleFuture = detailFuture;
      _couponsFuture = CouponService.fetchCouponsByStore(store.id);
      _routeError = null;
      _didLoadStoreArgs = true;
      if (store.coverUrl != null && store.coverUrl!.isNotEmpty) {
        _coverUrl = store.coverUrl;
        _coverLookupDone = true;
      }
    });

    productProvider.fetchProductsByStore(store.id).catchError((error) {
      AppLogger.warning('⚠️ فشل تحميل منتجات المتجر ${store.id}: $error');
    });

    _prefetchCover(storeProvider, store);
  }

  Future<void> _prefetchCover(
    StoreProvider storeProvider,
    StoreModel store,
  ) async {
    try {
      final url = await storeProvider.fetchStoreCoverUrl(store);
      if (!mounted) return;
      setState(() {
        if (url != null && url.isNotEmpty) {
          _coverUrl = url;
        }
        _coverLookupDone = true;
      });
    } catch (e) {
      AppLogger.warning('⚠️ لم يتم تحميل صورة الغلاف للمتجر ${store.id}: $e');
      if (!mounted) return;
      setState(() {
        _coverLookupDone = true;
      });
    }
  }

  void _checkLoginAndNavigate(Function action) {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      action();
    } else {
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  void _addToCart(ProductModel product) async {
    _checkLoginAndNavigate(() async {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);

      // عرض مؤشر تحميل
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('جاري الإضافة...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // التحقق من تعارض نظام التوصيل
      final conflict = await cartProvider.checkDeliveryModeConflict(product.id);

      if (!mounted) return;

      if (conflict != null) {
        // إخفاء مؤشر التحميل
        messenger.clearSnackBars();

        // عرض رسالة التأكيد
        final shouldClear = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, color: Colors.orange),
                SizedBox(width: 12),
                Text('بدء سلة جديدة؟'),
              ],
            ),
            content: Text(conflict.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  // إغلاق Dialog وعرض مؤشر تحميل
                  Navigator.pop(dialogContext, true);
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('نعم، ابدأ طلب جديد'),
              ),
            ],
          ),
        );

        if (shouldClear != true) return;

        // عرض مؤشر تحميل أثناء مسح السلة
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('جاري مسح السلة...'),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // مسح السلة
        await cartProvider.clearCart();

        // تحديث الرسالة
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('جاري إضافة المنتج...'),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // إضافة المنتج للسلة
      final success = await cartProvider.addToCart(productId: product.id);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('تمت إضافة ${product.name} إلى السلة'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('فشل إضافة المنتج إلى السلة'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _navigateToProductDetail(ProductModel product) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: product);
  }

  // مشاركة المتجر
  void _shareStore(StoreModel store) {
    final text =
        '''
🏪 ${store.name}
${store.category ?? 'متجر'}

⭐ التقييم: ${store.rating} (${store.reviewCount} تقييم)
🚚 التوصيل: ${store.deliveryFee == 0 ? 'مجاني' : '${store.deliveryFee} جنيه'}
⏰ الوقت: ${store.deliveryTime} دقيقة
💰 الحد الأدنى: ${store.minOrder} جنيه

${store.isOpen ? '✅ مفتوح الآن' : '❌ مغلق حالياً'}

📍 ${store.address}
${store.phone != null ? '📞 ${store.phone}' : ''}
    ''';

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ معلومات ${store.name}'),
        action: SnackBarAction(label: 'موافق', onPressed: () {}),
      ),
    );
  }

  Widget _buildStoreStatusBadge(StoreModel store) {
    final isOpen = store.isOpen;
    final color = isOpen ? Colors.green : Colors.red;
    final icon = isOpen ? Icons.check_circle : Icons.cancel_outlined;
    final label = isOpen ? 'مفتوح الآن' : 'مغلق حالياً';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryModeBadge(StoreModel store, ColorScheme colorScheme) {
    final isStoreDelivery = store.deliveryMode == 'store';
    final accent = isStoreDelivery
        ? colorScheme.primary
        : colorScheme.secondary;
    final icon = isStoreDelivery
        ? Icons.storefront
        : Icons.local_shipping_outlined;
    final label = isStoreDelivery
        ? 'التوصيل بواسطة المتجر'
        : 'سوق التل اسرع دليفري';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // تنسيق وقت التوصيل
  String _formatDeliveryTime(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return hours == 1 ? 'ساعة واحدة' : '$hours ساعات';
      }
      return '$hours س $remainingMinutes د';
    }
    return '$minutes دقيقة';
  }

  // عرض تفاصيل المتجر في Bottom Sheet
  void _showStoreDetailsBottomSheet(StoreModel store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.9, // يفتح كل الشاشة
            minChildSize: 0.7, // نفس الـ initial - ممنوع السحب لأسفل
            maxChildSize: 0.95, // يمكن سحبه لأعلى
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20,
                ), // تقليل المسافة العلوية فقط
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                          bottom: 12,
                        ), // تقليل المسافة
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // عنوان - اسم المتجر مع اللوجو
                    Row(
                      children: [
                        if (store.imageUrl != null &&
                            store.imageUrl!.isNotEmpty)
                          Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: store.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.restaurant),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              if (store.description != null &&
                                  store.description!.isNotEmpty)
                                Text(
                                  store.description!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 6),
                              _buildStoreStatusBadge(store),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // التقييم
                    _buildDetailRow(
                      icon: Icons.star,
                      iconColor: const Color(0xFFFFB300),
                      title: 'التقييم',
                      value: '${store.rating} (+${store.reviewCount})',
                    ),

                    const Divider(height: 24),

                    // المنطقة
                    _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      iconColor: Colors.red,
                      title: 'عنوان المتجر',
                      value: store.address,
                    ),

                    const Divider(height: 24),

                    // وقت التوصيل
                    _buildDetailRow(
                      icon: Icons.access_time_rounded,
                      iconColor: Colors.green,
                      title: 'وقت التوصيل',
                      value: _formatDeliveryTime(store.deliveryTime),
                    ),

                    const Divider(height: 24),

                    // الحد الأدنى للطلب
                    _buildDetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: Colors.orange,
                      title: 'الحد الادنى للطلب',
                      value: '${store.minOrder} ج.م',
                    ),

                    const Divider(height: 24),

                    // رسوم التوصيل
                    _buildDetailRow(
                      icon: Icons.delivery_dining_outlined,
                      iconColor: Colors.blue,
                      title: 'رسوم التوصيل',
                      value: store.deliveryFee == 0
                          ? 'مجاني'
                          : '${store.deliveryFee} ج.م',
                    ),

                    const Divider(height: 24),

                    _buildDetailRow(
                      icon: store.deliveryMode == 'store'
                          ? Icons.storefront
                          : Icons.local_shipping_outlined,
                      iconColor: store.deliveryMode == 'store'
                          ? Colors.deepOrange
                          : Colors.teal,
                      title: 'طريقة التوصيل',
                      value: store.deliveryMode == 'store'
                          ? 'المتجر مسؤول عن التوصيل'
                          : 'التطبيق يتولى التوصيل بالكامل',
                    ),

                    // رقم هاتف المتجر
                    if (store.phone != null && store.phone!.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildDetailRow(
                        icon: Icons.phone_outlined,
                        iconColor: Colors.green,
                        title: 'رقم الهاتف',
                        value: store.phone!,
                      ),
                    ],

                    const Divider(height: 24),

                    FutureBuilder<StoreDetailBundle>(
                      future: _detailBundleFuture!,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final data = snapshot.data;
                        if (data == null) {
                          return const SizedBox.shrink();
                        }

                        final sections = <Widget>[];

                        if (data.orderWindows.isNotEmpty) {
                          sections.addAll([
                            _buildOrderWindowsSection(data.orderWindows),
                            const Divider(height: 24),
                          ]);
                        }

                        if (data.branches.isNotEmpty) {
                          sections.addAll([
                            _buildBranchesSection(data.branches),
                            const Divider(height: 24),
                          ]);
                        }

                        sections.addAll([
                          _buildPaymentMethodsRow(data.paymentMethods),
                          const Divider(height: 24),
                          _buildDetailRow(
                            icon: Icons.business_outlined,
                            iconColor: Colors.purple,
                            title: 'اسم التاجر',
                            value: data.merchantName,
                          ),
                          const SizedBox(height: 20),
                        ]);

                        return Column(children: sections);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget مساعد لصف التفاصيل
  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsRow(List<String> methods) {
    final paymentMethods = methods.isEmpty ? ['نقدي'] : methods;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.payment, size: 24, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'طرق الدفع',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: paymentMethods.map((method) {
                  IconData icon = Icons.money;
                  final normalized = method.toLowerCase();
                  if (normalized.contains('card') || method.contains('بطاقة')) {
                    icon = Icons.credit_card;
                  } else if (normalized.contains('wallet') ||
                      method.contains('محفظة')) {
                    icon = Icons.account_balance_wallet;
                  }
                  return _buildPaymentIcon(icon, method);
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget أيقونة طريقة الدفع
  Widget _buildPaymentIcon(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  // Widget لعرض مواعيد العمل من جدول store_order_windows
  Widget _buildOrderWindowsSection(List<Map<String, dynamic>> orderWindows) {
    // تحويل رقم اليوم إلى اسم اليوم بالعربية
    String getDayName(int dayOfWeek) {
      const days = [
        'الأحد', // 0
        'الإثنين', // 1
        'الثلاثاء', // 2
        'الأربعاء', // 3
        'الخميس', // 4
        'الجمعة', // 5
        'السبت', // 6
      ];
      return days[dayOfWeek];
    }

    // تحويل الوقت من صيغة 24 ساعة إلى صيغة 12 ساعة
    String formatTime(String time) {
      try {
        final parts = time.split(':');
        if (parts.length < 2) return time;

        int hour = int.parse(parts[0]);
        final minute = parts[1];

        if (hour == 0) {
          return '12:$minute ص';
        } else if (hour < 12) {
          return '$hour:$minute ص';
        } else if (hour == 12) {
          return '12:$minute م';
        } else {
          return '${hour - 12}:$minute م';
        }
      } catch (e) {
        return time;
      }
    }

    // تجميع الأيام حسب رقم اليوم
    final groupedWindows = <int, List<Map<String, dynamic>>>{};
    for (var window in orderWindows) {
      final dayOfWeek = window['day_of_week'] as int;
      if (!groupedWindows.containsKey(dayOfWeek)) {
        groupedWindows[dayOfWeek] = [];
      }
      groupedWindows[dayOfWeek]!.add(window);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.schedule, size: 24, color: Colors.indigo),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مواعيد العمل',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ...List.generate(7, (index) {
                final windows = groupedWindows[index];
                if (windows == null || windows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          getDayName(index),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'مغلق',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // عرض جميع الفترات لنفس اليوم
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getDayName(index),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: windows.map((window) {
                            final openTime = formatTime(
                              window['open_time'] as String,
                            );
                            final closeTime = formatTime(
                              window['close_time'] as String,
                            );
                            return Text(
                              '$openTime - $closeTime',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Widget لعرض الفروع
  Widget _buildBranchesSection(List<Map<String, dynamic>> branches) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            size: 24,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الفروع (${branches.length})',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ...branches.map((branch) {
                final name = branch['name'] as String?;
                final address = branch['address'] as String? ?? 'لا يوجد عنوان';
                final phone = branch['phone'] as String?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name != null && name.isNotEmpty)
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// رأس المتجر - صورة الغلاف وبطاقة المعلومات في قسم واحد
  Widget _buildStoreHeroSection(StoreModel store, ColorScheme colorScheme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double coverHeight = screenWidth * 0.65;
    const double cardOverlap = 130;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: Hero(
                tag: 'store_${store.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _buildCoverImage(store, colorScheme),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: -cardOverlap,
              child: _buildStoreInfoCard(store, colorScheme),
            ),
          ],
        ),
        const SizedBox(height: cardOverlap + 32),
      ],
    );
  }

  Widget _buildCoverImage(StoreModel store, ColorScheme colorScheme) {
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return _buildCoverNetworkImage(
        _coverUrl!,
        colorScheme,
        key: ValueKey('store-cover-${store.id}'),
      );
    }

    if (!_coverLookupDone) {
      return _buildCoverPlaceholder(
        colorScheme,
        key: const ValueKey('store-cover-loading'),
      );
    }

    if (store.imageUrl != null && store.imageUrl!.isNotEmpty) {
      return _buildCoverNetworkImage(
        store.imageUrl!,
        colorScheme,
        key: ValueKey('store-logo-cover-${store.id}'),
      );
    }

    return _buildCoverPlaceholder(
      colorScheme,
      key: const ValueKey('store-cover-empty'),
    );
  }

  Widget _buildCoverNetworkImage(
    String url,
    ColorScheme colorScheme, {
    Key? key,
  }) {
    return CachedNetworkImage(
      key: key,
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      httpHeaders: const {'Cache-Control': 'no-cache'},
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (context, _) => _buildCoverPlaceholder(colorScheme),
      errorWidget: (context, failedUrl, error) {
        AppLogger.error('❌ فشل تحميل صورة الغلاف من: $failedUrl', error);
        return _buildCoverPlaceholder(colorScheme);
      },
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surfaceContainerHighest, colorScheme.surface],
        ),
      ),
      child: Icon(
        Icons.storefront,
        size: 56,
        color: colorScheme.outline.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildStoreInfoCard(StoreModel store, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _showStoreDetailsBottomSheet(store),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (store.imageUrl != null && store.imageUrl!.isNotEmpty)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200] ?? Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: store.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.restaurant),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.storefront, color: Colors.grey[500]),
                      ),
                    const SizedBox(height: 8),
                    _buildStoreStatusBadge(store),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (store.description != null &&
                          store.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          store.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 18, color: Color(0xFFFFB300)),
                    const SizedBox(width: 4),
                    Text(
                      '${store.rating}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      ' (+${store.reviewCount})',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),

                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDeliveryTime(store.deliveryTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      store.deliveryFee == 0
                          ? 'توصيل مجاني'
                          : '${store.deliveryFee} ج.م',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildDeliveryModeBadge(store, colorScheme),
          ],
        ),
      ),
    );
  }

  /// بانر الخصم - ديناميكي مع القسائم المتاحة
  Widget _buildDiscountBanner() {
    if (_couponsFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<CouponModel>>(
      future: _couponsFuture,
      builder: (context, snapshot) {
        // أثناء التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        // في حالة الخطأ أو عدم وجود بيانات
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // إخفاء البانر إذا لم يكن هناك قسائم
        }

        // تصفية القسائم النشطة فقط
        final activeCoupons = snapshot.data!
            .where((coupon) => coupon.isActive && coupon.canBeUsed)
            .toList();

        if (activeCoupons.isEmpty) {
          return const SizedBox.shrink(); // إخفاء إذا لم يكن هناك قسائم نشطة
        }

        // عرض أول قسيمة نشطة
        final coupon = activeCoupons.first;
        final hasMoreCoupons = activeCoupons.length > 1;

        return GestureDetector(
          onTap: () => hasMoreCoupons
              ? _showAllCoupons(activeCoupons)
              : _showCouponDetails(coupon),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9800),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasMoreCoupons
                            ? 'عروض وخصومات متاحة (${activeCoupons.length})'
                            : coupon.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasMoreCoupons
                            ? 'اضغط لعرض جميع القسائم'
                            : 'اضغط لنسخ الكود: ${coupon.code}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasMoreCoupons ? 'اختر' : coupon.discountValueFormatted,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // عرض تفاصيل القسيمة ونسخ الكود
  void _showCouponDetails(CouponModel coupon) {
    // نسخ الكود للحافظة
    Clipboard.setData(ClipboardData(text: coupon.code));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: Color(0xFFFF9800),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'تم نسخ الكود بنجاح',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF9800),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    coupon.code,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCouponDetailRow(
              icon: Icons.discount,
              label: 'قيمة الخصم',
              value: coupon.discountValueFormatted,
            ),
            if (coupon.minimumOrderAmount > 0)
              _buildCouponDetailRow(
                icon: Icons.shopping_cart,
                label: 'الحد الأدنى للطلب',
                value: '${coupon.minimumOrderAmount.toStringAsFixed(0)} ج.م',
              ),
            if (coupon.validUntil != null)
              _buildCouponDetailRow(
                icon: Icons.schedule,
                label: 'صالح حتى',
                value: coupon.validUntilFormatted,
              ),
            if (coupon.description != null && coupon.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  coupon.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('تم'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عرض قائمة بجميع القسائم المتاحة
  void _showAllCoupons(List<CouponModel> coupons) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_offer,
                          color: Color(0xFFFF9800),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'القسائم المتاحة',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              '${coupons.length} قسيمة نشطة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                // Coupons List
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: coupons.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final coupon = coupons[index];
                      return _buildCouponListItem(coupon);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // بطاقة قسيمة في القائمة
  Widget _buildCouponListItem(CouponModel coupon) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _showCouponDetails(coupon);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFFFF3E0).withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    coupon.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    coupon.discountValueFormatted,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                coupon.code,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Colors.grey[800],
                ),
              ),
            ),
            if (coupon.description != null && coupon.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  coupon.description!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (coupon.minimumOrderAmount > 0) ...[
                  Icon(Icons.shopping_cart, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'حد أدنى: ${coupon.minimumOrderAmount.toStringAsFixed(0)} ج.م',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'حتى ${coupon.validUntilFormatted}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty products state
  Widget _buildEmptyProducts(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد منتجات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory == 'الكل'
                  ? 'هذا المتجر لا يحتوي على منتجات حالياً'
                  : 'لا توجد منتجات في هذا التصنيف',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (_selectedCategory != 'الكل') ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() => _selectedCategory = 'الكل');
                },
                icon: const Icon(Icons.refresh),
                label: const Text('عرض جميع المنتجات'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_routeError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _routeError!,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
    }

    final store = _store;
    if (store == null ||
        _sectionsFuture == null ||
        _detailBundleFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final productProvider = Provider.of<ProductProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final storeProducts = productProvider.products
        .where((product) => product.storeId == store.id)
        .toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final productProvider = Provider.of<ProductProvider>(
              context,
              listen: false,
            );
            await productProvider.fetchProducts();
          },
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _sectionsFuture!,
            builder: (context, sectionsSnapshot) {
              // بناء قائمة التصنيفات من store_sections
              final sections = sectionsSnapshot.data ?? [];

              // فلترة التصنيفات: عرض فقط التصنيفات التي تحتوي على منتجات
              final categoriesWithProducts = <String>[];
              final sectionIdToName = <String, String>{};

              for (var section in sections) {
                final sectionId = section['id'] as String;
                final sectionName = section['name'] as String;

                // التحقق من وجود منتجات في هذا التصنيف باستخدام sectionId
                final hasProducts = storeProducts.any((p) {
                  return p.sectionId == sectionId;
                });

                if (hasProducts) {
                  categoriesWithProducts.add(sectionName);
                  sectionIdToName[sectionId] = sectionName;
                }
              }

              // إضافة "الكل" في البداية فقط إذا كان هناك منتجات
              final categories = storeProducts.isNotEmpty
                  ? ['الكل', ...categoriesWithProducts]
                  : categoriesWithProducts;

              // تصفية المنتجات حسب التصنيف المختار
              List<ProductModel> filteredProducts;
              if (_selectedCategory == 'الكل') {
                filteredProducts = storeProducts;
              } else {
                // البحث عن section_id المطابق للتصنيف المختار
                final selectedSection = sections.firstWhere(
                  (s) => s['name'] == _selectedCategory,
                  orElse: () => <String, dynamic>{},
                );
                final sectionId = selectedSection['id'] as String?;

                filteredProducts = storeProducts
                    .where((p) => p.sectionId == sectionId)
                    .toList();
              }

              return CustomScrollView(
                slivers: [
                  // AppBar بسيط مع العنوان فقط
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1A1A),
                    surfaceTintColor: Colors.transparent,
                    title: Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1A1A1A),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                      // زر البحث
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Color(0xFF1A1A1A),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.search);
                          },
                        ),
                      ),
                      // زر المشاركة
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.ios_share,
                            color: Color(0xFF1A1A1A),
                          ),
                          onPressed: () => _shareStore(store),
                        ),
                      ),
                      // زر المفضلة
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.favorite_border,
                            color: Color(0xFF1A1A1A),
                          ),
                          onPressed: () {
                            // Note: إضافة للمفضلة
                          },
                        ),
                      ),
                    ],
                  ),

                  // رأس المتجر كجزء من المحتوى
                  SliverToBoxAdapter(
                    child: _buildStoreHeroSection(store, colorScheme),
                  ),

                  // بانر الخصم
                  SliverToBoxAdapter(child: _buildDiscountBanner()),

                  // Category filter
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CategoryStickyHeader(
                      categories: categories,
                      selectedCategory: _selectedCategory,
                      onCategorySelected: (category) {
                        setState(() => _selectedCategory = category);
                      },
                      colorScheme: colorScheme,
                    ),
                  ),

                  // Products grid
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: filteredProducts.isEmpty
                        ? SliverToBoxAdapter(
                            child: _buildEmptyProducts(colorScheme),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.7,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final product = filteredProducts[index];
                              return ProductCard(
                                product: product,
                                compact: true, // ✅ تفعيل الوضع المضغوط
                                onTap: () => _navigateToProductDetail(product),
                                onBuyPressed: () => _addToCart(product),
                              );
                            }, childCount: filteredProducts.length),
                          ),
                  ),

                  // Bottom spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ),
      ),

      // زر السلة العائم
      floatingActionButton: store.isOpen
          ? Consumer<CartProvider>(
              builder: (context, cartProvider, _) {
                final cartCount = cartProvider.cartItems.length;
                return FloatingActionButton.extended(
                  onPressed: () {
                    _checkLoginAndNavigate(() {
                      Navigator.pushNamed(context, AppRoutes.cart);
                    });
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_outlined),
                      if (cartCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: Text(
                    cartCount > 0 ? 'السلة ($cartCount)' : 'عرض السلة',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            )
          : null,
    );
  }
}

// Category Sticky Header Delegate
class _CategoryStickyHeader extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final ColorScheme colorScheme;

  _CategoryStickyHeader({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.colorScheme,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((category) {
              final isSelected = selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => onCategorySelected(category),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFF9800)
                                : const Color(0xFF424242),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: isSelected ? 2 : 0,
                        width: isSelected ? 40 : 0,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 36; // تقليل لتتناسب مع المحتوى الأصغر جداً

  @override
  double get minExtent => 36;

  @override
  bool shouldRebuild(covariant _CategoryStickyHeader oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory;
  }
}
