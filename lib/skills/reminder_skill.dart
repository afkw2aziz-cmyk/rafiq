import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/natural_time.dart';
import 'skill.dart';

class ReminderSkill extends Skill {
  static const _key = 'reminders';

  @override
  String get id => 'reminder';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'reminder',
        nameAr: 'التذكيرات',
        nameEn: 'Reminders',
        descriptionAr: 'تذكيرات بالوقت من الكلام الطبيعي، مع إشعار.',
        descriptionEn: 'Natural-language time reminders with a notification.',
        icon: Icons.alarm,
        permissions: {'notifications'},
        triggers: [
          r'ذكرني|ذكّرني|تذكير|remind me|reminder|set a reminder',
          r'تذكيراتي|قائمة التذكيرات|my reminders|list reminders',
        ],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    final t = req.text.toLowerCase();

    if (RegExp(r'تذكيراتي|قائمة التذكيرات|my reminders|list reminders')
        .hasMatch(t)) {
      final items = _load(req.ctx);
      if (items.isEmpty) {
        return SkillResponse(
          text: ar ? 'ما عندك تذكيرات قادمة.' : 'You have no upcoming reminders.',
          face: CompanionState.idle,
        );
      }
      final lines = items.take(5).map((e) {
        final when = DateTime.tryParse(e['when'] as String? ?? '');
        return '• ${e['title']} — ${when == null ? '' : _fmt(when, ar)}';
      }).join('\n');
      return SkillResponse(
        text: ar ? 'تذكيراتك:\n$lines' : 'Your reminders:\n$lines',
        face: CompanionState.idle,
      );
    }

    if (RegExp(r'ألغ|الغ|cancel|delete').hasMatch(t) &&
        RegExp(r'تذكير|reminder').hasMatch(t)) {
      for (final e in _load(req.ctx)) {
        final id = e['id'];
        if (id is int) await req.ctx.notifications.cancel(id);
      }
      await req.ctx.storage.set(_key, '[]');
      return SkillResponse(
        text: ar ? 'ألغيت كل التذكيرات.' : 'All reminders cancelled.',
        face: CompanionState.happy,
      );
    }

    final parsed = parseWhen(req.text);
    if (parsed.when == null) {
      return SkillResponse(
        text: ar
            ? 'متى أذكّرك؟ قل مثلًا: ذكرني أتصل بأمي بكرة الساعة 5.'
            : 'When should I remind you? Try: remind me to call mom tomorrow at 5.',
        face: CompanionState.sad,
      );
    }

    final title = parsed.title.isEmpty
        ? (ar ? 'تذكير' : 'Reminder')
        : parsed.title;
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    final ok = await req.ctx.notifications.scheduleAt(
      id,
      parsed.when!,
      ar ? 'تذكير' : 'Reminder',
      title,
    );

    if (!ok) {
      return SkillResponse(
        text: ar
            ? 'ما قدرت أجدول الإشعار. فعّل إذن الإشعارات والمنبّهات من إعدادات النظام.'
            : 'I could not schedule the notification. Enable notifications and alarms in system settings.',
        face: CompanionState.sad,
      );
    }

    final items = _load(req.ctx)..add({
      'id': id,
      'title': title,
      'when': parsed.when!.toIso8601String(),
    });
    await req.ctx.storage.set(_key, jsonEncode(items));

    final whenText = _fmt(parsed.when!, ar);
    return SkillResponse(
      text: ar ? 'تم. أذكّرك: $title — $whenText.' : 'Done. I will remind you: $title — $whenText.',
      face: CompanionState.happy,
    );
  }

  List<Map<String, dynamic>> _load(SkillContext ctx) {
    final raw = ctx.storage.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final now = DateTime.now();
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) {
            final w = DateTime.tryParse(e['when'] as String? ?? '');
            return w != null && w.isAfter(now.subtract(const Duration(minutes: 1)));
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _fmt(DateTime d, bool ar) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final suffix = ar ? (d.hour < 12 ? 'ص' : 'م') : (d.hour < 12 ? 'AM' : 'PM');
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '$date $h:$m $suffix';
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
