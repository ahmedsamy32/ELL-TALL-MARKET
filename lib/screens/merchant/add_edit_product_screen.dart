import 'dart:async';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ell_tall_market/services/permission_service.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/core/logger.dart';
import 'package:ell_tall_market/services/product_service.dart';
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/screens/merchant/merchant_settings_screen.dart';
import 'package:ell_tall_market/services/template_service.dart';
import 'package:ell_tall_market/models/template_model.dart';
import 'package:uuid/uuid.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

/// شاشة إضافة/تعديل المنتجات
/// تحتوي على الحقول الأساسية + الحقول الديناميكية + الصور المتعددة
class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  // ===========================================================================
  // 1. Controllers & Keys
  // ===========================================================================
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  // ===========================================================================
  // 2. Services & Helpers
  // ===========================================================================
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // ===========================================================================
  // 3. State Variables
  // ===========================================================================
  bool _isLoading = true;
  bool _isSaving = false;
  String? _storeId;
  String? _storeCategoryId; // UUID الفئة (يُحفظ مع المنتج فقط)
  String? _selectedSectionId;
  List<Map<String, dynamic>> _storeSections = [];
  bool _existingGalleryLoaded = false;

  // ===========================================================================
  // 4. Image Data
  // ===========================================================================
  String? _imageUrl; // الصورة الأساسية الحالية (رابط)
  XFile? _primaryNewImage; // صورة أساسية جديدة (ملف)
  Uint8List? _primaryNewImageBytes; // بايتات الصورة الأساسية للعرض
  final List<XFile> _pickedImages = []; // صور إضافية جديدة مختارة
  final List<Uint8List> _pickedImagesBytes = []; // بايتات الصور الإضافية للعرض
  List<String> _existingImageUrls = []; // صور إضافية موجودة مسبقاً

  // ===========================================================================
  // 4.1 Specifications (Custom Fields)
  // ===========================================================================
  final List<Map<String, String>> _customFields = [];

  // ===========================================================================
  // 5. Attributes (Variant Groups)
  // ===========================================================================
  bool _attributesTouched = false;
  final List<_AttributeDraft> _attributeDrafts = [];
  Timer? _debounceTimer;
  StreamSubscription<bool>? _keyboardSubscription;

  String _attributeTypeDisplayName(String type) {
    switch (type) {
      case 'color':
        return 'اللون';
      case 'size':
        return 'المقاس';
      case 'material':
        return 'الخامة';
      case 'brand':
        return 'الماركة';
      case 'model':
        return 'الموديل';
      case 'weight':
        return 'الوزن';
      case 'volume':
        return 'السعة/الحجم';
      case 'unit':
        return 'وحدة القياس';
      case 'warranty':
        return 'الضمان';
      case 'flavor':
        return 'النكهة';
      case 'origin':
        return 'بلد المنشأ';
      case 'custom':
        return 'مخصص';
      default:
        return type;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupKeyboardListener();
  }

  void _initializeData() {
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

  void _setupKeyboardListener() {
    _keyboardSubscription = KeyboardVisibilityController().onChange.listen((
      bool visible,
    ) {
      if (!visible && mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _keyboardSubscription?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    for (final draft in _attributeDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  // أضف دالة لتنسيق الأرقام
  String _formatPrice(String value) {
    if (value.isEmpty) return '';
    final number = double.tryParse(value);
    if (number == null) return value;
    return number.toStringAsFixed(2);
  }

  // ===========================================================================
  // 7. Data Loading & Initialization
  // ===========================================================================
  void _initializeForm(ProductModel product) {
    _storeId = product.storeId;
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    _stockController.text = product.stockQuantity.toString();
    _imageUrl = product.imageUrl;
    _selectedSectionId = product.sectionId;

    // احتفظ بالفئة الحالية للمنتج إن وجدت
    _storeCategoryId = product.categoryId;

    // تحميل الصور الإضافية (بدون الصورة الأساسية)
    _existingImageUrls = List<String>.from(
      product.imageUrls ?? const [],
    ).where((u) => u != product.imageUrl).toList();

    // تحميل المواصفات (Custom Fields)
    _customFields.clear();
    if (product.customFields != null) {
      product.customFields!.forEach((key, value) {
        _customFields.add({'key': key, 'value': value.toString()});
      });
    }

    // تحميل الخصائص (Attributes)
    _attributeDrafts.clear();
    if (product.variantGroups != null) {
      for (final group in product.variantGroups!) {
        final draft = _AttributeDraft();
        draft.type = group.type;
        draft.customName = group.type == 'custom' ? group.name : '';
        draft.values = group.options.map((o) => o.value).toList();
        _attributeDrafts.add(draft);
      }
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

        setState(() {
          _storeId = widget.product!.storeId;
          // خزّن UUID الفئة مباشرة من المتجر (بدون تحميل اسم الفئة)
          _storeCategoryId = store?.category ?? widget.product?.categoryId;
          _isLoading = false;
        });

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

      setState(() {
        _storeId = firstStore.id;
        _storeCategoryId = firstStore.category; // UUID الفئة
        _isLoading = false;
      });

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

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إذن مطلوب'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService().openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            // Show duplicate button only in edit mode
            if (widget.product != null)
              IconButton(
                icon: const Icon(Icons.content_copy),
                tooltip: 'نسخ المنتج',
                onPressed: _duplicateProduct,
              ),
          ],
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        body: ResponsiveCenter(
          maxWidth: 700,
          child: _isLoading
              ? _buildShimmerForm()
              : SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildImageSection(),
                        _buildBasicInfoSection(),
                        _buildSectionSelector(),
                        _buildTemplatesSection(),
                        _buildSpecificationsSection(),
                        _buildAttributesSection(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
        ),
        floatingActionButton: _isSaving
            ? AppShimmer.wrap(
                context,
                child: AppShimmer.circle(context, size: 56),
              )
            : FloatingActionButton.extended(
                onPressed: _saveProduct,
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
      ),
    );
  }

  // ===========================================================================
  // 9. UI Sections (Widget Builders)
  // ===========================================================================
  Widget _buildShimmerForm() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad + 24),
      children: [
        _shimmerBox(height: 200, radius: 12),
        const SizedBox(height: 12),
        _shimmerBox(height: 180, radius: 12),
        const SizedBox(height: 12),
        _shimmerBox(height: 160, radius: 12),
        const SizedBox(height: 12),
        _shimmerBox(height: 140, radius: 12),
      ],
    );
  }

  Widget _shimmerBox({
    double width = double.infinity,
    double height = 80,
    double radius = 8,
  }) {
    return AppShimmer.wrap(
      context,
      child: AppShimmer.box(
        context,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(radius),
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
                                  _primaryNewImageBytes = null;
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
    if (_primaryNewImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _primaryNewImageBytes!,
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
                  onPressed: () => _showImageSourceDialog(false),
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
                      imageBytes: _pickedImagesBytes.length > pickedIndex
                          ? _pickedImagesBytes[pickedIndex]
                          : null,
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
    Uint8List? imageBytes,
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
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes,
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
              onTap: () => _showImagePreview(
                imageFile: imageFile,
                imageBytes: imageBytes,
                imageUrl: imageUrl,
              ),
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

  Future<void> _showImageSourceDialog(bool isPrimary) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isPrimary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isPrimary);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, bool isPrimary) async {
    try {
      // التحقق من الأذونات أولاً
      final permissionService = PermissionService();
      final result = await permissionService.requestImagePermissions(
        useCamera: source == ImageSource.camera,
        useGallery: source == ImageSource.gallery,
      );

      if (!result.granted) {
        if (!mounted) return;
        if (result.permanentlyDenied) {
          _showPermissionDialog(result.message ?? 'يجب منح الأذونات المطلوبة');
        } else {
          _showSnackBar(result.message ?? 'تم رفض الإذن', isError: true);
        }
        return;
      }

      if (!isPrimary && source == ImageSource.gallery) {
        await _pickMultipleImages();
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (!mounted || image == null) return;

      final croppedImage = await _cropImage(image);
      if (!mounted || croppedImage == null) return;

      setState(() {
        if (isPrimary) {
          if (_imageUrl != null && _imageUrl!.isNotEmpty) {
            _existingImageUrls.insert(0, _imageUrl!);
            _imageUrl = null;
          } else if (_primaryNewImage != null) {
            _pickedImages.insert(0, _primaryNewImage!);
            if (_primaryNewImageBytes != null) {
              _pickedImagesBytes.insert(0, _primaryNewImageBytes!);
            }
          }
          _primaryNewImage = croppedImage;
          // Read bytes immediately
          croppedImage.readAsBytes().then((bytes) {
            if (mounted) setState(() => _primaryNewImageBytes = bytes);
          });

          // Remove if it was in picked list (handle bytes list sync if needed, but tricky here)
          // Simplified: just remove by path logic, and relying on index might be hard.
          // Better: just handle the primary assignment.
          // Note: The original logic removed from _pickedImages if path matches.
          // We must also remove from _pickedImagesBytes at the same index.
          final index = _pickedImages.indexWhere(
            (f) => f.path == croppedImage.path,
          );
          if (index != -1) {
            _pickedImages.removeAt(index);
            if (index < _pickedImagesBytes.length) {
              _pickedImagesBytes.removeAt(index);
            }
          }
        } else {
          final alreadyInGallery = _pickedImages.any(
            (f) => f.path == croppedImage.path,
          );
          final isPrimaryImage =
              _primaryNewImage != null &&
              croppedImage.path == _primaryNewImage!.path;
          if (!alreadyInGallery && !isPrimaryImage) {
            _pickedImages.add(croppedImage);
            croppedImage.readAsBytes().then((bytes) {
              if (mounted) setState(() => _pickedImagesBytes.add(bytes));
            });
          }
        }
      });

      if (isPrimary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اختيار الصورة الرئيسية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل اختيار الصورة: $e')));
      }
    }
  }

  Future<void> _pickPrimaryImage() async {
    _showImageSourceDialog(true);
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
            final isPrimaryImage =
                _primaryNewImage != null &&
                image.path == _primaryNewImage!.path;
            if (!alreadyInGallery && !isPrimaryImage) {
              _pickedImages.add(image);
              image.readAsBytes().then((bytes) {
                if (mounted) setState(() => _pickedImagesBytes.add(bytes));
              });
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
          // WebUiSettings removed - causes crashes on Android/iOS
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

  void _showImagePreview({
    XFile? imageFile,
    Uint8List? imageBytes,
    String? imageUrl,
  }) {
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
                child: imageBytes != null
                    ? Image.memory(imageBytes)
                    : (imageFile != null
                          ? const SizedBox() // Fallback if bytes not ready
                          : Image.network(
                              imageUrl!,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image,
                                    size: 100,
                                    color: Colors.white,
                                  ),
                            )),
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
      if (index < _pickedImagesBytes.length) {
        _pickedImagesBytes.removeAt(index);
      }
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
        if (_primaryNewImageBytes != null) {
          _pickedImagesBytes.insert(0, _primaryNewImageBytes!);
        }
        _existingImageUrls.removeAt(index);
        _primaryNewImage = null;
        _primaryNewImageBytes = null;
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
        if (_primaryNewImageBytes != null &&
            index < _pickedImagesBytes.length) {
          _pickedImagesBytes[index] = _primaryNewImageBytes!;
        }
      } else {
        _pickedImages.removeAt(index);
        if (index < _pickedImagesBytes.length) {
          _pickedImagesBytes.removeAt(index);
        }
      }

      _primaryNewImage = selectedFile;
      // Ensure we have bytes for the new primary
      if (index < _pickedImagesBytes.length) {
        _primaryNewImageBytes = _pickedImagesBytes[index];
      } else {
        selectedFile.readAsBytes().then((bytes) {
          if (mounted) setState(() => _primaryNewImageBytes = bytes);
        });
      }
    });
  }

  void _clearAllAdditionalImages() {
    setState(() {
      _pickedImages.clear();
      _pickedImagesBytes.clear();
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
              textInputAction: TextInputAction.next,
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'السعر *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'ج.م',
                    ),
                    keyboardType: TextInputType.number,
                    onEditingComplete: () {
                      _priceController.text = _formatPrice(
                        _priceController.text,
                      );
                      FocusScope.of(context).nextFocus();
                    },
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
                    textInputAction: TextInputAction.next,
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
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 9. Specifications Section (Custom Fields)
  // ===========================================================================
  Widget _buildSpecificationsSection() {
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
                const Expanded(
                  child: Text(
                    'المواصفات الفنية (Specifications)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _customFields.add({'key': '', 'value': ''});
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('أضف مواصفة'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'أدخل تفاصيل ثابتة للمنتج (مثل: الخامة، المكونات، الوزن، الضمان). هذه المعلومات تظهر للعميل كجدول.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_customFields.isEmpty)
              Text(
                'لا توجد مواصفات مضافة',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            else
              ...List.generate(_customFields.length, (index) {
                return _buildSpecificationItem(index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificationItem(int index) {
    final field = _customFields[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'مواصفة ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  setState(() {
                    _customFields.removeAt(index);
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: field['key'],
            decoration: const InputDecoration(
              labelText: 'اسم المواصفة',
              hintText: 'مثال: الخامة، الوزن، الضمان',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              field['key'] = value;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: field['value'],
            decoration: const InputDecoration(
              labelText: 'القيمة',
              hintText: 'مثال: قطن 100%، 500 جرام، سنتان',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              field['value'] = value;
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 10. Attributes Section & Methods
  // ===========================================================================
  Widget _buildAttributesSection() {
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
                const Expanded(
                  child: Text(
                    'الخصائص (Attributes)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _attributesTouched = true;
                      _attributeDrafts.add(_AttributeDraft());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'اختر نوع الخاصية ثم اكتب القيم مفصولة بفواصل: مثال (أحمر, أزرق).',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_attributeDrafts.isEmpty)
              Text(
                'لا توجد خصائص مضافة',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              )
            else
              ...List.generate(_attributeDrafts.length, (index) {
                return _buildAttributeItem(index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeItem(int index) {
    final draft = _attributeDrafts[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.type,
                  decoration: const InputDecoration(
                    labelText: 'نوع الخاصية',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'color', child: Text('اللون')),
                    DropdownMenuItem(value: 'size', child: Text('المقاس')),
                    DropdownMenuItem(value: 'material', child: Text('الخامة')),
                    DropdownMenuItem(value: 'brand', child: Text('الماركة')),
                    DropdownMenuItem(value: 'model', child: Text('الموديل')),
                    DropdownMenuItem(value: 'weight', child: Text('الوزن')),
                    DropdownMenuItem(
                      value: 'volume',
                      child: Text('السعة/الحجم'),
                    ),
                    DropdownMenuItem(value: 'unit', child: Text('وحدة القياس')),
                    DropdownMenuItem(value: 'warranty', child: Text('الضمان')),
                    DropdownMenuItem(value: 'flavor', child: Text('النكهة')),
                    DropdownMenuItem(
                      value: 'origin',
                      child: Text('بلد المنشأ'),
                    ),
                    DropdownMenuItem(value: 'custom', child: Text('مخصص')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _attributesTouched = true;
                      draft.type = value;
                      if (draft.type != 'custom') {
                        draft.customName = '';
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _attributesTouched = true;
                    final draft = _attributeDrafts.removeAt(index);
                    draft.dispose();
                  });
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'حذف',
              ),
            ],
          ),
          if (draft.type == 'custom') ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.customName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم الخاصية (مخصص)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tune),
              ),
              onChanged: (value) {
                setState(() {
                  _attributesTouched = true;
                  draft.customName = value;
                });
              },
            ),
          ],
          if (draft.values.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: draft.values.map((value) {
                return Chip(
                  label: Text(value, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    setState(() {
                      _attributesTouched = true;
                      draft.values.remove(value);
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: draft.controller,
            focusNode: draft.focusNode,
            decoration: const InputDecoration(
              labelText: 'إضافة قيم',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.add_circle_outline),
              hintText: 'اكتب القيمة ثم اضغط Enter',
              isDense: true,
            ),
            onChanged: (val) {
              if (val.endsWith(',') || val.endsWith('،')) {
                final clean = val.substring(0, val.length - 1).trim();
                if (clean.isNotEmpty && !draft.values.contains(clean)) {
                  setState(() {
                    _attributesTouched = true;
                    draft.values.add(clean);
                    draft.controller.clear();
                  });
                  draft.focusNode.requestFocus();
                } else {
                  draft.controller.text = clean;
                }
              }
            },
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (val) {
              final clean = val.trim();
              if (clean.isNotEmpty) {
                if (!draft.values.contains(clean)) {
                  setState(() {
                    _attributesTouched = true;
                    draft.values.add(clean);
                    draft.controller.clear();
                  });
                }
                draft.focusNode.requestFocus();
              } else {
                FocusScope.of(context).nextFocus();
              }
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 11. Store Section Selector
  // ===========================================================================
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
                  'القسم/المنيو',
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

  // ===========================================================================
  // 11.5 Template Management
  // ===========================================================================
  Widget _buildTemplatesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showTemplateSelector,
              icon: const Icon(Icons.style),
              label: const Text('استخدام قالب'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveAsTemplate,
              icon: const Icon(Icons.save_as),
              label: const Text('حفظ كقالب'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTemplateSelector() async {
    if (_storeId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'اختر قالب للمنتج',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<TemplateModel>>(
                future: TemplateService.getTemplatesByStore(_storeId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('خطأ: ${snapshot.error}'));
                  }
                  final templates = snapshot.data ?? [];
                  if (templates.isEmpty) {
                    return const Center(child: Text('لا توجد قوالب محفوظة'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.style)),
                        title: Text(template.templateName),
                        subtitle: Text(template.description ?? 'بدون وصف'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('حذف القالب'),
                                content: const Text(
                                  'هل أنت متأكد من حذف هذا القالب؟',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      'حذف',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await TemplateService.deleteTemplate(
                                  template.id,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _showTemplateSelector(); // Re-open
                              } catch (e) {
                                AppLogger.error('فشل حذف القالب', e);
                              }
                            }
                          },
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          _applyTemplate(template);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyTemplate(TemplateModel template) {
    setState(() {
      // 1. Clear existing specs and attributes
      _customFields.clear();
      _attributeDrafts.clear();

      // 2. Load custom fields
      template.customFields.forEach((key, value) {
        _customFields.add({'key': key, 'value': value.toString()});
      });

      // 3. Load variant groups
      for (final groupData in template.variantGroups) {
        final group = ProductVariantGroup.fromJson(
          groupData as Map<String, dynamic>,
        );
        final draft = _AttributeDraft(
          id: group.id,
          customName: group.type == 'custom' ? group.name : '',
          type: group.type,
          values: group.options.map((o) => o.value).toList(),
          isRequired: group.isRequired,
        );
        _attributeDrafts.add(draft);
      }

      // 4. Update category if available
      if (template.categoryId != null && template.categoryId!.isNotEmpty) {
        _storeCategoryId = template.categoryId;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تطبيق قالب: ${template.templateName}')),
    );
  }

  Future<void> _saveAsTemplate() async {
    if (_storeId == null) return;

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حفظ كقالب'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'اسم القالب',
            hintText: 'مثال: ملابس قطنية، أحذية رياضية',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      // Create template from current data
      final template = TemplateModel(
        id: '',
        storeId: _storeId!,
        templateName: name,
        categoryId: _storeCategoryId,
        description: _descriptionController.text,
        customFields: {
          for (var f in _customFields)
            if (f['key'] != null && f['key']!.isNotEmpty)
              f['key']!: f['value'] ?? '',
        },
        variantGroups: _attributeDrafts.map((d) {
          final groupId = d.id;
          final displayName = d.getDisplayName(_attributeTypeDisplayName);
          return {
            'id': groupId,
            'name': displayName,
            'type': d.type,
            'is_required': d.isRequired,
            'options': d.values
                .map(
                  (v) => {
                    'id': _uuid.v4(),
                    'name': displayName,
                    'value': v,
                    'sort_order': 0,
                    'is_active': true,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                )
                .toList(),
            'created_at': DateTime.now().toIso8601String(),
          };
        }).toList(),
      );

      await TemplateService.createTemplate(template);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ القالب بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ القالب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===========================================================================
  // 12. Save Actions (Product Submission)
  // ===========================================================================
  bool _validateForm() {
    final formValid = _formKey.currentState?.validate() ?? false;

    if (!formValid) {
      _showValidationError('يرجى ملء جميع الحقول المطلوبة');
      return false;
    }

    if (_primaryNewImage == null && (_imageUrl == null || _imageUrl!.isEmpty)) {
      _showValidationError('الصورة الرئيسية مطلوبة');
      return false;
    }

    if (_selectedSectionId == null || _selectedSectionId!.isEmpty) {
      _showValidationError('يرجى اختيار قسم للمنتج');
      return false;
    }

    if (_storeId == null) {
      _showValidationError('تعذر تحديد المتجر');
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    HapticFeedback.mediumImpact(); // رد فعل لمسي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Duplicates the current product with confirmation dialog
  Future<void> _duplicateProduct() async {
    if (widget.product == null || _isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_copy, color: Colors.blue),
            SizedBox(width: 8),
            Text('نسخ المنتج'),
          ],
        ),
        content: Text('هل تريد إنشاء نسخة من "${widget.product!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نسخ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final duplicated = await ProductService.duplicateProduct(widget.product!);

      if (duplicated != null && mounted) {
        // Navigate to edit the duplicated product
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditProductScreen(product: duplicated),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('تم نسخ المنتج: ${duplicated.name}')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('فشل نسخ المنتج: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;

    if (!_validateForm()) return;

    // أضف دي بونسنج
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSave();
    });
  }

  Future<void> _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppShimmer.centeredLines(context),
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
        customFields: {
          for (var field in _customFields)
            if (field['key']!.isNotEmpty && field['value']!.isNotEmpty)
              field['key']!: field['value']!,
        },
        isActive: widget.product?.isActive ?? true,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: widget.product != null ? now : null,
      );

      AppLogger.info('Saving product...');
      AppLogger.info('   - Name: ${baseProduct.name}');
      AppLogger.info('   - Price: ${baseProduct.price}');
      AppLogger.info('   - Stock: ${baseProduct.stockQuantity}');
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

      // Save Attributes (Variant Groups) only if the user touched them in this session.
      // This avoids wiping existing variant groups when editing a product.
      if (savedProduct != null && _attributesTouched) {
        final nowForVariants = DateTime.now();
        final groups = <ProductVariantGroup>[];

        for (final draft in _attributeDrafts) {
          final values = draft.values;

          final groupName = draft.type == 'custom'
              ? draft.customName.trim()
              : _attributeTypeDisplayName(draft.type);

          if (groupName.isEmpty || values.isEmpty) continue;

          final options = <ProductVariantOption>[];
          for (var i = 0; i < values.length; i++) {
            options.add(
              ProductVariantOption(
                id: _uuid.v4(),
                name: groupName,
                value: values[i],
                sortOrder: i,
                isActive: true,
                createdAt: nowForVariants,
                updatedAt: null,
              ),
            );
          }

          groups.add(
            ProductVariantGroup(
              id: _uuid.v4(),
              name: groupName,
              type: draft.type,
              options: options,
              isRequired: false,
              sortOrder: groups.length,
              isActive: true,
              createdAt: nowForVariants,
              updatedAt: null,
            ),
          );
        }

        await ProductService.saveProductVariantGroups(savedProduct.id, groups);
        // Correctly attach the new groups to the product object before returning it to the caller
        savedProduct = savedProduct.copyWith(variantGroups: groups);
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

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges()) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('هل تريد الخروج؟'),
          content: const Text(
            'هناك تغييرات غير محفوظة. هل تريد الخروج دون حفظ؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('خروج', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return shouldExit ?? false;
    }
    return true;
  }

  bool _hasUnsavedChanges() {
    if (widget.product == null) {
      return _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _priceController.text.isNotEmpty ||
          _stockController.text.isNotEmpty ||
          _primaryNewImage != null ||
          _pickedImages.isNotEmpty;
    }

    // Check for changes in existing product
    final product = widget.product!;
    final currentDesc = _descriptionController.text.trim();
    final effectiveDesc = currentDesc.isEmpty ? null : currentDesc;

    return product.name != _nameController.text.trim() ||
        product.description != effectiveDesc ||
        product.price.toStringAsFixed(2) !=
            _formatPrice(_priceController.text.trim()) ||
        product.stockQuantity.toString() != _stockController.text.trim() ||
        _primaryNewImage != null ||
        _pickedImages.isNotEmpty ||
        _attributesTouched ||
        product.sectionId != _selectedSectionId;
  }
}

class _AttributeDraft {
  String id;
  String type;
  String customName;
  List<String> values;
  bool isRequired;
  final TextEditingController controller;
  final FocusNode focusNode;

  _AttributeDraft({
    String? id,
    this.type = 'custom',
    this.customName = '',
    List<String>? values,
    this.isRequired = false,
  }) : id = id ?? const Uuid().v4(),
       values = values ?? [],
       controller = TextEditingController(),
       focusNode = FocusNode() {
    if (this.values.isNotEmpty) {
      controller.text = this.values.join(', ');
    }
  }

  // Helper to get name from type
  String getDisplayName(String Function(String) typeToName) {
    return type == 'custom' ? customName : typeToName(type);
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}
