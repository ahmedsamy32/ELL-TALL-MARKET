import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/models/category_field_config.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/services/product_service.dart';
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/services/category_service.dart';
import 'package:ell_tall_market/screens/merchant/merchant_settings_screen.dart';
import 'package:shimmer/shimmer.dart';

/// شاشة إضافة/تعديل المنتجات
/// تحتوي على الحقول الأساسية + الحقول الديناميكية + الصور المتعددة
class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _storeId;
  String? _storeCategoryId; // UUID الفئة
  String? _storeCategoryName; // اسم الفئة (للعرض فقط)
  String? _selectedSectionId;
  List<Map<String, dynamic>> _storeSections = [];
  bool _existingGalleryLoaded = false;

  // الصور
  String? _imageUrl; // الصورة الأساسية
  XFile? _primaryNewImage; // صورة أساسية جديدة
  final List<XFile> _pickedImages = []; // صور إضافية جديدة
  List<String> _existingImageUrls = []; // صور إضافية موجودة

  // الحقول الديناميكية
  Map<String, dynamic> _dynamicFields = {};

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _initializeForm(widget.product!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingGalleryImages(
          storeId: widget.product!.storeId,
          productId: widget.product!.id,
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContext());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _initializeForm(ProductModel product) {
    _storeId = product.storeId;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    _stockController.text = product.stockQuantity.toString();
    _imageUrl = product.imageUrl;
    _selectedSectionId = product.sectionId;

    // تحميل الصور الإضافية (بدون الصورة الأساسية)
    _existingImageUrls = List<String>.from(
      product.imageUrls ?? const [],
    ).where((u) => u != product.imageUrl).toList();

    // تحميل الحقول المخصصة
    if (product.customFields != null && product.customFields!.isNotEmpty) {
      _dynamicFields = Map<String, dynamic>.from(product.customFields!);
      AppLogger.info('✅ [AddProduct] Loaded custom fields: $_dynamicFields');
    }
  }

  Future<void> _loadExistingGalleryImages({
    required String storeId,
    required String productId,
  }) async {
    if (_existingGalleryLoaded) return;
    try {
      final urls = await ProductService.listProductImageUrls(
        storeId: storeId,
        productId: productId,
      );
      if (!mounted) return;

      final primaryUrl = _imageUrl ?? widget.product?.imageUrl;
      final galleryUrls = urls
          .where((url) => primaryUrl == null || url != primaryUrl)
          .toList();

      setState(() {
        _existingImageUrls = galleryUrls;
        _existingGalleryLoaded = true;
      });

      AppLogger.info(
        '🖼️ تم تحميل ${galleryUrls.length} صورة من التخزين للمنتج $productId',
      );
    } catch (e) {
      AppLogger.warning('⚠️ فشل تحميل صور المعرض من التخزين: $e');
    }
  }

  Future<void> _loadContext() async {
    if (widget.product != null) {
      // في حالة التعديل، نحتاج لجلب معلومات المتجر لمعرفة الفئة
      try {
        final store = await StoreService.getStoreById(widget.product!.storeId);
        if (!mounted) return;

        if (store?.category != null) {
          // جلب معلومات الفئة الكاملة
          final category = await CategoryService.getCategoryById(
            store!.category!,
          );
          if (!mounted) return;

          setState(() {
            _storeId = widget.product!.storeId;
            _storeCategoryId = category?.id; // UUID الفئة
            _storeCategoryName = category?.name; // اسم الفئة للعرض
            _isLoading = false;
          });

          AppLogger.info('🏪 Store loaded for editing:');
          AppLogger.info('   Store ID: $_storeId');
          AppLogger.info('   Category ID: $_storeCategoryId');
          AppLogger.info('   Category Name: $_storeCategoryName');
        } else {
          setState(() {
            _storeId = widget.product!.storeId;
            _isLoading = false;
          });
        }

        await _loadStoreSections();
      } catch (e) {
        AppLogger.error('❌ Error loading store/category', e);
        if (mounted) {
          setState(() {
            _storeId = widget.product!.storeId;
            _isLoading = false;
          });
          await _loadStoreSections();
        }
      }
      return;
    }
    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final profile = authProvider.currentUserProfile;

      if (profile == null) {
        _showError('لم يتم العثور على الملف الشخصي');
        return;
      }

      final merchantProvider = Provider.of<MerchantProvider>(
        context,
        listen: false,
      );
      await merchantProvider.fetchMerchantByProfileId(profile.id);
      final merchant = merchantProvider.selectedMerchant;

      if (merchant == null) {
        _showError('لم يتم العثور على بيانات التاجر');
        return;
      }

      final stores = await StoreService.getMerchantStores(merchant.id);

      if (!mounted) return;

      if (stores.isEmpty) {
        _showError('لم يتم العثور على متجر مرتبط بحسابك');
        return;
      }

      final firstStore = stores.first;

      // جلب معلومات الفئة إذا كانت موجودة
      String? categoryId;
      String? categoryName;
      if (firstStore.category != null) {
        try {
          final category = await CategoryService.getCategoryById(
            firstStore.category!,
          );
          if (category != null) {
            categoryId = category.id;
            categoryName = category.name;
          }
        } catch (e) {
          AppLogger.warning('⚠️ Failed to load category: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _storeId = firstStore.id;
        _storeCategoryId = categoryId; // UUID الفئة
        _storeCategoryName = categoryName; // اسم الفئة للعرض
        _isLoading = false;
      });

      AppLogger.info('🏪 Store loaded:');
      AppLogger.info('   Store ID: $_storeId');
      AppLogger.info('   Category ID: $_storeCategoryId');
      AppLogger.info('   Category Name: $_storeCategoryName');

      await _loadStoreSections();
    } catch (e) {
      if (!mounted) return;
      _showError('فشل تحميل بيانات المتجر: ${e.toString()}');
    }
  }

  Future<void> _loadStoreSections() async {
    if (_storeId == null) return;
    try {
      final sections = await StoreService.getStoreSections(_storeId!);
      if (mounted) {
        setState(() {
          // فلترة الأقسام النشطة فقط
          _storeSections = sections
              .where((section) => section['is_active'] == true)
              .toList();
        });
        AppLogger.info(
          '✅ Loaded ${_storeSections.length} active sections (total: ${sections.length})',
        );
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load sections: $e');
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? _buildShimmerForm()
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildImageSection(),
                    _buildBasicInfoSection(),
                    _buildSectionSelector(),
                    _buildCategoryFieldsSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: _isSaving
          ? const CircularProgressIndicator()
          : FloatingActionButton.extended(
              onPressed: _saveProduct,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
    );
  }

  Widget _buildShimmerForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _shimmerBox(height: 200, radius: 12),
          const SizedBox(height: 12),
          _shimmerBox(height: 180, radius: 12),
          const SizedBox(height: 12),
          _shimmerBox(height: 160, radius: 12),
          const SizedBox(height: 12),
          _shimmerBox(height: 140, radius: 12),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 80,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'صور المنتج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_getTotalImagesCount()} صور',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // الصورة الأساسية
            _buildPrimaryImageSection(),
            const SizedBox(height: 12),
            // معرض الصور الإضافية
            _buildImageGallery(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryImageSection() {
    final hasPrimary =
        _primaryNewImage != null ||
        (_imageUrl != null && _imageUrl!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'الصورة الرئيسية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                // زر إضافة صورة رئيسية
                TextButton.icon(
                  onPressed: _pickPrimaryImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 16),
                  label: const Text('اختيار', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 150),
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: hasPrimary
                ? Stack(
                    children: [
                      Center(child: _buildPrimaryImagePreview()),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر المعاينة
                            IconButton(
                              icon: const Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(28, 28),
                              ),
                              onPressed: () => _showImagePreview(
                                imageFile: _primaryNewImage,
                                imageUrl: _imageUrl,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // زر الحذف
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(28, 28),
                              ),
                              onPressed: () {
                                setState(() {
                                  _primaryNewImage = null;
                                  _imageUrl = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اضغط "اختيار" لإضافة صورة *',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryImagePreview() {
    if (_primaryNewImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_primaryNewImage!.path),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 50),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildImageGallery() {
    final totalAdditional = _pickedImages.length + _existingImageUrls.length;

    AppLogger.info(
      '🖼️ بناء معرض الصور: picked=${_pickedImages.length}, existing=${_existingImageUrls.length}, total=$totalAdditional',
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_library, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'صور إضافية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                // زر إضافة صور متعددة
                TextButton.icon(
                  onPressed: _pickMultipleImages,
                  icon: const Icon(Icons.add_photo_alternate, size: 16),
                  label: const Text('إضافة', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (totalAdditional > 0) ...[
                  const SizedBox(width: 4),
                  // زر مسح الصور الإضافية
                  IconButton(
                    onPressed: _clearAllAdditionalImages,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    tooltip: 'مسح الكل',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (totalAdditional == 0)
            Container(
              constraints: const BoxConstraints(minHeight: 80),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: Text(
                'لا توجد صور إضافية',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            )
          else
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: totalAdditional,
                itemBuilder: (context, index) {
                  final isExisting = index < _existingImageUrls.length;

                  if (isExisting) {
                    return _buildImageThumbnail(
                      imageUrl: _existingImageUrls[index],
                      onRemove: () => _removeExistingImage(index),
                      onSetPrimary: () => _setExistingAsPrimary(index),
                    );
                  } else {
                    final pickedIndex = index - _existingImageUrls.length;
                    return _buildImageThumbnail(
                      imageFile: _pickedImages[pickedIndex],
                      onRemove: () => _removePickedImage(pickedIndex),
                      onSetPrimary: () => _setPickedAsPrimary(pickedIndex),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail({
    String? imageUrl,
    XFile? imageFile,
    required VoidCallback onRemove,
    required VoidCallback onSetPrimary,
  }) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 6),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () =>
                _showImagePreview(imageFile: imageFile, imageUrl: imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageFile != null
                  ? Image.file(
                      File(imageFile.path),
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 10),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () =>
                  _showImagePreview(imageFile: imageFile, imageUrl: imageUrl),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 10),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 2,
            right: 2,
            child: ElevatedButton(
              onPressed: onSetPrimary,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 2),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('رئيسية', style: TextStyle(fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalImagesCount() {
    final primaryCount =
        (_primaryNewImage != null ||
            (_imageUrl != null && _imageUrl!.isNotEmpty))
        ? 1
        : 0;
    return primaryCount + _existingImageUrls.length + _pickedImages.length;
  }

  Future<void> _pickPrimaryImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (image == null) return;

      // قص الصورة
      final croppedImage = await _cropImage(image);
      if (!mounted) return;
      if (croppedImage == null) return;

      setState(() {
        // إذا كانت الصورة الأساسية الحالية موجودة، انقلها للمعرض
        if (_imageUrl != null && _imageUrl!.isNotEmpty) {
          _existingImageUrls.insert(0, _imageUrl!);
          _imageUrl = null;
        } else if (_primaryNewImage != null) {
          _pickedImages.insert(0, _primaryNewImage!);
        }

        _primaryNewImage = croppedImage;

        // تأكد من عدم تكرار الصورة في المعرض
        _pickedImages.removeWhere((f) => f.path == croppedImage.path);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اختيار الصورة الرئيسية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل اختيار الصورة: $e')));
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (images.isEmpty || !mounted) return;

      final List<XFile> croppedImages = [];
      int successCount = 0;
      int cancelCount = 0;

      for (final image in images) {
        if (!mounted) break;
        try {
          final cropped = await _cropImage(image);
          if (cropped != null) {
            croppedImages.add(cropped);
            successCount++;
          } else {
            cancelCount++;
          }
        } on MissingPluginException catch (e) {
          AppLogger.warning(
            '⚠️ MissingPluginException: القص غير متاح على هذه المنصة: $e',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'القص غير متاح على هذا الجهاز، سيتم استخدام الصور الأصلية',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          croppedImages.addAll(images);
          break;
        } catch (e) {
          AppLogger.error('❌ خطأ في قص الصورة', e);
          cancelCount++;
        }
      }

      if (!mounted) return;

      if (croppedImages.isNotEmpty) {
        setState(() {
          // أضف كل صورة جديدة مباشرة إلى القائمة
          for (final image in croppedImages) {
            final alreadyInGallery = _pickedImages.any(
              (f) => f.path == image.path,
            );
            final isPrimary =
                _primaryNewImage != null &&
                image.path == _primaryNewImage!.path;
            if (!alreadyInGallery && !isPrimary) {
              _pickedImages.add(image);
              AppLogger.info(
                '✅ تم إضافة صورة: ${image.name}, العدد الكلي: ${_pickedImages.length}',
              );
            } else {
              AppLogger.info('⚠️ تم تخطي صورة مكررة أو رئيسية: ${image.name}');
            }
          }
        });

        AppLogger.info(
          '📊 إجمالي الصور الإضافية الآن: ${_pickedImages.length}',
        );

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إضافة $successCount صورة بنجاح${cancelCount > 0 ? " (تم إلغاء $cancelCount)" : ""}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (cancelCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء جميع عمليات القص'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل الصور: $e')));
      }
    }
  }

  /// قص الصورة باستخدام ImageCropper
  Future<XFile?> _cropImage(XFile imageFile) async {
    try {
      // احفظ الألوان قبل أي async gap
      final primaryColor = Theme.of(context).colorScheme.primary;
      final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

      final cropper = ImageCropper();
      final cropped = await cropper.cropImage(
        sourcePath: imageFile.path,
        compressQuality: 85,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'قص الصورة',
            toolbarColor: primaryColor,
            toolbarWidgetColor: onPrimaryColor,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'قص الصورة',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          WebUiSettings(context: context),
        ],
      );

      if (!mounted) return null;

      // إذا ألغى المستخدم القص
      if (cropped == null) {
        AppLogger.warning('تم إلغاء القص');
        return null;
      }

      // إرجاع الصورة المقصوصة
      return XFile(cropped.path);
    } on MissingPluginException {
      // إعادة رمي الاستثناء ليتم التعامل معه في الدالة المستدعية
      rethrow;
    } catch (e) {
      AppLogger.error('خطأ في قص الصورة', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل قص الصورة: $e')));
      }
      return null;
    }
  }

  void _showImagePreview({XFile? imageFile, String? imageUrl}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: imageFile != null
                    ? Image.file(File(imageFile.path))
                    : Image.network(
                        imageUrl!,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image,
                              size: 100,
                              color: Colors.white,
                            ),
                      ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removePickedImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  void _setExistingAsPrimary(int index) {
    setState(() {
      final selectedUrl = _existingImageUrls[index];

      // انقل الصورة الأساسية الحالية للمعرض
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        _existingImageUrls[index] = _imageUrl!;
      } else if (_primaryNewImage != null) {
        _pickedImages.insert(0, _primaryNewImage!);
        _existingImageUrls.removeAt(index);
        _primaryNewImage = null;
      } else {
        _existingImageUrls.removeAt(index);
      }

      _imageUrl = selectedUrl;
    });
  }

  void _setPickedAsPrimary(int index) {
    setState(() {
      final selectedFile = _pickedImages[index];

      // انقل الصورة الأساسية الحالية للمعرض
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        _existingImageUrls.insert(0, _imageUrl!);
        _imageUrl = null;
      } else if (_primaryNewImage != null) {
        _pickedImages[index] = _primaryNewImage!;
      } else {
        _pickedImages.removeAt(index);
      }

      _primaryNewImage = selectedFile;
    });
  }

  void _clearAllAdditionalImages() {
    setState(() {
      _pickedImages.clear();
      _existingImageUrls.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم مسح جميع الصور الإضافية'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعلومات الأساسية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم المنتج';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'السعر *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'ج.م',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (double.tryParse(value) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'الكمية *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (int.tryParse(value) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'القسم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_storeSections.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'لا توجد أقسام نشطة. يرجى إنشاء قسم نشط أولاً من إعدادات المتجر.',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _goToManageSections,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('إضافة قسم الآن'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedSectionId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                  hintText: 'اختر قسم',
                ),
                items: _storeSections.map((section) {
                  return DropdownMenuItem<String>(
                    value: section['id'] as String,
                    child: Text(section['name'] as String),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى اختيار قسم للمنتج';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedSectionId = value;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// يفتح إعدادات التاجر لإدارة الأقسام ثم يعيد تحميل الأقسام بعد الرجوع
  Future<void> _goToManageSections() async {
    try {
      // افتح شاشة إعدادات التاجر مباشرة (ليست مسجلة كمسار مُسمى)
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MerchantSettingsScreen(scrollToSections: true),
        ),
      );
      // عند العودة من إعدادات التاجر، أعد تحميل الأقسام للتحقق من التغييرات
      await _loadStoreSections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر فتح إعدادات التاجر'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCategoryFieldsSection() {
    AppLogger.info('🔍 _buildCategoryFieldsSection called');
    AppLogger.info('   _storeCategoryId: $_storeCategoryId');
    AppLogger.info('   _storeCategoryName: $_storeCategoryName');

    if (_storeCategoryId == null || _storeCategoryId!.isEmpty) {
      AppLogger.info('   ❌ No category ID, returning empty widget');
      return const SizedBox.shrink();
    }

    // استخدم ID الفئة للبحث
    final config = CategoryFieldConfig.getConfigForCategoryId(
      _storeCategoryId!,
    );

    AppLogger.info('   Config found: ${config != null}');
    AppLogger.info('   Fields count: ${config?.fields.length ?? 0}');

    if (config == null || config.fields.isEmpty) {
      AppLogger.info(
        '   ❌ No config or empty fields for category ID: $_storeCategoryId',
      );
      return const SizedBox.shrink();
    }

    AppLogger.info('   ✅ Showing category fields section');
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حقول خاصة بـ ${config.categoryName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'حقول إضافية بناءً على نوع النشاط التجاري',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...config.fields.map((field) => _buildDynamicField(field)),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicField(DynamicField field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (field.isRequired)
                const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          _buildFieldInput(field),
        ],
      ),
    );
  }

  Widget _buildFieldInput(DynamicField field) {
    switch (field.type) {
      case FieldType.singleChoice:
        return _buildSingleChoiceField(field);
      case FieldType.multipleChoice:
        return _buildMultipleChoiceField(field);
      case FieldType.text:
        return _buildTextField(field);
      case FieldType.number:
        return _buildNumberField(field);
    }
  }

  Widget _buildSingleChoiceField(DynamicField field) {
    final selectedValue = _dynamicFields[field.id] as String?;

    return Column(
      children: field.options.map((option) {
        return RadioListTile<String>(
          title: Text(option.label),
          value: option.id,
          // ignore: deprecated_member_use
          groupValue: selectedValue,
          // ignore: deprecated_member_use
          onChanged: (value) {
            setState(() {
              _dynamicFields[field.id] = value;
            });
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildMultipleChoiceField(DynamicField field) {
    final selectedValues =
        (_dynamicFields[field.id] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // إذا كان الحقل خاص بالمقاسات، اعرضها في Grid بـ 3 أعمدة
    if (field.id == 'sizes') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: field.options.map((option) {
          final isSelected = selectedValues.contains(option.id);
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 80) / 3,
            child: FilterChip(
              label: Text(
                option.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (checked) {
                setState(() {
                  if (checked) {
                    selectedValues.add(option.id);
                    _dynamicFields[field.id] = selectedValues;
                  } else {
                    selectedValues.remove(option.id);
                    _dynamicFields[field.id] = selectedValues.isEmpty
                        ? null
                        : selectedValues;
                  }
                });
              },
              checkmarkColor: Colors.white,
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.grey[200],
            ),
          );
        }).toList(),
      );
    }

    // للحقول الأخرى، استخدم CheckboxListTile العادي
    return Column(
      children: field.options.map((option) {
        final isSelected = selectedValues.contains(option.id);
        return CheckboxListTile(
          title: Text(option.label),
          value: isSelected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                selectedValues.add(option.id);
                _dynamicFields[field.id] = selectedValues;
              } else {
                selectedValues.remove(option.id);
                _dynamicFields[field.id] = selectedValues.isEmpty
                    ? null
                    : selectedValues;
              }
            });
          },
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildTextField(DynamicField field) {
    final initialValue = _dynamicFields[field.id]?.toString() ?? '';
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        hintText: field.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        setState(() {
          _dynamicFields[field.id] = value.isEmpty ? null : value;
        });
      },
      validator: field.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildNumberField(DynamicField field) {
    final initialValue = _dynamicFields[field.id]?.toString() ?? '';
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        hintText: field.label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        setState(() {
          final number = double.tryParse(value);
          _dynamicFields[field.id] = number;
        });
      },
      validator: field.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              if (double.tryParse(value) == null) {
                return 'يرجى إدخال رقم صحيح';
              }
              return null;
            }
          : null,
    );
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // التحقق من وجود الصورة الرئيسية (مطلوبة)
    final hasPrimaryImage =
        _primaryNewImage != null ||
        (_imageUrl != null && _imageUrl!.isNotEmpty);

    if (!hasPrimaryImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الصورة الرئيسية مطلوبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حفظ المنتج قبل تحديد المتجر'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final price = double.parse(_priceController.text.trim());
      final stock = int.parse(_stockController.text.trim());
      final description = _descriptionController.text.trim();
      final now = DateTime.now();

      final baseProduct = ProductModel(
        id: widget.product?.id ?? '',
        storeId: _storeId!,
        categoryId: widget.product?.categoryId ?? _storeCategoryId,
        sectionId: _selectedSectionId,
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        price: price,
        stockQuantity: stock,
        imageUrl: widget.product?.imageUrl ?? _imageUrl,
        customFields: _dynamicFields.isNotEmpty ? _dynamicFields : null,
        isActive: widget.product?.isActive ?? true,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: widget.product != null ? now : null,
      );

      AppLogger.info('Saving product...');
      AppLogger.info('   - Name: ${baseProduct.name}');
      AppLogger.info('   - Price: ${baseProduct.price}');
      AppLogger.info('   - Stock: ${baseProduct.stockQuantity}');
      AppLogger.info('   - Custom Fields: ${baseProduct.customFields}');
      AppLogger.info('   - Primary new: ${_primaryNewImage != null}');
      AppLogger.info('   - Additional picked: ${_pickedImages.length}');
      AppLogger.info('   - Additional existing: ${_existingImageUrls.length}');

      ProductModel? savedProduct;

      if (widget.product == null) {
        // إضافة منتج جديد
        final List<XFile> allImages = [];

        // إضافة الصورة الأساسية أولاً
        if (_primaryNewImage != null) {
          allImages.add(_primaryNewImage!);
        }

        // ثم إضافة باقي الصور
        allImages.addAll(_pickedImages);

        if (allImages.isNotEmpty) {
          final List<Uint8List> imagesBytes = [];
          final List<String> imageNames = [];

          for (final xfile in allImages) {
            imagesBytes.add(await xfile.readAsBytes());
            imageNames.add(
              xfile.name.isNotEmpty
                  ? xfile.name
                  : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
          }

          savedProduct = await ProductService.addProductWithImages(
            product: baseProduct,
            images: imagesBytes,
            imageNames: imageNames,
          );
        } else {
          savedProduct = await ProductService.addProduct(baseProduct);
        }

        AppLogger.info('✅ Product created with ID: ${savedProduct?.id}');
      } else {
        // تحديث منتج موجود
        String? updatedImageUrl = baseProduct.imageUrl;
        final List<String> newUploadedUrls = [];

        // رفع الصور الجديدة
        final List<XFile> allNewImages = [];

        if (_primaryNewImage != null) {
          allNewImages.add(_primaryNewImage!);
        }
        allNewImages.addAll(_pickedImages);

        if (allNewImages.isNotEmpty) {
          final List<Uint8List> imagesBytes = [];
          final List<String> imageNames = [];

          for (final xfile in allNewImages) {
            imagesBytes.add(await xfile.readAsBytes());
            imageNames.add(
              xfile.name.isNotEmpty
                  ? xfile.name
                  : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
          }

          final uploaded = await ProductService.uploadProductImages(
            storeId: _storeId!,
            productId: widget.product!.id,
            imagesBytesList: imagesBytes,
            fileNames: imageNames,
          );

          if (uploaded.isNotEmpty) {
            updatedImageUrl = uploaded.first; // الأولى هي الصورة الأساسية
            newUploadedUrls.addAll(uploaded);
          }
        } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
          updatedImageUrl = _imageUrl;
        } else if (_existingImageUrls.isNotEmpty) {
          updatedImageUrl = _existingImageUrls.first;
        }

        // مزامنة التخزين: حذف الصور التي لم تعد ضمن القائمة النهائية
        final finalUrls = <String>[
          if (updatedImageUrl != null) updatedImageUrl,
          ..._existingImageUrls,
          ...newUploadedUrls,
        ];

        // حدّث المنتج مع جميع الصور
        final productToUpdate = baseProduct.copyWith(
          imageUrl: updatedImageUrl,
          imageUrls: finalUrls, // احفظ جميع الصور في imageUrls
        );
        savedProduct = await ProductService.updateProduct(productToUpdate);

        await ProductService.removeProductImagesNotInUrls(
          storeId: _storeId!,
          productId: widget.product!.id,
          finalUrls: finalUrls,
        );

        AppLogger.info('✅ Product updated with ID: ${savedProduct?.id}');
      }

      if (!mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      if (savedProduct == null) {
        throw Exception('تعذر حفظ المنتج');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.product == null
                ? 'تم إضافة المنتج بنجاح ✅'
                : 'تم تحديث المنتج بنجاح ✅',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(savedProduct);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ المنتج: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
