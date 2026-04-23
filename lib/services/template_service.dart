import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logger.dart';
import '../models/template_model.dart';
import '../models/product_model.dart';

/// Service for managing product templates
class TemplateService {
  static final _supabase = Supabase.instance.client;

  // ===== Get Templates =====
  /// Get all templates for a specific store
  static Future<List<TemplateModel>> getTemplatesByStore(String storeId) async {
    try {
      final response = await _supabase
          .from('product_templates')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      final templates = (response as List)
          .map((item) => TemplateModel.fromMap(item as Map<String, dynamic>))
          .toList();

      AppLogger.info('تم تحميل ${templates.length} قالب للمتجر');
      return templates;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحميل القوالب: ${e.message}', e);
      throw Exception('فشل تحميل القوالب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحميل القوالب', e);
      throw Exception('فشل تحميل القوالب: ${e.toString()}');
    }
  }

  // ===== Create Template =====
  /// Create a new template
  static Future<TemplateModel?> createTemplate(TemplateModel template) async {
    try {
      final templateData = template.toMap();
      templateData.remove('id'); // Let database generate ID
      templateData['created_at'] = DateTime.now().toIso8601String();
      templateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('product_templates')
          .insert(templateData)
          .select()
          .single();

      AppLogger.info('تم إنشاء قالب جديد: ${response['template_name']}');
      return TemplateModel.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation
        AppLogger.error('اسم القالب موجود مسبقاً', e);
        throw Exception('اسم القالب موجود مسبقاً. اختر اسماً آخر');
      }
      AppLogger.error('PostgreSQL خطأ في إنشاء القالب: ${e.message}', e);
      throw Exception('فشل إنشاء القالب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في إنشاء القالب', e);
      throw Exception('فشل إنشاء القالب: ${e.toString()}');
    }
  }

  // ===== Update Template =====
  /// Update an existing template
  static Future<TemplateModel?> updateTemplate(TemplateModel template) async {
    try {
      final templateData = template.toMap();
      templateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('product_templates')
          .update(templateData)
          .eq('id', template.id)
          .select()
          .single();

      AppLogger.info('تم تحديث القالب: ${response['template_name']}');
      return TemplateModel.fromMap(response);
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تحديث القالب: ${e.message}', e);
      throw Exception('فشل تحديث القالب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تحديث القالب', e);
      throw Exception('فشل تحديث القالب: ${e.toString()}');
    }
  }

  // ===== Delete Template =====
  /// Delete a template
  static Future<bool> deleteTemplate(String templateId) async {
    try {
      await _supabase.from('product_templates').delete().eq('id', templateId);

      AppLogger.info('تم حذف القالب: $templateId');
      return true;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في حذف القالب: ${e.message}', e);
      throw Exception('فشل حذف القالب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في حذف القالب', e);
      throw Exception('فشل حذف القالب: ${e.toString()}');
    }
  }

  // ===== Apply Template to Product =====
  /// Apply a template to create a base ProductModel with pre-filled specs/attributes
  /// Returns a ProductModel with customFields and variantGroups populated
  static Future<ProductModel> applyTemplate(
    String templateId,
    String storeId,
  ) async {
    try {
      final response = await _supabase
          .from('product_templates')
          .select()
          .eq('id', templateId)
          .single();

      final template = TemplateModel.fromMap(response);

      // Create a base product with template data
      final baseProduct = ProductModel(
        id: '', // Will be generated when saved
        storeId: storeId,
        categoryId: template.categoryId ?? '',
        name: '', // To be filled by merchant
        description: template.description ?? '',
        price: 0.0, // To be filled by merchant
        inStock: true,
        customFields: template.customFields,
        variantGroups: template.variantGroups
            .map((e) => ProductVariantGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.now(),
      );

      AppLogger.info('تم تطبيق القالب: ${template.templateName}');
      return baseProduct;
    } on PostgrestException catch (e) {
      AppLogger.error('PostgreSQL خطأ في تطبيق القالب: ${e.message}', e);
      throw Exception('فشل تطبيق القالب: ${e.message}');
    } catch (e) {
      AppLogger.error('خطأ في تطبيق القالب', e);
      throw Exception('فشل تطبيق القالب: ${e.toString()}');
    }
  }

  // ===== Create Template from Product =====
  /// Create a template from an existing product's specifications
  static Future<TemplateModel?> createTemplateFromProduct({
    required ProductModel product,
    required String templateName,
  }) async {
    try {
      final template = TemplateModel(
        id: '', // Will be generated
        storeId: product.storeId,
        templateName: templateName,
        categoryId: product.categoryId,
        description: product.description,
        customFields: product.customFields,
        variantGroups: product.variantGroups ?? [],
      );

      return await createTemplate(template);
    } catch (e) {
      AppLogger.error('خطأ في إنشاء قالب من منتج', e);
      throw Exception('فشل إنشاء القالب: ${e.toString()}');
    }
  }
}
