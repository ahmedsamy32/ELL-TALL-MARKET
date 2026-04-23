import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/providers/merchant_coupons_provider.dart';
import 'package:ell_tall_market/services/coupon_service.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class ManageCouponsScreen extends StatefulWidget {
  const ManageCouponsScreen({super.key});

  @override
  State<ManageCouponsScreen> createState() => _ManageCouponsScreenState();
}

class _ManageCouponsScreenState extends State<ManageCouponsScreen> {
  List<CouponModel> _coupons = [];
  Map<String, String> _storeNames = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  CouponFilter _filter = CouponFilter.all;

  // ── Derived lists / counts ──
  List<CouponModel> get _filtered {
    switch (_filter) {
      case CouponFilter.active:
        return _coupons.where((c) => c.status == CouponStatus.active).toList();
      case CouponFilter.scheduled:
        return _coupons
            .where((c) => c.status == CouponStatus.scheduled)
            .toList();
      case CouponFilter.expired:
        return _coupons.where((c) => c.status == CouponStatus.expired).toList();
      case CouponFilter.all:
        return List.unmodifiable(_coupons);
    }
  }

  int get _activeCount =>
      _coupons.where((c) => c.status == CouponStatus.active).length;
  int get _scheduledCount =>
      _coupons.where((c) => c.status == CouponStatus.scheduled).length;
  int get _expiredCount =>
      _coupons.where((c) => c.status == CouponStatus.expired).length;
  int get _totalUsage => _coupons.fold(0, (sum, c) => sum + c.usedCount);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoupons());
  }

  Future<void> _loadCoupons() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final coupons = await CouponService.fetchAllCoupons();
      if (mounted) setState(() => _coupons = coupons);
      await _fetchAndCacheStoreNames(coupons);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAndCacheStoreNames(List<CouponModel> coupons) async {
    final storeIds = coupons
        .map((c) => c.storeId)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    if (storeIds.isEmpty) return;
    final names = await CouponService.fetchStoreNames(storeIds);
    if (mounted) setState(() => _storeNames = names);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكوبونات'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openCouponForm(),
            tooltip: 'إضافة كوبون',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveCenter(maxWidth: 1000, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return AppShimmer.list(context);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCoupons,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_isSaving) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
          ],
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildFilterChips(),
          const SizedBox(height: 12),
          if (_filtered.isEmpty)
            _buildEmptyState()
          else
            ..._filtered.asMap().entries.map(
              (e) => _buildCouponCard(e.value, e.key),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Stats row
  // ─────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      _StatInfo('فعّالة', _activeCount.toString(), Icons.check_circle_rounded, [
        const Color(0xFF43e97b),
        const Color(0xFF38f9d7),
      ]),
      _StatInfo('مجدوَلة', _scheduledCount.toString(), Icons.schedule_rounded, [
        const Color(0xFFfa709a),
        const Color(0xFFfee140),
      ]),
      _StatInfo(
        'الاستخدام',
        _totalUsage.toString(),
        Icons.trending_up_rounded,
        [const Color(0xFF667eea), const Color(0xFF764ba2)],
      ),
    ];

    return Row(
      children: stats.asMap().entries.map((e) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < stats.length - 1 ? 8 : 0),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 500 + e.key * 100),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: e.value.colors),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: e.value.colors[0].withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(e.value.icon, color: Colors.white, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      e.value.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.value.title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // Filter chips
  // ─────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = [
      (CouponFilter.all, 'الكل (${_coupons.length})'),
      (CouponFilter.active, 'فعّالة ($_activeCount)'),
      (CouponFilter.scheduled, 'مجدوَلة ($_scheduledCount)'),
      (CouponFilter.expired, 'منتهية ($_expiredCount)'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters
          .map(
            (f) => ChoiceChip(
              label: Text(f.$2),
              selected: _filter == f.$1,
              onSelected: (_) => setState(() => _filter = f.$1),
              selectedColor: const Color(0xFF667eea).withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: _filter == f.$1
                    ? const Color(0xFF667eea)
                    : Colors.grey.shade600,
                fontWeight: _filter == f.$1 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────────────────────────
  // Coupon card
  // ─────────────────────────────────────────────
  Widget _buildCouponCard(CouponModel coupon, int index) {
    final colors = _typeGradient(coupon.couponType);
    final statusColor = _statusColor(coupon.status);

    return TweenAnimationBuilder<double>(
      key: ValueKey(coupon.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: coupon.isActive
                ? colors[0].withValues(alpha: 0.2)
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _typeIcon(coupon.couponType),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          coupon.couponType.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors[0],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (coupon.storeId != null &&
                            _storeNames.containsKey(coupon.storeId)) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 11,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _storeNames[coupon.storeId]!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      coupon.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Prominent code display ──
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: coupon.code));
                  _showSnackBar('تم نسخ الكود: ${coupon.code}');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: colors[0].withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors[0].withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 18,
                        color: colors[0],
                      ),
                      const SizedBox(width: 10),
                      Text(
                        coupon.code,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          color: colors[0],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: colors[0].withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'نسخ',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors[0].withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Badges ──
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(coupon.discountValueFormatted),
                  if (coupon.minimumOrderAmount > 0)
                    _buildBadge(
                      'حد أدنى ${coupon.minimumOrderAmount.toStringAsFixed(0)} ج.م',
                    ),
                  if (coupon.usageLimit != null)
                    _buildBadge(
                      '${coupon.usedCount} / ${coupon.usageLimit} استخدام',
                    ),
                  if (coupon.couponType == CouponType.productSpecific &&
                      coupon.productIds.isNotEmpty)
                    _buildBadge('${coupon.productIds.length} منتج محدد'),
                  if (coupon.couponType == CouponType.tieredQuantity &&
                      coupon.quantityTiers.isNotEmpty)
                    _buildBadge('${coupon.quantityTiers.length} شريحة كمية'),
                  if (coupon.couponType == CouponType.flashSale &&
                      coupon.activeHoursStart != null)
                    _buildBadge(
                      '⚡ ${coupon.activeHoursFormatted}',
                      textColor: Colors.deepOrange,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Date range ──
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateRange(coupon.validFrom, coupon.validUntil),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),

              if (coupon.description != null &&
                  coupon.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  coupon.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // ── Action buttons ──
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      Icons.edit_rounded,
                      colors[0],
                      'تعديل',
                      () => _openCouponForm(coupon: coupon),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionBtn(
                      coupon.isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      coupon.isActive
                          ? Colors.orange.shade400
                          : Colors.green.shade500,
                      coupon.isActive ? 'إيقاف' : 'تفعيل',
                      () => _toggleCoupon(coupon),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconBtn(
                    Icons.delete_rounded,
                    Colors.red.shade400,
                    () => _deleteCoupon(coupon),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, {Color? textColor, Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor ?? Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
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
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == CouponFilter.all
                ? 'لا توجد كوبونات'
                : 'لا توجد كوبونات في هذا القسم',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'اضغط + لإضافة كوبون جديد',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════
  Color _statusColor(CouponStatus status) {
    switch (status) {
      case CouponStatus.active:
        return Colors.green.shade600;
      case CouponStatus.scheduled:
        return Colors.orange.shade600;
      case CouponStatus.expired:
        return Colors.red.shade400;
    }
  }

  List<Color> _typeGradient(CouponType type) {
    switch (type) {
      case CouponType.percentage:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case CouponType.fixedAmount:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case CouponType.freeDelivery:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case CouponType.productSpecific:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case CouponType.tieredQuantity:
        return [const Color(0xFF30cfd0), const Color(0xFF330867)];
      case CouponType.flashSale:
        return [const Color(0xFFf5576c), const Color(0xFFf093fb)];
    }
  }

  IconData _typeIcon(CouponType type) {
    switch (type) {
      case CouponType.percentage:
        return Icons.percent_rounded;
      case CouponType.fixedAmount:
        return Icons.attach_money_rounded;
      case CouponType.freeDelivery:
        return Icons.local_shipping_rounded;
      case CouponType.productSpecific:
        return Icons.inventory_2_rounded;
      case CouponType.tieredQuantity:
        return Icons.stacked_bar_chart_rounded;
      case CouponType.flashSale:
        return Icons.flash_on_rounded;
    }
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    final fmt = DateFormat('dd/MM/yyyy');
    if (end == null) return 'من ${fmt.format(start)} — دائم';
    return '${fmt.format(start)} — ${fmt.format(end)}';
  }

  // ═══════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════
  Future<void> _toggleCoupon(CouponModel coupon) async {
    setState(() => _isSaving = true);
    try {
      final success = await CouponService.toggleCouponStatus(
        couponId: coupon.id,
        isActive: !coupon.isActive,
      );
      if (success) {
        final idx = _coupons.indexWhere((c) => c.id == coupon.id);
        if (idx != -1) {
          setState(() {
            _coupons[idx] = coupon.copyWith(
              isActive: !coupon.isActive,
              updatedAt: DateTime.now(),
            );
          });
        }
        _showSnackBar(
          coupon.isActive ? 'تم إيقاف الكوبون' : 'تم تفعيل الكوبون',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteCoupon(CouponModel coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                Icons.delete_rounded,
                color: Colors.red.shade400,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('حذف الكوبون'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الكوبون "${coupon.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final success = await CouponService.deleteCoupon(coupon.id);
      if (success) {
        setState(() => _coupons.removeWhere((c) => c.id == coupon.id));
        _showSnackBar('تم حذف الكوبون');
      } else {
        _showSnackBar('فشل في حذف الكوبون', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═══════════════════════════════════════════════════
  //  COUPON FORM (bottom sheet)
  // ═══════════════════════════════════════════════════
  Future<void> _openCouponForm({CouponModel? coupon}) async {
    final supabaseProvider = context.read<SupabaseProvider>();
    final createdBy = supabaseProvider.currentUser?.id ?? '';

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: coupon?.name ?? '');
    final codeController = TextEditingController(text: coupon?.code ?? '');
    final descriptionController = TextEditingController(
      text: coupon?.description ?? '',
    );
    final discountController = TextEditingController(
      text: coupon != null ? coupon.discountValue.toStringAsFixed(2) : '',
    );
    final minOrderController = TextEditingController(
      text: coupon?.minimumOrderAmount.toString() ?? '0',
    );
    final maxDiscountController = TextEditingController(
      text: coupon?.maximumDiscountAmount?.toString() ?? '',
    );
    final usageLimitController = TextEditingController(
      text: coupon?.usageLimit?.toString() ?? '',
    );
    final usagePerUserController = TextEditingController(
      text: coupon?.usageLimitPerUser.toString() ?? '1',
    );

    CouponType selectedType = coupon?.couponType ?? CouponType.percentage;
    DateTime validFrom = coupon?.validFrom ?? DateTime.now();
    DateTime? validUntil = coupon?.validUntil;
    bool isActive = coupon?.isActive ?? true;
    List<QuantityTier> quantityTiers = List<QuantityTier>.from(
      coupon?.quantityTiers ?? [],
    );
    int? activeHoursStart = coupon?.activeHoursStart;
    int? activeHoursEnd = coupon?.activeHoursEnd;

    // ── متغيرات منتجات محددة ──
    List<String> selectedProductIds = List<String>.from(
      coupon?.productIds ?? [],
    );
    List<Map<String, dynamic>> allProducts = [];
    bool loadingAllProducts = false;
    String productSearchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.9,
                child: Column(
                  children: [
                    // ── Gradient header ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              coupon == null
                                  ? 'إنشاء كوبون جديد'
                                  : 'تعديل الكوبون',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // ── Form content ──
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              TextFormField(
                                controller: nameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'اسم الكوبون',
                                  prefixIcon: const Icon(Icons.label_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'أدخل اسم الكوبون'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Code
                              TextFormField(
                                controller: codeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'كود الكوبون',
                                  helperText: 'أحرف إنجليزية بدون مسافات',
                                  prefixIcon: const Icon(Icons.code_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? 'أدخل كود الكوبون'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Coupon type dropdown
                              DropdownButtonFormField<CouponType>(
                                initialValue: selectedType,
                                decoration: InputDecoration(
                                  labelText: 'نوع الكوبون',
                                  prefixIcon: const Icon(
                                    Icons.category_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: CouponType.values
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.displayName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => selectedType = v);
                                    // تحميل المنتجات عند اختيار productSpecific
                                    if (v == CouponType.productSpecific &&
                                        allProducts.isEmpty) {
                                      loadingAllProducts = true;
                                      setModalState(() {});
                                      CouponService.fetchAllProductsWithStore()
                                          .then((products) {
                                            allProducts = products;
                                            loadingAllProducts = false;
                                            setModalState(() {});
                                          })
                                          .catchError((_) {
                                            loadingAllProducts = false;
                                            setModalState(() {});
                                          });
                                    }
                                  }
                                },
                              ),

                              // Type description hint
                              if (selectedType.typeDescription.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 4,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF667eea,
                                      ).withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF667eea,
                                        ).withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          size: 14,
                                          color: Color(0xFF667eea),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            selectedType.typeDescription,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF667eea),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // ══ Product IDs (productSpecific) ══
                              if (selectedType ==
                                  CouponType.productSpecific) ...[
                                const SizedBox(height: 12),
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'اختر المنتجات المستهدفة',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (loadingAllProducts)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          )
                                        else if (allProducts.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text('لا توجد منتجات متاحة'),
                                          )
                                        else ...[
                                          // ── شريط الحالة + أزرار التحكم ──
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'تم اختيار ${selectedProductIds.length} من ${allProducts.length} منتج',
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            selectedProductIds
                                                                .isEmpty
                                                            ? Theme.of(ctx)
                                                                  .colorScheme
                                                                  .onSurfaceVariant
                                                            : const Color(
                                                                0xFF667eea,
                                                              ),
                                                        fontWeight:
                                                            selectedProductIds
                                                                .isEmpty
                                                            ? FontWeight.normal
                                                            : FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              if (selectedProductIds.isNotEmpty)
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  onPressed: () =>
                                                      setModalState(
                                                        () => selectedProductIds
                                                            .clear(),
                                                      ),
                                                  child: Text(
                                                    'إلغاء الكل',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.red.shade400,
                                                    ),
                                                  ),
                                                ),
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                onPressed: () => setModalState(
                                                  () {
                                                    final allIds = allProducts
                                                        .map(
                                                          (p) =>
                                                              p['id'] as String,
                                                        )
                                                        .toList();
                                                    if (selectedProductIds
                                                            .length ==
                                                        allProducts.length) {
                                                      selectedProductIds
                                                          .clear();
                                                    } else {
                                                      selectedProductIds
                                                        ..clear()
                                                        ..addAll(allIds);
                                                    }
                                                  },
                                                ),
                                                child: Text(
                                                  selectedProductIds.length ==
                                                          allProducts.length
                                                      ? 'إلغاء الكل'
                                                      : 'تحديد الكل',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // ── خانة البحث ──
                                          TextField(
                                            autofillHints: const [],
                                            autocorrect: false,
                                            onChanged: (v) => setModalState(
                                              () => productSearchQuery = v,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              hintText:
                                                  'ابحث باسم المنتج أو المتجر...',
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                size: 20,
                                              ),
                                              suffixIcon:
                                                  productSearchQuery.isNotEmpty
                                                  ? IconButton(
                                                      icon: const Icon(
                                                        Icons.clear,
                                                        size: 18,
                                                      ),
                                                      onPressed: () =>
                                                          setModalState(
                                                            () =>
                                                                productSearchQuery =
                                                                    '',
                                                          ),
                                                    )
                                                  : null,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // ── القائمة المفلترة ──
                                          Builder(
                                            builder: (context) {
                                              final q = productSearchQuery
                                                  .toLowerCase();
                                              final filtered = q.isEmpty
                                                  ? allProducts
                                                  : allProducts.where((p) {
                                                      final productName =
                                                          (p['name'] as String)
                                                              .toLowerCase();
                                                      final storeMap =
                                                          p['stores']
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >?;
                                                      final storeName =
                                                          (storeMap?['name']
                                                                      as String? ??
                                                                  '')
                                                              .toLowerCase();
                                                      return productName
                                                              .contains(q) ||
                                                          storeName.contains(q);
                                                    }).toList();

                                              if (filtered.isEmpty) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  child: Center(
                                                    child: Text(
                                                      'لا توجد نتائج لـ "$productSearchQuery"',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                              return SizedBox(
                                                height: 240,
                                                child: ListView.builder(
                                                  itemCount: filtered.length,
                                                  itemBuilder: (context, index) {
                                                    final p = filtered[index];
                                                    final pid =
                                                        p['id'] as String;
                                                    final pname =
                                                        p['name'] as String;
                                                    final price =
                                                        (p['price'] as num)
                                                            .toDouble();
                                                    final storeMap =
                                                        p['stores']
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >?;
                                                    final storeName =
                                                        storeMap?['name']
                                                            as String? ??
                                                        'غير معروف';
                                                    final isSelected =
                                                        selectedProductIds
                                                            .contains(pid);
                                                    return CheckboxListTile(
                                                      dense: true,
                                                      controlAffinity:
                                                          ListTileControlAffinity
                                                              .leading,
                                                      selected: isSelected,
                                                      selectedTileColor:
                                                          const Color(
                                                            0xFF667eea,
                                                          ).withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      title: Text(
                                                        pname,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                      ),
                                                      subtitle: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .storefront_rounded,
                                                            size: 12,
                                                            color: Colors
                                                                .grey
                                                                .shade500,
                                                          ),
                                                          const SizedBox(
                                                            width: 3,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              storeName,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey
                                                                    .shade500,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            '${price.toStringAsFixed(2)} ج.م',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      secondary: isSelected
                                                          ? const Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color: Color(
                                                                0xFF667eea,
                                                              ),
                                                              size: 20,
                                                            )
                                                          : null,
                                                      value: isSelected,
                                                      onChanged: (checked) {
                                                        setModalState(() {
                                                          if (checked == true) {
                                                            selectedProductIds
                                                                .add(pid);
                                                          } else {
                                                            selectedProductIds
                                                                .remove(pid);
                                                          }
                                                        });
                                                      },
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // ══ Quantity tiers (tieredQuantity) ══
                              if (selectedType ==
                                  CouponType.tieredQuantity) ...[
                                const SizedBox(height: 12),
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.stacked_bar_chart,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'شرائح الكمية',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              label: const Text('إضافة'),
                                              onPressed: () =>
                                                  setModalState(() {
                                                    quantityTiers.add(
                                                      const QuantityTier(
                                                        minQuantity: 2,
                                                        discountPercent: 5,
                                                      ),
                                                    );
                                                  }),
                                            ),
                                          ],
                                        ),
                                        if (quantityTiers.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'أضف شرائح: مثال — 2 قطع → 10%، 3 قطع → 20%',
                                            ),
                                          ),
                                        ...quantityTiers.asMap().entries.map((
                                          entry,
                                        ) {
                                          final i = entry.key;
                                          final tier = entry.value;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: tier
                                                        .minQuantity
                                                        .toString(),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'الحد الأدنى',
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                    onChanged: (val) {
                                                      final parsed =
                                                          int.tryParse(val);
                                                      if (parsed != null) {
                                                        setModalState(() {
                                                          quantityTiers[i] =
                                                              QuantityTier(
                                                                minQuantity:
                                                                    parsed,
                                                                discountPercent:
                                                                    tier.discountPercent,
                                                              );
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: tier
                                                        .discountPercent
                                                        .toStringAsFixed(0),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: '% خصم',
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                    onChanged: (val) {
                                                      final parsed =
                                                          double.tryParse(val);
                                                      if (parsed != null) {
                                                        setModalState(() {
                                                          quantityTiers[i] =
                                                              QuantityTier(
                                                                minQuantity: tier
                                                                    .minQuantity,
                                                                discountPercent:
                                                                    parsed,
                                                              );
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      setModalState(
                                                        () => quantityTiers
                                                            .removeAt(i),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // ══ Flash sale hours ══
                              if (selectedType == CouponType.flashSale) ...[
                                const SizedBox(height: 12),
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'ساعات التفعيل',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<int>(
                                                initialValue: activeHoursStart,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'من الساعة',
                                                      isDense: true,
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                items: List.generate(24, (h) {
                                                  final label = h == 0
                                                      ? '12 ص'
                                                      : h < 12
                                                      ? '$h ص'
                                                      : h == 12
                                                      ? '12 م'
                                                      : '${h - 12} م';
                                                  return DropdownMenuItem(
                                                    value: h,
                                                    child: Text(label),
                                                  );
                                                }),
                                                onChanged: (v) => setModalState(
                                                  () => activeHoursStart = v,
                                                ),
                                                validator: (v) =>
                                                    v == null ? 'مطلوب' : null,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: DropdownButtonFormField<int>(
                                                initialValue: activeHoursEnd,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'إلى الساعة',
                                                      isDense: true,
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                items: List.generate(24, (h) {
                                                  final label = h == 0
                                                      ? '12 ص'
                                                      : h < 12
                                                      ? '$h ص'
                                                      : h == 12
                                                      ? '12 م'
                                                      : '${h - 12} م';
                                                  return DropdownMenuItem(
                                                    value: h,
                                                    child: Text(label),
                                                  );
                                                }),
                                                onChanged: (v) => setModalState(
                                                  () => activeHoursEnd = v,
                                                ),
                                                validator: (v) =>
                                                    v == null ? 'مطلوب' : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Discount value
                              TextFormField(
                                controller: discountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText:
                                      selectedType == CouponType.tieredQuantity
                                      ? 'قيمة الخصم الافتراضية (اختياري)'
                                      : 'قيمة الخصم',
                                  suffixText:
                                      selectedType == CouponType.fixedAmount
                                      ? 'ج.م'
                                      : '%',
                                  prefixIcon: const Icon(
                                    Icons.discount_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) {
                                  if (selectedType ==
                                          CouponType.tieredQuantity ||
                                      selectedType == CouponType.freeDelivery) {
                                    return null;
                                  }
                                  final parsed = double.tryParse(v ?? '');
                                  if (parsed == null || parsed <= 0) {
                                    return 'أدخل قيمة خصم صحيحة';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Description
                              TextFormField(
                                controller: descriptionController,
                                maxLines: 2,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'الوصف (اختياري)',
                                  prefixIcon: const Icon(
                                    Icons.description_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Min order
                              TextFormField(
                                controller: minOrderController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'الحد الأدنى للطلب',
                                  suffixText: 'ج.م',
                                  prefixIcon: const Icon(
                                    Icons.shopping_cart_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Max discount
                              TextFormField(
                                controller: maxDiscountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'الحد الأقصى للخصم (اختياري)',
                                  suffixText: 'ج.م',
                                  prefixIcon: const Icon(Icons.north_rounded),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Usage limits row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: usageLimitController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'حد الاستخدام الكلي',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: usagePerUserController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: 'حد لكل مستخدم',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Date pickers
                              _DatePickerTile(
                                label: 'تاريخ البداية',
                                value: validFrom,
                                onPick: (date) {
                                  if (date != null) {
                                    setModalState(() => validFrom = date);
                                  }
                                },
                              ),
                              _DatePickerTile(
                                label: 'تاريخ الانتهاء (اختياري)',
                                value: validUntil,
                                onPick: (date) =>
                                    setModalState(() => validUntil = date),
                                onClear: () =>
                                    setModalState(() => validUntil = null),
                              ),

                              // Active toggle
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('تفعيل الكوبون فوراً'),
                                value: isActive,
                                onChanged: (v) =>
                                    setModalState(() => isActive = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Save button ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final input = CouponInput(
                              name: nameController.text.trim(),
                              code: codeController.text.trim(),
                              couponType: selectedType,
                              discountValue:
                                  double.tryParse(
                                    discountController.text.trim(),
                                  ) ??
                                  0,
                              minimumOrderAmount:
                                  double.tryParse(
                                    minOrderController.text.trim(),
                                  ) ??
                                  0,
                              maximumDiscountAmount:
                                  maxDiscountController.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(
                                      maxDiscountController.text.trim(),
                                    ),
                              usageLimit:
                                  usageLimitController.text.trim().isEmpty
                                  ? null
                                  : int.tryParse(
                                      usageLimitController.text.trim(),
                                    ),
                              usageLimitPerUser:
                                  int.tryParse(
                                    usagePerUserController.text.trim(),
                                  ) ??
                                  1,
                              validFrom: validFrom,
                              validUntil: validUntil,
                              isActive: isActive,
                              description:
                                  descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                              productIds: selectedProductIds,
                              quantityTiers: quantityTiers,
                              activeHoursStart: activeHoursStart,
                              activeHoursEnd: activeHoursEnd,
                            );

                            final navigator = Navigator.of(ctx);
                            setState(() => _isSaving = true);
                            try {
                              if (coupon == null) {
                                final newCoupon =
                                    await CouponService.createAdminCoupon(
                                      input: input,
                                      createdBy: createdBy,
                                    );
                                if (mounted) {
                                  setState(() => _coupons.insert(0, newCoupon));
                                }
                              } else {
                                final updated =
                                    await CouponService.updateCoupon(
                                      couponId: coupon.id,
                                      input: input,
                                    );
                                if (mounted) {
                                  setState(() {
                                    final idx = _coupons.indexWhere(
                                      (c) => c.id == coupon.id,
                                    );
                                    if (idx != -1) _coupons[idx] = updated;
                                  });
                                }
                              }
                              if (!mounted) return;
                              navigator.pop();
                              _showSnackBar(
                                coupon == null
                                    ? 'تم إنشاء الكوبون بنجاح ✅'
                                    : 'تم تحديث الكوبون بنجاح ✅',
                              );
                            } catch (e) {
                              _showSnackBar(
                                'فشل في حفظ الكوبون: $e',
                                isError: true,
                              );
                            } finally {
                              if (mounted) setState(() => _isSaving = false);
                            }
                          },
                          child: Text(
                            coupon == null ? 'إنشاء الكوبون' : 'حفظ التعديلات',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    codeController.dispose();
    descriptionController.dispose();
    discountController.dispose();
    minOrderController.dispose();
    maxDiscountController.dispose();
    usageLimitController.dispose();
    usagePerUserController.dispose();
  }
}

// ─────────────────────────────────────────────
// Helper data class for stat cards
// ─────────────────────────────────────────────
class _StatInfo {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;

  const _StatInfo(this.title, this.value, this.icon, this.colors);
}

// ─────────────────────────────────────────────
// Reusable date-picker tile (shared with merchant screen)
// ─────────────────────────────────────────────
class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.onPick,
    this.value,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value != null
            ? DateFormat('dd/MM/yyyy').format(value!)
            : 'لم يتم التحديد',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (value != null && onClear != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'مسح التاريخ',
              onPressed: onClear,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              onPick(picked);
            },
          ),
        ],
      ),
    );
  }
}
