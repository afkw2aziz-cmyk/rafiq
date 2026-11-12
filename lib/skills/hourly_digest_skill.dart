import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/digest_sources.dart';
import '../services/llm.dart';
import 'skill.dart';

/// «آخر المستجدات» — one Arabic digest that stitches together:
///  * the newest Al Jazeera headline
///  * fresh AI stories (Hacker News, last 24h)
///  * GitHub security advisories
///  * the biggest US stock movers
///
/// With a Gemini key the raw lines are turned into a short spoken Arabic brief;
/// without one the raw lines are still shown.
class HourlyDigestSkill extends Skill {
  @override
  String get id => 'digest';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'digest',
        nameAr: 'آخر المستجدات',
        nameEn: 'Hourly digest',
        descriptionAr:
            'نشرة مجمّعة: آخر خبر من الجزيرة + أخبار الذكاء الاصطناعي + ثغرات GitHub + تحركات الأسهم.',
        descriptionEn:
            'Combined brief: latest Al Jazeera headline + AI news + GitHub advisories + US movers.',
        icon: Icons.podcasts_outlined,
        triggers: [
          r'مستجدات|آخر الأخبار|اخر الاخبار|نشرة|ملخص شامل|ماذا يحدث|وش الجديد|آخر المستجدات',
          r'digest|brief|what.?s new|latest news|roundup',
        ],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    req.ctx.setFace(CompanionState.thinking);

    final sources = DigestSources(req.ctx.http);
    // Fetch all four in parallel; each guarded internally.
    final results = await Future.wait([
      sources.alJazeera(),
      sources.aiNews(limit: 3),
      sources.githubAdvisories(limit: 2),
      sources.stockMovers(limit: 2),
    ]);

    final aj = results[0] as DigestItem?;
    final ai = results[1] as List<DigestItem>;
    final gh = results[2] as List<DigestItem>;
    final st = results[3] as List<DigestItem>;

    if (aj == null && ai.isEmpty && gh.isEmpty && st.isEmpty) {
      return SkillResponse(
        text: ar ? 'تعذّر جلب المستجدات. تأكد من الاتصال.' : 'Could not fetch the digest. Check the connection.',
        face: CompanionState.sad,
      );
    }

    // --- Build the raw material (compact, for the model or for display) ---
    final raw = StringBuffer();
    if (aj != null) raw.writeln('الجزيرة: ${aj.title}');
    for (final a in ai) {
      raw.writeln('AI: ${a.title} (${a.metric})');
    }
    for (final g in gh) {
      raw.writeln('GitHub [${g.metric}]: ${g.title}');
    }
    for (final s in st) {
      raw.writeln('أسهم: ${s.title} (${s.metric})');
    }

    final router = LlmRouter(settings: req.ctx.settings, dio: req.ctx.http);
    if (router.isCloud) {
      try {
        final summary = await router.active.complete(
          [
            ChatMessage(
              'user',
              ar
                  ? 'هذه آخر المستجدات الآن. لخّصها في ٤ إلى ٦ أسطر عربية قصيرة، '
                      'كل سطر يبدأ بعنوان المجال (الجزيرة / ذكاء اصطناعي / أمن / أسهم)، '
                      'بلا مقدمات وبلا إعادة للروابط:\n$raw'
                  : 'Here are the latest updates. Summarize in 4-6 short lines, '
                      'each starting with a topic tag (AlJazeera / AI / Security / Stocks), '
                      'no intro, no links:\n$raw',
            )
          ],
          system: ar
              ? 'أنت محرر أخبار موجز ودقيق. تكتب عربية فصحى بلا حشو.'
              : 'You are a terse, precise news editor.',
          temperature: 0.3,
          maxTokens: 800,
        );
        return SkillResponse(text: summary, face: CompanionState.happy);
      } catch (_) {
        // fall through to the raw list
      }
    }

    // --- No key (or model failed): present the raw lines cleanly ---
    final lines = <String>[];
    if (aj != null) lines.add('🔹 الجزيرة: ${aj.title}');
    for (final a in ai) {
      lines.add('🤖 AI: ${a.title}');
    }
    for (final g in gh) {
      lines.add('🛡️ GitHub [${g.metric}]: ${g.title}');
    }
    for (final s in st) {
      lines.add('📈 أسهم: ${s.title} ${s.metric}');
    }
    final head = ar ? 'آخر المستجدات الآن:' : 'Latest updates now:';
    return SkillResponse(
      text: '$head\n${lines.join('\n')}',
      face: CompanionState.happy,
    );
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
