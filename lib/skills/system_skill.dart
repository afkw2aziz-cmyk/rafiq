import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../core/state.dart';
import 'skill.dart';

class SystemSkill extends Skill {
  final Battery _battery = Battery();

  @override
  String get id => 'system';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'system',
        nameAr: 'حالة الجهاز',
        nameEn: 'System',
        descriptionAr: 'البطارية والشحن والوقت وحالة النوم.',
        descriptionEn: 'Battery, charging, time and sleep state.',
        icon: Icons.battery_charging_full,
        triggers: [
          r'بطارية|شحن|البطارية|حالة الجهاز|battery|charging|device status',
          r'^(نوم|ننام|sleep|good night|تصبح على خير)',
        ],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final t = req.text.toLowerCase();
    final ar = req.ctx.isArabic;

    if (RegExp(r'^(نوم|ننام|sleep|good night|تصبح على خير)').hasMatch(t)) {
      return SkillResponse(
        text: ar ? 'تصبح على خير، أنا هنا لو احتجتني.' : 'Good night. I will be here.',
        face: CompanionState.sleeping,
        speak: false,
      );
    }

    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      final charging = state == BatteryState.charging || state == BatteryState.full;
      final time = _time(ar);
      final text = ar
          ? 'البطارية $level%${charging ? ' وتشحن الآن' : ''}، والساعة $time.'
          : 'Battery is $level%${charging ? ' and charging' : ''}. It is $time.';
      return SkillResponse(text: text, face: CompanionState.happy);
    } catch (_) {
      return SkillResponse(
        text: ar ? 'ما قدرت أقرأ حالة البطارية.' : 'I could not read the battery state.',
        face: CompanionState.sad,
      );
    }
  }

  String _time(bool ar) {
    final d = DateTime.now();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return ar ? '$h:$m' : '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
