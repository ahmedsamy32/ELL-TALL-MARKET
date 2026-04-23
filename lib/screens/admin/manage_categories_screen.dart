import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/providers/category_provider.dart';
import 'package:ell_tall_market/models/category_model.dart';
import 'package:ell_tall_market/widgets/app_search_bar.dart';
import 'package:ell_tall_market/services/category_service.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<XFile?> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      return pickedFile;
    } catch (e) {
      _showSnackBar('خطأ في اختيار الصورة: $e', isError: true);
      return null;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفئات'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addCategory,
            tooltip: 'إضافة فئة',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: Column(
          children: [
            AdminSearchBar(
              controller: _searchController,
              hintText: 'ابحث عن فئة',
              onChanged: (_) => setState(() {}),
            ),
            Expanded(child: _buildCategoryList(categoryProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(CategoryProvider provider) {
    if (provider.isLoading) {
      return AppShimmer.list(context);
    }

    if (provider.categories.isEmpty) {
      return Center(
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
                Icons.category_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد فئات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'اضغط + لإضافة فئة جديدة',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final filteredCategories = provider.categories.where((cat) {
      return _searchController.text.isEmpty ||
          cat.name.contains(_searchController.text);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return _buildCategoryCard(category, index);
      },
    );
  }

  Widget _buildCategoryCard(CategoryModel category, int index) {
    final colors = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)],
      [const Color(0xFFfa709a), const Color(0xFFfee140)],
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)],
      [const Color(0xFF30cfd0), const Color(0xFF330867)],
    ];
    final gradient = colors[index % colors.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _editCategory(category),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ── Category image / gradient fallback ──
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: category.hasImage
                          ? null
                          : LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: category.hasImage
                          ? Image.network(
                              category.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: gradient),
                                ),
                                child: const Icon(
                                  Icons.category_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.category_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category.description ?? 'لا يوجد وصف',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildActionBtn(
                    Icons.edit_rounded,
                    gradient[0],
                    () => _editCategory(category),
                  ),
                  const SizedBox(width: 6),
                  _buildActionBtn(
                    Icons.delete_rounded,
                    Colors.red.shade400,
                    () => _deleteCategory(category),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🖼️ Reusable image picker section widget
  // ─────────────────────────────────────────────
  Widget _buildImagePickerSection({
    required Uint8List? imageBytes,
    required String? existingImageUrl,
    required bool isUploading,
    required VoidCallback onPickImage,
    required VoidCallback onClearImage,
  }) {
    final hasExisting = existingImageUrl != null && existingImageUrl.isNotEmpty;
    final hasNew = imageBytes != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'صورة الفئة',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // ── New image preview (picked from gallery) ──
          if (hasNew)
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(imageBytes, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 18,
                  child: GestureDetector(
                    onTap: onClearImage,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'صورة جديدة',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            )
          // ── Existing image (already saved) ──
          else if (hasExisting)
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      existingImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey.shade400,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'الصورة الحالية',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),

          // ── Pick / Change button ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isUploading ? null : onPickImage,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: Text(
                  (hasNew || hasExisting) ? 'تغيير الصورة' : 'اختر صورة',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF667eea),
                  side: const BorderSide(color: Color(0xFF667eea)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // ── Upload progress ──
          if (isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'جاري رفع الصورة...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ➕ Add category
  // ─────────────────────────────────────────────
  void _addCategory() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    XFile? selectedImageFile;
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'إضافة فئة جديدة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم الفئة *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.label_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'الوصف (اختياري)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image picker
                    _buildImagePickerSection(
                      imageBytes: selectedImageBytes,
                      existingImageUrl: null,
                      isUploading: isUploading,
                      onPickImage: () async {
                        final file = await _pickImage();
                        if (file != null) {
                          final bytes = await file.readAsBytes();
                          setDialogState(() {
                            selectedImageFile = file;
                            selectedImageBytes = bytes;
                          });
                        }
                      },
                      onClearImage: () => setDialogState(() {
                        selectedImageFile = null;
                        selectedImageBytes = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isUploading
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      _showSnackBar(
                                        'يرجى إدخال اسم الفئة',
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setDialogState(() => isUploading = true);
                                    try {
                                      final newCat =
                                          await CategoryService.createCategory(
                                            name: name,
                                            description:
                                                descController.text
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : descController.text.trim(),
                                          );
                                      if (newCat != null &&
                                          selectedImageBytes != null) {
                                        await CategoryService.uploadCategoryImage(
                                          categoryId: newCat.id,
                                          imageBytes: selectedImageBytes!,
                                          fileName: selectedImageFile!.name,
                                        );
                                      }
                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                      if (!mounted) return;
                                      await Provider.of<CategoryProvider>(
                                        context,
                                        listen: false,
                                      ).fetchCategories(refresh: true);
                                      _showSnackBar('تم إضافة الفئة بنجاح ✅');
                                    } catch (e) {
                                      if (dialogContext.mounted) {
                                        setDialogState(
                                          () => isUploading = false,
                                        );
                                      }
                                      _showSnackBar(
                                        'فشل في إضافة الفئة: $e',
                                        isError: true,
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('إضافة'),
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
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ✏️ Edit category
  // ─────────────────────────────────────────────
  void _editCategory(CategoryModel category) {
    final nameController = TextEditingController(text: category.name);
    final descController = TextEditingController(
      text: category.description ?? '',
    );
    XFile? selectedImageFile;
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'تعديل الفئة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'اسم الفئة *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.label_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'الوصف (اختياري)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image picker (shows existing image)
                    _buildImagePickerSection(
                      imageBytes: selectedImageBytes,
                      existingImageUrl: category.imageUrl,
                      isUploading: isUploading,
                      onPickImage: () async {
                        final file = await _pickImage();
                        if (file != null) {
                          final bytes = await file.readAsBytes();
                          setDialogState(() {
                            selectedImageFile = file;
                            selectedImageBytes = bytes;
                          });
                        }
                      },
                      onClearImage: () => setDialogState(() {
                        selectedImageFile = null;
                        selectedImageBytes = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isUploading
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      _showSnackBar(
                                        'يرجى إدخال اسم الفئة',
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setDialogState(() => isUploading = true);
                                    try {
                                      // رفع الصورة الجديدة إن وجدت
                                      String? finalImageUrl = category.imageUrl;
                                      if (selectedImageBytes != null) {
                                        finalImageUrl =
                                            await CategoryService.uploadCategoryImage(
                                              categoryId: category.id,
                                              imageBytes: selectedImageBytes!,
                                              fileName: selectedImageFile!.name,
                                            );
                                      }

                                      final updated = category.copyWith(
                                        name: name,
                                        description:
                                            descController.text.trim().isEmpty
                                            ? null
                                            : descController.text.trim(),
                                        imageUrl: finalImageUrl,
                                      );

                                      if (!dialogContext.mounted) return;
                                      Navigator.pop(dialogContext);
                                      if (!mounted) return;
                                      // تحديث الاسم والوصف فقط إذا لم يتم الرفع (لأن uploadCategoryImage يحدث image_url بنفسه)
                                      await Provider.of<CategoryProvider>(
                                        context,
                                        listen: false,
                                      ).updateCategory(updated);
                                      _showSnackBar('تم تحديث الفئة بنجاح ✅');
                                    } catch (e) {
                                      if (dialogContext.mounted) {
                                        setDialogState(
                                          () => isUploading = false,
                                        );
                                      }
                                      _showSnackBar(
                                        'فشل في تحديث الفئة: $e',
                                        isError: true,
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4facfe),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: isUploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('حفظ'),
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
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🗑️ Delete category
  // ─────────────────────────────────────────────
  void _deleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            const Text('حذف الفئة'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف الفئة "${category.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (!mounted) return;
              final success = await Provider.of<CategoryProvider>(
                context,
                listen: false,
              ).deleteCategory(category.id);
              _showSnackBar(
                success ? 'تم حذف الفئة بنجاح' : 'فشل في حذف الفئة',
                isError: !success,
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
