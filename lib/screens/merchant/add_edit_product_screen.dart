import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/merchant_provider.dart';
import 'package:ell_tall_market/providers/supabase_provider.dart';
import 'package:ell_tall_market/services/product_service.dart';
import 'package:ell_tall_market/services/store_service.dart';
import 'package:ell_tall_market/widgets/custom_button.dart';
import 'package:ell_tall_market/widgets/custom_textfield.dart';

class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  _AddEditProductScreenState createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isContextLoading = true;
  bool _isSaving = false;
  String? _contextError;
  String? _storeId;
  String? _imageUrl;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _initializeForm(widget.product!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContext());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _initializeForm(ProductModel product) {
    _nameController.text = product.name;
    _descriptionController.text = product.description ?? '';
    _priceController.text = product.price.toStringAsFixed(2);
    _stockController.text = product.stockQuantity.toString();
    _categoryController.text = product.categoryId ?? '';
    _imageUrl = product.imageUrl;
  }

  Future<void> _loadContext() async {
    if (widget.product != null) {
      setState(() {
        _storeId = widget.product!.storeId;
        _isContextLoading = false;
      });
      return;
    }

    try {
      final authProvider = Provider.of<SupabaseProvider>(
        context,
        listen: false,
      );
      final profile = authProvider.currentUserProfile;

      if (profile == null) {
        setState(() {
          _contextError = 'لم يتم العثور على بيانات المستخدم.';
          _isContextLoading = false;
        });
        return;
      }

      final merchantProvider = Provider.of<MerchantProvider>(
        context,
        listen: false,
      );
      await merchantProvider.fetchMerchantByProfileId(profile.id);
      final merchant = merchantProvider.selectedMerchant;

      if (merchant == null) {
        setState(() {
          _contextError = 'لم يتم العثور على بيانات التاجر.';
          _isContextLoading = false;
        });
        return;
      }

      final stores = await StoreService.getMerchantStores(merchant.id);

      if (!mounted) return;

      if (stores.isEmpty) {
        setState(() {
          _contextError = 'لم يتم العثور على متجر مرتبط بالتاجر.';
          _isContextLoading = false;
        });
        return;
      }

      setState(() {
        _storeId = stores.first.id;
        _isContextLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contextError = 'فشل تحميل بيانات المتجر. يرجى المحاولة لاحقاً.';
        _isContextLoading = false;
      });
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
      ),
      body: _isContextLoading
          ? const Center(child: CircularProgressIndicator())
          : _contextError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _contextError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'إعادة المحاولة',
                      onPressed: () {
                        setState(() {
                          _isContextLoading = true;
                          _contextError = null;
                        });
                        _loadContext();
                      },
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildImageUploadSection(),
                    const SizedBox(height: 24),
                    _buildProductForm(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageUploadSection() {
    final hasImage =
        _pickedImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'صورة المنتج',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            hasImage ? _buildImagePreview() : _buildEmptyImagePlaceholder(),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: Text(hasImage ? 'تغيير الصورة' : 'إضافة صورة'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyImagePlaceholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 40),
    );
  }

  Widget _buildImagePreview() {
    Widget imageWidget;

    if (_pickedImage != null) {
      imageWidget = Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
    } else {
      imageWidget = Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: Colors.redAccent),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 120, height: 120, child: imageWidget),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () => setState(() {
              _pickedImage = null;
              _imageUrl = null;
            }),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _pickedImage = image;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اختيار الصورة بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل الصورة: ${e.toString()}')),
      );
    }
  }

  Widget _buildProductForm() {
    return Column(
      children: [
        CustomTextField(
          controller: _nameController,
          label: 'اسم المنتج',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال اسم المنتج';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _descriptionController,
          label: 'وصف المنتج',
          maxLines: 4,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال وصف المنتج';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _priceController,
                label: 'السعر (ر.س)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال السعر';
                  }
                  if (double.tryParse(value.trim()) == null) {
                    return 'يرجى إدخال سعر صحيح';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _stockController,
                label: 'الكمية المتاحة',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال الكمية';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'يرجى إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _categoryController,
          label: 'معرّف الفئة (اختياري)',
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'حفظ',
            onPressed: _isSaving ? null : _saveProduct,
            isLoading: _isSaving,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomButton(
            text: 'إلغاء',
            backgroundColor: Colors.grey,
            onPressed: _isSaving ? null : () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hasImage =
        _pickedImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

    if (!hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة صورة واحدة على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final storeId = widget.product?.storeId ?? _storeId;

    if (storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حفظ المنتج قبل تحديد المتجر المرتبط به'),
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
      final category = _categoryController.text.trim();
      final now = DateTime.now();

      final initialImageUrl =
          widget.product?.imageUrl ??
          ((_imageUrl != null && _imageUrl!.isNotEmpty) ? _imageUrl : null);

      final baseProduct = ProductModel(
        id: widget.product?.id ?? '',
        storeId: storeId,
        categoryId: category.isEmpty ? null : category,
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        price: price,
        stockQuantity: stock,
        imageUrl: initialImageUrl,
        isActive: widget.product?.isActive ?? true,
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: widget.product != null ? now : null,
      );

      ProductModel? savedProduct;

      if (widget.product == null) {
        if (_pickedImage != null) {
          final Uint8List bytes = await _pickedImage!.readAsBytes();
          final fileName = _pickedImage!.name.isNotEmpty
              ? _pickedImage!.name
              : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

          savedProduct = await ProductService.addProductWithImages(
            product: baseProduct,
            images: [bytes],
            imageNames: [fileName],
          );
        } else {
          savedProduct = await ProductService.addProduct(baseProduct);
        }
      } else {
        String? updatedImageUrl = baseProduct.imageUrl;

        if (_pickedImage != null) {
          final Uint8List bytes = await _pickedImage!.readAsBytes();
          final fileName = _pickedImage!.name.isNotEmpty
              ? _pickedImage!.name
              : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

          final uploadedUrls = await ProductService.uploadProductImages(
            productId: widget.product!.id,
            imagesBytesList: [bytes],
            fileNames: [fileName],
          );

          if (uploadedUrls.isNotEmpty) {
            updatedImageUrl = uploadedUrls.first;
          }
        } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
          updatedImageUrl = _imageUrl;
        } else {
          updatedImageUrl = null;
        }

        final productToUpdate = baseProduct.copyWith(imageUrl: updatedImageUrl);

        savedProduct = await ProductService.updateProduct(productToUpdate);
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
                ? 'تم إضافة المنتج بنجاح'
                : 'تم تحديث المنتج بنجاح',
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
