import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_companion/core/settings.dart';
import 'package:pixel_companion/services/intent_router.dart';

/// The parser is the fragile part — models wrap JSON in prose or code fences —
/// so it is exercised directly with realistic model output, no network needed.
void main() {
  group('IntentRouter availability', () {
    test('unavailable without a key', () {
      const noKey = AppSettings(geminiKey: '', geminiModel: 'gemini-2.5-flash');
      expect(IntentRouter(settings: noKey, dio: Dio()).available, isFalse);
    });

    test('unavailable without a model', () {
      const noModel = AppSettings(geminiKey: 'k', geminiModel: '');
      expect(IntentRouter(settings: noModel, dio: Dio()).available, isFalse);
    });

    test('available with key and model', () {
      const ok = AppSettings(geminiKey: 'k', geminiModel: 'gemini-2.5-flash');
      expect(IntentRouter(settings: ok, dio: Dio()).available, isTrue);
    });
  });

  group('parseDecision', () {
    test('reads a bare JSON object', () {
      final d = IntentRouter.parseDecision(
        '{"skill":"stock","text":"سعر سهم تسلا","confidence":1}',
        fallbackText: 'fallback',
      );
      expect(d, isNotNull);
      expect(d!.skillId, 'stock');
      expect(d.text, 'سعر سهم تسلا');
      expect(d.confidence, 1.0);
    });

    test('tolerates ```json code fences', () {
      final d = IntentRouter.parseDecision(
        '```json\n{"skill":"weather","text":"الطقس غداً في الرياض","confidence":1}\n```',
        fallbackText: 'fallback',
      );
      expect(d?.skillId, 'weather');
      expect(d?.text, 'الطقس غداً في الرياض');
    });

    test('tolerates prose around the object', () {
      final d = IntentRouter.parseDecision(
        'Here you go: {"skill":"reminder","text":"ذكّرني بعد ساعتين","confidence":0.9} done',
        fallbackText: 'fallback',
      );
      expect(d?.skillId, 'reminder');
      expect(d?.confidence, 0.9);
    });

    test('chat maps to a null skill so the fallback skill runs', () {
      final d = IntentRouter.parseDecision(
        '{"skill":"chat","text":"كيف حالك اليوم","confidence":1}',
        fallbackText: 'fallback',
      );
      expect(d, isNotNull);
      expect(d!.skillId, isNull);
      expect(d.text, 'كيف حالك اليوم');
    });

    test('unknown skill id is rejected', () {
      expect(
        IntentRouter.parseDecision(
          '{"skill":"hack_the_planet","text":"x","confidence":1}',
          fallbackText: 'fallback',
        ),
        isNull,
      );
    });

    test('no JSON at all is rejected', () {
      expect(IntentRouter.parseDecision('I cannot help with that.', fallbackText: 'f'), isNull);
    });

    test('empty text field falls back to the original request', () {
      final d = IntentRouter.parseDecision(
        '{"skill":"news","text":"","confidence":0.5}',
        fallbackText: 'الأخبار',
      );
      expect(d?.text, 'الأخبار');
    });

    test('malformed JSON is rejected, not thrown', () {
      expect(
        IntentRouter.parseDecision('{"skill":"stock", broken', fallbackText: 'f'),
        isNull,
      );
    });

    test('confidence is clamped into 0..1', () {
      final d = IntentRouter.parseDecision(
        '{"skill":"stock","text":"سعر سهم AAPL","confidence":7}',
        fallbackText: 'f',
      );
      expect(d!.confidence, 1.0);
    });
  });
}
