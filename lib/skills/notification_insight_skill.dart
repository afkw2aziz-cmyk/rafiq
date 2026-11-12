import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/notification_insight_service.dart';
import 'skill.dart';

/// Opt-in "what did I miss?" skill.
///
/// Reads the phone's own notifications (app label + title only) that the
/// NotificationListenerService captured while the user was away. Off by
/// default; the user must both enable the skill and grant Notification Access.
class NotificationInsightSkill extends Skill {
  final NotificationInsightService _service = NotificationInsightService();

  @override
  String get id => 'notifications';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'notifications',
        nameAr: 'الإشعارات',
        nameEn: 'Notifications',
        descriptionAr:
            'يلخّص الإشعارات التي وصلتك (اسم التطبيق والعنوان فقط، بدون النص).',
        descriptionEn:
            'Summarises notifications you received (app + title only, never the body).',
        icon: Icons.notifications_active_outlined,
        triggers: [
          r'إشعار|إشعارات|وش فاتني|وش صار|وش صار بالجوال|notific|what did i miss|missed something',
        ],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;

    if (!req.ctx.settings.notificationInsight) {
      return SkillResponse(
        text: ar
            ? 'خاصية الإشعارات مقفلة. فعّلها من الإعدادات أولاً.'
            : 'Notification insight is off. Enable it in Settings first.',
        face: CompanionState.sad,
        speak: false,
      );
    }

    if (!await _service.isGranted()) {
      return SkillResponse(
        text: ar
            ? 'لازم تعطيني صلاحية الإشعارات من إعدادات أندرويد: الإعدادات ← التطبيقات ← صلاحية الإشعارات.'
            : 'I need Notification Access. Grant it in Android Settings → Apps → Notification access.',
        face: CompanionState.sad,
        speak: false,
      );
    }

    final items = await _service.drain();
    if (items.isEmpty) {
      return SkillResponse(
        text: ar ? 'ما في إشعارات جديدة.' : 'No new notifications.',
        face: CompanionState.happy,
      );
    }

    // Group by app and present the most recent few per app.
    final byApp = <String, List<CapturedNotification>>{};
    for (final n in items) {
      byApp.putIfAbsent(n.app, () => []).add(n);
    }

    final lines = <String>[];
    for (final entry in byApp.entries) {
      // Newest first, cap 3 per app so the summary stays short.
      final titles = entry.value
          .sorted((a, b) => b.at.compareTo(a.at))
          .take(3)
          .map((e) => e.title)
          .join(ar ? '، ' : ', ');
      lines.add('${entry.key}: $titles');
    }

    final total = items.length;
    final head = ar
        ? 'وصلتك $total إشعار${total == 1 ? '' : 'ات'}:'
        : 'You got $total notification${total == 1 ? '' : 's'}:';
    final body = lines.take(6).join('\n');
    return SkillResponse(text: '$head\n$body', face: CompanionState.happy);
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}

extension _SortedList<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}
