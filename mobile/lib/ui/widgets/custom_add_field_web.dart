// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

int _nextViewId = 0;

Widget buildCustomAddField({
  required String hint,
  required ValueChanged<String> onSubmit,
  required bool enabled,
  required Color accent,
}) {
  return _WebCustomAddField(
    hint: hint,
    onSubmit: onSubmit,
    enabled: enabled,
    accent: accent,
  );
}

/// Web: keep [HtmlElementView] unmounted until tap — otherwise platform-view
/// DOM layers steal clicks from widgets above (city tiles, chips, etc.).
class _WebCustomAddField extends StatefulWidget {
  const _WebCustomAddField({
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
  State<_WebCustomAddField> createState() => _WebCustomAddFieldState();
}

class _WebCustomAddFieldState extends State<_WebCustomAddField> {
  bool _active = false;
  String? _viewType;
  html.DivElement? _root;
  html.InputElement? _input;
  html.ButtonElement? _button;

  @override
  void didUpdateWidget(covariant _WebCustomAddField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final input = _input;
    final button = _button;
    if (input != null) {
      input.disabled = !widget.enabled;
      if (oldWidget.hint != widget.hint) {
        input.placeholder = widget.hint;
      }
    }
    if (button != null) {
      button.disabled = !widget.enabled;
    }
    if (!widget.enabled && _active) {
      setState(() => _active = false);
    }
  }

  @override
  void dispose() {
    _tearDownPlatformView();
    super.dispose();
  }

  void _tearDownPlatformView() {
    _input?.remove();
    _button?.remove();
    _root?.remove();
    _input = null;
    _button = null;
    _root = null;
    _viewType = null;
  }

  void _ensurePlatformView() {
    if (_viewType != null) return;

    final border = widget.accent == GlowColors.coral
        ? '1px solid rgba(196, 92, 72, 0.35)'
        : '1px solid #D5E3E0';
    final accentHex = _cssHex(widget.accent);
    final viewType = 'glowai-custom-add-${_nextViewId++}';

    final root = html.DivElement()
      ..style.cssText = '''
      width: 100%;
      height: 48px;
      position: relative;
      box-sizing: border-box;
      pointer-events: auto;
    ''';

    final input = html.InputElement(type: 'text')
      ..className = 'glowai-native-input'
      ..placeholder = widget.hint
      ..maxLength = 80
      ..disabled = !widget.enabled
      ..style.cssText = '''
      width: 100%;
      height: 48px;
      box-sizing: border-box;
      margin: 0;
      padding: 0 44px 0 14px;
      border: $border;
      border-radius: 12px;
      background: #ffffff;
      color: #142429;
      font-size: 14px;
      font-family: inherit;
      line-height: 48px;
      outline: none;
    ''';
    input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        _submit();
      }
    });
    input.onBlur.listen((_) {
      // Collapse back to Flutter placeholder when empty so DOM can't linger.
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        final value = _input?.value?.trim() ?? '';
        if (value.isEmpty) {
          setState(() => _active = false);
        }
      });
    });

    final button = html.ButtonElement()
      ..type = 'button'
      ..title = 'Add'
      ..text = '+'
      ..disabled = !widget.enabled
      ..style.cssText = '''
      position: absolute;
      right: 4px;
      top: 4px;
      width: 40px;
      height: 40px;
      border: none;
      border-radius: 20px;
      background: transparent;
      color: $accentHex;
      font-size: 22px;
      line-height: 40px;
      cursor: pointer;
      padding: 0;
    ''';
    button.onClick.listen((_) => _submit());

    root.append(input);
    root.append(button);

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => root,
    );

    _viewType = viewType;
    _root = root;
    _input = input;
    _button = button;
  }

  void _activate() {
    if (!widget.enabled || _active) return;
    _ensurePlatformView();
    setState(() => _active = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _input?.focus();
    });
  }

  void _submit() {
    if (!widget.enabled) return;
    final value = _input?.value ?? '';
    if (_input != null) _input!.value = '';
    setState(() => _active = false);
    widget.onSubmit(value);
  }

  static String _cssHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.accent == GlowColors.coral
        ? GlowColors.coral.withValues(alpha: 0.35)
        : GlowColors.line;

    if (!_active || _viewType == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? _activate : null,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: GlowColors.muted.withValues(alpha: widget.enabled ? 1 : 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.add_rounded, color: widget.accent, size: 22),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: HtmlElementView(viewType: _viewType!),
    );
  }
}
