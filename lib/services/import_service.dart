// Removed dart:io for Web compatibility
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../core/logger.dart';


class ImportRow {
  final int index;
  final Map<String, dynamic> data;
  final List<String> errors;
  final List<String> warnings;

  ImportRow({
    required this.index,
    required this.data,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get isValid => errors.isEmpty;
}

class ImportService {
  static const _uuid = Uuid();

  /// Parses an Excel file bytes and returns a list of rows as maps.
  static Future<List<Map<String, dynamic>>> parseExcelFile(
    Uint8List bytes,
  ) async {
    try {
      // final bytes = await file.readAsBytes(); // Removed file read
      final excel = Excel.decodeBytes(bytes);
      final rows = <Map<String, dynamic>>[];

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        if (sheet.maxRows <= 1) continue;

        final headerRow = sheet.rows.isNotEmpty ? sheet.rows[0] : <Data?>[];
        final headers = <String>[];

        // Determine max columns by checking header length and longest row
        var maxCols = headerRow.length;
        for (final r in sheet.rows) {
          if (r.length > maxCols) maxCols = r.length;
        }
        for (var c = 0; c < maxCols; c++) {
          final cell = c < headerRow.length ? headerRow[c] : null;
          final h = cell?.value?.toString().trim() ?? '';
          headers.add(h);
        }

        AppLogger.info(
          'Found sheet "$table" with headers: ${headers.join(', ')}',
        );

        for (var i = 1; i < sheet.maxRows; i++) {
          final rowData = i < sheet.rows.length ? sheet.rows[i] : <Data?>[];
          final rowMap = <String, dynamic>{};
          for (var j = 0; j < headers.length; j++) {
            final headerName = headers[j];
            if (headerName.isEmpty) continue;

            final cellValue = j < rowData.length ? rowData[j]?.value : null;
            rowMap[headerName] = cellValue;
          }
          rows.add(rowMap);
        }
      }
      return rows;
    } catch (e) {
      AppLogger.error('فشل تحليل ملف Excel', e);
      throw Exception('فشل تحليل ملف Excel: $e');
    }
  }

  /// Maps raw row data to ProductModel fields and validates them.
  static ImportRow validateAndMap(
    Map<String, dynamic> rawData,
    int rowIndex,
    Map<String, String> columnMapping,
  ) {
    final errors = <String>[];
    final warnings = <String>[];
    final mappedData = <String, dynamic>{};

    // Helper to get value from raw data using mapping
    dynamic getValue(String field) {
      final columnName = columnMapping[field];
      if (columnName == null) return null;
      return rawData[columnName];
    }

    // Required Fields Validation
    final name = getValue('name')?.toString().trim();
    if (name == null || name.isEmpty) {
      errors.add('اسم المنتج مطلوب');
    } else {
      mappedData['name'] = name;
    }

    final priceStr = getValue('price')?.toString().trim();
    if (priceStr == null || priceStr.isEmpty) {
      errors.add('السعر مطلوب');
    } else {
      final price = double.tryParse(priceStr);
      if (price == null) {
        errors.add('تنسيق السعر غير صحيح: $priceStr');
      } else {
        mappedData['price'] = price;
      }
    }

    // Optional Fields
    mappedData['description'] = getValue('description')?.toString().trim();

    final stockStr = getValue('stock_quantity')?.toString().trim();
    if (stockStr != null && stockStr.isNotEmpty) {
      final stock = int.tryParse(stockStr);
      if (stock == null) {
        warnings.add('تنسيق الكمية غير صحيح، سيتم تعيينها كـ 0');
        mappedData['stock_quantity'] = 0;
      } else {
        mappedData['stock_quantity'] = stock;
      }
    } else {
      mappedData['stock_quantity'] = 0;
    }

    // Extract section name
    mappedData['section_name'] = getValue('section_name')?.toString().trim();

    // Custom Fields (Specifications)
    final customFields = <String, String>{};
    
    // Parse from single custom_fields column (e.g. "الخامة: قطن 100%, بلد المنشأ: مصر")
    final specsStr = getValue('custom_fields')?.toString().trim();
    if (specsStr != null && specsStr.isNotEmpty) {
      final parts = specsStr.split(RegExp(r'[,،;\n]'));
      for (var part in parts) {
        final pair = part.split(':');
        if (pair.length >= 2) {
          final key = pair[0].trim();
          final value = pair.sublist(1).join(':').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            customFields[key] = value;
          }
        }
      }
    }

    // Also check for any dynamic columns that start with 'مواصفة:' (legacy support)
    for (var entry in rawData.entries) {
      if (entry.key.startsWith('مواصفة:')) {
        final key = entry.key.replaceFirst('مواصفة:', '').trim();
        final value = entry.value?.toString().trim();
        if (value != null && value.isNotEmpty) {
          customFields[key] = value;
        }
      }
    }
    mappedData['customFields'] = customFields;

    // Parse Variants from Single 'variants_column' (الخصائص)
    final variantGroups = <Map<String, dynamic>>[];
    final variantsList = <Map<String, dynamic>>[];

    final variantsStr = getValue('variants_column')?.toString().trim();
    if (variantsStr != null && variantsStr.isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      final Map<String, Map<String, dynamic>> groupsMap = {};

      final parts = variantsStr.split(RegExp(r'[,،;\n]'));
      for (var part in parts) {
        part = part.trim();
        if (part.isEmpty) continue;

        final pair = part.split(':');
        final optionsStr = pair[0].trim();
        final detailsStr = pair.length > 1 ? pair.sublist(1).join(':').trim() : '';

        double? price;
        int? stock;
        if (detailsStr.isNotEmpty) {
          if (detailsStr.contains('/')) {
            final subParts = detailsStr.split('/');
            price = double.tryParse(subParts[0].trim());
            if (subParts.length > 1) {
              stock = int.tryParse(subParts[1].trim());
            }
          } else {
            price = double.tryParse(detailsStr);
          }
        }

        final optionValues = optionsStr
            .split(RegExp(r'[-/+]'))
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();

        if (optionValues.isEmpty) continue;

        final List<Map<String, dynamic>> selectedOptionsForVariant = [];

        for (final val in optionValues) {
          String groupName = 'النوع';
          String groupType = 'custom';

          final valLower = val.toLowerCase();
          
          final colorKeywords = ['أحمر', 'أحمر', 'أزرق', 'أخضر', 'أسود', 'أبيض', 'أصفر', 'بني', 'رمادي', 'وردي', 'برتقالي', 'بنفسجي', 'ذهبي', 'فضي', 'كحلي', 'بيج', 'red', 'blue', 'green', 'black', 'white', 'yellow', 'brown', 'grey', 'pink', 'orange', 'purple'];
          final sizeKeywords = ['كبير', 'وسط', 'صغير', 'ضخم', 's', 'm', 'l', 'xl', 'xxl', 'xxxl', 'xs', '3xl', '4xl', '5xl', 'مقاس', 'حجم', 'سعة', 'size', 'volume', 'large', 'medium', 'small'];

          if (colorKeywords.any((k) => valLower.contains(k))) {
            groupName = 'اللون';
            groupType = 'color';
          } else if (sizeKeywords.any((k) => valLower.contains(k))) {
            groupName = 'الحجم';
            groupType = 'volume';
          }

          if (!groupsMap.containsKey(groupName)) {
            groupsMap[groupName] = {
              'id': _uuid.v4(),
              'name': groupName,
              'type': groupType,
              'is_required': false,
              'options': <Map<String, dynamic>>[],
              'created_at': now,
            };
          }

          final group = groupsMap[groupName]!;
          final optionsList = group['options'] as List<Map<String, dynamic>>;

          Map<String, dynamic>? optionObj = optionsList.firstWhere(
            (o) => o['value'] == val,
            orElse: () => <String, dynamic>{},
          );

          if (optionObj.isEmpty) {
            optionObj = {
              'id': _uuid.v4(),
              'name': groupName,
              'value': val,
              'sort_order': optionsList.length,
              'is_active': true,
              'created_at': now,
            };
            optionsList.add(optionObj);
          }

          selectedOptionsForVariant.add(optionObj);
        }

        variantsList.add({
          'id': _uuid.v4(),
          'product_id': '',
          'selected_options': selectedOptionsForVariant,
          'sku': '',
          'price': price,
          'stock_quantity': stock,
          'is_active': true,
          'created_at': now,
        });
      }

      variantGroups.addAll(groupsMap.values);
    }
    mappedData['variantGroups'] = variantGroups;
    mappedData['variants'] = variantsList;

    // Parse Addons
    // Format: "الاضافات" value: "جبنة: 5, كاتشب: 2" or "cheese: 5, ketchup: 2"
    final addonsList = <Map<String, dynamic>>[];
    final addonsStr = getValue('addons')?.toString().trim();
    if (addonsStr != null && addonsStr.isNotEmpty) {
      final parts = addonsStr.split(RegExp(r'[,،;]'));
      for (var part in parts) {
        final pair = part.split(':');
        if (pair.length >= 2) {
          final addonName = pair[0].trim();
          final addonPriceStr = pair[1].trim();
          final addonPrice = double.tryParse(addonPriceStr) ?? 0.0;
          if (addonName.isNotEmpty) {
            addonsList.add({
              'id': _uuid.v4(),
              'name': addonName,
              'price': addonPrice,
              'image_url': null,
            });
          }
        }
      }
    }
    mappedData['addons'] = addonsList;

    return ImportRow(
      index: rowIndex,
      data: mappedData,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Bulk imports validated products.
  static Future<Map<String, dynamic>> importProducts({
    required List<ImportRow> validatedRows,
    required String storeId,
    String? sectionId,
    String? categoryId,
  }) async {
    int importedCount = 0;
    List<String> failedReasons = [];

    // Resolve categoryId if it is passed as a category name instead of a UUID
    String? resolvedCategoryId = categoryId;
    if (categoryId != null &&
        categoryId.isNotEmpty &&
        !RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                caseSensitive: false)
            .hasMatch(categoryId)) {
      try {
        final response = await Supabase.instance.client
            .from('categories')
            .select('id')
            .ilike('name', categoryId)
            .maybeSingle();
        if (response != null) {
          resolvedCategoryId = response['id'] as String?;
          AppLogger.info('Resolved category name "$categoryId" to UUID "$resolvedCategoryId"');
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشل جلب معرف الفئة من الاسم "$categoryId": $e');
      }
    }

    for (var row in validatedRows) {
      if (!row.isValid) continue;

      try {
        final data = row.data;

        // Use the categoryId passed from the screen (store's default category)
        // This ensures all imported products get the store's category
        if (resolvedCategoryId == null || resolvedCategoryId.isEmpty) {
          failedReasons.add('الصف ${row.index}: لم يتم تحديد فئة للمنتج');
          continue;
        }

        // Resolve or automatically create section by name
        String? rowSectionId = sectionId;
        final sectionName = data['section_name']?.toString().trim();
        if (sectionName != null && sectionName.isNotEmpty) {
          try {
            final secResponse = await Supabase.instance.client
                .from('store_sections')
                .select('id')
                .eq('store_id', storeId)
                .ilike('name', sectionName)
                .maybeSingle();

            if (secResponse != null) {
              rowSectionId = secResponse['id'] as String?;
            } else {
              final newSec = await Supabase.instance.client
                  .from('store_sections')
                  .insert({
                    'store_id': storeId,
                    'name': sectionName,
                    'is_active': true,
                    'display_order': 0,
                  })
                  .select('id')
                  .single();
              rowSectionId = newSec['id'] as String?;
              AppLogger.info('Automatically created store section "$sectionName" with ID "$rowSectionId"');
            }
          } catch (e) {
            AppLogger.warning('⚠️ فشل جلب أو إنشاء القسم من الاسم "$sectionName": $e');
          }
        }

        final product = ProductModel(
          id: '', // Generated by service
          storeId: storeId,
          categoryId: resolvedCategoryId,
          sectionId: rowSectionId,
          name: data['name'],
          description: data['description'],
          price: data['price'],
          stockQuantity: data['stock_quantity'],
          imageUrl: null, // No image from Excel
          customFields: Map<String, String>.from(data['customFields'] ?? {}),
          variantGroups: (data['variantGroups'] as List)
              .map(
                (e) => ProductVariantGroup.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
          variants: (data['variants'] as List?)
              ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
              .toList(),
          addons: (data['addons'] as List?)
              ?.map((e) => ProductAddon.fromMap(e as Map<String, dynamic>))
              .toList(),
          isActive: false, // Set to false by default as requested
          createdAt: DateTime.now(),
        );

        final result = await ProductService.addProduct(product);
        if (result != null) {
          importedCount++;
        } else {
          failedReasons.add(
            'الصف ${row.index}: فشل الإضافة في قاعدة البيانات، النتيجة فارغة',
          );
          AppLogger.error(
            'فشل إضافة المنتج في الصف ${row.index}: النتيجة فارغة',
            null,
          );
        }
      } catch (e) {
        failedReasons.add('الصف ${row.index}: $e');
        AppLogger.error('فشل استيراد الصف ${row.index}', e);
        // Continue with next row
      }
    }
    return {'count': importedCount, 'errors': failedReasons};
  }

  /// Generates a sample Excel template for product import.
  static Future<List<int>?> generateTemplate() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Headers
      final headers = [
        'الاسم',
        'السعر',
        'المخزون',
        'الوصف',
        'القسم',
        'المواصفات الفنية',
        'الخصائص',
        'الاضافات',
      ];

      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
      }

      // Sample Data Row
      // Sample Data - Example 1: Clothing
      final sample1 = [
        'تيشيرت قطن عصري',
        '250.0',
        '50',
        'تيشيرت عالي الجودة متوفر بألوان ومقاسات مختلفة',
        'ملابس رجالي',
        'الخامة: قطن 100%, بلد المنشأ: مصر',
        'أحمر-S: 250/10, أحمر-M: 260/15, أزرق-S: 270/8, أسود-XL: 290/5', // الخصائص
        'علبة هدايا: 15', // الاضافات
      ];
      for (var i = 0; i < sample1.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        );
        cell.value = TextCellValue(sample1[i]);
      }

      // Sample Data - Example 2: Restaurant
      final sample2 = [
        'وجبة برجر عائلي',
        '180.0',
        '100',
        'برجر مشوي على الفحم مع خضروات طازجة وصوص خاص',
        'وجبات سريعة',
        'المكونات: لحم بقري بلدي, المصنع: مطبخنا الرئيسي',
        'صغير: 150/20, وسط: 180/30, كبير: 210/50', // الخصائص
        'بطاطس: 15, كولا: 10', // الاضافات
      ];
      for (var i = 0; i < sample2.length; i++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
        );
        cell.value = TextCellValue(sample2[i]);
      }

      return excel.encode();
    } catch (e) {
      AppLogger.error('فشل إنشاء ملف النموذج', e);
      return null;
    }
  }
}
