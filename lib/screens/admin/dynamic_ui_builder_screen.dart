import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ell_tall_market/providers/dynamic_ui_provider.dart';

class DynamicUIBuilderScreen extends StatefulWidget {
  const DynamicUIBuilderScreen({super.key});

  @override
  State<DynamicUIBuilderScreen> createState() => _DynamicUIBuilderScreenState();
}

class _DynamicUIBuilderScreenState extends State<DynamicUIBuilderScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DynamicUIProvider>(context, listen: false).loadUIConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uiProvider = Provider.of<DynamicUIProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('بناء واجهة المستخدم'),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _saveUIConfig),
          IconButton(icon: Icon(Icons.refresh), onPressed: _resetUIConfig),
        ],
      ),
      body: uiProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildUIBuilder(uiProvider),
    );
  }

  Widget _buildUIBuilder(DynamicUIProvider provider) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('المظهر العام'),
            _buildColorPicker('لون التطبيق الرئيسي', 'primaryColor', '#2A6DE5'),
            _buildColorPicker(
              'لون التطبيق الثانوي',
              'secondaryColor',
              '#FF6E40',
            ),
            _buildDropdownSetting(
              'نوع الخط',
              provider.getConfigValue('fontFamily') ?? 'Cairo',
              ['Cairo', 'Tajawal', 'Roboto', 'OpenSans'],
              (value) => provider.updateConfigValue('fontFamily', value),
            ),
            _buildDropdownSetting(
              'حجم الخط',
              provider.getConfigValue('fontSize') ?? 'medium',
              ['small', 'medium', 'large', 'xlarge'],
              (value) => provider.updateConfigValue('fontSize', value),
            ),

            _buildSectionHeader('تخطيط الصفحة الرئيسية'),
            _buildDropdownSetting(
              'نمط العرض',
              provider.getConfigValue('layout') ?? 'grid',
              ['grid', 'list', 'staggered'],
              (value) => provider.updateConfigValue('layout', value),
            ),
            _buildSwitchSetting(
              'إظهار البنرات',
              provider.getConfigValue('showBanners') ?? true,
              (value) => provider.updateConfigValue('showBanners', value),
            ),
            _buildSwitchSetting(
              'إظهار الفئات',
              provider.getConfigValue('showCategories') ?? true,
              (value) => provider.updateConfigValue('showCategories', value),
            ),
            _buildSwitchSetting(
              'إظهار المنتجات المميزة',
              provider.getConfigValue('showFeaturedProducts') ?? true,
              (value) =>
                  provider.updateConfigValue('showFeaturedProducts', value),
            ),
            _buildSwitchSetting(
              'إظهار التقييمات',
              provider.getConfigValue('showReviews') ?? true,
              (value) => provider.updateConfigValue('showReviews', value),
            ),

            _buildSectionHeader('الحركات والانتقالات'),
            _buildSwitchSetting(
              'تفعيل الحركات',
              provider.getConfigValue('animationEnabled') ?? true,
              (value) => provider.updateConfigValue('animationEnabled', value),
            ),
            _buildDropdownSetting(
              'سرعة الانتقال',
              provider.getConfigValue('transitionSpeed') ?? 'normal',
              ['slow', 'normal', 'fast'],
              (value) => provider.updateConfigValue('transitionSpeed', value),
            ),

            _buildSectionHeader('إعدادات متقدمة'),
            _buildTextFieldSetting(
              'عدد العناصر في الصفحة',
              provider.getConfigValue('itemsPerPage') ?? '20',
              (value) => provider.updateConfigValue('itemsPerPage', value),
            ),
            _buildSwitchSetting(
              'التخزين المؤقت',
              provider.getConfigValue('cacheEnabled') ?? true,
              (value) => provider.updateConfigValue('cacheEnabled', value),
            ),
            _buildSwitchSetting(
              'وضع غير متصل',
              provider.getConfigValue('offlineMode') ?? false,
              (value) => provider.updateConfigValue('offlineMode', value),
            ),

            SizedBox(height: 32),
            _buildPreviewSection(provider),
            SizedBox(height: 32),
            _buildActionButtons(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildColorPicker(String title, String key, String defaultValue) {
    final currentColor =
        Provider.of<DynamicUIProvider>(context).getConfigValue(key) ??
        defaultValue;

    return ListTile(
      title: Text(title),
      trailing: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _parseColor(currentColor),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey),
        ),
      ),
      onTap: () => _showColorPickerDialog(key, currentColor),
    );
  }

  Widget _buildDropdownSetting(
    String title,
    dynamic value,
    List<dynamic> options,
    ValueChanged<dynamic> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton(
        value: value,
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option.toString()),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildTextFieldSetting(
    String title,
    String value,
    ValueChanged<String> onChanged,
  ) {
    final controller = TextEditingController(text: value);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: title,
        border: OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildPreviewSection(DynamicUIProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معاينة الواجهة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_android, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('معاينة الواجهة الحية'),
                    Text('سيتم تحديثها تلقائياً مع التغييرات'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(DynamicUIProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _saveUIConfig,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('حفظ التغييرات'),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: OutlinedButton(
            onPressed: _resetUIConfig,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('استعادة الإعدادات'),
          ),
        ),
      ],
    );
  }

  void _showColorPickerDialog(String key, String currentColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('اختر لون'),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: _parseColor(currentColor),
            onColorChanged: (color) {
              Provider.of<DynamicUIProvider>(
                context,
                listen: false,
              ).updateConfigValue(key, colorToHex(color));
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('تم'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      // Remove # if present
      final hex = colorHex.replaceFirst('#', '');
      // If length is 6, add FF for alpha
      final fullHex = hex.length == 6 ? 'FF$hex' : hex;
      return Color(int.parse(fullHex, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
  }

  void _saveUIConfig() async {
    try {
      final provider = Provider.of<DynamicUIProvider>(context, listen: false);
      provider.updateUIConfig(provider.uiConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ إعدادات الواجهة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ الإعدادات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetUIConfig() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('استعادة الإعدادات الافتراضية'),
        content: Text('هل أنت متأكد من أنك تريد استعادة الإعدادات الافتراضية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final provider = Provider.of<DynamicUIProvider>(
                  context,
                  listen: false,
                );
                provider.resetToDefault();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم استعادة الإعدادات الافتراضية'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('فشل استعادة الإعدادات: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

// نموذج مبسط لأداة اختيار الألوان
class ColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.color;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: _currentColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'RGB: ${(_currentColor.r * 255).round()}, ${(_currentColor.g * 255).round()}, ${(_currentColor.b * 255).round()}',
        ),
        SizedBox(height: 16),
        // يمكن إضافة منتقي ألوان حقيقي هنا
      ],
    );
  }
}
