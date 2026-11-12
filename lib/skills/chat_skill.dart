import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/llm.dart';
import 'skill.dart';

class ChatSkill extends Skill {
  final List<ChatMessage> _history = [];

  @override
  String get id => 'chat';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'chat',
        nameAr: 'المحادثة',
        nameEn: 'Chat',
        descriptionAr: 'محادثة حرة مع Gemini أو الرد المحلي بدون مفتاح.',
        descriptionEn: 'Free-form conversation via Gemini, or local replies without a key.',
        icon: Icons.chat_bubble_outline,
        triggers: [],
      );

  @override
  Future<void> init(SkillContext ctx) async {
    _history.clear();
  }

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    final router = LlmRouter(settings: req.ctx.settings, dio: req.ctx.http);
    final system = _systemPrompt(req.ctx);

    _history.add(ChatMessage('user', req.text));
    if (_history.length > 10) {
      _history.removeRange(0, _history.length - 10);
    }

    try {
      final reply = await router.active.complete(
        List<ChatMessage>.from(_history),
        system: system,
        temperature: router.isCloud ? 0.85 : 0.5,
        maxTokens: 400,
      );
      _history.add(ChatMessage('model', reply));
      return SkillResponse(text: reply, face: CompanionState.happy);
    } catch (e) {
      _history.removeLast();
      return SkillResponse(
        text: ar
            ? 'تعذّر الاتصال بالنموذج. تأكد من مفتاح Gemini أو جرّب لاحقًا.'
            : 'Could not reach the model. Check the Gemini key or try again.',
        face: CompanionState.sad,
      );
    }
  }

  String _systemPrompt(SkillContext ctx) {
    final s = ctx.settings;
    final ar = s.isArabic;
    final personality = switch (s.personality) {
      'calm' => ar ? 'هادئ ومتزن' : 'calm and grounded',
      'brief' => ar ? 'مختصر جدًا، جملة أو جملتين' : 'very brief, one or two sentences',
      _ => ar ? 'مرح وفضولي وخفيف الدم' : 'cheerful, curious and playful',
    };
    final name = s.companionName;
    final city = s.city;
    if (ar) {
      return 'أنت $name، رفيق ذكي يعيش داخل هاتف Pixel. شخصيتك: $personality. '
          'تتحدث العربية الفصحى المبسطة، وتفهم اللهجة الخليجية. '
          'تكون ردودك قصيرة ومناسبة للنطق الصوتي (بدون رموز ماركداون أو قوائم طويلة). '
          'تعرف أن المستخدم في $city. لا تدّعي أنك بشري، ولا تخترع معلومات.';
    }
    return 'You are $name, a witty companion living inside a Pixel phone. '
        'Personality: $personality. Keep replies short and speakable, no markdown or long lists. '
        'The user is in $city. Never claim to be human and never invent facts.';
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
