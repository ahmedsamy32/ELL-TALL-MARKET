import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/delivery_company_model.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/app_settings_provider.dart';
import 'package:ell_tall_market/models/settings_model.dart';
import 'package:ell_tall_market/utils/app_routes.dart';
import 'package:ell_tall_market/services/delivery_company_service.dart';
import 'package:ell_tall_market/services/delivery_zone_pricing_service.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';

class ManageDeliveryCompanyScreen extends StatefulWidget {
  const ManageDeliveryCompanyScreen({super.key});

  @override
  State<ManageDeliveryCompanyScreen> createState() =>
      _ManageDeliveryCompanyScreenState();
}

class _ManageDeliveryCompanyScreenState
    extends State<ManageDeliveryCompanyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<DeliveryCompanyModel> _companies = [];
  String? _error;

  // Settings State & Controllers
  final _settingsFormKey = GlobalKey<FormState>();
  late AppSettingsModel _currentSettings;

  final _appDeliveryBaseFeeController = TextEditingController();
  final _appDeliveryFeePerKmController = TextEditingController();
  final _appDeliveryMaxDistanceController = TextEditingController();
  final _appDeliveryEstimatedTimeController = TextEditingController();
  final _multiStoreDeliveryFeePerKmController = TextEditingController();
  final _multiStoreDeliveryMinDistanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSettings = AppSettingsModel.empty();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
      Provider.of<AppSettingsProvider>(context, listen: false).loadSettings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appDeliveryBaseFeeController.dispose();
    _appDeliveryFeePerKmController.dispose();
    _appDeliveryMaxDistanceController.dispose();
    _appDeliveryEstimatedTimeController.dispose();
    _multiStoreDeliveryFeePerKmController.dispose();
    _multiStoreDeliveryMinDistanceController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final companies = await DeliveryCompanyService.getAllCompanies();
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load companies', e);
      if (!mounted) return;
      setState(() {
        _error = 'فشل تحميل المكاتب: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<AppSettingsProvider>(context);
    final loadedSettings = settingsProvider.appSettings;

    // Only populate controllers when settings are loaded/changed from database
    if (loadedSettings.id != _currentSettings.id) {
      _currentSettings = loadedSettings;
      _appDeliveryBaseFeeController.text = _currentSettings.appDeliveryBaseFee.toString();
      _appDeliveryFeePerKmController.text = _currentSettings.appDeliveryFeePerKm.toString();
      _appDeliveryMaxDistanceController.text = _currentSettings.appDeliveryMaxDistance.toString();
      _appDeliveryEstimatedTimeController.text = _currentSettings.appDeliveryEstimatedTime.toString();
      _multiStoreDeliveryFeePerKmController.text = _currentSettings.multiStoreDeliveryFeePerKm.toString();
      _multiStoreDeliveryMinDistanceController.text = _currentSettings.multiStoreDeliveryMinDistance.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚚 إدارة مكاتب التوصيل'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: 'المكاتب المسجلة'),
            Tab(icon: Icon(Icons.settings), text: 'إعدادات التوصيل العامة'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              if (_tabController.index == 0) {
                _loadCompanies();
              } else {
                Provider.of<AppSettingsProvider>(context, listen: false).loadSettings();
              }
            },
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddCompanySheet(),
              label: const Text('مكتب جديد'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Companies list
          ResponsiveCenter(
            maxWidth: 1200,
            child: SafeArea(child: _buildBody()),
          ),
          // Tab 2: General settings
          ResponsiveCenter(
            maxWidth: 700,
            child: SafeArea(
              child: settingsProvider.isLoading
                  ? AppShimmer.centeredLines(context)
                  : _buildGeneralSettingsTab(settingsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppShimmer.list(context);
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(_error ?? 'حدث خطأ'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCompanies,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_companies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text('لم يتم إضافة مكاتب توصيل بعد'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddCompanySheet(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مكتب توصيل'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المكاتب المسجلة (${_companies.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _companies.length,
            itemBuilder: (context, index) {
              return _buildCompanyCard(_companies[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(DeliveryCompanyModel company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(Icons.local_shipping, color: AppColors.primary),
        ),
        title: Text(
          company.companyName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📍 ${company.city}${company.governorate != null ? ' - ${company.governorate}' : ''}',
            ),
            if (company.address != null && company.address!.isNotEmpty)
              Text('📬 ${company.address}'),
          ],
        ),
        isThreeLine: company.address != null && company.address!.isNotEmpty,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded),
                  SizedBox(width: 8),
                  Text('تعديل'),
                ],
              ),
              onTap: () => _showEditCompanySheet(company),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () => _showDeleteConfirmation(company),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCompanySheet() {
    final nameController = TextEditingController();
    final nameEnController = TextEditingController();
    final ownerEmailController = TextEditingController();
    final ownerNameController = TextEditingController();
    final ownerPasswordController = TextEditingController();
    final ownerPhoneController = TextEditingController();

    // FocusNodes للتحكم في ترتيب الانتقال
    final nameFocus = FocusNode();
    final nameEnFocus = FocusNode();
    final ownerNameFocus = FocusNode();
    final emailFocus = FocusNode();
    final passwordFocus = FocusNode();
    final phoneFocus = FocusNode();

    String? selectedGovernorate;
    String? selectedCity;
    String? selectedOwnerImagePath;
    bool isSubmitting = false;
    bool obscurePassword = true;
    bool nameError = false;
    bool nameEnError = false;
    bool emailError = false;
    bool passwordError = false;
    bool governorateError = false;
    bool cityError = false;
    final rootMessenger = ScaffoldMessenger.of(context);
    final sheetMessengerKey = GlobalKey<ScaffoldMessengerState>();
    final zonesFuture = DeliveryZonePricingService.getActiveZones();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return ScaffoldMessenger(
            key: sheetMessengerKey,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'مكتب توصيل جديد',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // صورة شخصية
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: selectedOwnerImagePath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(60),
                                        child: Image.file(
                                          File(selectedOwnerImagePath!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                  );
                                  if (image == null) return;
                                  setSheetState(() {
                                    selectedOwnerImagePath = image.path;
                                  });
                                },
                                icon: const Icon(Icons.photo_camera),
                                label: Text(
                                  selectedOwnerImagePath == null
                                      ? 'اختيار صورة شخصية'
                                      : 'تغيير الصورة',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          focusNode: nameFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            nameFocus.unfocus();
                            FocusScope.of(context).requestFocus(nameEnFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم المكتب *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.business),
                            errorText: nameError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameEnController,
                          focusNode: nameEnFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            nameEnFocus.unfocus();
                            FocusScope.of(context).requestFocus(ownerNameFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم المكتب بالإنجليزي *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.abc),
                            errorText: nameEnError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerNameController,
                          focusNode: ownerNameFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            ownerNameFocus.unfocus();
                            FocusScope.of(context).requestFocus(emailFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم صاحب المكتب',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerEmailController,
                          focusNode: emailFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            emailFocus.unfocus();
                            FocusScope.of(context).requestFocus(passwordFocus);
                          },
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني للمكتب *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.email),
                            errorText: emailError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerPasswordController,
                          focusNode: passwordFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            passwordFocus.unfocus();
                            FocusScope.of(context).requestFocus(phoneFocus);
                          },
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                            errorText: passwordError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerPhoneController,
                          focusNode: phoneFocus,
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم التلفون',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // اختيار المنطقة من جدول delivery_zone_pricing
                        FutureBuilder<List<DeliveryZonePricingModel>>(
                          future: zonesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 48,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'حدث خطأ في تحميل المناطق: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'لا توجد مناطق توصيل مسجلة في النظام',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            final zones = snapshot.data!;

                            final usedCities = _companies
                                .where(
                                  (company) => company.city.trim().isNotEmpty,
                                )
                                .map((company) => company.city.trim())
                                .toSet();

                            final governorates =
                                zones
                                    .where((zone) {
                                      final governorate = zone.governorate
                                          .trim();
                                      final city = zone.city?.trim() ?? '';
                                      return governorate.isNotEmpty &&
                                          city.isNotEmpty &&
                                          !usedCities.contains(city);
                                    })
                                    .map((zone) => zone.governorate.trim())
                                    .toSet()
                                    .toList()
                                  ..sort();

                            if (governorates.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'لا توجد محافظات متاحة حالياً. كل المدن مستخدمة بالفعل.',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              );
                            }

                            final cities =
                                selectedGovernorate == null
                                      ? <String>[]
                                      : zones
                                            .where(
                                              (zone) =>
                                                  zone.governorate ==
                                                  selectedGovernorate,
                                            )
                                            .map(
                                              (zone) => zone.city?.trim() ?? '',
                                            )
                                            .where(
                                              (value) =>
                                                  value.isNotEmpty &&
                                                  !usedCities.contains(value),
                                            )
                                            .toSet()
                                            .toList()
                                  ..sort();

                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: selectedGovernorate,
                                  decoration: InputDecoration(
                                    labelText: 'اختر المحافظة *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.map),
                                    errorText: governorateError
                                        ? 'هذا الحقل مطلوب'
                                        : null,
                                  ),
                                  isExpanded: true,
                                  items: governorates
                                      .map(
                                        (governorate) => DropdownMenuItem(
                                          value: governorate,
                                          child: Text(
                                            governorate,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setSheetState(() {
                                      selectedGovernorate = value;
                                      selectedCity = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (selectedGovernorate != null &&
                                    cities.isEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'كل المدن في هذه المحافظة مستخدمة بالفعل. اختر محافظة أخرى.',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCity,
                                  decoration: InputDecoration(
                                    labelText: 'اختر المدينة *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.location_city),
                                    helperText:
                                        'المدن المعروضة تعتمد على المحافظة المختارة',
                                    errorText: cityError
                                        ? 'هذا الحقل مطلوب'
                                        : null,
                                  ),
                                  isExpanded: true,
                                  items: cities
                                      .map(
                                        (city) => DropdownMenuItem(
                                          value: city,
                                          child: Text(
                                            city,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: selectedGovernorate == null
                                      ? null
                                      : (value) {
                                          setSheetState(() {
                                            selectedCity = value;
                                          });
                                        },
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (nameController.text.isEmpty ||
                                            nameEnController.text.isEmpty ||
                                            ownerEmailController.text.isEmpty ||
                                            selectedGovernorate == null ||
                                            selectedCity == null ||
                                            ownerPasswordController
                                                .text
                                                .isEmpty) {
                                          setSheetState(() {
                                            nameError =
                                                nameController.text.isEmpty;
                                            nameEnError =
                                                nameEnController.text.isEmpty;
                                            emailError = ownerEmailController
                                                .text
                                                .isEmpty;
                                            passwordError =
                                                ownerPasswordController
                                                    .text
                                                    .isEmpty;
                                            governorateError =
                                                selectedGovernorate == null;
                                            cityError = selectedCity == null;
                                          });
                                          sheetMessengerKey.currentState
                                              ?.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'الرجاء إدخال اسم المكتب واسمه بالإنجليزي والبريد الإلكتروني وكلمة المرور والمحافظة والمدينة',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                          return;
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                          nameError = false;
                                          nameEnError = false;
                                          emailError = false;
                                          passwordError = false;
                                          governorateError = false;
                                          cityError = false;
                                        });

                                        final provider = context
                                            .read<SupabaseProvider>();
                                        final navigator = Navigator.of(context);
                                        final focusScope = FocusScope.of(
                                          context,
                                        );
                                        final sheetMessenger =
                                            sheetMessengerKey.currentState;

                                        try {
                                          String? deliveryAdminId;
                                          final createUserResult =
                                              await provider.addUser(
                                                fullName:
                                                    ownerNameController.text
                                                        .trim()
                                                        .isEmpty
                                                    ? nameController.text.trim()
                                                    : ownerNameController.text
                                                          .trim(),
                                                email: ownerEmailController.text
                                                    .trim(),
                                                phone: ownerPhoneController.text
                                                    .trim(),
                                                password:
                                                    ownerPasswordController.text
                                                        .trim(),
                                                role: UserRole
                                                    .deliveryCompanyAdmin,
                                              );

                                          if (createUserResult == null) {
                                            setSheetState(() {
                                              isSubmitting = false;
                                            });
                                            sheetMessenger?.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  provider.error ??
                                                      'فشل إنشاء حساب المكتب',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }

                                          deliveryAdminId = createUserResult;

                                          await DeliveryCompanyService.createCompany(
                                            companyName: nameController.text
                                                .trim(),
                                            companyNameEn: nameEnController.text
                                                .trim(),
                                            ownerEmail: ownerEmailController
                                                .text
                                                .trim(),
                                            ownerName:
                                                ownerNameController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : ownerNameController.text
                                                      .trim(),
                                            ownerPhone:
                                                ownerPhoneController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : ownerPhoneController.text
                                                      .trim(),
                                            ownerImagePath:
                                                selectedOwnerImagePath,
                                            city: selectedCity!,
                                            governorate: selectedGovernorate,
                                            address: '',
                                            adminId: deliveryAdminId,
                                          );

                                          if (!mounted) return;
                                          focusScope.unfocus();
                                          navigator.pop();
                                          await _loadCompanies();
                                          if (!mounted) return;
                                          rootMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '✅ تم إضافة المكتب بنجاح',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          setSheetState(() {
                                            isSubmitting = false;
                                          });
                                          sheetMessenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '❌ فشل: ${e.toString()}',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('إضافة'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('إلغاء'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditCompanySheet(DeliveryCompanyModel company) {
    final nameController = TextEditingController(text: company.companyName);
    final nameEnController = TextEditingController(text: company.companyNameEn);
    final ownerEmailController = TextEditingController(
      text: company.ownerEmail,
    );
    final ownerNameController = TextEditingController(text: company.ownerName);
    final ownerPasswordController = TextEditingController();
    final ownerPhoneController = TextEditingController(
      text: company.ownerPhone,
    );

    // FocusNodes للتحكم في ترتيب الانتقال
    final nameFocus = FocusNode();
    final nameEnFocus = FocusNode();
    final ownerNameFocus = FocusNode();
    final emailFocus = FocusNode();
    final passwordFocus = FocusNode();
    final phoneFocus = FocusNode();

    String? selectedGovernorate = company.governorate;
    String? selectedCity = company.city;
    String? selectedOwnerImagePath = company.ownerImagePath;
    bool isSubmitting = false;
    bool obscurePassword = true;
    bool nameError = false;
    bool nameEnError = false;
    bool emailError = false;
    bool passwordError = false;
    bool governorateError = false;
    bool cityError = false;
    final rootMessenger = ScaffoldMessenger.of(context);
    final sheetMessengerKey = GlobalKey<ScaffoldMessengerState>();
    final zonesFuture = DeliveryZonePricingService.getActiveZones();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return ScaffoldMessenger(
            key: sheetMessengerKey,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'تعديل المكتب',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // صورة شخصية
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: selectedOwnerImagePath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(60),
                                        child: Image.file(
                                          File(selectedOwnerImagePath!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                  );
                                  if (image == null) return;
                                  setSheetState(() {
                                    selectedOwnerImagePath = image.path;
                                  });
                                },
                                icon: const Icon(Icons.photo_camera),
                                label: Text(
                                  selectedOwnerImagePath == null
                                      ? 'اختيار صورة شخصية'
                                      : 'تغيير الصورة',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          focusNode: nameFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            nameFocus.unfocus();
                            FocusScope.of(context).requestFocus(nameEnFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم المكتب *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.business),
                            errorText: nameError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameEnController,
                          focusNode: nameEnFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            nameEnFocus.unfocus();
                            FocusScope.of(context).requestFocus(ownerNameFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم المكتب بالإنجليزي *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.abc),
                            errorText: nameEnError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerNameController,
                          focusNode: ownerNameFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            ownerNameFocus.unfocus();
                            FocusScope.of(context).requestFocus(emailFocus);
                          },
                          decoration: InputDecoration(
                            labelText: 'اسم مدير المكتب',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerEmailController,
                          focusNode: emailFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            emailFocus.unfocus();
                            FocusScope.of(context).requestFocus(passwordFocus);
                          },
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني للمكتب *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.email),
                            errorText: emailError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerPasswordController,
                          focusNode: passwordFocus,
                          textInputAction: TextInputAction.next,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          onSubmitted: (_) {
                            passwordFocus.unfocus();
                            FocusScope.of(context).requestFocus(phoneFocus);
                          },
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                            errorText: passwordError ? 'هذا الحقل مطلوب' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ownerPhoneController,
                          focusNode: phoneFocus,
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) {
                            FocusScope.of(context).unfocus();
                          },
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'رقم التلفون',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // اختيار المنطقة من جدول delivery_zone_pricing
                        FutureBuilder<List<DeliveryZonePricingModel>>(
                          future: zonesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 48,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'حدث خطأ في تحميل المناطق: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'لا توجد مناطق توصيل مسجلة في النظام',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            final zones = snapshot.data!;

                            final usedCities = _companies
                                .where(
                                  (existing) =>
                                      existing.id != company.id &&
                                      existing.city.trim().isNotEmpty,
                                )
                                .map((existing) => existing.city.trim())
                                .toSet();

                            final governorates =
                                zones
                                    .where((zone) {
                                      final governorate = zone.governorate
                                          .trim();
                                      final city = zone.city?.trim() ?? '';
                                      return governorate.isNotEmpty &&
                                          city.isNotEmpty &&
                                          !usedCities.contains(city);
                                    })
                                    .map((zone) => zone.governorate.trim())
                                    .toSet()
                                    .toList()
                                  ..sort();

                            if (governorates.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'لا توجد محافظات متاحة حالياً. كل المدن مستخدمة بالفعل.',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              );
                            }

                            final cities =
                                selectedGovernorate == null
                                      ? <String>[]
                                      : zones
                                            .where(
                                              (zone) =>
                                                  zone.governorate ==
                                                  selectedGovernorate,
                                            )
                                            .map(
                                              (zone) => zone.city?.trim() ?? '',
                                            )
                                            .where(
                                              (value) =>
                                                  value.isNotEmpty &&
                                                  !usedCities.contains(value),
                                            )
                                            .toSet()
                                            .toList()
                                  ..sort();

                            if (selectedGovernorate != null &&
                                !governorates.contains(selectedGovernorate)) {
                              selectedGovernorate = governorates.isNotEmpty
                                  ? governorates.first
                                  : null;
                            }

                            if (selectedGovernorate != null &&
                                selectedCity != null &&
                                !cities.contains(selectedCity)) {
                              selectedCity = cities.isNotEmpty
                                  ? cities.first
                                  : null;
                            }

                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: selectedGovernorate,
                                  decoration: InputDecoration(
                                    labelText: 'اختر المحافظة *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.map),
                                    errorText: governorateError
                                        ? 'هذا الحقل مطلوب'
                                        : null,
                                  ),
                                  isExpanded: true,
                                  items: governorates
                                      .map(
                                        (governorate) => DropdownMenuItem(
                                          value: governorate,
                                          child: Text(
                                            governorate,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setSheetState(() {
                                      selectedGovernorate = value;
                                      selectedCity = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (selectedGovernorate != null &&
                                    cities.isEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'كل المدن في هذه المحافظة مستخدمة بالفعل. اختر محافظة أخرى.',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                DropdownButtonFormField<String>(
                                  initialValue: selectedCity,
                                  decoration: InputDecoration(
                                    labelText: 'اختر المدينة *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: const Icon(Icons.location_city),
                                    helperText:
                                        'المدن المعروضة تعتمد على المحافظة المختارة',
                                    errorText: cityError
                                        ? 'هذا الحقل مطلوب'
                                        : null,
                                  ),
                                  isExpanded: true,
                                  items: cities
                                      .map(
                                        (city) => DropdownMenuItem(
                                          value: city,
                                          child: Text(
                                            city,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: selectedGovernorate == null
                                      ? null
                                      : (value) {
                                          setSheetState(() {
                                            selectedCity = value;
                                          });
                                        },
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (nameController.text.isEmpty ||
                                            nameEnController.text.isEmpty ||
                                            ownerEmailController.text.isEmpty ||
                                            selectedGovernorate == null ||
                                            selectedCity == null ||
                                            ownerPasswordController
                                                .text
                                                .isEmpty) {
                                          setSheetState(() {
                                            nameError =
                                                nameController.text.isEmpty;
                                            nameEnError =
                                                nameEnController.text.isEmpty;
                                            emailError = ownerEmailController
                                                .text
                                                .isEmpty;
                                            passwordError =
                                                ownerPasswordController
                                                    .text
                                                    .isEmpty;
                                            governorateError =
                                                selectedGovernorate == null;
                                            cityError = selectedCity == null;
                                          });
                                          sheetMessengerKey.currentState
                                              ?.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'الرجاء إدخال اسم المكتب واسمه بالإنجليزي والبريد الإلكتروني وكلمة المرور والمحافظة والمدينة',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                          return;
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                          nameError = false;
                                          nameEnError = false;
                                          emailError = false;
                                          passwordError = false;
                                          governorateError = false;
                                          cityError = false;
                                        });
                                        final provider = context
                                            .read<SupabaseProvider>();
                                        final navigator = Navigator.of(context);
                                        final focusScope = FocusScope.of(
                                          context,
                                        );
                                        final sheetMessenger =
                                            sheetMessengerKey.currentState;

                                        try {
                                          if (company.adminId != null) {
                                            final updateOk = await provider
                                                .updateUserByAdmin(
                                                  userId: company.adminId!,
                                                  fullName:
                                                      ownerNameController.text
                                                          .trim()
                                                          .isEmpty
                                                      ? nameController.text
                                                            .trim()
                                                      : ownerNameController.text
                                                            .trim(),
                                                  email: ownerEmailController
                                                      .text
                                                      .trim(),
                                                  phone: ownerPhoneController
                                                      .text
                                                      .trim(),
                                                  role: UserRole
                                                      .deliveryCompanyAdmin,
                                                  password:
                                                      ownerPasswordController
                                                          .text
                                                          .trim(),
                                                );

                                            if (!updateOk) {
                                              setSheetState(() {
                                                isSubmitting = false;
                                              });
                                              sheetMessenger?.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error ??
                                                        'فشل تحديث حساب المكتب',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }
                                          }

                                          await DeliveryCompanyService.updateCompany(
                                            companyId: company.id,
                                            companyName: nameController.text
                                                .trim(),
                                            companyNameEn: nameEnController.text
                                                .trim(),
                                            ownerEmail: ownerEmailController
                                                .text
                                                .trim(),
                                            ownerName:
                                                ownerNameController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : ownerNameController.text
                                                      .trim(),
                                            ownerPhone:
                                                ownerPhoneController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : ownerPhoneController.text
                                                      .trim(),
                                            ownerImagePath:
                                                selectedOwnerImagePath,
                                            city: selectedCity!,
                                            governorate: selectedGovernorate,
                                            address: company.address,
                                          );

                                          if (!mounted) return;
                                          focusScope.unfocus();
                                          navigator.pop();
                                          await _loadCompanies();
                                          if (!mounted) return;
                                          rootMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '✅ تم تحديث المكتب بنجاح',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          setSheetState(() {
                                            isSubmitting = false;
                                          });
                                          sheetMessenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '❌ فشل: ${e.toString()}',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('حفظ'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('إلغاء'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(DeliveryCompanyModel company) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المكتب'),
        content: Text('هل أنت متأكد من حذف مكتب "${company.companyName}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final authProvider = context.read<SupabaseProvider>();
              Navigator.pop(context);
              final success = await DeliveryCompanyService.deleteCompany(
                company.id,
              );
              var userDeleted = true;
              if (success &&
                  company.adminId != null &&
                  company.adminId!.isNotEmpty) {
                final deleteResult = await authProvider.deleteUser(
                  company.adminId!,
                );
                userDeleted = deleteResult.success;
              }
              if (success) {
                await _loadCompanies();
              }
              if (!mounted) return;
              if (success && userDeleted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم حذف المكتب بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (success && !userDeleted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ تم حذف المكتب، لكن تعذر حذف حساب البريد'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('❌ فشل حذف المكتب'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsTab(AppSettingsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _settingsFormKey,
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🚚 إعدادات التوصيل العامة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    _buildDeliveryInfoBanner(),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.deliveryZonePricing);
                      },
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('إدارة تسعير المناطق (Owner فقط)'),
                    ),
                    const SizedBox(height: 16),
                    _buildTextFieldSetting(
                      "💰 رسوم التوصيل الأساسية (ج.م)",
                      _appDeliveryBaseFeeController,
                    ),
                    _buildTextFieldSetting(
                      "📏 رسوم لكل كيلومتر (ج.م)",
                      _appDeliveryFeePerKmController,
                    ),
                    _buildTextFieldSetting(
                      "🗺️ أقصى مسافة للتوصيل (كم)",
                      _appDeliveryMaxDistanceController,
                    ),
                    _buildIntFieldSetting(
                      "⏱️ الوقت التقديري للتوصيل (دقيقة)",
                      _appDeliveryEstimatedTimeController,
                    ),
                    const Divider(height: 32),
                    const Text(
                      "🏪 رسوم التوصيل لعدة متاجر",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSwitchSetting(
                      "تفعيل رسوم التوصيل بين المتاجر",
                      _currentSettings.multiStoreDeliveryFeeEnabled,
                      (value) => _updateSetting(multiStoreDeliveryFeeEnabled: value),
                    ),
                    _buildTextFieldSetting(
                      "💰 سعر كيلومتر التوصيل بين المتاجر (ج.م)",
                      _multiStoreDeliveryFeePerKmController,
                    ),
                    _buildTextFieldSetting(
                      "📏 الحد الأدنى للمسافة لتطبيق رسوم المتاجر (كم)",
                      _multiStoreDeliveryMinDistanceController,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'هذه الإعدادات تُطبق عند اختيار التاجر "توصيل التطبيق".\nيتم حساب رسوم التوصيل تلقائياً بناءً على المسافة.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldSetting(
    String title,
    TextEditingController controller, {
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          if (double.tryParse(value) == null) {
            return 'يرجى إدخال رقم صحيح';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildIntFieldSetting(
    String title,
    TextEditingController controller, {
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          if (int.tryParse(value) == null) {
            return 'يرجى إدخال رقم صحيح';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionButtons(AppSettingsProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetSettings,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة تعيين'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _updateSetting({
    double? appDeliveryBaseFee,
    double? appDeliveryFeePerKm,
    double? appDeliveryMaxDistance,
    int? appDeliveryEstimatedTime,
    double? multiStoreDeliveryFeePerKm,
    double? multiStoreDeliveryMinDistance,
    bool? multiStoreDeliveryFeeEnabled,
  }) {
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        appDeliveryBaseFee: appDeliveryBaseFee ?? _currentSettings.appDeliveryBaseFee,
        appDeliveryFeePerKm: appDeliveryFeePerKm ?? _currentSettings.appDeliveryFeePerKm,
        appDeliveryMaxDistance: appDeliveryMaxDistance ?? _currentSettings.appDeliveryMaxDistance,
        appDeliveryEstimatedTime: appDeliveryEstimatedTime ?? _currentSettings.appDeliveryEstimatedTime,
        multiStoreDeliveryFeePerKm: multiStoreDeliveryFeePerKm ?? _currentSettings.multiStoreDeliveryFeePerKm,
        multiStoreDeliveryMinDistance: multiStoreDeliveryMinDistance ?? _currentSettings.multiStoreDeliveryMinDistance,
        multiStoreDeliveryFeeEnabled: multiStoreDeliveryFeeEnabled ?? _currentSettings.multiStoreDeliveryFeeEnabled,
      );
    });
  }

  void _saveSettings() async {
    if (!_settingsFormKey.currentState!.validate()) return;

    final updatedSettings = _currentSettings.copyWith(
      appDeliveryBaseFee: double.tryParse(_appDeliveryBaseFeeController.text) ?? _currentSettings.appDeliveryBaseFee,
      appDeliveryFeePerKm: double.tryParse(_appDeliveryFeePerKmController.text) ?? _currentSettings.appDeliveryFeePerKm,
      appDeliveryMaxDistance: double.tryParse(_appDeliveryMaxDistanceController.text) ?? _currentSettings.appDeliveryMaxDistance,
      appDeliveryEstimatedTime: int.tryParse(_appDeliveryEstimatedTimeController.text) ?? _currentSettings.appDeliveryEstimatedTime,
      multiStoreDeliveryFeePerKm: double.tryParse(_multiStoreDeliveryFeePerKmController.text) ?? _currentSettings.multiStoreDeliveryFeePerKm,
      multiStoreDeliveryMinDistance: double.tryParse(_multiStoreDeliveryMinDistanceController.text) ?? _currentSettings.multiStoreDeliveryMinDistance,
    );

    try {
      await Provider.of<AppSettingsProvider>(
        context,
        listen: false,
      ).updateAppSettings(updatedSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل حفظ الإعدادات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين الإعدادات'),
        content: const Text(
          'هل تريد إعادة تعيين جميع الإعدادات للقيم الافتراضية؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final provider = Provider.of<AppSettingsProvider>(context, listen: false);
                await provider.resetSettings();
                final loaded = provider.appSettings;
                setState(() {
                  _currentSettings = loaded;
                  _appDeliveryBaseFeeController.text = loaded.appDeliveryBaseFee.toString();
                  _appDeliveryFeePerKmController.text = loaded.appDeliveryFeePerKm.toString();
                  _appDeliveryMaxDistanceController.text = loaded.appDeliveryMaxDistance.toString();
                  _appDeliveryEstimatedTimeController.text = loaded.appDeliveryEstimatedTime.toString();
                  _multiStoreDeliveryFeePerKmController.text = loaded.multiStoreDeliveryFeePerKm.toString();
                  _multiStoreDeliveryMinDistanceController.text = loaded.multiStoreDeliveryMinDistance.toString();
                });
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم إعادة التعيين بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ فشل إعادة التعيين: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
