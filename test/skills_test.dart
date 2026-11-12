import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_companion/services/natural_time.dart';
import 'package:pixel_companion/skills/registry.dart';

void main() {
  final base = DateTime(2026, 11, 11, 10, 0); // Wednesday

  group('natural time', () {
    test('tomorrow at 3pm', () {
      final r = parseWhen('add a meeting tomorrow at 3pm with Sara', nowOverride: base);
      expect(r.when, DateTime(2026, 11, 12, 15, 0));
      expect(r.title.toLowerCase(), contains('meeting'));
    });

    test('Arabic tomorrow at 5', () {
      final r = parseWhen('ذكرني أتصل بأمي بكرة الساعة 5', nowOverride: base);
      expect(r.when, DateTime(2026, 11, 12, 17, 0));
    });

    test('relative hours', () {
      final r = parseWhen('remind me in 2 hours to stretch', nowOverride: base);
      expect(r.when, base.add(const Duration(hours: 2)));
    });

    test('weekday rolls forward', () {
      final r = parseWhen('meeting on friday at 9am', nowOverride: base);
      expect(r.when?.weekday, DateTime.friday);
      expect(r.when?.hour, 9);
    });

    test('no time returns null', () {
      final r = parseWhen('hello there', nowOverride: base);
      expect(r.when, isNull);
    });
  });

  group('skill registry', () {
    final registry = SkillRegistry.bootstrap();

    test('routes weather in Arabic', () {
      expect(registry.match('كيف الطقس اليوم؟')?.id, 'weather');
    });

    test('routes reminders in English', () {
      expect(registry.match('remind me to call mom')?.id, 'reminder');
    });

    test('routes calendar', () {
      expect(registry.match('أضف اجتماع بكرة')?.id, 'calendar');
    });

    test('unknown falls back to null (chat)', () {
      expect(registry.match('tell me a story'), isNull);
    });

    test('all nine skills registered', () {
      expect(registry.all.length, 9);
    });
  });
}
