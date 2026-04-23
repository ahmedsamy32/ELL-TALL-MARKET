import 'package:flutter/material.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';

class DeliveryZonePricingScreen extends StatefulWidget {
  const DeliveryZonePricingScreen({super.key});

  @override
  State<DeliveryZonePricingScreen> createState() =>
      _DeliveryZonePricingScreenState();
}

class _DeliveryZonePricingScreenState extends State<DeliveryZonePricingScreen> {
  bool _isLoading = true;
  List<DeliveryZonePricingModel> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    try {
      final zones = await DeliveryZonePricingService.getAllZonesForAdmin();
      if (!mounted) return;
      setState(() => _zones = zones);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحميل المناطق: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalize(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  List<String> get _governorates {
    final values = _zones
        .map((z) => z.governorate.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<DeliveryZonePricingModel> _zonesByGovernorate(String governorate) {
    final gov = _normalize(governorate);
    return _zones.where((z) => _normalize(z.governorate) == gov).toList();
  }

  DeliveryZonePricingModel? _governorateDefault(String governorate) {
    final list = _zonesByGovernorate(governorate)
        .where(
          (z) => (z.city ?? '').trim().isEmpty && (z.area ?? '').trim().isEmpty,
        )
        .toList();
    if (list.isEmpty) return null;
    return list.first;
  }

  List<String> _citiesForGovernorate(String governorate) {
    final list = _zonesByGovernorate(governorate)
        .map((z) => (z.city ?? '').trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    list.sort();
    return list;
  }

  DeliveryZonePricingModel? _cityDefault(String governorate, String city) {
    final gov = _normalize(governorate);
    final c = _normalize(city);
    final list = _zones
        .where(
          (z) =>
              _normalize(z.governorate) == gov &&
              _normalize(z.city) == c &&
              (z.area ?? '').trim().isEmpty,
        )
        .toList();
    if (list.isEmpty) return null;
    return list.first;
  }

  List<DeliveryZonePricingModel> _areasForCity(
    String governorate,
    String city,
  ) {
    final gov = _normalize(governorate);
    final c = _normalize(city);
    final list = _zones
        .where(
          (z) =>
              _normalize(z.governorate) == gov &&
              _normalize(z.city) == c &&
              (z.area ?? '').trim().isNotEmpty,
        )
        .toList();
    list.sort((a, b) => (a.area ?? '').compareTo(b.area ?? ''));
    return list;
  }

  Future<void> _showZoneDialog({
    DeliveryZonePricingModel? zone,
    String? preGovernorate,
    String? preCity,
    bool lockGovernorate = false,
    bool lockCity = false,
  }) async {
    final result = await showModalBottomSheet<_ZoneFormDialogResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (dialogContext) => _ZoneFormBottomSheet(
        zone: zone,
        preGovernorate: preGovernorate,
        preCity: preCity,
        lockGovernorate: lockGovernorate,
        lockCity: lockCity,
      ),
    );

    if (result == null) return;

    if (result.area.isNotEmpty && result.city.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إدخال منطقة بدون اختيار مدينة')),
      );
      return;
    }

    try {
      await DeliveryZonePricingService.upsertZone(
        zoneId: zone?.id,
        governorate: result.governorate,
        city: result.city,
        area: result.area,
        fee: result.fee,
        estimatedMinutes: result.estimatedMinutes,
        isActive: result.isActive,
      );

      await _loadZones();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ منطقة التسعير بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ المنطقة: $e')));
    }
  }

  Future<void> _deleteZone(DeliveryZonePricingModel zone) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'حذف منطقة التسعير',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('هل تريد حذف "${zone.scopeLabel}"؟'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('حذف'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await DeliveryZonePricingService.deleteZone(zone.id);
      await _loadZones();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المنطقة')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  String _zoneDetails(DeliveryZonePricingModel zone) {
    return 'السعر: ${zone.fee.toStringAsFixed(2)} ج.م'
        '${zone.estimatedMinutes != null ? ' • ${zone.estimatedMinutes} دقيقة' : ''}'
        '${!zone.isActive ? ' • غير مفعّل' : ''}';
  }

  Widget _buildLeafZoneTile(DeliveryZonePricingModel zone) {
    return ListTile(
      dense: true,
      title: Text(
        zone.area?.trim().isNotEmpty == true ? zone.area! : 'افتراضي',
      ),
      subtitle: Text(_zoneDetails(zone)),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showZoneDialog(zone: zone),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteZone(zone),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسعير مناطق التوصيل')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showZoneDialog(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة محافظة/مدينة/منطقة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _zones.isEmpty
          ? const Center(child: Text('لا توجد مناطق تسعير حتى الآن'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final governorate = _governorates[index];
                final governorateDefault = _governorateDefault(governorate);
                final cities = _citiesForGovernorate(governorate);
                return Card(
                  child: ExpansionTile(
                    title: Text(
                      governorate,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'مدن: ${cities.length} • مناطق: ${_zonesByGovernorate(governorate).where((z) => (z.area ?? '').trim().isNotEmpty).length}',
                    ),
                    trailing: IconButton(
                      tooltip: 'إضافة مدينة تحت المحافظة',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _showZoneDialog(
                        preGovernorate: governorate,
                        lockGovernorate: true,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      if (governorateDefault != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Card(
                            child: _buildLeafZoneTile(governorateDefault),
                          ),
                        ),
                      if (cities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('لا توجد مدن تحت هذه المحافظة بعد'),
                        ),
                      ...cities.map((city) {
                        final cityDefault = _cityDefault(governorate, city);
                        final areas = _areasForCity(governorate, city);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Card(
                            child: ExpansionTile(
                              title: Text(city),
                              subtitle: Text('مناطق: ${areas.length}'),
                              trailing: IconButton(
                                tooltip: 'إضافة منطقة تحت المدينة',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _showZoneDialog(
                                  preGovernorate: governorate,
                                  preCity: city,
                                  lockGovernorate: true,
                                  lockCity: true,
                                ),
                              ),
                              children: [
                                if (cityDefault != null)
                                  _buildLeafZoneTile(cityDefault),
                                if (areas.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'لا توجد مناطق تحت هذه المدينة بعد',
                                    ),
                                  ),
                                ...areas.map(_buildLeafZoneTile),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemCount: _governorates.length,
            ),
    );
  }
}

class _ZoneFormDialogResult {
  final String governorate;
  final String city;
  final String area;
  final double fee;
  final int? estimatedMinutes;
  final bool isActive;

  const _ZoneFormDialogResult({
    required this.governorate,
    required this.city,
    required this.area,
    required this.fee,
    required this.estimatedMinutes,
    required this.isActive,
  });
}

class _ZoneFormBottomSheet extends StatefulWidget {
  final DeliveryZonePricingModel? zone;
  final String? preGovernorate;
  final String? preCity;
  final bool lockGovernorate;
  final bool lockCity;

  const _ZoneFormBottomSheet({
    required this.zone,
    required this.preGovernorate,
    required this.preCity,
    required this.lockGovernorate,
    required this.lockCity,
  });

  @override
  State<_ZoneFormBottomSheet> createState() => _ZoneFormBottomSheetState();
}

class _ZoneFormBottomSheetState extends State<_ZoneFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _governorateCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _etaCtrl;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _governorateCtrl = TextEditingController(
      text: widget.zone?.governorate ?? widget.preGovernorate ?? '',
    );
    _cityCtrl = TextEditingController(
      text: widget.zone?.city ?? widget.preCity ?? '',
    );
    _areaCtrl = TextEditingController(text: widget.zone?.area ?? '');
    _feeCtrl = TextEditingController(
      text: widget.zone != null ? widget.zone!.fee.toStringAsFixed(2) : '',
    );
    _etaCtrl = TextEditingController(
      text: widget.zone?.estimatedMinutes?.toString() ?? '',
    );
    _isActive = widget.zone?.isActive ?? true;
  }

  @override
  void dispose() {
    _governorateCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _feeCtrl.dispose();
    _etaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.zone == null
                      ? 'إضافة منطقة تسعير'
                      : 'تعديل منطقة التسعير',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _governorateCtrl,
                  readOnly: widget.lockGovernorate,
                  decoration: const InputDecoration(labelText: 'المحافظة *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'المحافظة مطلوبة'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityCtrl,
                  readOnly: widget.lockCity,
                  decoration: const InputDecoration(
                    labelText: 'المدينة (اختياري)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _areaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المنطقة/الحي (اختياري)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _feeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'سعر التوصيل *'),
                  validator: (v) {
                    final fee = double.tryParse((v ?? '').trim());
                    if (fee == null || fee < 0) return 'سعر غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _etaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'وقت التوصيل (دقيقة - اختياري)',
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return null;
                    final eta = int.tryParse(v!.trim());
                    if (eta == null || eta <= 0) return 'وقت غير صالح';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('مفعّل'),
                  onChanged: (v) {
                    setState(() => _isActive = v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          final result = _ZoneFormDialogResult(
                            governorate: _governorateCtrl.text.trim(),
                            city: _cityCtrl.text.trim(),
                            area: _areaCtrl.text.trim(),
                            fee: double.parse(_feeCtrl.text.trim()),
                            estimatedMinutes: _etaCtrl.text.trim().isEmpty
                                ? null
                                : int.parse(_etaCtrl.text.trim()),
                            isActive: _isActive,
                          );

                          Navigator.pop(context, result);
                        },
                        child: const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
