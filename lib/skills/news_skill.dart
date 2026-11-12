import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/llm.dart';
import 'skill.dart';

class NewsSkill extends Skill {
  @override
  String get id => 'news';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'news',
        nameAr: 'الأخبار',
        nameEn: 'News',
        descriptionAr: 'ملخص أخبار التقنية والذكاء الاصطناعي في ثلاث نقاط.',
        descriptionEn: 'A three-bullet tech and AI news digest.',
        icon: Icons.newspaper_outlined,
        triggers: [r'أخبار|اخبار|عناوين|news|headlines'],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    req.ctx.setFace(CompanionState.thinking);
    try {
      final stories = await fetchHeadlines(req.ctx.http, aiOnly: true);
      if (stories.isEmpty) {
        return SkillResponse(
          text: ar ? 'ما وصلتني أخبار الآن.' : 'No headlines right now.',
          face: CompanionState.sad,
        );
      }

      final router = LlmRouter(settings: req.ctx.settings, dio: req.ctx.http);
      if (router.isCloud) {
        try {
          final list = stories.take(8).map((s) => '- ${s.title} (${s.source})').join('\n');
          final summary = await router.active.complete(
            [
              ChatMessage(
                'user',
                ar
                    ? 'لخّص عناوين الأخبار التالية في ٣ نقاط قصيرة، كل نقطة سطر، بلا مقدمات:\n$list'
                    : 'Summarize these headlines in 3 short bullets, one per line, no intro:\n$list',
              )
            ],
            system: ar
                ? 'أنت مساعد خبير تقنية. اكتب عربية فصحى موجزة.'
                : 'You are a concise tech editor.',
            temperature: 0.4,
            maxTokens: 300,
          );
          return SkillResponse(text: summary, face: CompanionState.happy);
        } catch (_) {
          // fall through to raw list
        }
      }

      final lines = stories.take(3).map((s) => '• ${s.title}').join('\n');
      return SkillResponse(
        text: ar ? 'أهم عناوين التقنية الآن:\n$lines' : 'Top tech headlines:\n$lines',
        face: CompanionState.happy,
      );
    } catch (_) {
      return SkillResponse(
        text: ar ? 'تعذّر جلب الأخبار. تأكد من الاتصال.' : 'Could not fetch news. Check the connection.',
        face: CompanionState.sad,
      );
    }
  }

  static Future<List<NewsItem>> fetchHeadlines(Dio dio, {bool aiOnly = true}) async {
    final queries = aiOnly
        ? ['artificial intelligence', 'AI']
        : ['technology'];
    final out = <NewsItem>[];
    for (final q in queries) {
      final res = await dio.get<Map<String, dynamic>>(
        'https://hn.algolia.com/api/v1/search',
        queryParameters: {
          'query': q,
          'tags': 'story',
          'hitsPerPage': 6,
          'numericFilters': 'points>30',
        },
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final hits = res.data?['hits'] as List? ?? const [];
      for (final h in hits) {
        final m = h as Map;
        final title = (m['title'] ?? m['story_title'] ?? '').toString();
        if (title.isEmpty) continue;
        out.add(NewsItem(
          title: title,
          source: (m['author'] ?? 'HN').toString(),
          url: (m['url'] ?? '').toString(),
        ));
      }
      if (out.isNotEmpty) break;
    }
    final seen = <String>{};
    return out.where((e) => seen.add(e.title)).toList();
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}

class NewsItem {
  const NewsItem({required this.title, required this.source, required this.url});
  final String title;
  final String source;
  final String url;
}
