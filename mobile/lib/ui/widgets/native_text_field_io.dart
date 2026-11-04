import 'package:flutter/material.dart';

import '../../core/theme.dart';

Widget buildNativeTextField({
  required TextEditingController controller,
  String? label,
  String? hint,
  bool enabled = true,
  bool obscureText = false,
  bool autofocus = false,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  VoidCallback? onToggleObscure,
  IconData? prefixIcon,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    obscureText: obscureText,
    autofocus: autofocus,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    style: const TextStyle(color: GlowColors.ink),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: onToggleObscure == null
          ? null
          : IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
            ),
    ),
  );
}
