import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final bool isPasswordField; // ← جديد
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final bool readOnly;
  final bool enabled;
  final void Function()? onTap;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hintText,
    this.isPasswordField = false, // الافتراضي مش باسورد
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.inputFormatters,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPasswordField; // لو باسورد نخفي النص
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPasswordField ? _obscureText : false,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      validator: widget.validator,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      onTap: widget.onTap,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
        filled: true,
        fillColor: widget.enabled ? Colors.grey[100] : Colors.grey[200],
        prefixIcon: widget.prefixIcon,
        prefixText: widget.prefixText,
        counterText: widget.maxLength != null ? '' : null,
        suffixIcon: widget.isPasswordField
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: widget.enabled
                    ? () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      }
                    : null,
              )
            : widget.suffixIcon,
      ),
    );
  }
}
