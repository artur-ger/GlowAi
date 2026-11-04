// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

int _nextId = 0;

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
  return _WebNativeTextField(
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

class _WebNativeTextField extends StatefulWidget {
  const _WebNativeTextField({
    required this.controller,
    this.label,
    this.hint,
    required this.enabled,
    required this.obscureText,
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
  State<_WebNativeTextField> createState() => _WebNativeTextFieldState();
}

class _WebNativeTextFieldState extends State<_WebNativeTextField> {
  late final String _viewType;
  late final html.DivElement _root;
  late final html.InputElement _input;
  html.ButtonElement? _eye;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'glowai-native-tf-${_nextId++}';
    _root = html.DivElement()
      ..style.cssText = 'width:100%;position:relative;box-sizing:border-box;';

    _input = html.InputElement()
      ..className = 'glowai-native-input'
      ..value = widget.controller.text
      ..disabled = !widget.enabled
      ..placeholder = widget.hint ?? widget.label ?? ''
      ..style.cssText = '''
        width: 100%;
        height: 52px;
        box-sizing: border-box;
        margin: 0;
        padding: 0 ${widget.onToggleObscure != null ? '44' : '14'}px 0 14px;
        border: 1px solid #D5E3E0;
        border-radius: 12px;
        background: #ffffff;
        color: #142429;
        font-size: 15px;
        font-family: inherit;
        outline: none;
      ''';
    _applyInputType();
    _input.onInput.listen((_) {
      if (_syncing) return;
      _syncing = true;
      widget.controller.value = TextEditingValue(
        text: _input.value ?? '',
        selection: TextSelection.collapsed(offset: (_input.value ?? '').length),
      );
      _syncing = false;
    });
    _input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        widget.onSubmitted?.call(_input.value ?? '');
      }
    });
    _root.append(_input);

    if (widget.onToggleObscure != null) {
      final eye = html.ButtonElement();
      eye.type = 'button';
      eye.text = widget.obscureText ? '👁' : '🙈';
      eye.title = widget.obscureText ? 'Показать' : 'Скрыть';
      eye.style.cssText = '''
        position: absolute;
        right: 4px;
        top: 6px;
        width: 40px;
        height: 40px;
        border: none;
        background: transparent;
        cursor: pointer;
        font-size: 16px;
      ''';
      eye.onClick.listen((_) => widget.onToggleObscure?.call());
      _eye = eye;
      _root.append(eye);
    }

    widget.controller.addListener(_onController);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) => _root);
  }

  void _applyInputType() {
    if (widget.obscureText) {
      _input.type = 'password';
    } else if (widget.keyboardType == TextInputType.emailAddress) {
      _input.type = 'email';
    } else if (widget.keyboardType == TextInputType.number) {
      _input.type = 'tel';
    } else {
      _input.type = 'text';
    }
  }

  void _onController() {
    if (_syncing) return;
    final next = widget.controller.text;
    if (_input.value != next) {
      _syncing = true;
      _input.value = next;
      _syncing = false;
    }
  }

  @override
  void didUpdateWidget(covariant _WebNativeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _input.disabled = !widget.enabled;
    _applyInputType();
    _input.placeholder = widget.hint ?? widget.label ?? '';
    _eye?.text = widget.obscureText ? '👁' : '🙈';
    _eye?.title = widget.obscureText ? 'Показать' : 'Скрыть';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GlowColors.muted,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 52,
          width: double.infinity,
          child: HtmlElementView(viewType: _viewType),
        ),
      ],
    );
  }
}
