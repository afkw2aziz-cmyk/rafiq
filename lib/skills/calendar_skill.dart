import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/calendar_service.dart';
import '../services/natural_time.dart';
import 'skill.dart';

class CalendarSkill extends Skill {
  @override
  String get id => 'calendar';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'calendar',
        nameAr: 'التقويم',
        nameEn: 'Calendar',
        descriptionAr: 'يقرأ مواعيدك من تقويم الجهاز ويضيف مواعيد جديدة بالكلام.',
        descriptionEn: 'Reads the device calendar and creates events by voice.',
        icon: Icons.calendar_month_outlined,
        permissions: {'calendar'},
        triggers: [
          r'موعد|مواعيد|اجتماع|جدول|تقويم|meeting|appointment|calendar|schedule',
        ],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    final t = req.text.toLowerCase();
    final wantsList = RegExp(r'مواعيدي|مواعيد|جدولي|وش عندي|إيش عندي|what.*calendar|my (events|schedule)|upcoming')
        .hasMatch(t);

    if (RegExp(r'ألغ|الغ|cancel|delete').hasMatch(t)) {
      return SkillResponse(
        text: ar
            ? 'حذف المواعيد من التطبيق غير مفعّل بعد. افتح تطبيق التقويم مباشرة للحذف.'
            : 'Deleting events is not enabled yet. Use the Calendar app directly.',
        face: CompanionState.sad,
      );
    }

    if (wantsList) {
      try {
        final now = DateTime.now();
        final events = await req.ctx.calendar
            .events(now, now.add(const Duration(days: 7)));
        if (events.isEmpty) {
          return SkillResponse(
            text: ar ? 'ما عندك مواعيد في الأيام السبعة القادمة.' : 'No events in the next 7 days.',
            face: CompanionState.idle,
          );
        }
        final lines = events.take(5).map((e) {
          return '• ${_fmt(e.start, ar)} — ${e.title}';
        }).join('\n');
        return SkillResponse(
          text: ar ? 'أقرب مواعيدك:\n$lines' : 'Your next events:\n$lines',
          face: CompanionState.idle,
        );
      } on CalendarPermissionException {
        return _needPermission(ar);
      } catch (_) {
        return SkillResponse(
          text: ar ? 'تعذّر قراءة التقويم.' : 'Could not read the calendar.',
          face: CompanionState.sad,
        );
      }
    }

    final parsed = parseWhen(req.text);
    if (parsed.when == null) {
      return SkillResponse(
        text: ar
            ? 'متى الموعد؟ قل مثلًا: أضف اجتماع بكرة الساعة 3.'
            : 'When is it? Try: add a meeting tomorrow at 3.',
        face: CompanionState.sad,
      );
    }
    final title = parsed.title.isEmpty
        ? (ar ? 'موعد' : 'Event')
        : parsed.title;
    try {
      final id = await req.ctx.calendar.insert(
        title: title,
        start: parsed.when!,
        end: parsed.when!.add(const Duration(hours: 1)),
      );
      if (id == null) throw Exception('insert failed');
      final whenText = _fmt(parsed.when!, ar);
      return SkillResponse(
        text: ar
            ? 'أضفت «$title» في $whenText إلى تقويمك.'
            : 'Added “$title” on $whenText to your calendar.',
        face: CompanionState.happy,
      );
    } on CalendarPermissionException {
      return _needPermission(ar);
    } catch (_) {
      return SkillResponse(
        text: ar ? 'ما قدرت أضيف الموعد.' : 'I could not create the event.',
        face: CompanionState.sad,
      );
    }
  }

  SkillResponse _needPermission(bool ar) => SkillResponse(
        text: ar
            ? 'أحتاج إذن التقويم. فعّله من الإعدادات › الصلاحيات.'
            : 'I need calendar permission. Enable it in Settings › Permissions.',
        face: CompanionState.sad,
      );

  String _fmt(DateTime d, bool ar) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final suffix = ar ? (d.hour < 12 ? 'ص' : 'م') : (d.hour < 12 ? 'AM' : 'PM');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $h:$m $suffix';
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
