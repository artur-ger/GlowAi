import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

/// App UI language: ru | en. Persisted; drives [S] and MaterialApp locale.
class AppLocale extends ChangeNotifier {
  AppLocale._();
  static final AppLocale instance = AppLocale._();

  static const _prefsKey = 'glowai_locale_v1';

  String _code = 'ru';
  bool _ready = false;

  String get code => _code;
  bool get isRu => _code == 'ru';
  bool get isEn => _code == 'en';
  bool get ready => _ready;
  Locale get locale => Locale(_code);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'en' || saved == 'ru') {
      _code = saved!;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setCode(String code) async {
    if (code != 'ru' && code != 'en') return;
    if (_code == code) return;
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
    notifyListeners();
  }

  String t(String key) => S.text(key, _code);
}
