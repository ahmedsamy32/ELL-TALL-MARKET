import 'package:flutter/material.dart';
import '../../models/template_model.dart';
import '../../services/template_service.dart';
import '../../core/logger.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class TemplateManagerScreen extends StatefulWidget {
  final String storeId;

  const TemplateManagerScreen({super.key, required this.storeId});

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  bool _isLoading = true;
  List<TemplateModel> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await TemplateService.getTemplatesByStore(
        widget.storeId,
      );
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('فشل تحميل القوالب', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل القوالب: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTemplate(TemplateModel template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القالب'),
        content: Text('هل أنت متأكد من حذف القالب "${template.templateName}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await TemplateService.deleteTemplate(template.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف القالب بنجاح')));
        _loadTemplates();
      }
    } catch (e) {
      AppLogger.error('فشل حذف القالب', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف القالب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قوالب المنتجات'),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _templates.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadTemplates,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return _buildTemplateCard(template);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد قوالب محفوظة',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'يمكنك حفظ أي منتج كقالب أثناء إضافته لتتمكن من استخدامه لاحقاً بسهولة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(TemplateModel template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.style, color: Colors.blue.shade700),
        ),
        title: Text(
          template.templateName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (template.description != null &&
                template.description!.isNotEmpty)
              Text(
                template.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildInfoChip(
                  Icons.layers_outlined,
                  '${template.customFields.length} مواصفة',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.list_alt_outlined,
                  '${template.variantGroups.length} خاصية',
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _deleteTemplate(template),
        ),
        onTap: () {
          // Maybe show a preview dialog or allow editing name/description
          _showTemplateDetails(template);
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showTemplateDetails(TemplateModel template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.templateName),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (template.description != null) ...[
                  const Text(
                    'الوصف:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(template.description!),
                  const Divider(),
                ],
                const Text(
                  'المواصفات:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (template.customFields.isEmpty)
                  const Text('لا توجد مواصفات')
                else
                  ...template.customFields.entries.map(
                    (e) => Text('• ${e.key}: ${e.value}'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'الخصائص:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (template.variantGroups.isEmpty)
                  const Text('لا توجد خصائص')
                else
                  ...template.variantGroups.map((g) {
                    final map = g as Map<String, dynamic>;
                    return Text('• ${map['name']} (${map['type']})');
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
