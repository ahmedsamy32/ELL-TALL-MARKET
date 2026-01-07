import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef SearchCallback = void Function(String value);

/// 🔍 شريط بحث موحد للتطبيق - تصميم عصري
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final SearchCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final bool readOnly;
  final bool enabled;
  final bool showFilterIcon;
  final bool autofocus;
  final EdgeInsetsGeometry? margin;
  final FocusNode? focusNode;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'ابحث عن المنتجات أو المتاجر...',
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.onFilterTap,
    this.readOnly = false,
    this.enabled = true,
    this.showFilterIcon = false,
    this.autofocus = false,
    this.margin,
    this.focusNode,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SearchBar(
        controller: _controller,
        focusNode: _focusNode,
        hintText: widget.hintText,
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(Icons.search_rounded),
        ),
        trailing: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onChanged?.call('');
              },
            )
          else if (widget.showFilterIcon)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: widget.onFilterTap,
            ),
        ],
        elevation: const WidgetStatePropertyAll(1),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Theme.of(context).colorScheme.surfaceContainerHighest;
          }
          // رمادي فاتح للخلفية بدلاً من الأبيض
          return Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.90);
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        enabled: widget.enabled,
        autoFocus: widget.autofocus,
        onTap: widget.readOnly ? widget.onTap : null,
        onChanged: (value) {
          setState(() {});
          widget.onChanged?.call(value);
        },
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            HapticFeedback.lightImpact();
            // تنفيذ callback المخصص أولاً إذا كان موجودًا
            if (widget.onSubmitted != null) {
              widget.onSubmitted!(value);
            } else {
              // إذا لم يكن هناك callback مخصص، انتقل لصفحة البحث
              Navigator.pushNamed(context, '/search', arguments: value);
            }
          }
        },
      ),
    );
  }
}

/// 🔍 شريط بحث مضغوط للاستخدام في AppBar
class CompactSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const CompactSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'ابحث...',
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<CompactSearchBar> createState() => _CompactSearchBarState();
}

class _CompactSearchBarState extends State<CompactSearchBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {});
                    widget.onChanged('');
                    widget.onClear?.call();
                  },
                  splashRadius: 18,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

/// 🔍 شريط بحث مع فلتر للاستخدام في صفحات الإدارة
class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final List<Widget>? filterChips;
  final EdgeInsetsGeometry? margin;

  const AdminSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'ابحث هنا...',
    required this.onChanged,
    this.filterChips,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSearchBar(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
            margin: EdgeInsets.zero,
            showFilterIcon: false,
          ),
          if (filterChips != null && filterChips!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: filterChips!),
          ],
        ],
      ),
    );
  }
}
