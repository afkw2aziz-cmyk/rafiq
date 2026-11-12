import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'pixel_companion';
  static const _channelName = 'PixelCompanion';
  static const _channelDesc = 'Reminders, briefs and alerts';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    _ready = true;
  }

  Future<void> requestPermission() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  AndroidNotificationDetails get _details => const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );

  Future<void> show(int id, String title, String body) async {
    await init();
    await _plugin.show(id, title, body, NotificationDetails(android: _details));
  }

  /// Schedules an absolute instant. UTC is used so no device timezone plugin is
  /// required; notification delivery is absolute anyway.
  Future<bool> scheduleAt(
    int id,
    DateTime when,
    String title,
    String body,
  ) async {
    await init();
    if (when.isBefore(DateTime.now())) return false;
    final at = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        NotificationDetails(android: _details),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          NotificationDetails(android: _details),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
