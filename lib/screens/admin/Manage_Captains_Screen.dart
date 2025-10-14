import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/models/Profile_model.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/widgets/custom_search_bar.dart';

class ManageCaptainsScreen extends StatefulWidget {
  const ManageCaptainsScreen({super.key});

  @override
  _ManageCaptainsScreenState createState() => _ManageCaptainsScreenState();
}

class _ManageCaptainsScreenState extends State<ManageCaptainsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupabaseProvider>(context, listen: false).fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<SupabaseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الكباتن'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "إضافة كابتن جديد",
            onPressed: _addCaptain,
          ),
        ],
      ),
      body: Column(
        children: [
          AdminSearchBar(
            controller: _searchController,
            hintText: 'بحث عن كابتن',
            onChanged: (value) {
              setState(() {});
            },
          ),
          Expanded(child: _buildCaptainsList(authProvider)),
        ],
      ),
    );
  }

  Widget _buildCaptainsList(SupabaseProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final captains = provider.allUsers
        .where(
          (u) =>
              u.role == UserRole.captain &&
              ((u.fullName?.contains(_searchController.text) ?? false) ||
                  (u.email?.contains(_searchController.text) ?? false) ||
                  (u.phone?.contains(_searchController.text) ?? false)),
        )
        .toList();

    if (captains.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.motorcycle, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا يوجد كباتن', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: captains.length,
      itemBuilder: (context, index) {
        final captain = captains[index];
        return _buildCaptainCard(captain);
      },
    );
  }

  Widget _buildCaptainCard(ProfileModel captain) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: captain.avatarUrl != null
              ? NetworkImage(captain.avatarUrl!)
              : const AssetImage('assets/images/default_avatar.png')
                    as ImageProvider,
        ),
        title: Text(captain.fullName ?? 'بدون اسم'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(captain.email ?? 'بدون بريد'),
            Text(captain.phone ?? 'بدون هاتف'),
            Chip(
              label: const Text(
                "كابتن",
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: AppColors.warning,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editCaptain(captain),
            ),
            IconButton(
              icon: Icon(
                captain.isActive ? Icons.block : Icons.check_circle,
                color: captain.isActive ? Colors.red : Colors.green,
              ),
              onPressed: () => _toggleCaptainStatus(captain),
            ),
          ],
        ),
      ),
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
          return AlertDialog(
            title: const Text('إضافة كابتن جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
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
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: selectedImage != null
                          ? FileImage(selectedImage!)
                          : const AssetImage('assets/images/default_avatar.png')
                                as ImageProvider,
                      child: selectedImage == null
                          ? const Icon(Icons.camera_alt, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                  ),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);

                  // TODO: رفع بيانات الكابتن + الصورة مع AuthProvider
                  // Provider.of<authProvider>(context, listen: false).addCaptain(
                  //   name: _nameController.text,
                  //   email: _emailController.text,
                  //   phone: _phoneController.text,
                  //   password: _passwordController.text,
                  //   imageFile: _selectedImage,
                  // );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم إضافة الكابتن بنجاح")),
                  );
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editCaptain(ProfileModel captain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل بيانات الكابتن'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: captain.fullName,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextFormField(
                initialValue: captain.email,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
              ),
              TextFormField(
                initialValue: captain.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: حفظ التعديلات
            },
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
        title: Text(captain.isActive ? 'تعطيل الكابتن' : 'تفعيل الكابتن'),
        content: Text(
          'هل أنت متأكد من ${captain.isActive ? 'تعطيل' : 'تفعيل'} الكابتن ${captain.fullName ?? 'بدون اسم'}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: تغيير حالة الكابتن
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
