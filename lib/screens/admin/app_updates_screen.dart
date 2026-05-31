import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ell_tall_market/widgets/app_shimmer.dart';
import 'package:ell_tall_market/utils/app_colors.dart';
import 'package:ell_tall_market/utils/helpers.dart';
import 'package:ell_tall_market/utils/responsive_helper.dart';

class AppUpdatesScreen extends StatefulWidget {
  const AppUpdatesScreen({super.key});

  @override
  State<AppUpdatesScreen> createState() => _AppUpdatesScreenState();
}

class _AppUpdatesScreenState extends State<AppUpdatesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _updates = [];
  String _platformFilter = 'all';
  bool _activeOnly = false;

  static const List<String> _platformOptions = [
    'all',
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
  ];

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var query = _supabase.from('app_updates').select();
      if (_platformFilter != 'all') {
        query = query.eq('platform', _platformFilter);
      }
      if (_activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response as List);

      if (!mounted) return;
      setState(() {
        _updates = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل التحديثات.';
        _isLoading = false;
      });
    }
  }

  void _scheduleLoadUpdates() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUpdates();
    });
  }

  Future<void> _openUpdateForm({Map<String, dynamic>? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _UpdateFormSheet(
          supabase: _supabase,
          existing: existing,
          platformOptions: _platformOptions,
          formatPlatform: _formatPlatform,
          onSaved: _loadUpdates,
        );
      },
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> updateRow) async {
    try {
      await _supabase
          .from('app_updates')
          .update({'is_active': !(updateRow['is_active'] == true)})
          .eq('id', updateRow['id']);
      await _loadUpdates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحديث الحالة.')));
    }
  }

  Future<void> _deleteUpdate(Map<String, dynamic> updateRow) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف التحديث؟'),
          content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('app_updates').delete().eq('id', updateRow['id']);
      await _loadUpdates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر حذف التحديث.')));
    }
  }

  Future<void> _openUpdateUrl(String url) async {
    try {
      await Helpers.launchURL(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحديث.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التحديثات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadUpdates,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'إضافة تحديث',
            onPressed: () => _openUpdateForm(),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadUpdates,
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadUpdates,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFilters(context),
        const SizedBox(height: 12),
        if (_isLoading)
          AppShimmer.list(context, itemCount: 6, itemHeight: 90)
        else if (_updates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'لا توجد تحديثات متاحة.',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          )
        else
          ..._updates.map(_buildUpdateCard),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    final isMobile = context.isMobile;
    final dropdownItemStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ) ??
        TextStyle(color: Theme.of(context).colorScheme.onSurface);
    final platformDropdown = DropdownButtonFormField<String>(
      initialValue: _platformFilter,
      dropdownColor: Theme.of(context).colorScheme.surface,
      decoration: const InputDecoration(
        labelText: 'المنصة',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      isExpanded: true,
      iconSize: 18,
      menuMaxHeight: 240,
      style: dropdownItemStyle,
      iconEnabledColor: Theme.of(context).colorScheme.onSurface,
      items: _platformOptions
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(_formatPlatform(value), style: dropdownItemStyle),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _platformFilter = value);
        _scheduleLoadUpdates();
      },
    );

    final activeOnlyToggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'المفعلة فقط',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
        ),
        const SizedBox(width: 6),
        Switch.adaptive(
          value: _activeOnly,
          onChanged: (value) {
            setState(() => _activeOnly = value);
            _scheduleLoadUpdates();
          },
        ),
      ],
    );

    return Row(
      children: [
        SizedBox(width: isMobile ? 170 : 260, child: platformDropdown),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: activeOnlyToggle,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> updateRow) {
    final latest = updateRow['latest_version']?.toString() ?? '-';
    final minVersion = updateRow['min_supported_version']?.toString();
    final updateUrl = updateRow['update_url']?.toString() ?? '';
    final platform = updateRow['platform']?.toString() ?? 'android';
    final isActive = updateRow['is_active'] == true;
    final isForce = updateRow['force_update'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatPlatform(platform)} - v$latest',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isForce)
                  const Chip(
                    label: Text('إجباري'),
                    backgroundColor: AppColors.warning,
                  ),
                const SizedBox(width: 8),
                Icon(
                  isActive ? Icons.check_circle : Icons.cancel,
                  color: isActive ? AppColors.success : AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (minVersion != null && minVersion.isNotEmpty)
              Text('أقل إصدار مدعوم: $minVersion'),
            const SizedBox(height: 6),
            Text('الرابط: $updateUrl'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openUpdateForm(existing: updateRow),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleActive(updateRow),
                  icon: Icon(isActive ? Icons.pause : Icons.play_arrow_rounded),
                  label: Text(isActive ? 'تعطيل' : 'تفعيل'),
                ),
                OutlinedButton.icon(
                  onPressed: updateUrl.isEmpty
                      ? null
                      : () => _openUpdateUrl(updateUrl),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('فتح الرابط'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteUpdate(updateRow),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPlatform(String platform) {
    switch (platform) {
      case 'all':
        return 'الكل';
      case 'android':
        return 'أندرويد';
      case 'ios':
        return 'iOS';
      case 'web':
        return 'ويب';
      case 'windows':
        return 'ويندوز';
      case 'macos':
        return 'ماك';
      case 'linux':
        return 'لينكس';
      default:
        return platform.toUpperCase();
    }
  }
}

class _UpdateFormSheet extends StatefulWidget {
  const _UpdateFormSheet({
    required this.supabase,
    required this.platformOptions,
    required this.formatPlatform,
    required this.onSaved,
    this.existing,
  });

  final SupabaseClient supabase;
  final List<String> platformOptions;
  final String Function(String) formatPlatform;
  final Future<void> Function() onSaved;
  final Map<String, dynamic>? existing;

  @override
  State<_UpdateFormSheet> createState() => _UpdateFormSheetState();
}

class _UpdateFormSheetState extends State<_UpdateFormSheet> {
  static const _defaultDialogTitle = 'تحديث جديد متاح';
  static const _defaultDialogMessage =
      'يتوفر تحديث جديد للتطبيق لتحسين الأداء وإضافة ميزات جديدة.';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _latestController;
  late final TextEditingController _minController;
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;

  late String _platform;
  late bool _forceUpdate;
  late bool _isActive;
  late Set<String> _selectedPlatforms;
  bool _showPlatformError = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _latestController = TextEditingController(
      text: existing?['latest_version']?.toString() ?? '',
    );
    _minController = TextEditingController(
      text: existing?['min_supported_version']?.toString() ?? '',
    );
    _urlController = TextEditingController(
      text: existing?['update_url']?.toString() ?? '',
    );
    _titleController = TextEditingController(
      text: existing == null
          ? _defaultDialogTitle
          : (existing['title']?.toString() ?? ''),
    );
    _messageController = TextEditingController(
      text: existing == null
          ? _defaultDialogMessage
          : (existing['message']?.toString() ?? ''),
    );

    _platform = existing?['platform']?.toString() ?? 'android';
    _forceUpdate = existing?['force_update'] == true;
    _isActive = existing?['is_active'] != false;
    _selectedPlatforms = {_platform};
  }

  @override
  void dispose() {
    _latestController.dispose();
    _minController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    if (!_isEditing && _selectedPlatforms.isEmpty) {
      setState(() => _showPlatformError = true);
      return;
    }

    final baseData = <String, dynamic>{
      'latest_version': _latestController.text.trim(),
      'min_supported_version': _minController.text.trim().isEmpty
          ? null
          : _minController.text.trim(),
      'update_url': _urlController.text.trim(),
      'title': _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      'message': _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
      'force_update': _forceUpdate,
      'is_active': _isActive,
    };

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await widget.supabase
            .from('app_updates')
            .update({...baseData, 'platform': _platform})
            .eq('id', widget.existing!['id']);
      } else {
        final rows = _selectedPlatforms.map(
          (value) => {...baseData, 'platform': value},
        );
        await widget.supabase.from('app_updates').insert(rows.toList());
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر حفظ التحديث.')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _togglePlatform(String value, bool selected) {
    setState(() {
      if (selected) {
        if (value == 'all') {
          _selectedPlatforms
            ..clear()
            ..add('all');
        } else {
          _selectedPlatforms.remove('all');
          _selectedPlatforms.add(value);
        }
      } else {
        _selectedPlatforms.remove(value);
      }
      _showPlatformError = _selectedPlatforms.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dropdownItemStyle = TextStyle(
      fontSize: 14,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final Widget platformSelector = _isEditing
        ? DropdownButtonFormField<String>(
            initialValue: _platform,
            dropdownColor: Theme.of(context).colorScheme.surface,
            style: dropdownItemStyle,
            iconEnabledColor: Theme.of(context).colorScheme.onSurface,
            decoration: const InputDecoration(
              labelText: 'المنصة',
              border: OutlineInputBorder(),
            ),
            items: widget.platformOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      widget.formatPlatform(value),
                      style: dropdownItemStyle,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _platform = value);
            },
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المنصات',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.platformOptions
                    .map(
                      (value) => FilterChip(
                        label: Text(widget.formatPlatform(value)),
                        selected: _selectedPlatforms.contains(value),
                        onSelected: (selected) =>
                            _togglePlatform(value, selected),
                      ),
                    )
                    .toList(),
              ),
              if (_showPlatformError)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'اختر منصة واحدة على الأقل.',
                    style: TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
            ],
          );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'تعديل التحديث' : 'إضافة تحديث جديد',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                platformSelector,
                const SizedBox(height: 12),
                TextFormField(
                  controller: _latestController,
                  decoration: const InputDecoration(
                    labelText: 'آخر إصدار',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'آخر إصدار مطلوب.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minController,
                  decoration: const InputDecoration(
                    labelText: 'أقل إصدار مدعوم (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'رابط التحديث',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'رابط التحديث مطلوب.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الرسالة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'نص الرسالة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _forceUpdate,
                  title: const Text('تحديث إجباري'),
                  onChanged: (value) => setState(() => _forceUpdate = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('مفعل'),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _submit,
                        child: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
