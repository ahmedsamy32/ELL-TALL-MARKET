// Removed dart:io for Web compatibility
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
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

        final headerRow = sheet.rows[0];
        final headers = headerRow
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .toList();

        for (var i = 1; i < sheet.maxRows; i++) {
          final rowData = sheet.rows[i];
          final rowMap = <String, dynamic>{};
          for (var j = 0; j < headers.length; j++) {
            if (headers[j].isNotEmpty) {
              rowMap[headers[j]] = rowData[j]?.value;
            }
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

    mappedData['category_id'] = getValue('category_id')?.toString().trim();
    mappedData['imageUrl'] = getValue('image_url')?.toString().trim();

    // Custom Fields (Specifications)
    final customFields = <String, String>{};
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

    // Attributes (Variants)
    // Format: "خاصية:اللون" value: "أحمر, أزرق, أخضر"
    final variantGroups = <Map<String, dynamic>>[];
    for (var entry in rawData.entries) {
      if (entry.key.startsWith('خاصية:')) {
        final groupName = entry.key.replaceFirst('خاصية:', '').trim();
        final valuesStr = entry.value?.toString().trim();
        if (valuesStr != null && valuesStr.isNotEmpty) {
          final values = valuesStr
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList();
          if (values.isNotEmpty) {
            final now = DateTime.now().toIso8601String();
            variantGroups.add({
              'id': _uuid.v4(),
              'name': groupName,
              'type': _inferAttributeType(groupName),
              'is_required': false,
              'options': values
                  .map(
                    (v) => {
                      'id': _uuid.v4(),
                      'name': groupName,
                      'value': v,
                      'sort_order': 0,
                      'is_active': true,
                      'created_at': now,
                    },
                  )
                  .toList(),
              'created_at': now,
            });
          }
        }
      }
    }
    mappedData['variantGroups'] = variantGroups;

    return ImportRow(
      index: rowIndex,
      data: mappedData,
      errors: errors,
      warnings: warnings,
    );
  }

  static String _inferAttributeType(String name) {
    name = name.toLowerCase();
    if (name.contains('لون') || name.contains('color')) return 'color';
    if (name.contains('مقاس') || name.contains('size')) return 'size';
    if (name.contains('خام') || name.contains('material')) return 'material';
    if (name.contains('مارك') || name.contains('brand')) return 'brand';
    if (name.contains('وزن') || name.contains('weight')) return 'weight';
    return 'custom';
  }

  /// Bulk imports validated products.
  static Future<int> importProducts({
    required List<ImportRow> validatedRows,
    required String storeId,
    String? sectionId,
  }) async {
    int importedCount = 0;

    for (var row in validatedRows) {
      if (!row.isValid) continue;

      try {
        final data = row.data;

        // Ensure category_id is null if it's empty string
        final categoryId = data['category_id']?.toString().trim();
        final effectiveCategoryId = (categoryId == null || categoryId.isEmpty)
            ? null
            : categoryId;

        final product = ProductModel(
          id: '', // Generated by service
          storeId: storeId,
          categoryId: effectiveCategoryId,
          sectionId: sectionId,
          name: data['name'],
          description: data['description'],
          price: data['price'],
          stockQuantity: data['stock_quantity'],
          imageUrl: data['imageUrl'],
          customFields: Map<String, String>.from(data['customFields'] ?? {}),
          variantGroups: (data['variantGroups'] as List)
              .map(
                (e) => ProductVariantGroup.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
          isActive: false, // Set to false by default as requested
          createdAt: DateTime.now(),
        );

        final result = await ProductService.addProduct(product);
        if (result != null) {
          importedCount++;
        } else {
          AppLogger.error(
            'فشل إضافة المنتج في الصف ${row.index}: النتيجة فارغة',
            null,
          );
        }
      } catch (e) {
        AppLogger.error('فشل استيراد الصف ${row.index}', e);
        // Continue with next row
      }
    }
    return importedCount;
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
        'الوصف',
        'المخزون',
        'مواصفة:الخامة أو المكونات',
        'مواصفة:بلد المنشأ',
        'خاصية:اللون أو النوع',
        'خاصية:الحجم أو المقاس',
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
        'تيشيرت عالي الجودة متوفر بألوان ومقاسات مختلفة',
        '50',
        'قطن 100%',
        'مصر',
        'أحمر, أزرق, أسود',
        'S, M, L, XL',
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
        'برجر مشوي على الفحم مع خضروات طازجة وصوص خاص',
        '100',
        'لحم بقري بلدي, خس, طماطم, صوص',
        'مطبخنا الرئيسي',
        'عادي, حار',
        'وجبة فردية, وجبة كبيرة',
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
