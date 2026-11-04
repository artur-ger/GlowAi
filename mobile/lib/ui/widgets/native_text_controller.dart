import 'package:flutter/widgets.dart';

/// TextEditingController that can read live value from a web HTML input.
class NativeTextEditingController extends TextEditingController {
  NativeTextEditingController({super.text});

  String Function()? _webRead;
  void Function(String value)? _webWrite;

  void bindWeb({
    required String Function() read,
    required void Function(String value) write,
  }) {
    _webRead = read;
    _webWrite = write;
  }

  void unbindWeb() {
    _webRead = null;
    _webWrite = null;
  }

  /// Always prefer the live HTML value on web when bound.
  @override
  String get text => _webRead?.call() ?? super.text;

  @override
  set text(String newText) {
    super.text = newText;
    _webWrite?.call(newText);
  }

  /// Pull HTML → Flutter value before API calls.
  void flushFromWeb() {
    final live = _webRead?.call();
    if (live == null) return;
    if (super.text == live) return;
    super.value = TextEditingValue(
      text: live,
      selection: TextSelection.collapsed(offset: live.length),
    );
  }
}
