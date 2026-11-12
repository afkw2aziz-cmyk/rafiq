import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings.dart';
import '../core/state.dart';
import '../services/calendar_service.dart';
import '../services/notification_service.dart';

class SkillManifest {
  const SkillManifest({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.icon,
    this.permissions = const {},
    this.triggers = const [],
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final IconData icon;
  final Set<String> permissions;

  /// Regex patterns (case-insensitive) used for cheap intent routing.
  final List<String> triggers;

  String name(bool ar) => ar ? nameAr : nameEn;
  String description(bool ar) => ar ? descriptionAr : descriptionEn;
}

class SkillRequest {
  const SkillRequest({required this.text, required this.ctx, this.args});
  final String text;
  final SkillContext ctx;
  final Map<String, dynamic>? args;
}

class SkillResponse {
  const SkillResponse({
    required this.text,
    this.face = CompanionState.happy,
    this.data,
    this.speak = true,
  });

  final String text;
  final CompanionState face;
  final Object? data;
  final bool speak;

  static SkillResponse error(String text) =>
      SkillResponse(text: text, face: CompanionState.sad);
}

class SkillEvent {
  const SkillEvent({required this.text, this.face = CompanionState.surprised});
  final String text;
  final CompanionState face;
}

class SkillStorage {
  SkillStorage(this._prefs);
  final SharedPreferences _prefs;

  int bump(String key) {
    final n = (_prefs.getInt('counter_$key') ?? 0) + 1;
    _prefs.setInt('counter_$key', n);
    return n;
  }

  String? get(String key) => _prefs.getString('kv_$key');
  Future<void> set(String key, String value) => _prefs.setString('kv_$key', value);
}

class SkillContext {
  SkillContext({
    required this.settings,
    required this.http,
    required this.notifications,
    required this.calendar,
    required this.storage,
    required this.setFace,
  });

  final AppSettings settings;
  final Dio http;
  final NotificationService notifications;
  final CalendarService calendar;
  final SkillStorage storage;
  final void Function(CompanionState) setFace;

  bool get isArabic => settings.isArabic;
  DateTime get now => DateTime.now();

  String pick(String ar, String en) => isArabic ? ar : en;

  Future<void> refreshSettings(AppSettings s) async {
    // Skills read settings through the context; the engine rebuilds the
    // context for every invocation, so this is intentionally a no-op hook.
  }
}

abstract class Skill {
  String get id;
  SkillManifest get manifest;
  Future<void> init(SkillContext ctx) async {}
  Future<SkillResponse> invoke(SkillRequest req);
  Stream<SkillEvent> get events => const Stream.empty();
  Widget? buildSettings(BuildContext context) => null;
}
