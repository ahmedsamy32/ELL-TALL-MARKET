// screens/admin/manage_banners_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../models/banner_model.dart';
import '../../providers/banner_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../services/banner_service.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Provider.of<BannerProvider>(context, listen: false).fetchBanners(),
    );
  }

  Future<String?> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        return pickedFile.path;
      }
    } catch (e) {
      _showSnackBar('خطأ في اختيار الصورة: $e', isError: true);
    }
    return null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
    final bannerProvider = Provider.of<BannerProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'إدارة البانرات',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF262626),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: bannerProvider.isLoading
                  ? const _LoadingState()
                  : bannerProvider.banners.isEmpty
                  ? const _EmptyState()
                  : _BannersList(
                      bannerProvider: bannerProvider,
                      parentState: this,
                    ),
            ),
            // Side floating add button
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: FloatingActionButton.small(
                  heroTag: 'addBannerSideFab',
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                  tooltip: 'إضافة بانر',
                  onPressed: () =>
                      _showAddBannerDialog(context, bannerProvider),
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBannerDialog(BuildContext context, BannerProvider provider) {
    final titleController = TextEditingController();
    final imageUrlController = TextEditingController();
    String? selectedImagePath;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1890FF,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            color: Color(0xFF1890FF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'إضافة بانر جديد',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF262626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    _buildTextField(
                      controller: titleController,
                      label: 'عنوان البانر',
                      hint: 'أدخل عنوان البانر',
                      required: true,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: imageUrlController,
                      label: 'رابط الصورة',
                      hint: 'أو أدخل رابط الصورة مباشرة',
                      enabled: selectedImagePath == null && !isUploading,
                    ),
                    const SizedBox(height: 16),

                    // Image Picker
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD9D9D9)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : () async {
                                          final imagePath = await _pickImage(
                                            ImageSource.gallery,
                                          );
                                          if (imagePath != null) {
                                            setState(() {
                                              selectedImagePath = imagePath;
                                              imageUrlController.clear();
                                            });
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 18,
                                  ),
                                  label: const Text('اختر صورة من المعرض'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1890FF),
                                    elevation: 0,
                                    side: const BorderSide(
                                      color: Color(0xFFD9D9D9),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              if (selectedImagePath != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: isUploading
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedImagePath = null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Color(0xFFFF4D4F),
                                  ),
                                  tooltip: 'إزالة الصورة المختارة',
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFFFF4D4F,
                                    ).withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Image Preview
                          if (selectedImagePath != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD9D9D9),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(selectedImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],

                          // Upload Progress
                          if (isUploading) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF91D5FF),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1890FF),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'جاري رفع الصورة...',
                                    style: TextStyle(
                                      color: Color(0xFF1890FF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isUploading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(color: Color(0xFF595959)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  final supabaseProvider =
                                      Provider.of<SupabaseProvider>(
                                        context,
                                        listen: false,
                                      );
                                  if (!supabaseProvider.isAdmin) {
                                    _showSnackBar(
                                      'غير مصرح لك بإضافة البانرات. يتطلب صلاحيات المدير',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (titleController.text.trim().isEmpty) {
                                    _showSnackBar(
                                      'يرجى إدخال عنوان البانر',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  String? finalImageUrl;

                                  // إذا تم اختيار صورة من المعرض، ارفعها أولاً
                                  if (selectedImagePath != null) {
                                    setState(() => isUploading = true);
                                    try {
                                      finalImageUrl =
                                          await BannerService.uploadBannerImage(
                                            selectedImagePath!,
                                          );
                                      if (!context.mounted) return;
                                      setState(() => isUploading = false);
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      setState(() => isUploading = false);
                                      _showSnackBar(
                                        'فشل في رفع الصورة: $e',
                                        isError: true,
                                      );
                                      return;
                                    }
                                  } else if (imageUrlController.text
                                      .trim()
                                      .isNotEmpty) {
                                    finalImageUrl = imageUrlController.text
                                        .trim();
                                  } else {
                                    _showSnackBar(
                                      'يرجى اختيار صورة أو إدخال رابط',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (finalImageUrl != null &&
                                      finalImageUrl.isNotEmpty) {
                                    provider.addBanner(
                                      BannerModel(
                                        id: _uuid.v4(),
                                        title: titleController.text.trim(),
                                        imageUrl: finalImageUrl,
                                        displayOrder: 0,
                                        isActive: true,
                                        startDate: DateTime.now(),
                                        createdAt: DateTime.now(),
                                      ),
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                    _showSnackBar('تم إضافة البانر بنجاح');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1890FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('حفظ'),
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

  void _showEditBannerDialog(
    BuildContext context,
    BannerProvider provider,
    BannerModel banner,
  ) {
    final titleController = TextEditingController(text: banner.title);
    final imageUrlController = TextEditingController(text: banner.imageUrl);
    String? selectedImagePath;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF52C41A,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFF52C41A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'تعديل البانر',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF262626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    _buildTextField(
                      controller: titleController,
                      label: 'عنوان البانر',
                      hint: 'أدخل عنوان البانر',
                      required: true,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: imageUrlController,
                      label: 'رابط الصورة',
                      hint: 'أو أدخل رابط الصورة مباشرة',
                      enabled: selectedImagePath == null && !isUploading,
                    ),
                    const SizedBox(height: 16),

                    // Image Picker
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD9D9D9)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : () async {
                                          final imagePath = await _pickImage(
                                            ImageSource.gallery,
                                          );
                                          if (imagePath != null) {
                                            setState(() {
                                              selectedImagePath = imagePath;
                                              imageUrlController.clear();
                                            });
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.photo_library,
                                    size: 18,
                                  ),
                                  label: const Text('تغيير الصورة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1890FF),
                                    elevation: 0,
                                    side: const BorderSide(
                                      color: Color(0xFFD9D9D9),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              if (selectedImagePath != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: isUploading
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedImagePath = null;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Color(0xFFFF4D4F),
                                  ),
                                  tooltip: 'إزالة الصورة المختارة',
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFFFF4D4F,
                                    ).withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Current Image Preview
                          if (selectedImagePath == null) ...[
                            const SizedBox(height: 16),
                            Container(
                              height: 80,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD9D9D9),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  banner.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                        child: Icon(Icons.image_not_supported),
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'الصورة الحالية',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8C8C8C),
                              ),
                            ),
                          ],

                          // New Image Preview
                          if (selectedImagePath != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFD9D9D9),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(selectedImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'الصورة الجديدة',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF52C41A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          // Upload Progress
                          if (isUploading) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF91D5FF),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF1890FF),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'جاري رفع الصورة...',
                                    style: TextStyle(
                                      color: Color(0xFF1890FF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isUploading
                              ? null
                              : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(color: Color(0xFF595959)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  final supabaseProvider =
                                      Provider.of<SupabaseProvider>(
                                        context,
                                        listen: false,
                                      );
                                  if (!supabaseProvider.isAdmin) {
                                    _showSnackBar(
                                      'غير مصرح لك بتعديل البانرات. يتطلب صلاحيات المدير',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  if (titleController.text.trim().isEmpty) {
                                    _showSnackBar(
                                      'يرجى إدخال عنوان البانر',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  String? finalImageUrl = banner.imageUrl;

                                  // إذا تم اختيار صورة جديدة من المعرض، ارفعها أولاً
                                  if (selectedImagePath != null) {
                                    setState(() => isUploading = true);
                                    try {
                                      finalImageUrl =
                                          await BannerService.uploadBannerImage(
                                            selectedImagePath!,
                                          );
                                      if (!context.mounted) return;
                                      setState(() => isUploading = false);
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      setState(() => isUploading = false);
                                      _showSnackBar(
                                        'فشل في رفع الصورة: $e',
                                        isError: true,
                                      );
                                      return;
                                    }
                                  } else if (imageUrlController.text
                                      .trim()
                                      .isNotEmpty) {
                                    finalImageUrl = imageUrlController.text
                                        .trim();
                                  }

                                  if (finalImageUrl != null &&
                                      finalImageUrl.isNotEmpty) {
                                    provider.updateBanner(
                                      BannerModel(
                                        id: banner.id,
                                        title: titleController.text.trim(),
                                        imageUrl: finalImageUrl,
                                        displayOrder: banner.displayOrder,
                                        isActive: banner.isActive,
                                        startDate: banner.startDate,
                                        endDate: banner.endDate,
                                        createdAt: banner.createdAt,
                                        updatedAt: DateTime.now(),
                                      ),
                                    );
                                    Navigator.pop(context);
                                    _showSnackBar('تم تحديث البانر بنجاح');
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF52C41A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('تحديث'),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF262626),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF8C8C8C)),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: const Color(0xFF1890FF), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: const TextStyle(fontSize: 14, color: Color(0xFF262626)),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1890FF)),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل البانرات...',
            style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library,
              size: 48,
              color: Color(0xFFBFBFBF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد بانرات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF262626),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابدأ بإضافة بانر جديد لعرضه في التطبيق',
            style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BannersList extends StatelessWidget {
  const _BannersList({required this.bannerProvider, required this.parentState});

  final BannerProvider bannerProvider;
  final _ManageBannersScreenState parentState;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bannerProvider.banners.length,
      itemBuilder: (context, index) {
        final banner = bannerProvider.banners[index];
        return _BannerCard(
          banner: banner,
          index: index,
          parentState: parentState,
        );
      },
    );
  }
}

class _BannerCard extends StatefulWidget {
  const _BannerCard({
    required this.banner,
    required this.index,
    required this.parentState,
  });

  final BannerModel banner;
  final int index;
  final _ManageBannersScreenState parentState;

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF1890FF).withValues(alpha: 0.3)
                : const Color(0xFFD9D9D9),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF1890FF).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Banner Image
              Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    widget.banner.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Color(0xFFBFBFBF),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Banner Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.banner.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF262626),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.banner.isActive
                            ? const Color(0xFFF6FFED)
                            : const Color(0xFFFFF2F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.banner.isActive
                              ? const Color(0xFFB7EB8F)
                              : const Color(0xFFFFCCC7),
                        ),
                      ),
                      child: Text(
                        widget.banner.isActive ? 'نشط' : 'غير نشط',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.banner.isActive
                              ? const Color(0xFF52C41A)
                              : const Color(0xFFFF4D4F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.edit,
                    color: const Color(0xFF1890FF),
                    tooltip: 'تعديل',
                    onPressed: () {
                      final bannerProvider = Provider.of<BannerProvider>(
                        context,
                        listen: false,
                      );
                      final supabaseProvider = Provider.of<SupabaseProvider>(
                        context,
                        listen: false,
                      );

                      if (!supabaseProvider.isAdmin) {
                        widget.parentState._showSnackBar(
                          'غير مصرح لك بتعديل البانرات. يتطلب صلاحيات المدير',
                          isError: true,
                        );
                        return;
                      }

                      widget.parentState._showEditBannerDialog(
                        context,
                        bannerProvider,
                        widget.banner,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: widget.banner.isActive
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: widget.banner.isActive
                        ? const Color(0xFFFF4D4F)
                        : const Color(0xFF52C41A),
                    tooltip: widget.banner.isActive ? 'إلغاء التفعيل' : 'تفعيل',
                    onPressed: () {
                      final bannerProvider = Provider.of<BannerProvider>(
                        context,
                        listen: false,
                      );
                      final supabaseProvider = Provider.of<SupabaseProvider>(
                        context,
                        listen: false,
                      );

                      if (!supabaseProvider.isAdmin) {
                        widget.parentState._showSnackBar(
                          'غير مصرح لك بتعديل البانرات. يتطلب صلاحيات المدير',
                          isError: true,
                        );
                        return;
                      }

                      bannerProvider.toggleBannerStatus(widget.banner.id);
                      widget.parentState._showSnackBar(
                        widget.banner.isActive
                            ? 'تم إلغاء تفعيل البانر'
                            : 'تم تفعيل البانر',
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.delete,
                    color: const Color(0xFFFF4D4F),
                    tooltip: 'حذف',
                    onPressed: () {
                      final supabaseProvider = Provider.of<SupabaseProvider>(
                        context,
                        listen: false,
                      );

                      if (!supabaseProvider.isAdmin) {
                        widget.parentState._showSnackBar(
                          'غير مصرح لك بحذف البانرات. يتطلب صلاحيات المدير',
                          isError: true,
                        );
                        return;
                      }

                      _showDeleteConfirmation(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Color(0xFFFF4D4F),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'تأكيد الحذف',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF262626),
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف البانر "${widget.banner.title}"؟\n\nلا يمكن التراجع عن هذا الإجراء.',
          style: const TextStyle(color: Color(0xFF595959), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Color(0xFF595959)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final bannerProvider = Provider.of<BannerProvider>(
                context,
                listen: false,
              );
              bannerProvider.deleteBanner(widget.banner.id);
              Navigator.pop(context);
              widget.parentState._showSnackBar('تم حذف البانر بنجاح');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
