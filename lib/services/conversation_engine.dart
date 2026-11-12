import 'package:dio/dio.dart';

import '../core/settings.dart';
import '../core/state.dart';
import '../skills/news_skill.dart';
import '../skills/registry.dart';
import '../skills/skill.dart';
import '../skills/weather_skill.dart';
import 'calendar_service.dart';
import 'intent_router.dart';
import 'notification_service.dart';
import 'tts_service.dart';

class ConversationEngine {
  ConversationEngine({
    required this.registry,
    required this.settings,
    required this.http,
    required this.notifications,
    required this.calendar,
    required this.tts,
    required this.storage,
    required this.setFace,
    this.onMessage,
  });

  final SkillRegistry registry;
  final AppSettings settings;
  final Dio http;
  final NotificationService notifications;
  final CalendarService calendar;
  final TtsService tts;
  final SkillStorage storage;
  final void Function(CompanionState state) setFace;
  final void Function(String who, String text)? onMessage;

  Future<SkillResponse> handle(
    String rawText, {
    bool speak = true,
    bool persist = true,
  }) async {
    final text = rawText.trim();
    final ar = settings.isArabic;
    if (text.isEmpty) {
      return SkillResponse(text: '', face: CompanionState.idle, speak: false);
    }

    if (persist) onMessage?.call('user', text);

    // 1) Try the model first: it understands natural phrasing the regexes miss
    //    ("كم تسوى تسلا الحين؟") and rewrites it into the compact form skills
    //    expect. 2) Fall back to the local regex registry when there is no key
    //    or the model is unreachable, so the app never depends on the network.
    Skill? skill;
    var routedText = text;
    final router = IntentRouter(settings: settings, dio: http);
    if (router.available && settings.smartRouting) {
      final decision = await router.decide(text, enabled: settings.enabledSkills);
      if (decision != null) {
        routedText = decision.text;
        if (decision.skillId != null) {
          final picked = registry.byId(decision.skillId!);
          if (picked != null && _isEnabled(picked.id)) skill = picked;
        }
      }
    }

    skill ??= registry.match(routedText);
    if (skill != null && !_isEnabled(skill.id)) {
      skill = null;
    }
    skill ??= registry.byId('chat');
    if (skill == null) {
      return SkillResponse(
        text: ar ? 'ما عندي مهارة لهذا الطلب.' : 'I have no skill for that.',
        face: CompanionState.sad,
      );
    }

    setFace(CompanionState.thinking);
    final ctx = SkillContext(
      settings: settings,
      http: http,
      notifications: notifications,
      calendar: calendar,
      storage: storage,
      setFace: setFace,
    );

    SkillResponse response;
    try {
      response = await skill.invoke(SkillRequest(text: routedText, ctx: ctx));
    } catch (_) {
      response = SkillResponse(
        text: ar ? 'صار خطأ غير متوقع. جرّب مرة ثانية.' : 'Something went wrong. Try again.',
        face: CompanionState.sad,
      );
    }

    setFace(response.face);
    if (persist) onMessage?.call('model', response.text);

    if (speak && response.speak && response.text.trim().isNotEmpty) {
      setFace(CompanionState.speaking);
      await tts.speak(
        response.text,
        locale: settings.ttsLocale,
        rate: settings.ttsRate,
      );
    }
    setFace(CompanionState.idle);
    return response;
  }

  bool _isEnabled(String id) {
    if (id == 'system') return true;
    return settings.enabledSkills.contains(id);
  }

  Future<String> buildMorningBrief() async {
    final ar = settings.isArabic;
    final parts = <String>[];
    try {
      parts.add(await WeatherSkill.fetchBrief(http, city: settings.city, ar: ar));
    } catch (_) {}
    if (_isEnabled('news')) {
      try {
        final stories = await NewsSkill.fetchHeadlines(http);
        if (stories.isNotEmpty) {
          final bullets = stories.take(3).map((s) => '• ${s.title}').join('\n');
          parts.add(ar ? 'أخبار التقنية:\n$bullets' : 'Tech headlines:\n$bullets');
        }
      } catch (_) {}
    }
    if (parts.isEmpty) {
      return ar
          ? 'صباح الخير. ما قدرت أجيب ملخص اليوم، تأكد من الاتصال.'
          : 'Good morning. I could not build today’s brief; check the connection.';
    }
    return ar
        ? 'صباح الخير ☀️\n${parts.join('\n\n')}'
        : 'Good morning ☀️\n${parts.join('\n\n')}';
  }
}
