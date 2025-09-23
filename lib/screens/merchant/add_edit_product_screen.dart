import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/models/product_model.dart';
import 'package:ell_tall_market/providers/firebase_auth_provider.dart';
import 'package:ell_tall_market/services/product_service.dart';
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
  final _oldPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();

  List<String> _productImages = [];
  final ImagePicker _picker = ImagePicker();
  final ProductService _productService = ProductService();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _initializeForm(widget.product!);
    }
  }

  void _initializeForm(ProductModel product) {
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toString();
    _oldPriceController.text = product.salePrice?.toString() ?? '';
    _stockController.text = product.stockQuantity.toString();
    _categoryController.text = product.categoryId;
    _productImages = [product.imageUrl, ...product.images];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // تحميل الصور
              _buildImageUploadSection(),
              SizedBox(height: 24),

              // معلومات المنتج
              _buildProductForm(),
              SizedBox(height: 24),

              // أزرار الحفظ
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'صور المنتج',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._productImages.map((imageUrl) => _buildImagePreview(imageUrl)),
            _buildAddImageButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview(String imageUrl) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _productImages.remove(imageUrl);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add, size: 30, color: Colors.grey),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // هنا سيتم رفع الصورة إلى السيرفر والحصول على الرابط
        setState(() {
          _productImages.add(image.path);
        });
      }
    } catch (e) {
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
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال اسم المنتج';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        CustomTextField(
          controller: _descriptionController,
          label: 'وصف المنتج',
          maxLines: 4,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال وصف المنتج';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _priceController,
                label: 'السعر (ر.س)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال السعر';
                  }
                  if (double.tryParse(value) == null) {
                    return 'يرجى إدخال سعر صحيح';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _oldPriceController,
                label: 'السعر القديم (ر.س) - اختياري',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _stockController,
                label: 'الكمية المتاحة',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الكمية';
                  }
                  if (int.tryParse(value) == null) {
                    return 'يرجى إدخال رقم صحيح';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                controller: _categoryController,
                label: 'الفئة',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال الفئة';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(text: 'حفظ', onPressed: _saveProduct),
        ),
        SizedBox(width: 16),
        Expanded(
          child: CustomButton(
            text: 'إلغاء',
            backgroundColor: Colors.grey,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate() && _productImages.isNotEmpty) {
      try {
        final authProvider = Provider.of<FirebaseAuthProvider>(context, listen: false);
        final currentUser = authProvider.user;
        // تجهيز بيانات المنتج
        final product = ProductModel(
          id: widget.product?.id ?? '',
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          salePrice: _oldPriceController.text.isNotEmpty ? double.tryParse(_oldPriceController.text.trim()) : null,
          stockQuantity: int.parse(_stockController.text.trim()),
          categoryId: _categoryController.text.trim(),
          storeId: currentUser?.storeId ?? '',
          isAvailable: true,
          images: _productImages,
          createdAt: DateTime.now(),
        );
        if (widget.product == null) {
          await _productService.addProduct(product);
        } else {
          await _productService.updateProduct(product);
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
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ المنتج: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (_productImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إضافة صورة واحدة على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
