import 'package:flutter/material.dart';

import 'native_text_field_io.dart'
    if (dart.library.html) 'native_text_field_web.dart' as impl;

/// Text field that stays usable on Flutter web (real HTML input).
class NativeTextField extends StatelessWidget {
  const NativeTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onToggleObscure,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onToggleObscure;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return impl.buildNativeTextField(
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      obscureText: obscureText,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onToggleObscure: onToggleObscure,
      prefixIcon: prefixIcon,
    );
  }
}
