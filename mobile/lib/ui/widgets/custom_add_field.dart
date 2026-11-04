import 'package:flutter/material.dart';

import 'custom_add_field_io.dart'
    if (dart.library.html) 'custom_add_field_web.dart' as impl;

/// Inline “type and add” field.
/// Web: real HTML input (Flutter TextField hybrid editor paints a grey overlay).
/// IO: normal [TextField].
class CustomAddField extends StatelessWidget {
  const CustomAddField({
    super.key,
    required this.hint,
    required this.onSubmit,
    this.enabled = true,
    this.accent = const Color(0xFF0F6E6A),
  });

  final String hint;
  final ValueChanged<String> onSubmit;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return impl.buildCustomAddField(
      hint: hint,
      onSubmit: onSubmit,
      enabled: enabled,
      accent: accent,
    );
  }
}
