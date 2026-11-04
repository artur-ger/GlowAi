import 'package:flutter/foundation.dart';

/// Lightweight invalidate bus: bump only when profile data actually changes.
/// Profile listens and refetches; no polling, no refresh on every frame.
class AppSync extends ChangeNotifier {
  AppSync._();
  static final AppSync instance = AppSync._();

  int _checksEpoch = 0;
  int _sessionEpoch = 0;

  int get checksEpoch => _checksEpoch;
  int get sessionEpoch => _sessionEpoch;

  /// Saved / deleted check, remind set, etc.
  void checksChanged() {
    _checksEpoch++;
    notifyListeners();
  }

  /// Login / logout / delete account / verify.
  void sessionChanged() {
    _sessionEpoch++;
    notifyListeners();
  }
}
