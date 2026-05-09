import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/models/delivery_company_model.dart';
import 'package:ell_tall_market/models/delivery_zone_pricing_model.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
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
    extends State<ManageDeliveryCompanyScreen> {
  bool _isLoading = true;
  List<DeliveryCompanyModel> _companies = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanies();
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚚 إدارة مكاتب التوصيل'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadCompanies,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCompanySheet(),
        label: const Text('مكتب جديد'),
        icon: const Icon(Icons.add),
      ),
      body: ResponsiveCenter(
        maxWidth: 1200,
        child: SafeArea(child: _buildBody()),
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
    final ownerEmailController = TextEditingController();
    final ownerNameController = TextEditingController();
    final ownerPasswordController = TextEditingController();
    final ownerPhoneController = TextEditingController();

    // FocusNodes للتحكم في ترتيب الانتقال
    final nameFocus = FocusNode();
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
                            FocusScope.of(context).requestFocus(ownerNameFocus);
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
                                            ownerEmailController.text.isEmpty ||
                                            selectedGovernorate == null ||
                                            selectedCity == null ||
                                            ownerPasswordController
                                                .text
                                                .isEmpty) {
                                          setSheetState(() {
                                            nameError =
                                                nameController.text.isEmpty;
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
                                                    'الرجاء إدخال الاسم والبريد الإلكتروني وكلمة المرور والمحافظة والمدينة',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                          return;
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                          nameError = false;
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
                            FocusScope.of(context).requestFocus(ownerNameFocus);
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
                                            ownerEmailController.text.isEmpty ||
                                            selectedGovernorate == null ||
                                            selectedCity == null ||
                                            ownerPasswordController
                                                .text
                                                .isEmpty) {
                                          setSheetState(() {
                                            nameError =
                                                nameController.text.isEmpty;
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
                                                    'الرجاء إدخال الاسم والبريد الإلكتروني وكلمة المرور والمحافظة والمدينة',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                          return;
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                          nameError = false;
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
}
