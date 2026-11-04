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
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onToggleObscure,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return impl.buildNativeTextField(
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onToggleObscure: onToggleObscure,
    );
  }
}
