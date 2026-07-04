import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:ell_tall_market/services/store_wallet_service.dart';
import 'package:ell_tall_market/services/delivery_company_wallet_service.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';

typedef ManualTopupCreator =
    Future<Map<String, dynamic>> Function({
      required bool isOffice,
      required String entityId,
      required double amount,
      String? notes,
      String? reference,
    });

typedef WalletAdjuster =
    Future<Map<String, dynamic>> Function({
      required bool isOffice,
      required String entityId,
      required double amount,
      required bool isCredit,
      String? notes,
    });

Widget _bottomSheetContent(BuildContext context, Widget child) {
  return SafeArea(
    child: Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
}

bool _isLikelyUuid(String value) {
  final trimmed = value.trim();
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  return uuidPattern.hasMatch(trimmed);
}

class StoreWalletTopupsScreen extends StatefulWidget {
  const StoreWalletTopupsScreen({super.key});

  @override
  State<StoreWalletTopupsScreen> createState() =>
      _StoreWalletTopupsScreenState();
}

class _StoreWalletTopupsScreenState extends State<StoreWalletTopupsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isStoreLoading = true;
  bool _isOfficeLoading = true;
  String? _storeErrorMessage;
  String? _officeErrorMessage;
  List<Map<String, dynamic>> _storeTopups = [];
  List<Map<String, dynamic>> _officeTopups = [];
  String _storeStatusFilter = 'pending';
  String _officeStatusFilter = 'pending';
  Set<String> _lastSelectedStoreIds = {};
  Set<String> _lastSelectedCompanyIds = {};
  Map<String, double> _storeBalances = {};
  Map<String, double> _officeBalances = {};
  bool _isBalancesLoading = true;
  String? _balancesErrorMessage;
  List<Map<String, dynamic>> _balanceRows = [];
  String _balanceTypeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStoreTopups();
    _loadOfficeTopups();
    _loadBalancesOverview();
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreTopups() async {
    setState(() {
      _isStoreLoading = true;
      _storeErrorMessage = null;
      _storeBalances = {};
    });

    try {
      var query = _supabase
          .from('store_wallet_topups')
          .select(
            'id, store_id, amount, receipt_path, instapay_reference, status, notes, created_at, reviewed_at, store:stores(name)',
          );

      if (_storeStatusFilter != 'all') {
        query = query.eq('status', _storeStatusFilter);
      }

      final response = await query.order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response as List);

      final storeIds = rows
          .map((row) => row['store_id']?.toString())
          .whereType<String>()
          .toSet();

      if (!mounted) return;
      setState(() {
        _storeTopups = rows;
        _isStoreLoading = false;
      });

      await _loadStoreBalances(storeIds);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _storeErrorMessage = 'تعذر تحميل طلبات المتاجر';
        _isStoreLoading = false;
        _storeBalances = {};
      });
    }
  }

  Future<void> _loadOfficeTopups() async {
    setState(() {
      _isOfficeLoading = true;
      _officeErrorMessage = null;
      _officeBalances = {};
    });

    try {
      final rows = await DeliveryCompanyWalletService.getTopups(
        status: _officeStatusFilter,
      );

      final companyIds = rows
          .map((row) => row['company_id']?.toString())
          .whereType<String>()
          .toSet();

      if (!mounted) return;
      setState(() {
        _officeTopups = rows;
        _isOfficeLoading = false;
      });

      await _loadOfficeBalances(companyIds);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _officeErrorMessage = 'تعذر تحميل طلبات المكاتب';
        _isOfficeLoading = false;
        _officeBalances = {};
      });
    }
  }

  Future<void> _loadStoreBalances(Set<String> storeIds) async {
    if (storeIds.isEmpty) {
      if (!mounted) return;
      setState(() => _storeBalances = {});
      return;
    }

    try {
      final response = await _supabase
          .from('store_wallets')
          .select('store_id, balance')
          .inFilter('store_id', storeIds.toList());

      final rows = List<Map<String, dynamic>>.from(response as List);
      final balances = <String, double>{};
      for (final row in rows) {
        final storeId = row['store_id']?.toString();
        final balance = (row['balance'] as num?)?.toDouble();
        if (storeId != null && balance != null) {
          balances[storeId] = balance;
        }
      }

      if (!mounted) return;
      setState(() => _storeBalances = balances);
    } catch (e) {
      if (!mounted) return;
      setState(() => _storeBalances = {});
    }
  }

  Future<void> _loadOfficeBalances(Set<String> companyIds) async {
    if (companyIds.isEmpty) {
      if (!mounted) return;
      setState(() => _officeBalances = {});
      return;
    }

    try {
      final response = await _supabase
          .from('delivery_company_wallets')
          .select('company_id, balance')
          .inFilter('company_id', companyIds.toList());

      final rows = List<Map<String, dynamic>>.from(response as List);
      final balances = <String, double>{};
      for (final row in rows) {
        final companyId = row['company_id']?.toString();
        final balance = (row['balance'] as num?)?.toDouble();
        if (companyId != null && balance != null) {
          balances[companyId] = balance;
        }
      }

      if (!mounted) return;
      setState(() => _officeBalances = balances);
    } catch (e) {
      if (!mounted) return;
      setState(() => _officeBalances = {});
    }
  }

  Future<void> _loadBalancesOverview() async {
    setState(() {
      _isBalancesLoading = true;
      _balancesErrorMessage = null;
      _balanceRows = [];
    });

    try {
      final mergedRows = <Map<String, dynamic>>[];
      String? errorMessage;

      try {
        final storesResponse = await _supabase
            .from('stores')
            .select('id, name, category, merchant:merchants(remaining_orders, subscription_tiers(name))')
            .order('name');
        final stores = List<Map<String, dynamic>>.from(storesResponse as List);
        final storeIds = stores
            .map((store) => store['id']?.toString())
            .whereType<String>()
            .toList();

        final storeBalanceMap = <String, double>{};
        final storeCategoryMap = <String, List<Map<String, dynamic>>>{};
        if (storeIds.isNotEmpty) {
          final balancesResponse = await _supabase
              .from('store_wallets')
              .select('store_id, balance')
              .inFilter('store_id', storeIds);
          final balancesRows = List<Map<String, dynamic>>.from(
            balancesResponse as List,
          );
          for (final row in balancesRows) {
            final storeId = row['store_id']?.toString();
            final balance = (row['balance'] as num?)?.toDouble();
            if (storeId != null && balance != null) {
              storeBalanceMap[storeId] = balance;
            }
          }

          try {
            final categoriesResponse = await _supabase
                .from('store_categories')
                .select('store_id, display_order, category:categories(name)')
                .eq('is_visible', true)
                .inFilter('store_id', storeIds);
            final categoriesRows = List<Map<String, dynamic>>.from(
              categoriesResponse as List,
            );
            for (final row in categoriesRows) {
              final storeId = row['store_id']?.toString();
              final categoryMap = row['category'] as Map<String, dynamic>?;
              final name = categoryMap?['name']?.toString();
              if (storeId == null || name == null || name.trim().isEmpty) {
                continue;
              }
              final order = (row['display_order'] as num?)?.toInt() ?? 0;
              storeCategoryMap.putIfAbsent(storeId, () => []);
              storeCategoryMap[storeId]!.add({'name': name, 'order': order});
            }
          } catch (_) {
            // Ignore category errors; balances can still be shown.
          }
        }

        final categoryNameMap = <String, String>{};
        final directCategoryIds = stores
            .map((store) => store['category']?.toString())
            .whereType<String>()
            .map((value) => value.trim())
            .where(_isLikelyUuid)
            .toSet()
            .toList();
        if (directCategoryIds.isNotEmpty) {
          try {
            final categoriesResponse = await _supabase
                .from('categories')
                .select('id, name')
                .inFilter('id', directCategoryIds);
            final categoriesRows = List<Map<String, dynamic>>.from(
              categoriesResponse as List,
            );
            for (final row in categoriesRows) {
              final id = row['id']?.toString();
              final name = row['name']?.toString();
              if (id == null || name == null || name.trim().isEmpty) {
                continue;
              }
              categoryNameMap[id] = name.trim();
            }
          } catch (_) {
            // Ignore category name lookup errors.
          }
        }

        mergedRows.addAll(
          stores.map((store) {
            final storeId = store['id']?.toString();
            final name = store['name']?.toString() ?? 'غير معروف';
            final categories = storeId == null
                ? null
                : (storeCategoryMap[storeId] ?? []).toList();
            String? categoryLabel;
            final directCategoryRaw = store['category']?.toString();
            final directCategory = directCategoryRaw?.trim();
            if (categories != null && categories.isNotEmpty) {
              categories.sort(
                (a, b) => (a['order'] as int).compareTo(b['order'] as int),
              );
              final names = categories
                  .map((entry) => entry['name']?.toString())
                  .whereType<String>()
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList();
              if (names.isNotEmpty) {
                categoryLabel = names.join('، ');
              }
            }
            if (categoryLabel == null || categoryLabel.trim().isEmpty) {
              if (directCategory != null && directCategory.isNotEmpty) {
                categoryLabel =
                    categoryNameMap[directCategory] ?? directCategory;
              }
            }
            final balance = storeId == null
                ? 0.0
                : (storeBalanceMap[storeId] ?? 0.0);

            final merchantData = store['merchant'];
            Map<String, dynamic>? merchantMap;
            if (merchantData is Map<String, dynamic>) {
              merchantMap = merchantData;
            } else if (merchantData is List && merchantData.isNotEmpty) {
              merchantMap = merchantData.first as Map<String, dynamic>?;
            }
            final remainingOrders = merchantMap?['remaining_orders'] as int? ?? 0;
            final tierData = merchantMap?['subscription_tiers'];
            Map<String, dynamic>? tierMap;
            if (tierData is Map<String, dynamic>) {
              tierMap = tierData;
            } else if (tierData is List && tierData.isNotEmpty) {
              tierMap = tierData.first as Map<String, dynamic>?;
            }
            final packageName = tierMap?['name']?.toString() ?? 'بدون باقة';
            final packageInfo = "$packageName ($remainingOrders أوردر متبقي)";

            return {
              'id': storeId,
              'name': name,
              'balance': balance,
              'type': 'store',
              'category': categoryLabel,
              'package_info': packageInfo,
            };
          }),
        );
      } catch (_) {
        errorMessage = 'تعذر تحميل أرصدة المتاجر';
      }

      try {
        final companiesResponse = await _supabase
            .from('delivery_companies')
            .select('id, company_name')
            .order('company_name');
        final companies = List<Map<String, dynamic>>.from(
          companiesResponse as List,
        );
        final companyIds = companies
            .map((company) => company['id']?.toString())
            .whereType<String>()
            .toList();

        final officeBalanceMap = <String, double>{};
        if (companyIds.isNotEmpty) {
          final balancesResponse = await _supabase
              .from('delivery_company_wallets')
              .select('company_id, balance')
              .inFilter('company_id', companyIds);
          final balancesRows = List<Map<String, dynamic>>.from(
            balancesResponse as List,
          );
          for (final row in balancesRows) {
            final companyId = row['company_id']?.toString();
            final balance = (row['balance'] as num?)?.toDouble();
            if (companyId != null && balance != null) {
              officeBalanceMap[companyId] = balance;
            }
          }
        }

        mergedRows.addAll(
          companies.map((company) {
            final companyId = company['id']?.toString();
            final name = company['company_name']?.toString() ?? 'غير معروف';
            final balance = companyId == null
                ? 0.0
                : (officeBalanceMap[companyId] ?? 0.0);
            return {
              'id': companyId,
              'name': name,
              'balance': balance,
              'type': 'office',
            };
          }),
        );
      } catch (_) {
        errorMessage ??= 'تعذر تحميل أرصدة المكاتب';
      }

      mergedRows.sort((a, b) {
        final nameA = a['name']?.toString() ?? '';
        final nameB = b['name']?.toString() ?? '';
        return nameA.compareTo(nameB);
      });

      if (!mounted) return;
      setState(() {
        _balanceRows = mergedRows;
        _isBalancesLoading = false;
        _balancesErrorMessage = mergedRows.isEmpty
            ? (errorMessage ?? 'تعذر تحميل الأرصدة')
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _balancesErrorMessage = 'تعذر تحميل الأرصدة';
        _isBalancesLoading = false;
        _balanceRows = [];
      });
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchTopupEntities() async {
    try {
      final storesResponse = await _supabase
          .from('stores')
          .select('id, name, category')
          .order('name');
      final stores = List<Map<String, dynamic>>.from(storesResponse as List);
      final storeIds = stores
          .map((store) => store['id']?.toString())
          .whereType<String>()
          .toList();

      final storeCategoryMap = <String, List<Map<String, dynamic>>>{};
      if (storeIds.isNotEmpty) {
        try {
          final categoriesResponse = await _supabase
              .from('store_categories')
              .select('store_id, display_order, category:categories(name)')
              .eq('is_visible', true)
              .inFilter('store_id', storeIds);
          final categoriesRows = List<Map<String, dynamic>>.from(
            categoriesResponse as List,
          );
          for (final row in categoriesRows) {
            final storeId = row['store_id']?.toString();
            final categoryMap = row['category'] as Map<String, dynamic>?;
            final name = categoryMap?['name']?.toString();
            if (storeId == null || name == null || name.trim().isEmpty) {
              continue;
            }
            final order = (row['display_order'] as num?)?.toInt() ?? 0;
            storeCategoryMap.putIfAbsent(storeId, () => []);
            storeCategoryMap[storeId]!.add({'name': name, 'order': order});
          }
        } catch (_) {
          // Ignore category errors; stores can still be shown.
        }
      }

      final categoryNameMap = <String, String>{};
      final directCategoryIds = stores
          .map((store) => store['category']?.toString())
          .whereType<String>()
          .map((value) => value.trim())
          .where(_isLikelyUuid)
          .toSet()
          .toList();
      if (directCategoryIds.isNotEmpty) {
        try {
          final categoriesResponse = await _supabase
              .from('categories')
              .select('id, name')
              .inFilter('id', directCategoryIds);
          final categoriesRows = List<Map<String, dynamic>>.from(
            categoriesResponse as List,
          );
          for (final row in categoriesRows) {
            final id = row['id']?.toString();
            final name = row['name']?.toString();
            if (id == null || name == null || name.trim().isEmpty) {
              continue;
            }
            categoryNameMap[id] = name.trim();
          }
        } catch (_) {
          // Ignore category name lookup errors.
        }
      }

      final enrichedStores = stores.map((store) {
        final storeId = store['id']?.toString();
        final categories = storeId == null
            ? null
            : (storeCategoryMap[storeId] ?? []).toList();
        String? categoryLabel;
        final directCategoryRaw = store['category']?.toString();
        final directCategory = directCategoryRaw?.trim();
        if (categories != null && categories.isNotEmpty) {
          categories.sort(
            (a, b) => (a['order'] as int).compareTo(b['order'] as int),
          );
          final names = categories
              .map((entry) => entry['name']?.toString())
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            categoryLabel = names.join('، ');
          }
        }
        if (categoryLabel == null || categoryLabel.trim().isEmpty) {
          if (directCategory != null && directCategory.isNotEmpty) {
            categoryLabel = categoryNameMap[directCategory] ?? directCategory;
          }
        }
        final enriched = Map<String, dynamic>.from(store);
        enriched['category_label'] = categoryLabel;
        return enriched;
      }).toList();

      final companiesResponse = await _supabase
          .from('delivery_companies')
          .select('id, company_name')
          .order('company_name');

      return {
        'stores': enrichedStores,
        'companies': List<Map<String, dynamic>>.from(companiesResponse as List),
      };
    } catch (e) {
      return {'stores': [], 'companies': []};
    }
  }

  Future<Map<String, dynamic>> _createManualTopup({
    required bool isOffice,
    required String entityId,
    required double amount,
    String? notes,
    String? reference,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return {'success': false, 'error': 'not_authenticated'};
    }

    final mergedNotes = (notes == null || notes.trim().isEmpty)
        ? 'إضافة يدوية من الإدارة'
        : 'إضافة يدوية من الإدارة - ${notes.trim()}';

    try {
      final table = isOffice
          ? 'delivery_company_wallet_topups'
          : 'store_wallet_topups';
      final insertPayload = <String, dynamic>{
        isOffice ? 'company_id' : 'store_id': entityId,
        'amount': amount,
        'receipt_path': null,
        'instapay_reference': reference?.trim().isEmpty ?? true
            ? null
            : reference!.trim(),
        'status': 'pending',
        'requested_by': userId,
        'notes': mergedNotes,
      };

      final response = await _supabase
          .from(table)
          .insert(insertPayload)
          .select('id')
          .single();

      final topupId = response['id']?.toString();
      if (topupId == null) {
        return {'success': false, 'error': 'invalid_response'};
      }

      final approveResult = isOffice
          ? await DeliveryCompanyWalletService.approveTopup(
              topupId: topupId,
              notes: mergedNotes,
            )
          : await StoreWalletService.approveTopup(
              topupId: topupId,
              notes: mergedNotes,
            );

      if (approveResult['success'] == true) {
        return {'success': true};
      }

      return {
        'success': false,
        'error': approveResult['error'] ?? 'unexpected_response',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _adjustWalletBalance({
    required bool isOffice,
    required String entityId,
    required double amount,
    required bool isCredit,
    String? notes,
  }) async {
    return isOffice
        ? await DeliveryCompanyWalletService.adjustWalletBalance(
            companyId: entityId,
            amount: amount,
            isCredit: isCredit,
            notes: notes,
          )
        : await StoreWalletService.adjustWalletBalance(
            storeId: entityId,
            amount: amount,
            isCredit: isCredit,
            notes: notes,
          );
  }

  Future<bool> _updateTopupFields({
    required String topupId,
    required bool isOffice,
    double? amount,
    String? reference,
    bool updateReference = false,
  }) async {
    final payload = <String, dynamic>{};
    if (amount != null) {
      payload['amount'] = amount;
    }
    if (updateReference) {
      final trimmed = reference?.trim();
      payload['instapay_reference'] = trimmed == null || trimmed.isEmpty
          ? null
          : trimmed;
    }

    if (payload.isEmpty) return true;

    try {
      await _supabase
          .from(
            isOffice ? 'delivery_company_wallet_topups' : 'store_wallet_topups',
          )
          .update(payload)
          .eq('id', topupId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _reviewTopup({
    required String topupId,
    required bool approve,
    required bool isOffice,
    required double currentAmount,
    String? currentReference,
  }) async {
    final sheetResult = await showModalBottomSheet<_ReviewTopupResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (dialogContext) => _ReviewTopupSheet(
        approve: approve,
        initialAmount: currentAmount,
        initialReference: currentReference,
      ),
    );

    if (sheetResult == null) {
      return;
    }

    final parsedAmount = sheetResult.amount;
    final notes = sheetResult.notes;
    final reference = sheetResult.reference;

    final amountChanged = (parsedAmount - currentAmount).abs() > 0.001;
    final currentRef = currentReference?.trim() ?? '';
    final newRef = reference?.trim() ?? '';
    final referenceChanged = currentRef != newRef;

    if (amountChanged || referenceChanged) {
      final updated = await _updateTopupFields(
        topupId: topupId,
        amount: amountChanged ? parsedAmount : null,
        reference: reference,
        updateReference: referenceChanged,
        isOffice: isOffice,
      );
      if (!updated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث بيانات الطلب'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final reviewResult = approve
        ? await (isOffice
              ? DeliveryCompanyWalletService.approveTopup(
                  topupId: topupId,
                  notes: notes,
                )
              : StoreWalletService.approveTopup(topupId: topupId, notes: notes))
        : await (isOffice
              ? DeliveryCompanyWalletService.rejectTopup(
                  topupId: topupId,
                  notes: notes,
                )
              : StoreWalletService.rejectTopup(topupId: topupId, notes: notes));

    final success = reviewResult['success'] == true;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم تحديث الطلب بنجاح'
              : 'فشل تحديث الطلب: ${reviewResult['error'] ?? 'خطأ غير معروف'}',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (isOffice) {
      _loadOfficeTopups();
    } else {
      _loadStoreTopups();
    }
  }

  Future<void> _showManualTopupDialog() async {
    final dataFuture = _fetchTopupEntities();
    final bool isOffice = _tabController.index == 1;
    final Set<String> initialSelectedIds = Set<String>.from(
      isOffice ? _lastSelectedCompanyIds : _lastSelectedStoreIds,
    );

    final result = await showModalBottomSheet<_ManualTopupResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (dialogContext) => _ManualTopupSheet(
        isOffice: isOffice,
        dataFuture: dataFuture,
        initialSelectedIds: initialSelectedIds,
        createManualTopup: _createManualTopup,
        adjustWalletBalance: _adjustWalletBalance,
      ),
    );

    if (result == null) return;

    if (result.selectedIds.isNotEmpty) {
      if (result.isOffice) {
        _lastSelectedCompanyIds = Set<String>.from(result.selectedIds);
      } else {
        _lastSelectedStoreIds = Set<String>.from(result.selectedIds);
      }
    }

    if (!result.success) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isCredit ? 'تمت إضافة الرصيد بنجاح' : 'تم خصم الرصيد بنجاح',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _loadStoreTopups();
    await _loadOfficeTopups();
  }

  Future<void> _showReceipt(
    String receiptPath, {
    required bool isOffice,
  }) async {
    final signedUrl = isOffice
        ? await DeliveryCompanyWalletService.createSignedReceiptUrl(receiptPath)
        : await StoreWalletService.createSignedReceiptUrl(receiptPath);
    if (!mounted) return;

    if (signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر عرض الإيصال حالياً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (dialogContext) => _bottomSheetContent(
        dialogContext,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 320,
              height: 320,
              child: Image.network(
                signedUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('تعذر تحميل الإيصال'));
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(dialogContext);
                },
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات شحن المحافظ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'إضافة رصيد يدوي',
            onPressed: _showManualTopupDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'طلبات المتاجر'),
            Tab(text: 'طلبات المكاتب'),
            Tab(text: 'الأرصدة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTopupsTab(),
          _buildOfficeTopupsTab(),
          _buildBalancesTab(),
        ],
      ),
    );
  }

  Widget _buildStoreTopupsTab() {
    if (_isStoreLoading) {
      return RefreshIndicator(
        onRefresh: _loadStoreTopups,
        child: Column(
          children: [
            _buildStatusFilter(
              value: _storeStatusFilter,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _storeStatusFilter = value);
                _loadStoreTopups();
              },
            ),
            Expanded(child: AppShimmer.list(context)),
          ],
        ),
      );
    }

    if (_storeErrorMessage != null) {
      return Center(child: Text(_storeErrorMessage!));
    }

    return RefreshIndicator(
      onRefresh: _loadStoreTopups,
      child: Column(
        children: [
          _buildStatusFilter(
            value: _storeStatusFilter,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _storeStatusFilter = value);
              _loadStoreTopups();
            },
          ),
          Expanded(child: _buildTopupsList(_storeTopups, isOffice: false)),
        ],
      ),
    );
  }

  Widget _buildOfficeTopupsTab() {
    if (_isOfficeLoading) {
      return RefreshIndicator(
        onRefresh: _loadOfficeTopups,
        child: Column(
          children: [
            _buildStatusFilter(
              value: _officeStatusFilter,
              onChanged: (value) {
                if (value == null) return;
                setState(() => _officeStatusFilter = value);
                _loadOfficeTopups();
              },
            ),
            Expanded(child: AppShimmer.list(context)),
          ],
        ),
      );
    }

    if (_officeErrorMessage != null) {
      return Center(child: Text(_officeErrorMessage!));
    }

    return RefreshIndicator(
      onRefresh: _loadOfficeTopups,
      child: Column(
        children: [
          _buildStatusFilter(
            value: _officeStatusFilter,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _officeStatusFilter = value);
              _loadOfficeTopups();
            },
          ),
          Expanded(child: _buildTopupsList(_officeTopups, isOffice: true)),
        ],
      ),
    );
  }

  Widget _buildBalancesTab() {
    if (_isBalancesLoading) {
      return RefreshIndicator(
        onRefresh: _loadBalancesOverview,
        child: AppShimmer.list(context),
      );
    }

    if (_balancesErrorMessage != null) {
      return Center(child: Text(_balancesErrorMessage!));
    }

    final filteredRows = _balanceTypeFilter == 'all'
        ? _balanceRows
        : _balanceRows
              .where(
                (row) =>
                    row['type'] ==
                    (_balanceTypeFilter == 'stores' ? 'store' : 'office'),
              )
              .toList();

    final totalItems = filteredRows.isEmpty ? 2 : filteredRows.length + 1;

    return RefreshIndicator(
      onRefresh: _loadBalancesOverview,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: totalItems,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return DropdownButtonFormField<String>(
              key: ValueKey(_balanceTypeFilter),
              initialValue: _balanceTypeFilter,
              decoration: const InputDecoration(
                labelText: 'تصفية الأرصدة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('الكل')),
                DropdownMenuItem(value: 'stores', child: Text('متاجر')),
                DropdownMenuItem(value: 'offices', child: Text('مكاتب')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _balanceTypeFilter = value);
              },
            );
          }

          if (filteredRows.isEmpty) {
            return const Center(child: Text('لا توجد بيانات حالياً'));
          }

          final row = filteredRows[index - 1];
          final name = row['name']?.toString() ?? 'غير معروف';
          final balance = (row['balance'] as num?)?.toDouble() ?? 0.0;
          final category = row['category']?.toString();
          final packageInfo = row['package_info']?.toString() ?? 'بدون باقة';
          final subtitle = row['type'] == 'store'
              ? (category != null && category.trim().isNotEmpty
                    ? 'متجر • فئة: $category\nالباقة: $packageInfo'
                    : 'متجر • بدون فئة\nالباقة: $packageInfo')
              : 'مكتب';

          return Card(
            child: ListTile(
              title: Text(name),
              subtitle: Text(subtitle),
              trailing: Text(balance.toStringAsFixed(2)),
              isThreeLine: row['type'] == 'store',
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusFilter({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'حالة الطلب',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
          DropdownMenuItem(value: 'approved', child: Text('مقبول')),
          DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
          DropdownMenuItem(value: 'all', child: Text('الكل')),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTopupsList(
    List<Map<String, dynamic>> topups, {
    required bool isOffice,
  }) {
    if (topups.isEmpty) {
      return const Center(child: Text('لا توجد طلبات حالياً'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topups.length,
      itemBuilder: (context, index) {
        final topup = topups[index];
        final amount = (topup['amount'] as num?)?.toDouble() ?? 0.0;
        final status = (topup['status'] as String?) ?? 'pending';
        final receiptPath = topup['receipt_path'] as String?;
        final entityName = isOffice
            ? ((topup['company'] as Map<String, dynamic>?)?['company_name'] ??
                  topup['company_id'])
            : ((topup['store'] as Map<String, dynamic>?)?['name'] ??
                  topup['store_id']);
        final balance = isOffice
            ? _officeBalances[topup['company_id']?.toString() ?? '']
            : _storeBalances[topup['store_id']?.toString() ?? ''];
        final topupId = topup['id'].toString();
        final createdAt = _parseDate(topup['created_at']);
        final reference = topup['instapay_reference'] as String?;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entityName.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _formatStatus(status),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _statusColor(status),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('المبلغ: ${amount.toStringAsFixed(2)}'),
                Text(
                  balance == null
                      ? 'الرصيد الحالي: غير متاح'
                      : 'الرصيد الحالي: ${balance.toStringAsFixed(2)}',
                ),
                Text('التاريخ: ${_formatDate(createdAt)}'),
                if (reference != null && reference.isNotEmpty)
                  Text('مرجع إنستا باي: $reference'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: receiptPath == null
                          ? null
                          : () => _showReceipt(receiptPath, isOffice: isOffice),
                      icon: const Icon(Icons.image),
                      label: const Text('عرض الإيصال'),
                    ),
                    const Spacer(),
                    if (status == 'pending')
                      TextButton(
                        onPressed: () => _reviewTopup(
                          topupId: topupId,
                          approve: false,
                          isOffice: isOffice,
                          currentAmount: amount,
                          currentReference: reference,
                        ),
                        child: const Text('رفض'),
                      ),
                    if (status == 'pending')
                      ElevatedButton(
                        onPressed: () => _reviewTopup(
                          topupId: topupId,
                          approve: true,
                          isOffice: isOffice,
                          currentAmount: amount,
                          currentReference: reference,
                        ),
                        child: const Text('قبول'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('yyyy/MM/dd HH:mm').format(date);
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.parse(value.toString());
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class _ReviewTopupResult {
  final double amount;
  final String? notes;
  final String? reference;

  const _ReviewTopupResult({required this.amount, this.notes, this.reference});
}

class _ReviewTopupSheet extends StatefulWidget {
  final bool approve;
  final double initialAmount;
  final String? initialReference;

  const _ReviewTopupSheet({
    required this.approve,
    required this.initialAmount,
    this.initialReference,
  });

  @override
  State<_ReviewTopupSheet> createState() => _ReviewTopupSheetState();
}

class _ReviewTopupSheetState extends State<_ReviewTopupSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2),
    );
    _referenceController = TextEditingController(
      text: widget.initialReference ?? '',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parseAmount(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _bottomSheetContent(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.approve ? 'تأكيد قبول الشحن' : 'تأكيد رفض الشحن',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المبلغ الفعلي',
              border: const OutlineInputBorder(),
              errorText: _amountError,
            ),
            onChanged: (_) {
              if (_amountError != null) {
                setState(() => _amountError = null);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'مرجع إنستا باي (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(context);
                  },
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final parsedAmount = _parseAmount(_amountController.text);
                    if (parsedAmount == null || parsedAmount <= 0) {
                      setState(() => _amountError = 'أدخل مبلغ صحيح');
                      return;
                    }
                    final notes = _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim();
                    final reference = _referenceController.text.trim();
                    final referenceValue = reference.isEmpty ? null : reference;
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(
                      context,
                      _ReviewTopupResult(
                        amount: parsedAmount,
                        notes: notes,
                        reference: referenceValue,
                      ),
                    );
                  },
                  child: const Text('تأكيد'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualTopupResult {
  final bool success;
  final int count;
  final Set<String> selectedIds;
  final bool isCredit;
  final bool isOffice;

  const _ManualTopupResult({
    required this.success,
    required this.count,
    required this.selectedIds,
    required this.isCredit,
    required this.isOffice,
  });
}

class _ManualTopupSheet extends StatefulWidget {
  final bool isOffice;
  final Future<Map<String, List<Map<String, dynamic>>>> dataFuture;
  final Set<String> initialSelectedIds;
  final ManualTopupCreator createManualTopup;
  final WalletAdjuster adjustWalletBalance;

  const _ManualTopupSheet({
    required this.isOffice,
    required this.dataFuture,
    required this.initialSelectedIds,
    required this.createManualTopup,
    required this.adjustWalletBalance,
  });

  @override
  State<_ManualTopupSheet> createState() => _ManualTopupSheetState();
}

class _ManualTopupSheetState extends State<_ManualTopupSheet> {
  late final TextEditingController _searchController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _referenceController;
  late bool _isOfficeScope;
  late Set<String> _selectedStoreIds;
  late Set<String> _selectedOfficeIds;
  bool _isCredit = true;
  bool _isSaving = false;
  String? _amountError;
  String? _entityError;
  String? _submitError;
  String _searchQuery = '';

  Set<String> get _activeSelectedIds =>
      _isOfficeScope ? _selectedOfficeIds : _selectedStoreIds;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _referenceController = TextEditingController();
    _isOfficeScope = widget.isOffice;
    _selectedStoreIds = _isOfficeScope
        ? <String>{}
        : Set<String>.from(widget.initialSelectedIds);
    _selectedOfficeIds = _isOfficeScope
        ? Set<String>.from(widget.initialSelectedIds)
        : <String>{};
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double? _parseAmount(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: widget.dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _bottomSheetContent(
            context,
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final stores = snapshot.data?['stores'] ?? [];
        final companies = snapshot.data?['companies'] ?? [];
        final entities = _isOfficeScope ? companies : stores;
        final filteredEntities = entities.where((entity) {
          final name =
              (_isOfficeScope ? entity['company_name'] : entity['name'])
                  ?.toString() ??
              '';
          final id = entity['id']?.toString() ?? '';
          final category = _isOfficeScope
              ? ''
              : (entity['category_label']?.toString() ?? '');
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return name.toLowerCase().contains(query) ||
              id.toLowerCase().contains(query) ||
              category.toLowerCase().contains(query);
        }).toList();

        return _bottomSheetContent(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إضافة رصيد يدوي',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _isOfficeScope ? 'offices' : 'stores',
                decoration: const InputDecoration(
                  labelText: 'الجهة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'stores', child: Text('متاجر')),
                  DropdownMenuItem(value: 'offices', child: Text('مكاتب')),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _isOfficeScope = value == 'offices';
                          _entityError = null;
                          _submitError = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool>(
                initialValue: _isCredit,
                decoration: const InputDecoration(
                  labelText: 'نوع العملية',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('إضافة')),
                  DropdownMenuItem(value: false, child: Text('خصم')),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _isCredit = value ?? true;
                          _submitError = null;
                        });
                      },
              ),
              if (!_isCredit) ...[
                const SizedBox(height: 6),
                Text(
                  'سيتم خصم المبلغ من الرصيد الحالي',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: _isOfficeScope
                      ? 'بحث عن مكتب توصيل'
                      : 'بحث عن متجر',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            final ids = filteredEntities
                                .map((entity) => entity['id']?.toString())
                                .whereType<String>()
                                .where((id) => id.isNotEmpty)
                                .toList();
                            setState(() {
                              _activeSelectedIds.addAll(ids);
                              _entityError = null;
                            });
                          },
                    child: const Text('تحديد الكل'),
                  ),
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            setState(() {
                              _activeSelectedIds.clear();
                              _entityError = null;
                            });
                          },
                    child: const Text('إلغاء الكل'),
                  ),
                  const Spacer(),
                  Text(
                    'المحدد: ${_activeSelectedIds.length}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: filteredEntities.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد نتائج',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredEntities.length,
                        itemBuilder: (context, index) {
                          final entity = filteredEntities[index];
                          final entityId = entity['id']?.toString();
                          final entityName =
                              (_isOfficeScope
                                      ? entity['company_name']
                                      : entity['name'])
                                  ?.toString() ??
                              entityId ??
                              'غير معروف';
                          final categoryLabel = _isOfficeScope
                              ? null
                              : (entity['category_label']?.toString());
                          final subtitle = _isOfficeScope
                              ? null
                              : (categoryLabel != null &&
                                        categoryLabel.trim().isNotEmpty
                                    ? 'فئة: $categoryLabel'
                                    : 'فئة: بدون');
                          final isSelected =
                              entityId != null &&
                              _activeSelectedIds.contains(entityId);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            value: isSelected,
                            onChanged: _isSaving || entityId == null
                                ? null
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _activeSelectedIds.add(entityId);
                                      } else {
                                        _activeSelectedIds.remove(entityId);
                                      }
                                      _entityError = null;
                                      _submitError = null;
                                    });
                                  },
                            title: Text(entityName),
                            subtitle: subtitle == null
                                ? null
                                : Text(
                                    subtitle,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                          );
                        },
                      ),
              ),
              if (_entityError != null) ...[
                const SizedBox(height: 8),
                Text(_entityError!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  border: const OutlineInputBorder(),
                  errorText: _amountError,
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'مرجع (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(_submitError!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.pop(
                                context,
                                _ManualTopupResult(
                                  success: false,
                                  count: 0,
                                  selectedIds: Set<String>.from(
                                    _activeSelectedIds,
                                  ),
                                  isCredit: _isCredit,
                                  isOffice: _isOfficeScope,
                                ),
                              );
                            },
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              if (_activeSelectedIds.isEmpty) {
                                setState(() => _entityError = 'اختر جهة الشحن');
                                return;
                              }

                              final parsedAmount = _parseAmount(
                                _amountController.text,
                              );
                              if (parsedAmount == null || parsedAmount <= 0) {
                                setState(() => _amountError = 'أدخل مبلغ صحيح');
                                return;
                              }

                              setState(() {
                                _isSaving = true;
                                _submitError = null;
                              });

                              final rawNotes = _notesController.text.trim();
                              final debitNotes = rawNotes.isEmpty
                                  ? 'خصم يدوي من الإدارة'
                                  : 'خصم يدوي من الإدارة - $rawNotes';

                              int successCount = 0;
                              final totalCount = _activeSelectedIds.length;

                              for (final entityId in _activeSelectedIds) {
                                final saveResult = _isCredit
                                    ? await widget.createManualTopup(
                                        isOffice: _isOfficeScope,
                                        entityId: entityId,
                                        amount: parsedAmount,
                                        notes: rawNotes,
                                        reference: _referenceController.text,
                                      )
                                    : await widget.adjustWalletBalance(
                                        isOffice: _isOfficeScope,
                                        entityId: entityId,
                                        amount: parsedAmount,
                                        isCredit: false,
                                        notes: debitNotes,
                                      );

                                if (saveResult['success'] == true) {
                                  successCount += 1;
                                }
                              }

                              if (!context.mounted) return;

                              if (successCount == totalCount) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.pop(
                                  context,
                                  _ManualTopupResult(
                                    success: true,
                                    count: successCount,
                                    selectedIds: Set<String>.from(
                                      _activeSelectedIds,
                                    ),
                                    isCredit: _isCredit,
                                    isOffice: _isOfficeScope,
                                  ),
                                );
                              } else {
                                setState(() {
                                  _isSaving = false;
                                  _submitError =
                                      'تم تنفيذ $successCount من $totalCount. حاول مرة أخرى.';
                                });
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isCredit ? 'إضافة' : 'خصم'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
