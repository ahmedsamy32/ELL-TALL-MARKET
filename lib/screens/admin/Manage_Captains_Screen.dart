import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/providers/captain_provider.dart';
import 'package:ell_tall_market/models/profile_model.dart';
import 'package:ell_tall_market/services/captain_service.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/utils/ant_design_theme.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';

class ManageCaptainsScreen extends StatefulWidget {
  const ManageCaptainsScreen({super.key});

  @override
  State<ManageCaptainsScreen> createState() => _ManageCaptainsScreenState();
}

class _ManageCaptainsScreenState extends State<ManageCaptainsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDataLoaded) {
        Provider.of<SupabaseProvider>(context, listen: false).fetchAllUsers();
        _isDataLoaded = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseProvider>(
      builder: (context, authProvider, child) {
        return Scaffold(
          backgroundColor: AntColors.fillSecondary,
          appBar: AppBar(
            title: const Text(
              'إدارة الكباتن',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AntColors.text,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: AntColors.text,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.white,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AntColors.primary,
                      AntColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AntBorderRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AntColors.primary.withValues(alpha: 0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  tooltip: "إضافة كابتن جديد",
                  onPressed: _addCaptain,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Search Section with Ant Design styling
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AntBorderRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: AntColors.border, width: 1),
                  ),
                  child: AdminSearchBar(
                    controller: _searchController,
                    hintText: 'البحث عن كابتن...',
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                Expanded(child: _buildCaptainsList(authProvider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaptainsList(SupabaseProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AntColors.primary),
        ),
      );
    }

    final captains = provider.allUsers
        .where(
          (u) =>
              u.role == UserRole.captain &&
              ((u.fullName?.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ) ??
                      false) ||
                  (u.email?.toLowerCase().contains(
                        _searchController.text.toLowerCase(),
                      ) ??
                      false) ||
                  (u.phone?.contains(_searchController.text) ?? false)),
        )
        .toList();

    if (captains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AntColors.textQuaternary.withValues(alpha: 0.1),
                    spreadRadius: 5,
                    blurRadius: 10,
                  ),
                ],
                border: Border.all(color: AntColors.border, width: 1),
              ),
              child: Icon(
                Icons.motorcycle,
                size: 64,
                color: AntColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا يوجد كباتن',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AntColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على الزر + لإضافة كابتن جديد',
              style: TextStyle(fontSize: 14, color: AntColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: captains.length,
      itemBuilder: (context, index) {
        final captain = captains[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildCaptainCard(captain),
        );
      },
    );
  }

  Widget _buildCaptainCard(ProfileModel captain) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        side: BorderSide(color: AntColors.border, width: 1),
      ),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AntBorderRadius.lg),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // صورة الملف الشخصي
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AntColors.textQuaternary.withValues(alpha: 0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: captain.avatarUrl != null
                        ? null
                        : Colors.grey[300],
                    backgroundImage: captain.avatarUrl != null
                        ? NetworkImage(captain.avatarUrl!)
                        : null,
                    child: captain.avatarUrl == null
                        ? Icon(Icons.person, color: Colors.grey[600], size: 30)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // معلومات الكابتن
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              captain.fullName ?? 'بدون اسم',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: captain.isActive
                                  ? AntColors.success.withValues(alpha: 0.1)
                                  : AntColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AntBorderRadius.sm,
                              ),
                              border: Border.all(
                                color: captain.isActive
                                    ? AntColors.success
                                    : AntColors.error,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              captain.isActive ? 'نشط' : 'معطل',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: captain.isActive
                                    ? AntColors.success
                                    : AntColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 16,
                            color: AntColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              captain.email ?? 'بدون بريد',
                              style: TextStyle(
                                fontSize: 14,
                                color: AntColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: AntColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            captain.phone ?? 'بدون هاتف',
                            style: TextStyle(
                              fontSize: 14,
                              color: AntColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // أزرار الإجراءات
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AntColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AntBorderRadius.sm),
                        border: Border.all(
                          color: AntColors.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: AntColors.primary),
                        onPressed: () => _editCaptain(captain),
                        tooltip: 'تعديل',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: captain.isActive
                            ? AntColors.error.withValues(alpha: 0.1)
                            : AntColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AntBorderRadius.sm),
                        border: Border.all(
                          color: captain.isActive
                              ? AntColors.error.withValues(alpha: 0.2)
                              : AntColors.success.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          captain.isActive ? Icons.block : Icons.check_circle,
                          color: captain.isActive
                              ? AntColors.error
                              : AntColors.success,
                        ),
                        onPressed: () => _toggleCaptainStatus(captain),
                        tooltip: captain.isActive ? 'تعطيل' : 'تفعيل',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // شريط الحالة
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AntColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AntBorderRadius.xl),
                border: Border.all(
                  color: AntColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.motorcycle, size: 16, color: AntColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'كابتن توصيل',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AntColors.warning,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AntColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: BorderSide(color: AntColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AntColors.fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }

  void _addCaptain() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AntBorderRadius.lg),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // العنوان
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AntColors.primary,
                              AntColors.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AntBorderRadius.md,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'إضافة كابتن جديد',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AntColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // اختيار الصورة
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedFile = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                        );
                        if (pickedFile != null) {
                          setStateDialog(() {
                            selectedImage = File(pickedFile.path);
                          });
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedImage != null
                              ? Colors.transparent
                              : AntColors.fillSecondary,
                          border: Border.all(color: AntColors.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AntColors.textQuaternary.withValues(
                                alpha: 0.1,
                              ),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: selectedImage != null
                            ? ClipOval(
                                child: Image.file(
                                  selectedImage!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    color: AntColors.textTertiary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'اضغط لإضافة صورة',
                                    style: TextStyle(
                                      color: AntColors.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // حقول الإدخال
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AntColors.fillSecondary,
                      borderRadius: BorderRadius.circular(AntBorderRadius.lg),
                      border: Border.all(color: AntColors.border, width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: nameController,
                          label: 'الاسم الكامل',
                          icon: Icons.person,
                          hint: 'أدخل اسم الكابتن',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: emailController,
                          label: 'البريد الإلكتروني',
                          icon: Icons.email,
                          hint: 'example@email.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: phoneController,
                          label: 'رقم الهاتف',
                          icon: Icons.phone,
                          hint: '+966 50 000 0000',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: passwordController,
                          label: 'كلمة المرور',
                          icon: Icons.lock,
                          hint: 'أدخل كلمة مرور قوية',
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // أزرار الإجراءات
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Text(
                            'إلغاء',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AntColors.primary,
                                AntColors.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AntBorderRadius.md,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              // التحقق من صحة البيانات
                              if (nameController.text.isEmpty ||
                                  emailController.text.isEmpty ||
                                  phoneController.text.isEmpty ||
                                  passwordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'يرجى ملء جميع الحقول المطلوبة',
                                    ),
                                    backgroundColor: AntColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AntBorderRadius.md,
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(context);

                              // الحصول على المزودين قبل عرض مؤشر التحميل
                              final supabaseProvider =
                                  Provider.of<SupabaseProvider>(
                                    context,
                                    listen: false,
                                  );
                              final captainProvider =
                                  Provider.of<CaptainProvider>(
                                    context,
                                    listen: false,
                                  );

                              // عرض مؤشر التحميل
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Container(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AntColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              try {
                                // 1. إنشاء حساب المستخدم والملف الشخصي
                                final newUserId = await supabaseProvider
                                    .addUser(
                                      fullName: nameController.text.trim(),
                                      email: emailController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      password: passwordController.text,
                                      role: UserRole.captain,
                                    );

                                if (newUserId == null) {
                                  if (!context.mounted) return;
                                  Navigator.pop(context); // إغلاق مؤشر التحميل
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'فشل إنشاء حساب الكابتن: ${supabaseProvider.error ?? 'خطأ غير معروف'}',
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  });
                                  return;
                                }

                                // 2. إنشاء سجل الكابتن
                                final captainSuccess = await captainProvider
                                    .addCaptain(
                                      profileId: newUserId,
                                      vehicleType: 'motorcycle',
                                      isActive: true,
                                    );

                                if (!captainSuccess) {
                                  if (context.mounted) {
                                    Navigator.pop(
                                      context,
                                    ); // إغلاق مؤشر التحميل
                                  }
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'فشل إنشاء سجل الكابتن: ${captainProvider.error ?? 'خطأ غير معروف'}',
                                        ),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  });
                                  return;
                                }

                                // 3. رفع الصورة إذا تم اختيارها
                                if (selectedImage != null) {
                                  try {
                                    final imageBytes = await selectedImage!
                                        .readAsBytes();
                                    final fileName =
                                        '${DateTime.now().millisecondsSinceEpoch}.jpg';

                                    await CaptainService.uploadCaptainProfile(
                                      captainId: newUserId,
                                      imageBytes: imageBytes,
                                      fileName: fileName,
                                    );
                                  } catch (e) {
                                    AppLogger.error('فشل رفع صورة الكابتن', e);
                                  }
                                }

                                if (context.mounted) {
                                  Navigator.pop(context); // إغلاق مؤشر التحميل
                                }

                                // إعادة تحميل قائمة الكباتن
                                await supabaseProvider.fetchAllUsers();

                                // عرض رسالة النجاح
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'تم إضافة الكابتن بنجاح ✅',
                                      ),
                                      backgroundColor: AntColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AntBorderRadius.md,
                                        ),
                                      ),
                                    ),
                                  );
                                });
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context); // إغلاق مؤشر التحميل
                                }
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('حدث خطأ: ${e.toString()}'),
                                      backgroundColor: AntColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AntBorderRadius.md,
                                        ),
                                      ),
                                    ),
                                  );
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'إضافة الكابتن',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _editCaptain(ProfileModel captain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        ),
        title: Text(
          'تعديل بيانات الكابتن',
          style: TextStyle(color: AntColors.text, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: captain.fullName,
                decoration: InputDecoration(
                  labelText: 'الاسم',
                  labelStyle: TextStyle(color: AntColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AntBorderRadius.md),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: captain.email,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  labelStyle: TextStyle(color: AntColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AntBorderRadius.md),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: captain.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  labelStyle: TextStyle(color: AntColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AntBorderRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AntColors.textSecondary,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: حفظ التعديلات
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AntColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AntBorderRadius.md),
              ),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _toggleCaptainStatus(ProfileModel captain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.lg),
        ),
        title: Text(
          captain.isActive ? 'تعطيل الكابتن' : 'تفعيل الكابتن',
          style: TextStyle(color: AntColors.text, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'هل أنت متأكد من ${captain.isActive ? 'تعطيل' : 'تفعيل'} الكابتن ${captain.fullName ?? 'بدون اسم'}؟',
          style: TextStyle(color: AntColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AntColors.textSecondary,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: تغيير حالة الكابتن
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: captain.isActive
                  ? AntColors.error
                  : AntColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AntBorderRadius.md),
              ),
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
