// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'native_text_controller.dart';

int _nextId = 0;

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
  return _WebNativeTextField(
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

class _WebNativeTextField extends StatefulWidget {
  const _WebNativeTextField({
    required this.controller,
    this.label,
    this.hint,
    required this.enabled,
    required this.obscureText,
    required this.autofocus,
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
    final leftPad = widget.prefixIcon != null ? 42 : 14;
    final rightPad = widget.onToggleObscure != null ? 44 : 14;

    _root = html.DivElement();
    _root.style.cssText = 'width:100%;position:relative;box-sizing:border-box;';

    _input = html.InputElement();
    _input.className = 'glowai-native-input';
    _input.value = widget.controller.text;
    _input.disabled = !widget.enabled;
    _input.placeholder = widget.hint ?? widget.label ?? '';
    _input.autofocus = widget.autofocus;
    _input.style.cssText = '''
      width: 100%;
      height: 52px;
      box-sizing: border-box;
      margin: 0;
      padding: 0 ${rightPad}px 0 ${leftPad}px;
      border: 1px solid #D5E3E0;
      border-radius: 12px;
      background: #ffffff;
      color: #142429;
      font-size: 15px;
      font-family: inherit;
      outline: none;
    ''';
    _applyInputType();

    void pushToFlutter() {
      if (_syncing) return;
      _syncing = true;
      final live = _input.value ?? '';
      widget.controller.value = TextEditingValue(
        text: live,
        selection: TextSelection.collapsed(offset: live.length),
      );
      _syncing = false;
      widget.onChanged?.call(live);
    }

    _input.onInput.listen((_) => pushToFlutter());
    _input.onChange.listen((_) => pushToFlutter());
    _input.onBlur.listen((_) => pushToFlutter());
    _input.onKeyDown.listen((event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        pushToFlutter();
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

    _bindController(widget.controller);
    widget.controller.addListener(_onController);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) => _root);

    if (widget.autofocus) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        _input.focus();
      });
    }
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

  void _bindController(TextEditingController controller) {
    if (controller is NativeTextEditingController) {
      controller.bindWeb(
        read: () => _input.value ?? '',
        write: (value) {
          if (_input.value != value) _input.value = value;
        },
      );
    }
  }

  @override
  void didUpdateWidget(covariant _WebNativeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      if (oldWidget.controller is NativeTextEditingController) {
        (oldWidget.controller as NativeTextEditingController).unbindWeb();
      }
      // value.text is Flutter storage; .text may already proxy another HTML input
      final stored = widget.controller.value.text;
      _bindController(widget.controller);
      widget.controller.addListener(_onController);
      _syncing = true;
      _input.value = stored;
      _syncing = false;
    }
    _input.disabled = !widget.enabled;
    _applyInputType();
    _input.placeholder = widget.hint ?? widget.label ?? '';
    _eye?.text = widget.obscureText ? '👁' : '🙈';
    _eye?.title = widget.obscureText ? 'Показать' : 'Скрыть';
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    final c = widget.controller;
    if (c is NativeTextEditingController) c.unbindWeb();
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
