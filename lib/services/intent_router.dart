import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/settings.dart';
import 'llm.dart';

/// Result of asking the model "which skill is this, and how should I phrase it?"
class RouteDecision {
  const RouteDecision({required this.skillId, required this.text, this.confidence = 0});

  /// Skill id chosen by the model, or null when it decided this is chit-chat.
  final String? skillId;

  /// The user's request re-phrased into the compact form skills expect
  /// (e.g. «سعر سهم TSLA» instead of «كم تسوى تسلا الحين؟»).
  final String text;

  final double confidence;
}

/// Uses Gemini to pick a skill and normalise the request before the regex
/// registry runs. Everything is best-effort: on any failure the caller keeps
/// the original text and the local regex routing.
///
/// Privacy: only the user's own sentence plus the list of skill ids/names is
/// sent — never history, notifications or settings.
class IntentRouter {
  IntentRouter({required this.settings, required this.dio});

  final AppSettings settings;
  final Dio dio;

  /// Skills the model is allowed to pick, with a short hint of what each does.
  static const _catalogue = <String, String>{
    'weather': 'الطقس اليوم أو غداً لمدينة',
    'reminder': 'تذكير أو منبّه في وقت معيّن',
    'calendar': 'مواعيد وأحداث التقويم',
    'stock': 'سعر سهم أو مؤشر أو محفظة',
    'news': 'عناوين أخبار التقنية والذكاء الاصطناعي',
    'digest': 'نشرة مجمّعة: الجزيرة + ذكاء اصطناعي + ثغرات + أسهم',
    'chat': 'أي سؤال عام أو حديث عادي لا يحتاج مهارة',
  };

  bool get available =>
      settings.geminiKey.trim().isNotEmpty && settings.geminiModel.trim().isNotEmpty;

  /// Returns null when the model is unavailable or the answer is unusable;
  /// callers then fall back to the local regex matcher.
  Future<RouteDecision?> decide(String rawText, {Set<String>? enabled}) async {
    if (!available) return null;
    final text = rawText.trim();
    if (text.isEmpty) return null;

    final allowed = _catalogue.entries
        .where((e) => e.key == 'chat' || enabled == null || enabled.contains(e.key))
        .map((e) => '- ${e.key}: ${e.value}')
        .join('\n');

    final provider = GeminiProvider(
      apiKey: settings.geminiKey,
      model: settings.geminiModel,
      dio: dio,
    );

    try {
      final reply = await provider.complete(
        [
          ChatMessage(
            'user',
            'طلب المستخدم: "$text"\n\n'
            'المهارات المتاحة:\n$allowed\n\n'
            'أعد JSON فقط بالشكل: '
            '{"skill":"<id أو chat>","text":"<الطلب بصيغة مختصرة يفهمها النظام>",'
            '"confidence":<0..1>}',
          )
        ],
        system: 'أنت مصنّف نوايا صارم. اختر مهارة واحدة فقط من القائمة. '
            'أعد JSON صالحاً بلا أي شرح أو علامات Markdown. '
            'في حقل text أعد صياغة طلب المستخدم بنفس لغته وبكلمات مفتاحية واضحة: '
            'مثال «سعر سهم TSLA» أو «الطقس في الرياض» أو «ذكّرني بعد ساعة أن أتصل بأمي». '
            'إن كان حديثاً عاماً فاختر chat وأعد النص كما هو.',
        temperature: 0.0,
        maxTokens: 200,
      );
      return parseDecision(reply, fallbackText: text);
    } catch (_) {
      return null;
    }
  }

  /// Public so it can be unit-tested without a network call: models wrap the
  /// JSON in prose or code fences often enough that this needs coverage.
  static RouteDecision? parseDecision(String reply, {required String fallbackText}) {
    var body = reply.trim();
    // Tolerate code fences the model may add despite instructions.
    if (body.startsWith('```')) {
      body = body.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      body = body.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    Map<String, dynamic> json;
    try {
      json = jsonDecode(body.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final rawSkill = (json['skill'] ?? '').toString().trim().toLowerCase();
    final skillId = _catalogue.containsKey(rawSkill) ? rawSkill : null;
    if (skillId == null) return null;

    final normalised = (json['text'] ?? '').toString().trim();
    final conf = (json['confidence'] as num?)?.toDouble() ?? 0.6;

    return RouteDecision(
      skillId: skillId == 'chat' ? null : skillId,
      text: normalised.isEmpty ? fallbackText : normalised,
      confidence: conf.clamp(0.0, 1.0),
    );
  }
}
