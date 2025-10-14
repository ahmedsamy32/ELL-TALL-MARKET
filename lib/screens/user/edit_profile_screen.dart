import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/Profile_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  File? _pickedImage;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<SupabaseProvider>(
      context,
      listen: false,
    ).currentUserProfile!;
    _nameController = TextEditingController(text: user.fullName ?? '');
    _phoneController = TextEditingController(text: user.phone ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );

      // إنشاء نموذج المستخدم المحدث
      final updatedUser = ProfileModel(
        id: authProvider.currentUserProfile!.id,
        fullName: _nameController.text.trim(),
        email: authProvider.currentUserProfile!.email,
        phone: _phoneController.text.trim(),
        avatarUrl:
            _pickedImage?.path ?? authProvider.currentUserProfile!.avatarUrl,
        role: authProvider.currentUserProfile!.role,
        isActive: authProvider.currentUserProfile!.isActive,
        createdAt: authProvider.currentUserProfile!.createdAt,
        updatedAt: DateTime.now(),
      );

      // تحديث البروفايل
      await authProvider.updateProfile(updatedUser);

      // تحديث كلمة المرور إذا تم تعبئتها
      if (_currentPasswordController.text.isNotEmpty ||
          _newPasswordController.text.isNotEmpty ||
          _confirmPasswordController.text.isNotEmpty) {
        // التحقق من تعبئة جميع حقول كلمة المرور
        if (_currentPasswordController.text.isEmpty ||
            _newPasswordController.text.isEmpty ||
            _confirmPasswordController.text.isEmpty) {
          _showErrorSnackBar('يجب تعبئة جميع حقول كلمة المرور');
          setState(() => _isSaving = false);
          return;
        }

        // التحقق من تطابق كلمة المرور الجديدة
        if (_newPasswordController.text != _confirmPasswordController.text) {
          _showErrorSnackBar('كلمة المرور الجديدة وتأكيدها لا تتطابق');
          setState(() => _isSaving = false);
          return;
        }

        // التحقق من قوة كلمة المرور
        if (_newPasswordController.text.length < 6) {
          _showErrorSnackBar('كلمة المرور يجب أن تحتوي على 6 أحرف على الأقل');
          setState(() => _isSaving = false);
          return;
        }

        final passwordResult = await authProvider.updatePasswordWithSupabase(
          _newPasswordController.text,
        );

        if (!passwordResult) {
          _showErrorSnackBar(
            'فشل في تحديث كلمة المرور. تأكد من صحة كلمة المرور الحالية',
          );
          setState(() => _isSaving = false);
          return;
        }

        // مسح حقول كلمة المرور بعد النجاح
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }

      _showSuccessSnackBar('تم حفظ التغييرات بنجاح');
    } catch (e) {
      _showErrorSnackBar('حدث خطأ غير متوقع: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'هل أنت متأكد من أنك تريد حذف الحساب نهائياً؟\n\nسيتم حذف جميع بياناتك ولا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Sign out instead of delete (delete functionality needs to be implemented)
        await authProvider.signOut();
        _showSuccessSnackBar('تم تسجيل الخروج بنجاح');
        // العودة لشاشة تسجيل الدخول
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        _showErrorSnackBar('حدث خطأ: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<SupabaseProvider>(context).currentUserProfile!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // صورة الحساب
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _pickedImage != null
                      ? FileImage(_pickedImage!)
                      : (user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : const AssetImage(
                                    'assets/images/default_avatar.png',
                                  ))
                            as ImageProvider,
                ),
              ),
              const SizedBox(height: 16),

              // الاسم
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (value) =>
                    value!.isEmpty ? 'الرجاء إدخال الاسم' : null,
              ),
              const SizedBox(height: 16),

              // الهاتف
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? 'الرجاء إدخال رقم الهاتف' : null,
              ),
              const SizedBox(height: 24),

              const Divider(thickness: 1),

              const SizedBox(height: 16),
              const Text(
                'تغيير كلمة المرور',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),
              // كلمة المرور الحالية
              TextFormField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              // كلمة المرور الجديدة
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              // تأكيد كلمة المرور
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة',
                ),
                obscureText: true,
              ),

              const SizedBox(height: 32),
              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ التغييرات'),
                ),
              ),

              const SizedBox(height: 24),
              // زر حذف الحساب بعيد عن الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _deleteAccount,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('حذف الحساب نهائيًا'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
