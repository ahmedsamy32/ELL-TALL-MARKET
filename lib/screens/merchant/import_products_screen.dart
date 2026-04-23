// Removed dart:io for Web compatibility
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ell_tall_market/services/permission_service.dart';
import '../../services/import_service.dart';
import '../../core/logger.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class ImportProductsScreen extends StatefulWidget {
  final String storeId;
  final String? sectionId;

  const ImportProductsScreen({
    super.key,
    required this.storeId,
    this.sectionId,
  });

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  bool _isParsing = false;
  bool _isImporting = false;
  // String? _selectedFileName; // Unused
  Uint8List? _selectedFileBytes;
  List<Map<String, dynamic>> _rawRows = [];
  List<ImportRow> _validatedRows = [];

  final Map<String, String> _columnMapping = {
    'name': 'الاسم',
    'price': 'السعر',
    'description': 'الوصف',
    'stock_quantity': 'المخزون',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد منتجات من Excel'),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        maxWidth: 700,
        child: _selectedFileBytes == null
            ? _buildFilePicker()
            : _buildImportWorkflow(),
      ),
      bottomNavigationBar: _selectedFileBytes != null
          ? _buildBottomActions()
          : null,
    );
  }

  Widget _buildFilePicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file, size: 80, color: Colors.blue.shade200),
          const SizedBox(height: 24),
          const Text(
            'اختر ملف Excel (.xlsx)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'تأكد من استخدام التنسيق الصحيح للملف لضمان نجاح الاستيراد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_open),
            label: const Text('اختيار الملف'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download),
            label: const Text('تحميل ملف النموذج الاسترشادي'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      // التحقق من أذونات التخزين
      final permissionService = PermissionService();
      final permissionResult = await permissionService
          .requestStoragePermission();

      if (!permissionResult.granted && !permissionResult.permanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                permissionResult.message ?? 'تم رفض إذن الوصول للملفات',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // Important for Web to get bytes
      );

      if (result != null) {
        Uint8List? fileBytes;

        if (kIsWeb) {
          fileBytes = result.files.single.bytes;
          // On Web and Mobile (withData: true), we try to use bytes.
          if (result.files.single.bytes != null) {
            fileBytes = result.files.single.bytes;
          } else {
            // If bytes are missing, we can't proceed without dart:io File.
            // For this specific task, we rely on withData: true.
            throw Exception('فشل قراءة بيانات الملف (Bytes missing)');
          }
        }

        setState(() {
          // _selectedFileName = fileName;
          _selectedFileBytes = fileBytes;
          _isParsing = true;
        });
        _parseAndValidateFile();
      }
    } catch (e) {
      AppLogger.error('فشل اختيار الملف', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل اختيار الملف: $e')));
      }
    }
  }

  Future<void> _parseAndValidateFile() async {
    if (_selectedFileBytes == null) return;

    try {
      final rows = await ImportService.parseExcelFile(_selectedFileBytes!);
      setState(() {
        _rawRows = rows;
        _validateRows();
        _isParsing = false;
      });
    } catch (e) {
      AppLogger.error('فشل معالجة الملف', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل معالجة الملف. تأكد من أنه ملف Excel صالح.'),
          ),
        );
        setState(() {
          _selectedFileBytes = null;
          // _selectedFileName = null;
          _isParsing = false;
        });
      }
    }
  }

  void _validateRows() {
    _validatedRows = [];
    for (var i = 0; i < _rawRows.length; i++) {
      _validatedRows.add(
        ImportService.validateAndMap(_rawRows[i], i + 1, _columnMapping),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = await ImportService.generateTemplate();
      if (bytes == null) return;

      // Try to use FilePicker to save the file at a specific location
      final fileName = "template_${DateTime.now().millisecondsSinceEpoch}.xlsx";

      if (kIsWeb) {
        // Web download
        // On web saveFile might not work as expected or requires bytes.
        // Actually file_picker saveFile works on some platforms.
        // Simpler way for web is usually anchor download.
        // But let's try platform.saveFile first.
        await FilePicker.platform.saveFile(
          dialogTitle: 'احفظ ملف النموذج',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
          bytes: Uint8List.fromList(bytes),
        );
        return;
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ الملف',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (outputFile == null) {
        // If saveFile returns null (user cancelled or platform not supported),
        // fallback to sharing as a secondary option
        if (mounted) {
          // final tempDir = await getTemporaryDirectory(); // Removed unused
          // final file = File('${tempDir.path}/$fileName'); // Removed File
          // await file.writeAsBytes(bytes);
          // Only use Share on mobile if we have a file path, which is hard without dart:io.
          // For now, we rely on saveFile working.

          if (!mounted) return;
          // Share functionality removed for Web compatibility (relied on File)
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الملف بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('فشل حفظ النموذج', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل حفظ النموذج: $e')));
      }
    }
  }

  Widget _buildImportWorkflow() {
    if (_isParsing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحليل محتوى الملف...'),
          ],
        ),
      );
    }

    final validCount = _validatedRows.where((r) => r.isValid).length;
    final errorCount = _validatedRows.length - validCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(validCount, errorCount),
          const SizedBox(height: 24),
          const Text(
            'معاينة البيانات (أول 5 صفوف):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildPreviewList(),
          const SizedBox(height: 24),
          _buildMappingSection(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int valid, int errors) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'تم العثور على ${_validatedRows.length} منتج في الملف',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  Icons.check_circle,
                  '$valid جاهزة',
                  Colors.green,
                ),
                _buildSummaryItem(Icons.error, '$errors بها أخطاء', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPreviewList() {
    final previewRows = _validatedRows.take(5).toList();
    if (previewRows.isEmpty) return const Text('لا توجد بيانات للمعاينة');

    return Column(
      children: previewRows.map((row) => _buildPreviewItem(row)).toList(),
    );
  }

  Widget _buildPreviewItem(ImportRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: row.isValid
              ? Colors.green.shade50
              : Colors.red.shade50,
          child: Text(
            '${row.index}',
            style: TextStyle(
              color: row.isValid ? Colors.green : Colors.red,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(row.data['name'] ?? 'اسم مفقود'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('السعر: ${row.data['price'] ?? 0} ج.م'),
            if (row.errors.isNotEmpty)
              Text(
                row.errors.join(', '),
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
          ],
        ),
        trailing: Icon(
          row.isValid ? Icons.check_circle_outline : Icons.error_outline,
          color: row.isValid ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _buildMappingSection() {
    return ExpansionTile(
      title: const Text(
        'إعدادات ربط الأعمدة (اختياري)',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: const Text(
        'قم بتعديلها إذا كانت أسماء الأعمدة في ملفك مختلفة',
        style: TextStyle(fontSize: 12),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: _columnMapping.keys.map((key) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(_getFieldLabel(key))),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          _columnMapping[key] = value;
                          _validateRows();
                          setState(() {});
                        },
                        controller: TextEditingController(
                          text: _columnMapping[key],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getFieldLabel(String key) {
    switch (key) {
      case 'name':
        return 'اسم المنتج';
      case 'price':
        return 'السعر';
      case 'description':
        return 'الوصف';
      case 'stock_quantity':
        return 'المخزون';
      default:
        return key;
    }
  }

  Widget _buildBottomActions() {
    final validRows = _validatedRows.where((r) => r.isValid).toList();
    final canImport = validRows.isNotEmpty && !_isImporting;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isImporting
                    ? null
                    : () => setState(() {
                        _selectedFileBytes = null;
                        // _selectedFileName = null;
                      }),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canImport ? () => _startImport(validRows) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('استيراد ${validRows.length} منتج'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startImport(List<ImportRow> rows) async {
    setState(() => _isImporting = true);

    try {
      final count = await ImportService.importProducts(
        validatedRows: rows,
        storeId: widget.storeId,
        sectionId: widget.sectionId,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              count > 0 ? 'تم اكتمال الاستيراد' : 'لم يتم استيراد أي منتج',
            ),
            content: Text(
              count > 0
                  ? 'تم بنجاح استيراد $count منتج إلى متجرك.\n\nملاحظة: المنتجات المستوردة معطلة (غير مفعلة) حالياً لتتمكن من مراجعتها وإكمال بياناتها ثم تفعيلها.'
                  : 'لم يتم العثور على أي منتجات صالحة للاستيراد. يرجى التأكد من تعبئة البيانات بشكل صحيح في ملف Excel.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  if (count > 0) {
                    Navigator.pop(context, true); // Return to list with refresh
                  }
                },
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      AppLogger.error('فشل عملية الاستيراد', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الاستيراد: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}
