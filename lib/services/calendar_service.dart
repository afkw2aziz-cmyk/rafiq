import 'package:flutter/services.dart';

class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.calendarName = '',
    this.allDay = false,
  });

  final int id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final String calendarName;
  final bool allDay;

  factory CalendarEntry.fromMap(Map<dynamic, dynamic> m) => CalendarEntry(
        id: (m['id'] as num?)?.toInt() ?? -1,
        title: m['title'] as String? ?? '',
        start: DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()),
        end: DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt()),
        location: m['location'] as String? ?? '',
        calendarName: m['calendar'] as String? ?? '',
        allDay: m['allDay'] as bool? ?? false,
      );
}

class CalendarPermissionException implements Exception {
  @override
  String toString() => 'Calendar permission denied';
}

class CalendarService {
  static const MethodChannel _channel = MethodChannel('pixelcompanion/calendar');

  Future<List<Map<String, dynamic>>> calendars() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('calendars');
      return (raw ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PlatformException catch (e) {
      if (e.code == 'permission') throw CalendarPermissionException();
      rethrow;
    }
  }

  Future<List<CalendarEntry>> events(DateTime from, DateTime to) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('events', {
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
      });
      return (raw ?? [])
          .map((e) => CalendarEntry.fromMap(e as Map))
          .toList();
    } on PlatformException catch (e) {
      if (e.code == 'permission') throw CalendarPermissionException();
      rethrow;
    }
  }

  Future<int?> insert({
    required String title,
    required DateTime start,
    required DateTime end,
    String location = '',
    String description = '',
  }) async {
    try {
      return await _channel.invokeMethod<int>('insert', {
        'title': title,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'location': location,
        'description': description,
      });
    } on PlatformException catch (e) {
      if (e.code == 'permission') throw CalendarPermissionException();
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    try {
      final ok = await _channel.invokeMethod<bool>('delete', {'id': id});
      return ok ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'permission') throw CalendarPermissionException();
      return false;
    }
  }
}
