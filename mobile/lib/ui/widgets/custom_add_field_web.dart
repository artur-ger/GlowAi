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
  late final String _viewType;
  late final html.DivElement _root;
  late final html.InputElement _input;
  late final html.ButtonElement _button;

  @override
  void initState() {
    super.initState();
    _viewType = 'glowai-custom-add-${_nextViewId++}';

    final border = widget.accent == GlowColors.coral
        ? '1px solid rgba(196, 92, 72, 0.35)'
        : '1px solid #D5E3E0';
    final accentHex = _cssHex(widget.accent);

    _root = html.DivElement();
    _root.style.cssText = '''
      width: 100%;
      height: 48px;
      position: relative;
      box-sizing: border-box;
    ''';

    _input = html.InputElement(type: 'text');
    _input.className = 'glowai-native-input';
    _input.placeholder = widget.hint;
    _input.maxLength = 80;
    _input.disabled = !widget.enabled;
    _input.style.cssText = '''
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
    _input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        _submit();
      }
    });

    _button = html.ButtonElement();
    _button.type = 'button';
    _button.title = 'Add';
    _button.text = '+';
    _button.disabled = !widget.enabled;
    _button.style.cssText = '''
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
    _button.onClick.listen((_) => _submit());

    _root.append(_input);
    _root.append(_button);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _root,
    );
  }

  @override
  void didUpdateWidget(covariant _WebCustomAddField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _input.disabled = !widget.enabled;
    _button.disabled = !widget.enabled;
    if (oldWidget.hint != widget.hint) {
      _input.placeholder = widget.hint;
    }
  }

  void _submit() {
    if (!widget.enabled) return;
    final value = _input.value ?? '';
    _input.value = '';
    widget.onSubmit(value);
  }

  static String _cssHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
