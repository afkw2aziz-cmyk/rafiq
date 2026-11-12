import 'package:dio/dio.dart';

import '../core/settings.dart';

class ChatMessage {
  const ChatMessage(this.role, this.content);
  final String role; // user | model
  final String content;
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class LLMProvider {
  String get id;
  bool get configured;
  Future<String> complete(
    List<ChatMessage> messages, {
    String? system,
    double temperature = 0.8,
    int maxTokens = 512,
  });
}

class GeminiProvider implements LLMProvider {
  GeminiProvider({
    required this.apiKey,
    required this.model,
    required this.dio,
  });

  final String apiKey;
  final String model;
  final Dio dio;

  @override
  String get id => 'gemini';

  @override
  bool get configured => apiKey.trim().isNotEmpty;

  @override
  Future<String> complete(
    List<ChatMessage> messages, {
    String? system,
    double temperature = 0.8,
    int maxTokens = 512,
  }) async {
    if (!configured) throw LlmException('Missing Gemini API key');
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
    try {
      final res = await dio.post<Map<String, dynamic>>(
        url,
        queryParameters: {'key': apiKey},
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          if (system != null && system.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': system}
              ]
            },
          'contents': [
            for (final m in messages)
              {
                'role': m.role == 'model' ? 'model' : 'user',
                'parts': [
                  {'text': m.content}
                ],
              }
          ],
          'generationConfig': {
            'temperature': temperature,
            'maxOutputTokens': maxTokens,
            'topP': 0.95,
            // Gemini 2.5 spends part of the output budget on internal
            // "thinking" and truncates the visible reply (finishReason:
            // MAX_TOKENS after ~46 chars). Disable it so the whole budget
            // goes to the answer. Older 1.5 models ignore this field.
            'thinkingConfig': {'thinkingBudget': 0},
          },
        },
      );
      final candidates = res.data?['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw LlmException('Empty response from Gemini');
      }
      final parts = (candidates.first as Map)['content']?['parts'] as List?;
      final text = parts
              ?.map((p) => (p as Map)['text'] ?? '')
              .where((t) => t.toString().trim().isNotEmpty)
              .join('\n') ??
          '';
      if (text.trim().isEmpty) throw LlmException('Empty text from Gemini');
      return text.trim();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final detail = e.response?.data is Map
          ? ((e.response!.data as Map)['error']?['message'] ?? '')
          : '';
      throw LlmException(
        'Gemini ${code ?? 'network'}: ${detail.toString().isEmpty ? e.message : detail}',
      );
    }
  }
}

/// Zero-dependency fallback so the app is never dead without a key.
class LocalProvider implements LLMProvider {
  LocalProvider(this.settings);
  final AppSettings settings;

  @override
  String get id => 'local';

  @override
  bool get configured => true;

  @override
  Future<String> complete(
    List<ChatMessage> messages, {
    String? system,
    double temperature = 0.8,
    int maxTokens = 512,
  }) async {
    final ar = settings.isArabic;
    final q = messages.isEmpty ? '' : messages.last.content.toLowerCase();
    final name = settings.companionName;

    String reply;
    if (RegExp(r'(الوقت|الساعة|time|clock)').hasMatch(q)) {
      final t = TimeOfDayX.now();
      reply = ar ? 'الساعة الآن $t.' : 'It is $t right now.';
    } else if (RegExp(r'(تاريخ|اليوم|date|today)').hasMatch(q)) {
      final d = DateTime.now();
      reply = ar
          ? 'اليوم ${d.year}-${_two(d.month)}-${_two(d.day)}.'
          : 'Today is ${d.year}-${_two(d.month)}-${_two(d.day)}.';
    } else if (RegExp(r'(نكتة|ضحك|joke|funny)').hasMatch(q)) {
      reply = ar
          ? 'مرة روبوت قال لصاحبه: عندي إحساس… بس الإحساس إحساس بطارية.'
          : 'A robot told its friend: I have feelings… mostly battery feelings.';
    } else if (RegExp(r'(شكرا|شكراً|thanks|thank you)').hasMatch(q)) {
      reply = ar ? 'العفو! أنا هنا دائمًا.' : 'Anytime! I am always here.';
    } else if (RegExp(r'(من أنت|اسمك|who are you|your name)').hasMatch(q)) {
      reply = ar
          ? 'أنا $name، رفيقك على هذا الجهاز. أشتغل محليًا، ولو أضفت مفتاح Gemini أصير أذكى.'
          : 'I am $name, your on-device companion. I work offline; add a Gemini key and I get smarter.';
    } else {
      reply = ar
          ? 'ما وصلني مفتاح Gemini، فأنا أرد محليًا فقط. جرّب: الطقس، الأخبار، أسهمي، ذكرني… أو أضف المفتاح من الإعدادات.'
          : 'No Gemini key yet, so I answer locally. Try weather, news, stocks, reminders… or add a key in Settings.';
    }
    return reply;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class TimeOfDayX {
  static String now() {
    final d = DateTime.now();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }
}

class LlmRouter {
  LlmRouter({required this.settings, required this.dio});
  final AppSettings settings;
  final Dio dio;

  LLMProvider get active {
    if (settings.geminiKey.trim().isNotEmpty) {
      return GeminiProvider(
        apiKey: settings.geminiKey.trim(),
        model: settings.geminiModel,
        dio: dio,
      );
    }
    return LocalProvider(settings);
  }

  bool get isCloud => active.configured && active.id == 'gemini';
}
