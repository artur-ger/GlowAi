// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> requestClimateNotificationPermission() async {
  final perm = html.Notification.permission;
  if (perm == 'granted') return true;
  if (perm == 'denied') return false;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

Future<void> showClimateWebNotification({
  required String title,
  required String body,
}) async {
  if (html.Notification.permission != 'granted') return;
  html.Notification(title, body: body);
}
