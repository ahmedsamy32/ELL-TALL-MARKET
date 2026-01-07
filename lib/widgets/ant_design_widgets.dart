import 'package:flutter/material.dart';
import 'package:ell_tall_market/utils/ant_design_theme.dart';

/// Ant Design Style Components for Admin Screens

class AntCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double elevation;

  const AntCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      shadowColor: AntColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AntBorderRadius.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AntBorderRadius.md),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AntSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class AntButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AntButtonType type;
  final bool loading;
  final IconData? icon;
  final double? width;

  const AntButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = AntButtonType.primary,
    this.loading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    Color borderColor;

    switch (type) {
      case AntButtonType.primary:
        backgroundColor = AntColors.primary;
        foregroundColor = Colors.white;
        borderColor = AntColors.primary;
        break;
      case AntButtonType.secondary:
        backgroundColor = AntColors.fill;
        foregroundColor = AntColors.text;
        borderColor = AntColors.border;
        break;
      case AntButtonType.success:
        backgroundColor = AntColors.success;
        foregroundColor = Colors.white;
        borderColor = AntColors.success;
        break;
      case AntButtonType.warning:
        backgroundColor = AntColors.warning;
        foregroundColor = Colors.white;
        borderColor = AntColors.warning;
        break;
      case AntButtonType.error:
        backgroundColor = AntColors.error;
        foregroundColor = Colors.white;
        borderColor = AntColors.error;
        break;
      case AntButtonType.text:
        backgroundColor = Colors.transparent;
        foregroundColor = AntColors.primary;
        borderColor = Colors.transparent;
        break;
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: type == AntButtonType.primary ? 2 : 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AntSpacing.lg,
            vertical: AntSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AntBorderRadius.md),
            side: type == AntButtonType.secondary
                ? BorderSide(color: borderColor)
                : BorderSide.none,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: AntSpacing.sm),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum AntButtonType { primary, secondary, success, warning, error, text }

class AntInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final bool enabled;

  const AntInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AntColors.primary)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AntBorderRadius.md),
          borderSide: const BorderSide(color: AntColors.error, width: 2),
        ),
        filled: true,
        fillColor: enabled ? AntColors.fill : AntColors.fillSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AntSpacing.md,
          vertical: AntSpacing.md,
        ),
        labelStyle: const TextStyle(color: AntColors.textSecondary),
        hintStyle: const TextStyle(color: AntColors.textQuaternary),
      ),
    );
  }
}

class AntBadge extends StatelessWidget {
  final String text;
  final AntBadgeType type;
  final bool outlined;

  const AntBadge({
    super.key,
    required this.text,
    this.type = AntBadgeType.primary,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case AntBadgeType.primary:
        backgroundColor = outlined ? Colors.transparent : AntColors.primary;
        textColor = outlined ? AntColors.primary : Colors.white;
        borderColor = AntColors.primary;
        break;
      case AntBadgeType.success:
        backgroundColor = outlined ? Colors.transparent : AntColors.success;
        textColor = outlined ? AntColors.success : Colors.white;
        borderColor = AntColors.success;
        break;
      case AntBadgeType.warning:
        backgroundColor = outlined ? Colors.transparent : AntColors.warning;
        textColor = outlined ? AntColors.warning : Colors.white;
        borderColor = AntColors.warning;
        break;
      case AntBadgeType.error:
        backgroundColor = outlined ? Colors.transparent : AntColors.error;
        textColor = outlined ? AntColors.error : Colors.white;
        borderColor = AntColors.error;
        break;
      case AntBadgeType.info:
        backgroundColor = outlined ? Colors.transparent : AntColors.info;
        textColor = outlined ? AntColors.info : Colors.white;
        borderColor = AntColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AntBorderRadius.xl),
        border: outlined ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

enum AntBadgeType { primary, success, warning, error, info }

class AntAvatar extends StatelessWidget {
  final String? imageUrl;
  final IconData? icon;
  final String? text;
  final double size;
  final Color? backgroundColor;

  const AntAvatar({
    super.key,
    this.imageUrl,
    this.icon,
    this.text,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AntColors.fillSecondary,
        boxShadow: [AntShadows.sm],
      ),
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    if (icon != null) {
      return Icon(icon, color: AntColors.textSecondary, size: size * 0.6);
    } else if (text != null && text!.isNotEmpty) {
      return Center(
        child: Text(
          text!.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: AntColors.textSecondary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return Icon(
        Icons.person,
        color: AntColors.textSecondary,
        size: size * 0.6,
      );
    }
  }
}

class AntDialog extends StatelessWidget {
  final String? title;
  final Widget content;
  final List<Widget> actions;

  const AntDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AntBorderRadius.lg),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AntSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AntColors.text,
                ),
              ),
              const SizedBox(height: AntSpacing.md),
            ],
            content,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AntSpacing.lg),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class AntStatistic extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final AntBadgeType? badgeType;

  const AntStatistic({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.badgeType,
  });

  @override
  Widget build(BuildContext context) {
    return AntCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AntColors.textSecondary, size: 20),
                const SizedBox(width: AntSpacing.sm),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AntColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AntSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              color: AntColors.text,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (badgeType != null) ...[
            const SizedBox(height: AntSpacing.sm),
            AntBadge(text: 'نشط', type: badgeType!, outlined: true),
          ],
        ],
      ),
    );
  }
}
