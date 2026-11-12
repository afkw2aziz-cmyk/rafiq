import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_companion/skills/registry.dart';

void main() {
  test('digest triggers route to digest skill, not news', () {
    final r = SkillRegistry.bootstrap();
    for (final q in ['digest', 'مستجدات', 'آخر المستجدات', 'نشرة', 'whats new', 'roundup']) {
      final s = r.match(q);
      expect(s?.id, 'digest', reason: '"$q" should hit digest, got ${s?.id}');
    }
  });

  test('news still routes to news', () {
    final r = SkillRegistry.bootstrap();
    for (final q in ['أخبار', 'news', 'headlines']) {
      final s = r.match(q);
      expect(s?.id, 'news', reason: '"$q" got ${s?.id}');
    }
  });
}
