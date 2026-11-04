import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

Widget buildCustomAddField({
  required String hint,
  required ValueChanged<String> onSubmit,
  required bool enabled,
  required Color accent,
}) {
  return _IoCustomAddField(
    hint: hint,
    onSubmit: onSubmit,
    enabled: enabled,
    accent: accent,
  );
}

class _IoCustomAddField extends StatefulWidget {
  const _IoCustomAddField({
    required this.hint,
    required this.onSubmit,
    required this.enabled,
    required this.accent,
  });

  final String hint;
  final ValueChanged<String> onSubmit;
  final bool enabled;
  final Color accent;

  @override
  State<_IoCustomAddField> createState() => _IoCustomAddFieldState();
}

class _IoCustomAddFieldState extends State<_IoCustomAddField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text;
    _controller.clear();
    widget.onSubmit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final idleBorder = widget.accent == GlowColors.coral
        ? GlowColors.coral.withValues(alpha: 0.35)
        : GlowColors.line;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        maxLines: 1,
        style: const TextStyle(fontSize: 14, height: 1.2, color: GlowColors.ink),
        cursorColor: widget.accent,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        inputFormatters: [LengthLimitingTextInputFormatter(80)],
        decoration: InputDecoration(
          hintText: widget.hint,
          hintMaxLines: 1,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: idleBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.accent, width: 1.4),
          ),
          suffixIcon: IconButton(
            onPressed: widget.enabled ? _submit : null,
            icon: Icon(Icons.add_circle_outline, color: widget.accent),
          ),
        ),
      ),
    );
  }
}
