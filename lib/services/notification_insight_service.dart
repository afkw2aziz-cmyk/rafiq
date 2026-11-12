import 'package:flutter/services.dart';

/// One captured notification: app label + title only. Never the body.
class CapturedNotification {
  const CapturedNotification({
    required this.app,
    required this.title,
    required this.at,
    required this.package,
  });

  final String app;
  final String title;
  final DateTime at;
  final String package;

  static CapturedNotification? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final app = raw['app'] as String?;
    final title = raw['title'] as String?;
    if (app == null || title == null) return null;
    final atMs = (raw['at'] as num?)?.toInt() ?? 0;
    return CapturedNotification(
      app: app,
      title: title,
      at: DateTime.fromMillisecondsSinceEpoch(atMs),
      package: raw['package'] as String? ?? '',
    );
  }
}

/// Thin Dart bridge over the Android NotificationListenerService.
///
/// Privacy contract (mirrored in Kotlin):
///  - Only app label + title cross the channel.
///  - The native buffer is in-memory, capped at 50, and drained on read.
///  - Nothing is written to disk.
class NotificationInsightService {
  static const _channel = MethodChannel('pixelcompanion/notifications');

  /// Whether the user has granted Notification Access in system settings.
  Future<bool> isGranted() async {
    try {
      final v = await _channel.invokeMethod<bool>('isEnabled');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns and clears everything captured since the last call.
  Future<List<CapturedNotification>> drain() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('drain');
      if (raw == null) return const [];
      return raw
          .map(CapturedNotification.fromMap)
          .whereType<CapturedNotification>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Peek without clearing (used for a live settings preview).
  Future<List<CapturedNotification>> peek() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('peek');
      if (raw == null) return const [];
      return raw
          .map(CapturedNotification.fromMap)
          .whereType<CapturedNotification>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
