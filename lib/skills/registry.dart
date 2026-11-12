import 'calendar_skill.dart';
import 'chat_skill.dart';
import 'hourly_digest_skill.dart';
import 'news_skill.dart';
import 'notification_insight_skill.dart';
import 'reminder_skill.dart';
import 'skill.dart';
import 'stock_skill.dart';
import 'system_skill.dart';
import 'weather_skill.dart';

class SkillRegistry {
  final Map<String, Skill> _skills = {};

  void register(Skill skill) => _skills[skill.id] = skill;

  List<Skill> get all => _skills.values.toList();

  Skill? byId(String id) => _skills[id];

  Skill? match(String text) {
    for (final skill in _skills.values) {
      if (skill.id == 'chat') continue;
      for (final pattern in skill.manifest.triggers) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
          return skill;
        }
      }
    }
    return null;
  }

  static SkillRegistry bootstrap() {
    final r = SkillRegistry();
    r
      ..register(SystemSkill())
      ..register(WeatherSkill())
      ..register(ReminderSkill())
      ..register(CalendarSkill())
      ..register(ChatSkill())
      ..register(HourlyDigestSkill())
      ..register(NewsSkill())
      ..register(StockSkill())
      ..register(NotificationInsightSkill());
    return r;
  }
}
