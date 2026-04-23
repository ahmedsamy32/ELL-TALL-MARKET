import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/services/coupon_service.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';

/// بوتوم شيت القسائم — المسجلة والمستخدمة
class UserCouponsSheet extends StatefulWidget {
  const UserCouponsSheet({super.key});

  /// فتح البوتوم شيت
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UserCouponsSheet(),
    );
  }

  @override
  State<UserCouponsSheet> createState() => _UserCouponsSheetState();
}

class _UserCouponsSheetState extends State<UserCouponsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<CouponModel> _availableCoupons = [];
  List<_UsedCouponInfo> _usedCoupons = [];

  bool _isLoadingAvailable = true;
  bool _isLoadingUsed = true;
  String? _errorAvailable;
  String? _errorUsed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadAvailableCoupons();
    _loadUsedCoupons();
  }

  /// تحويل الخطأ لرسالة مفهومة للمستخدم
  String _friendlyError(dynamic error) {
    if (error is SocketException) {
      return 'لا يوجد اتصال بالإنترنت.\nتحقق من اتصالك وحاول مرة أخرى.';
    }
    if (error is PostgrestException) {
      if (error.code == 'PGRST301' || error.code == '42501') {
        return 'ليس لديك صلاحية لعرض القسائم.\nيرجى تسجيل الدخول مرة أخرى.';
      }
      return 'حدث خطأ في الخادم.\nيرجى المحاولة لاحقاً. (${error.code})';
    }
    if (error is AuthException) {
      return 'انتهت صلاحية الجلسة.\nيرجى تسجيل الدخول مرة أخرى.';
    }
    final msg = error.toString();
    if (msg.contains('TimeoutException') ||
        msg.contains('Connection closed') ||
        msg.contains('HandshakeException')) {
      return 'انتهت مهلة الاتصال.\nتحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
    }
    return 'حدث خطأ غير متوقع.\nيرجى المحاولة لاحقاً.';
  }

  Future<void> _loadAvailableCoupons() async {
    setState(() {
      _isLoadingAvailable = true;
      _errorAvailable = null;
    });

    try {
      final coupons = await CouponService.fetchActiveCoupons();
      if (mounted) {
        setState(() {
          _availableCoupons = coupons;
          _isLoadingAvailable = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorAvailable = _friendlyError(e);
          _isLoadingAvailable = false;
        });
      }
    }
  }

  Future<void> _loadUsedCoupons() async {
    setState(() {
      _isLoadingUsed = true;
      _errorUsed = null;
    });

    try {
      final userId = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      ).currentUser?.id;

      if (userId == null) {
        if (mounted) {
          setState(() {
            _usedCoupons = [];
            _isLoadingUsed = false;
          });
        }
        return;
      }

      final usageList = await CouponService.fetchUserCouponUsage(userId);
      if (mounted) {
        setState(() {
          _usedCoupons = usageList.map((row) {
            final couponData = row['coupons'] as Map<String, dynamic>?;
            return _UsedCouponInfo(
              coupon: couponData != null
                  ? CouponModel.fromMap(couponData)
                  : null,
              discountAmount: (row['discount_amount'] as num?)?.toDouble() ?? 0,
              usedAt: row['used_at'] != null
                  ? DateTime.parse(row['used_at'].toString())
                  : DateTime.now(),
              orderId: row['order_id'] as String?,
            );
          }).toList();
          _isLoadingUsed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorUsed = _friendlyError(e);
          _isLoadingUsed = false;
        });
      }
    }
  }

  void _copyCouponCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('تم نسخ الكود: $code'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle Bar ──
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.confirmation_num_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'القسائم',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'استخدم القسائم للحصول على خصومات',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Tab Bar ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_offer_rounded, size: 18),
                          const SizedBox(width: 6),
                          const Text('المتاحة'),
                          if (_availableCoupons.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_availableCoupons.length}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_rounded, size: 18),
                          const SizedBox(width: 6),
                          const Text('المستخدمة'),
                          if (_usedCoupons.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_usedCoupons.length}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvailableTab(scrollController),
                    _buildUsedTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Available Coupons Tab
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAvailableTab(ScrollController scrollController) {
    if (_isLoadingAvailable) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorAvailable != null) {
      return _buildErrorState(_errorAvailable!, onRetry: _loadAvailableCoupons);
    }

    if (_availableCoupons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.local_offer_outlined,
        title: 'لا توجد قسائم متاحة حالياً',
        subtitle: 'تابعنا للحصول على عروض وخصومات جديدة!',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailableCoupons,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _availableCoupons.length,
        itemBuilder: (context, index) {
          return _buildAvailableCouponCard(_availableCoupons[index]);
        },
      ),
    );
  }

  Widget _buildAvailableCouponCard(CouponModel coupon) {
    final colorScheme = Theme.of(context).colorScheme;

    // ألوان حسب نوع الكوبون
    final Color accentColor;
    final IconData typeIcon;
    switch (coupon.couponType) {
      case CouponType.percentage:
        accentColor = const Color(0xFF6A5AE0);
        typeIcon = Icons.percent_rounded;
        break;
      case CouponType.fixedAmount:
        accentColor = const Color(0xFF00897B);
        typeIcon = Icons.attach_money_rounded;
        break;
      case CouponType.freeDelivery:
        accentColor = const Color(0xFFFF6D00);
        typeIcon = Icons.local_shipping_rounded;
        break;
      case CouponType.productSpecific:
        accentColor = const Color(0xFF5C6BC0);
        typeIcon = Icons.inventory_2_rounded;
        break;
      case CouponType.tieredQuantity:
        accentColor = const Color(0xFF43A047);
        typeIcon = Icons.stacked_bar_chart_rounded;
        break;
      case CouponType.flashSale:
        accentColor = const Color(0xFFE53935);
        typeIcon = Icons.flash_on_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── الجزء العلوي: نوع الخصم ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.08),
                  accentColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                // أيقونة نوع الخصم
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),

                // قيمة الخصم والوصف
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.discountValueFormatted,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      if (coupon.name.isNotEmpty)
                        Text(
                          coupon.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // نوع الكوبون
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    coupon.couponType.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── الخط المنقط (قسيمة مثل التذكرة) ──
          Row(
            children: [
              _buildSemiCircle(accentColor, isLeft: true),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dashCount = (constraints.maxWidth / 10).floor();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(dashCount, (_) {
                        return Container(
                          width: 5,
                          height: 1.5,
                          color: accentColor.withValues(alpha: 0.3),
                        );
                      }),
                    );
                  },
                ),
              ),
              _buildSemiCircle(accentColor, isLeft: false),
            ],
          ),

          // ── الجزء السفلي: الكود والتفاصيل ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // كود الكوبون مع زر النسخ
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.2),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.confirmation_num_outlined,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                coupon.code,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _copyCouponCode(coupon.code),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // تفاصيل إضافية
                Row(
                  children: [
                    // الحد الأدنى
                    if (coupon.minimumOrderAmount > 0)
                      _buildDetailChip(
                        icon: Icons.shopping_cart_outlined,
                        label:
                            'حد أدنى ${coupon.minimumOrderAmount.toStringAsFixed(0)} ج.م',
                        colorScheme: colorScheme,
                      ),
                    if (coupon.minimumOrderAmount > 0) const SizedBox(width: 8),

                    // تاريخ الانتهاء
                    if (coupon.validUntil != null)
                      _buildDetailChip(
                        icon: Icons.schedule_rounded,
                        label:
                            'حتى ${DateFormat('dd/MM').format(coupon.validUntil!)}',
                        colorScheme: colorScheme,
                      ),
                    if (coupon.validUntil != null) const SizedBox(width: 8),

                    // الاستخدامات المتبقية
                    if (coupon.usageLimit != null)
                      _buildDetailChip(
                        icon: Icons.people_outline_rounded,
                        label: 'متبقي ${coupon.usageLimit! - coupon.usedCount}',
                        colorScheme: colorScheme,
                      ),
                  ],
                ),

                // ── تفاصيل الأنواع الجديدة ──
                if (coupon.couponType == CouponType.productSpecific &&
                    coupon.productIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'على ${coupon.productIds.length} منتج محدد',
                    colorScheme: colorScheme,
                  ),
                ],
                if (coupon.couponType == CouponType.tieredQuantity &&
                    coupon.quantityTiers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: coupon.quantityTiers.map((tier) {
                      return _buildDetailChip(
                        icon: Icons.stacked_bar_chart,
                        label: tier.label,
                        colorScheme: colorScheme,
                      );
                    }).toList(),
                  ),
                ],
                if (coupon.couponType == CouponType.flashSale &&
                    coupon.activeHoursFormatted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailChip(
                    icon: Icons.flash_on_rounded,
                    label: '⚡ ${coupon.activeHoursFormatted}',
                    colorScheme: colorScheme,
                  ),
                  if (!coupon.isWithinActiveHours)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'غير متاح الآن — ينشط ${coupon.activeHoursFormatted}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],

                // وصف الكوبون
                if (coupon.description != null &&
                    coupon.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          coupon.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Used Coupons Tab
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildUsedTab(ScrollController scrollController) {
    if (_isLoadingUsed) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorUsed != null) {
      return _buildErrorState(_errorUsed!, onRetry: _loadUsedCoupons);
    }

    if (_usedCoupons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'لم تستخدم أي قسيمة بعد',
        subtitle: 'عند استخدام قسيمة في طلبك، ستظهر هنا',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsedCoupons,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _usedCoupons.length,
        itemBuilder: (context, index) {
          return _buildUsedCouponCard(_usedCoupons[index]);
        },
      ),
    );
  }

  Widget _buildUsedCouponCard(_UsedCouponInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    final coupon = info.coupon;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerLow,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // أيقونة
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم الكوبون أو الكود
                Text(
                  coupon?.name ?? 'قسيمة محذوفة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // الكود
                if (coupon != null)
                  Text(
                    coupon.code,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 4),
                // تاريخ الاستخدام
                Text(
                  'استُخدمت ${DateFormat('dd/MM/yyyy').format(info.usedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // قيمة الخصم
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '-${info.discountAmount.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'مستخدمة ✓',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Widgets
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSemiCircle(Color color, {required bool isLeft}) {
    return Container(
      width: 12,
      height: 24,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: isLeft
            ? const BorderRadius.horizontal(right: Radius.circular(12))
            : const BorderRadius.horizontal(left: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
          bottom: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, {required VoidCallback onRetry}) {
    final colorScheme = Theme.of(context).colorScheme;

    // اختيار الأيقونة حسب نوع الخطأ
    final bool isNetwork =
        message.contains('اتصال') ||
        message.contains('إنترنت') ||
        message.contains('مهلة');
    final bool isAuth =
        message.contains('صلاحية') || message.contains('تسجيل الدخول');

    final IconData errorIcon = isNetwork
        ? Icons.wifi_off_rounded
        : isAuth
        ? Icons.lock_outline_rounded
        : Icons.error_outline_rounded;
    final Color iconColor = isNetwork
        ? Colors.orange
        : isAuth
        ? Colors.deepPurple
        : colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(errorIcon, size: 48, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// معلومات القسيمة المستخدمة
class _UsedCouponInfo {
  final CouponModel? coupon;
  final double discountAmount;
  final DateTime usedAt;
  final String? orderId;

  const _UsedCouponInfo({
    this.coupon,
    required this.discountAmount,
    required this.usedAt,
    this.orderId,
  });
}
