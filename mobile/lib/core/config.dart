import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  /// Priority:
  /// 1) --dart-define=API_BASE_URL=...
  /// 2) on web: same origin (when UI served from FastAPI)
  /// 3) local backend default
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') return origin;
    }
    return 'http://127.0.0.1:8000';
  }
}
