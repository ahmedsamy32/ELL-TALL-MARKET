import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/app_colors.dart';

/// 🔍 ويدجت شريط بحث موحد للتطبيق
/// يوفر تصميم متسق وألوان موحدة لجميع أشرطة البحث
class CustomSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showShadow;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const CustomSearchBar({
    super.key,
    this.controller,
    this.hintText = 'ابحث هنا...',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.margin,
    this.padding,
    this.height,
    this.borderRadius = 25.0,
    this.backgroundColor,
    this.borderColor,
    this.showShadow = true,
    this.focusNode,
    this.textInputAction,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: widget.height ?? 50,
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:
            widget.backgroundColor ?? (isDark ? AppColors.dark : Colors.white),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: _isFocused
              ? AppColors.primary
              : (widget.borderColor ??
                    (isDark ? AppColors.grey : Colors.grey[300]!)),
          width: _isFocused ? 2.0 : 1.0,
        ),
        boxShadow: widget.showShadow
            ? [
                BoxShadow(
                  color: _isFocused
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : (isDark ? Colors.black26 : Colors.black12),
                  blurRadius: _isFocused ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // أيقونة البحث أو أيقونة مخصصة
          widget.prefixIcon ??
              Icon(
                Icons.search,
                color: _isFocused
                    ? AppColors.primary
                    : (isDark ? AppColors.grey : Colors.grey[600]),
                size: 22,
              ),
          const SizedBox(width: 12),

          // حقل النص
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() {
                  _isFocused = hasFocus;
                });
              },
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                readOnly: widget.readOnly,
                enabled: widget.enabled,
                textInputAction:
                    widget.textInputAction ?? TextInputAction.search,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.onBackground,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.grey : Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                onTap: widget.onTap,
              ),
            ),
          ),

          // أيقونة إضافية أو زر المسح
          if (widget.suffixIcon != null)
            widget.suffixIcon!
          else if (_controller.text.isNotEmpty && widget.enabled)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: isDark ? AppColors.grey : Colors.grey[600],
                size: 20,
              ),
              onPressed: () {
                _controller.clear();
                widget.onChanged?.call('');
              },
            ),
        ],
      ),
    );
  }
}

/// 🔍 شريط بحث مضغوط للاستخدام في AppBar
class CompactSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final double height;

  const CompactSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'ابحث...',
    required this.onChanged,
    this.onClear,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.grey : Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : AppColors.onBackground,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? AppColors.grey : Colors.grey[600],
            fontSize: 14,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark ? AppColors.grey : Colors.grey[600],
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                    onClear?.call();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
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
          // شريط البحث
          CustomSearchBar(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
            margin: EdgeInsets.zero,
          ),

          // فلاتر إضافية
          if (filterChips != null && filterChips!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: filterChips!),
          ],
        ],
      ),
    );
  }
}
