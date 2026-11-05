import 'package:shared_preferences/shared_preferences.dart';

import 'climate_reminders_stub.dart'
    if (dart.library.html) 'climate_reminders_web.dart' as platform;

/// Leave/return reminders: in-app banner + optional web Notification.
class ClimateReminders {
  static const _enabledKey = 'glowai_climate_reminders_v1';
  static const _lastFireKey = 'glowai_climate_remind_last_v1';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> enableWithPermission() async {
    final ok = await platform.requestClimateNotificationPermission();
    await setEnabled(ok);
    return ok;
  }

  /// Fire at most once per moment+day when leave/return window is active.
  Future<void> maybeNotify({
    required String moment,
    required String title,
    required String body,
  }) async {
    if (moment != 'leave' && moment != 'return') return;
    if (!await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final stamp = '$day:$moment';
    if (prefs.getString(_lastFireKey) == stamp) return;
    await platform.showClimateWebNotification(title: title, body: body);
    await prefs.setString(_lastFireKey, stamp);
  }
}
