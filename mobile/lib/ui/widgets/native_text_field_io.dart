import 'package:flutter/material.dart';

import '../../core/theme.dart';

Widget buildNativeTextField({
  required TextEditingController controller,
  String? label,
  String? hint,
  bool enabled = true,
  bool obscureText = false,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  ValueChanged<String>? onSubmitted,
  VoidCallback? onToggleObscure,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    obscureText: obscureText,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onSubmitted: onSubmitted,
    style: const TextStyle(color: GlowColors.ink),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
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
