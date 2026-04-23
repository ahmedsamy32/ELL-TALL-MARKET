import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:ell_tall_market/models/coupon_model.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/merchant_coupons_provider.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/services/coupon_service.dart';
import 'package:ell_tall_market/services/product_service.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class MerchantCouponsScreen extends StatefulWidget {
  const MerchantCouponsScreen({super.key});

  @override
  State<MerchantCouponsScreen> createState() => _MerchantCouponsScreenState();
}

class _MerchantCouponsScreenState extends State<MerchantCouponsScreen> {
  late final MerchantCouponsProvider _couponsProvider;
  bool _isBootstrapping = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _couponsProvider = MerchantCouponsProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapData());
  }

  @override
  void dispose() {
    _couponsProvider.dispose();
    super.dispose();
  }

  Future<void> _bootstrapData() async {
    setState(() {
      _isBootstrapping = true;
      _initError = null;
    });

    final supabaseProvider = context.read<SupabaseProvider>();
    final merchantProvider = context.read<MerchantProvider>();

    try {
      if (supabaseProvider.currentUser == null) {
        setState(() {
          _initError = 'يجب تسجيل الدخول لإدارة الكوبونات.';
          _isBootstrapping = false;
        });
        return;
      }

      if (merchantProvider.selectedMerchant == null &&
          supabaseProvider.currentUserProfile != null) {
        await merchantProvider.fetchMerchantByProfileId(
          supabaseProvider.currentUserProfile!.id,
        );
      }

      final merchant = merchantProvider.selectedMerchant;
      if (merchant == null) {
        if (!mounted) return;
        setState(() {
          _initError = 'لم يتم العثور على متجر مرتبط بالحساب الحالي.';
          _isBootstrapping = false;
        });
        return;
      }

      await _couponsProvider.initialize(merchantId: merchant.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = 'حدث خطأ أثناء تحميل بيانات الكوبونات. حاول لاحقاً.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MerchantCouponsProvider>.value(
      value: _couponsProvider,
      child: Consumer<MerchantCouponsProvider>(
        builder: (context, couponsProvider, _) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return Scaffold(
            appBar: AppBar(title: const Text('كوبونات المتجر')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: !_couponsProvider.hasStore || _isBootstrapping
                  ? null
                  : () => _openCouponForm(),
              icon: const Icon(Icons.add),
              label: const Text('إنشاء كوبون'),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.startFloat,
            body: ResponsiveCenter(
              maxWidth: 800,
              child: SafeArea(
                child: _buildBody(couponsProvider, colorScheme, textTheme),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    MerchantCouponsProvider provider,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (_isBootstrapping && provider.coupons.isEmpty) {
      return _buildShimmerList();
    }

    if (provider.isLoading) {
      return _buildShimmerList();
    }

    if (_initError != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        message: _initError!,
        color: colorScheme.error,
        actionLabel: 'إعادة المحاولة',
        onAction: _bootstrapData,
      );
    }

    if (!provider.hasStore) {
      return _buildMessageState(
        icon: Icons.store_mall_directory_outlined,
        message: 'لم يتم تعيين متجر لهذا الحساب بعد.',
        color: colorScheme.onSurfaceVariant,
      );
    }

    if (provider.error != null && provider.coupons.isEmpty) {
      return _buildMessageState(
        icon: Icons.warning_amber_rounded,
        message: provider.error!,
        color: colorScheme.error,
        actionLabel: 'إعادة المحاولة',
        onAction: provider.refresh,
      );
    }

    final coupons = provider.filteredCoupons;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (provider.isSaving) const LinearProgressIndicator(minHeight: 2),
          _buildSummaryRow(provider, colorScheme, textTheme),
          const SizedBox(height: 24),
          _buildFilterChips(provider, colorScheme),
          const SizedBox(height: 16),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                provider.error!,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ),
          if (coupons.isEmpty)
            _buildEmptyState(colorScheme)
          else
            ...coupons.map((coupon) => _buildCouponCard(coupon, provider)),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    final cs = Theme.of(context).colorScheme;
    return AppShimmer.wrap(
      context,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        primary: false,
        itemCount: 5,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    required Color color,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: color, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    MerchantCouponsProvider provider,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final cards = [
      _summaryCard(
        title: 'الكوبونات الفعّالة',
        value: provider.activeCount.toString(),
        icon: Icons.local_offer,
        color: colorScheme.primary,
        textTheme: textTheme,
      ),
      _summaryCard(
        title: 'الكوبونات المجدولة',
        value: provider.scheduledCount.toString(),
        icon: Icons.schedule_outlined,
        color: Colors.orange,
        textTheme: textTheme,
      ),
      _summaryCard(
        title: 'إجمالي الاستخدام',
        value: provider.totalUsage.toString(),
        icon: Icons.trending_up,
        color: colorScheme.secondary,
        textTheme: textTheme,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return Row(
            children: cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: card,
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Column(
          children: cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required TextTheme textTheme,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: textTheme.headlineSmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    MerchantCouponsProvider provider,
    ColorScheme colorScheme,
  ) {
    final filters = [
      (CouponFilter.all, 'الكل (${provider.coupons.length})'),
      (CouponFilter.active, 'فعّالة (${provider.activeCount})'),
      (CouponFilter.scheduled, 'مجدوَلة (${provider.scheduledCount})'),
      (CouponFilter.expired, 'منتهية (${provider.expiredCount})'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters
          .map(
            (filter) => ChoiceChip(
              label: Text(filter.$2),
              selected: provider.activeFilter == filter.$1,
              onSelected: (_) => provider.setFilter(filter.$1),
              selectedColor: colorScheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: provider.activeFilter == filter.$1
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCouponCard(
    CouponModel coupon,
    MerchantCouponsProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(coupon.status, colorScheme);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_offer_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coupon.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: Text(coupon.statusLabel),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(color: statusColor),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge('الكود: ${coupon.code}'),
                _badge(coupon.discountValueFormatted),
                _badge(
                  'الحد الأدنى: ${coupon.minimumOrderAmount.toStringAsFixed(2)} ج.م',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الاستخدام: ${coupon.usedCount}${coupon.usageLimit != null ? ' / ${coupon.usageLimit}' : ''}',
                ),
                Text(_formatDateRange(coupon.validFrom, coupon.validUntil)),
              ],
            ),
            if (coupon.description != null && coupon.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  coupon.description!,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openCouponForm(coupon: coupon),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleToggle(provider, coupon),
                    icon: Icon(
                      coupon.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    label: Text(coupon.isActive ? 'إيقاف' : 'تفعيل'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _confirmDelete(provider, coupon),
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                label: Text('حذف', style: TextStyle(color: colorScheme.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 48,
            color: colorScheme.onSurface,
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد كوبونات في هذا القسم',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإنشاء كوبون جديد لجذب المزيد من العملاء.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Color _statusColor(CouponStatus status, ColorScheme colorScheme) {
    switch (status) {
      case CouponStatus.scheduled:
        return Colors.orange;
      case CouponStatus.expired:
        return colorScheme.error;
      case CouponStatus.active:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  String _formatDateRange(DateTime start, DateTime? end) {
    if (end == null) {
      return 'ساري حتى إشعار آخر';
    }
    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  Future<void> _openCouponForm({CouponModel? coupon}) async {
    if (!_couponsProvider.hasStore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إعداد المتجر قبل إنشاء كوبون.')),
      );
      return;
    }

    final supabaseProvider = context.read<SupabaseProvider>();
    final createdBy = supabaseProvider.currentUser?.id;
    if (createdBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: coupon?.name ?? '');
    final codeController = TextEditingController(text: coupon?.code ?? '');
    final descriptionController = TextEditingController(
      text: coupon?.description ?? '',
    );
    final discountController = TextEditingController(
      text: coupon?.discountValue.toStringAsFixed(2) ?? '',
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

    // ── متغيرات الأنواع الجديدة ──
    List<String> selectedProductIds = List<String>.from(
      coupon?.productIds ?? [],
    );
    List<QuantityTier> quantityTiers = List<QuantityTier>.from(
      coupon?.quantityTiers ?? [],
    );
    int? activeHoursStart = coupon?.activeHoursStart;
    int? activeHoursEnd = coupon?.activeHoursEnd;
    List<ProductModel> storeProducts = [];
    bool loadingProducts = false;
    String productSearchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(
                          coupon == null ? 'إنشاء كوبون جديد' : 'تعديل الكوبون',
                        ),
                        subtitle: const Text('املأ البيانات الأساسية'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: formKey,
                            child: FocusTraversalGroup(
                              policy: OrderedTraversalPolicy(),
                              child: Column(
                                children: [
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(1),
                                    child: TextFormField(
                                      controller: nameController,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'اسم الكوبون',
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'أدخل اسم الكوبون';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(2),
                                    child: TextFormField(
                                      controller: codeController,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'كود الكوبون',
                                        helperText: 'أحرف إنجليزية بدون مسافات',
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'أدخل كود الكوبون';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(3),
                                    child: DropdownButtonFormField<CouponType>(
                                      initialValue: selectedType,
                                      decoration: const InputDecoration(
                                        labelText: 'نوع الكوبون',
                                      ),
                                      items: CouponType.values
                                          .map(
                                            (type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type.displayName),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setModalState(
                                            () => selectedType = value,
                                          );
                                          // تحميل المنتجات عند اختيار كوبون منتجات محددة
                                          if (value ==
                                                  CouponType.productSpecific &&
                                              storeProducts.isEmpty) {
                                            loadingProducts = true;
                                            setModalState(() {});
                                            ProductService.getProductsByStore(
                                                  _couponsProvider.storeId!,
                                                  activeOnly: true,
                                                )
                                                .then((products) {
                                                  storeProducts = products;
                                                  loadingProducts = false;
                                                  setModalState(() {});
                                                })
                                                .catchError((_) {
                                                  loadingProducts = false;
                                                  setModalState(() {});
                                                });
                                          }
                                        }
                                        FocusScope.of(context).nextFocus();
                                      },
                                    ),
                                  ),
                                  // ── وصف النوع ──
                                  if (selectedType.typeDescription.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        selectedType.typeDescription,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                      ),
                                    ),

                                  // ═══════════════════════════════════════
                                  // ██  كوبون المنتجات المحددة  ██
                                  // ═══════════════════════════════════════
                                  if (selectedType ==
                                      CouponType.productSpecific) ...[
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
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
                                                Text(
                                                  'اختر المنتجات المستهدفة',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (loadingProducts)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 16,
                                                ),
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              )
                                            else if (storeProducts.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  'لا توجد منتجات في متجرك',
                                                ),
                                              )
                                            else ...[
                                              // ── شريط الحالة + زر الكل ──
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'تم اختيار ${selectedProductIds.length} من ${storeProducts.length} منتج',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                selectedProductIds
                                                                    .isEmpty
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurfaceVariant
                                                                : Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            fontWeight:
                                                                selectedProductIds
                                                                    .isEmpty
                                                                ? FontWeight
                                                                      .normal
                                                                : FontWeight
                                                                      .w600,
                                                          ),
                                                    ),
                                                  ),
                                                  if (selectedProductIds
                                                      .isNotEmpty)
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
                                                            () =>
                                                                selectedProductIds
                                                                    .clear(),
                                                          ),
                                                      child: Text(
                                                        'إلغاء الكل',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.error,
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
                                                    onPressed: () =>
                                                        setModalState(() {
                                                          final allIds =
                                                              storeProducts
                                                                  .map(
                                                                    (p) => p.id,
                                                                  )
                                                                  .toList();
                                                          if (selectedProductIds
                                                                  .length ==
                                                              storeProducts
                                                                  .length) {
                                                            selectedProductIds
                                                                .clear();
                                                          } else {
                                                            selectedProductIds
                                                              ..clear()
                                                              ..addAll(allIds);
                                                          }
                                                        }),
                                                    child: Text(
                                                      selectedProductIds
                                                                  .length ==
                                                              storeProducts
                                                                  .length
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
                                                      'ابحث في المنتجات...',
                                                  prefixIcon: const Icon(
                                                    Icons.search,
                                                    size: 20,
                                                  ),
                                                  suffixIcon:
                                                      productSearchQuery
                                                          .isNotEmpty
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
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
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
                                                  final filtered =
                                                      productSearchQuery.isEmpty
                                                      ? storeProducts
                                                      : storeProducts
                                                            .where(
                                                              (p) => p.name
                                                                  .toLowerCase()
                                                                  .contains(
                                                                    productSearchQuery
                                                                        .toLowerCase(),
                                                                  ),
                                                            )
                                                            .toList();
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
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  return SizedBox(
                                                    height: 220,
                                                    child: ListView.builder(
                                                      itemCount:
                                                          filtered.length,
                                                      itemBuilder: (context, index) {
                                                        final product =
                                                            filtered[index];
                                                        final isSelected =
                                                            selectedProductIds
                                                                .contains(
                                                                  product.id,
                                                                );
                                                        return CheckboxListTile(
                                                          dense: true,
                                                          controlAffinity:
                                                              ListTileControlAffinity
                                                                  .leading,
                                                          selected: isSelected,
                                                          selectedTileColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                                  .withValues(
                                                                    alpha: 0.08,
                                                                  ),
                                                          title: Text(
                                                            product.name,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                        .w600
                                                                  : FontWeight
                                                                        .normal,
                                                            ),
                                                          ),
                                                          subtitle: Text(
                                                            '${product.price.toStringAsFixed(2)} ج.م',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                          secondary: isSelected
                                                              ? Icon(
                                                                  Icons
                                                                      .check_circle,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.primary,
                                                                  size: 20,
                                                                )
                                                              : null,
                                                          value: isSelected,
                                                          onChanged: (checked) {
                                                            setModalState(() {
                                                              if (checked ==
                                                                  true) {
                                                                selectedProductIds
                                                                    .add(
                                                                      product
                                                                          .id,
                                                                    );
                                                              } else {
                                                                selectedProductIds
                                                                    .remove(
                                                                      product
                                                                          .id,
                                                                    );
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

                                  // ═══════════════════════════════════════
                                  // ██  شرائح الكمية  ██
                                  // ═══════════════════════════════════════
                                  if (selectedType ==
                                      CouponType.tieredQuantity) ...[
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
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
                                                  onPressed: () {
                                                    setModalState(() {
                                                      quantityTiers.add(
                                                        const QuantityTier(
                                                          minQuantity: 2,
                                                          discountPercent: 5,
                                                        ),
                                                      );
                                                    });
                                                  },
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
                                                            TextInputType
                                                                .number,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  'الحد الأدنى للكمية',
                                                              isDense: true,
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
                                                            TextInputType
                                                                .number,
                                                        decoration:
                                                            const InputDecoration(
                                                              labelText:
                                                                  '% خصم',
                                                              isDense: true,
                                                            ),
                                                        onChanged: (val) {
                                                          final parsed =
                                                              double.tryParse(
                                                                val,
                                                              );
                                                          if (parsed != null) {
                                                            setModalState(() {
                                                              quantityTiers[i] =
                                                                  QuantityTier(
                                                                    minQuantity:
                                                                        tier.minQuantity,
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
                                                        Icons
                                                            .remove_circle_outline,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () {
                                                        setModalState(() {
                                                          quantityTiers
                                                              .removeAt(i);
                                                        });
                                                      },
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

                                  // ═══════════════════════════════════════
                                  // ██  ساعات التفعيل (Flash Sale)  ██
                                  // ═══════════════════════════════════════
                                  if (selectedType == CouponType.flashSale) ...[
                                    const SizedBox(height: 8),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
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
                                                    initialValue:
                                                        activeHoursStart,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'من الساعة',
                                                          isDense: true,
                                                        ),
                                                    items: List.generate(24, (
                                                      h,
                                                    ) {
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
                                                    onChanged: (val) =>
                                                        setModalState(
                                                          () =>
                                                              activeHoursStart =
                                                                  val,
                                                        ),
                                                    validator: (val) =>
                                                        val == null
                                                        ? 'مطلوب'
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: DropdownButtonFormField<int>(
                                                    initialValue:
                                                        activeHoursEnd,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'إلى الساعة',
                                                          isDense: true,
                                                        ),
                                                    items: List.generate(24, (
                                                      h,
                                                    ) {
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
                                                    onChanged: (val) =>
                                                        setModalState(
                                                          () => activeHoursEnd =
                                                              val,
                                                        ),
                                                    validator: (val) =>
                                                        val == null
                                                        ? 'مطلوب'
                                                        : null,
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
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(4),
                                    child: TextFormField(
                                      controller: discountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: InputDecoration(
                                        labelText:
                                            selectedType ==
                                                CouponType.tieredQuantity
                                            ? 'قيمة الخصم الافتراضية (اختياري)'
                                            : 'قيمة الخصم',
                                        suffixText:
                                            selectedType ==
                                                CouponType.fixedAmount
                                            ? 'ج.م'
                                            : '%',
                                      ),
                                      validator: (value) {
                                        // شرائح الكمية لا تحتاج قيمة خصم إلزامية
                                        if (selectedType ==
                                            CouponType.tieredQuantity) {
                                          return null;
                                        }
                                        if (selectedType ==
                                            CouponType.freeDelivery) {
                                          return null;
                                        }
                                        final parsed = double.tryParse(
                                          value ?? '',
                                        );
                                        if (parsed == null || parsed <= 0) {
                                          return 'أدخل قيمة خصم صحيحة';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(5),
                                    child: TextFormField(
                                      controller: descriptionController,
                                      maxLines: 2,
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'الوصف (اختياري)',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(6),
                                    child: TextFormField(
                                      controller: minOrderController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'الحد الأدنى للطلب',
                                        suffixText: 'ج.م',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(7),
                                    child: TextFormField(
                                      controller: maxDiscountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      decoration: const InputDecoration(
                                        labelText:
                                            'الحد الأقصى للخصم (اختياري)',
                                        suffixText: 'ج.م',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FocusTraversalOrder(
                                          order: const NumericFocusOrder(8),
                                          child: TextFormField(
                                            controller: usageLimitController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(),
                                            textInputAction:
                                                TextInputAction.next,
                                            onFieldSubmitted: (_) =>
                                                FocusScope.of(
                                                  context,
                                                ).nextFocus(),
                                            decoration: const InputDecoration(
                                              labelText: 'حد الاستخدام الكلي',
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FocusTraversalOrder(
                                          order: const NumericFocusOrder(9),
                                          child: TextFormField(
                                            controller: usagePerUserController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(),
                                            textInputAction:
                                                TextInputAction.done,
                                            onFieldSubmitted: (_) =>
                                                FocusScope.of(
                                                  context,
                                                ).unfocus(),
                                            decoration: const InputDecoration(
                                              labelText: 'حد لكل مستخدم',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
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
                                    onPick: (date) {
                                      setModalState(() => validUntil = date);
                                    },
                                    onClear: () =>
                                        setModalState(() => validUntil = null),
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('تفعيل الكوبون فوراً'),
                                    value: isActive,
                                    onChanged: (value) =>
                                        setModalState(() => isActive = value),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
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

                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              final success = coupon == null
                                  ? await _couponsProvider.createCoupon(
                                      input: input,
                                      createdBy: createdBy,
                                    )
                                  : await _couponsProvider.updateCoupon(
                                      couponId: coupon.id,
                                      input: input,
                                    );

                              if (!mounted) return;

                              if (success) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      coupon == null
                                          ? 'تم إنشاء الكوبون بنجاح'
                                          : 'تم تحديث الكوبون بنجاح',
                                    ),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'فشل حفظ الكوبون. حاول مرة أخرى.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(coupon == null ? 'حفظ' : 'تحديث'),
                          ),
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

  Future<void> _handleToggle(
    MerchantCouponsProvider provider,
    CouponModel coupon,
  ) async {
    final success = await provider.toggleCoupon(coupon);
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل تغيير حالة الكوبون.')));
    }
  }

  Future<void> _confirmDelete(
    MerchantCouponsProvider provider,
    CouponModel coupon,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الكوبون'),
        content: Text('هل أنت متأكد من حذف الكوبون ${coupon.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await provider.deleteCoupon(coupon.id);
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('فشل حذف الكوبون.')));
      }
    }
  }
}

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
        spacing: 8,
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
