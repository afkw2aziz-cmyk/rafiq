import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/settings.dart';
import '../services/digest_sources.dart';
import '../services/llm.dart';
import '../skills/news_skill.dart';
import '../skills/stock_skill.dart';
import '../skills/weather_skill.dart';
import 'notification_service.dart';

const kMorningTask = 'pixelcompanion.morningBrief';
const kStockTask = 'pixelcompanion.stockCheck';
const kDigestTask = 'pixelcompanion.hourlyDigest';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final settings = await _readSettings(prefs);
    final notifications = NotificationService();

    try {
      if (task == kMorningTask) {
        final ar = settings.isArabic;
        final body = await _brief(settings);
        await notifications.show(
          1001,
          ar ? 'ملخص الصباح' : 'Morning brief',
          body,
        );
        await BackgroundScheduler.scheduleMorningBrief(settings);
      } else if (task == kStockTask) {
        await _checkStocks(settings, notifications);
      } else if (task == kDigestTask) {
        if (settings.enabledSkills.contains('digest')) {
          final ar = settings.isArabic;
          final body = await _digest(settings);
          await notifications.show(
            1002,
            ar ? 'آخر المستجدات' : 'Latest updates',
            body,
          );
        }
      }
    } catch (_) {
      // Never fail the worker chain; retrying is handled by the schedule.
    }
    return true;
  });
}

Future<AppSettings> _readSettings(SharedPreferences prefs) async {
  final raw = prefs.getString('pixel_companion_settings_v1');
  if (raw == null) return const AppSettings();
  try {
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const AppSettings();
  }
}

Future<String> _brief(AppSettings s) async {
  final dio = Dio();
  final ar = s.isArabic;
  final parts = <String>[];
  try {
    parts.add(await WeatherSkill.fetchBrief(dio, city: s.city, ar: ar));
  } catch (_) {}
  if (s.enabledSkills.contains('news')) {
    try {
      final stories = await NewsSkill.fetchHeadlines(dio);
      if (stories.isNotEmpty) {
        parts.add(stories.take(3).map((e) => '• ${e.title}').join('\n'));
      }
    } catch (_) {}
  }
  if (parts.isEmpty) {
    return ar ? 'تأكد من الاتصال لعرض ملخص اليوم.' : 'Check your connection for today’s brief.';
  }
  return parts.join('\n\n');
}

/// Builds the combined digest text for the hourly notification.
Future<String> _digest(AppSettings s) async {
  final ar = s.isArabic;
  final dio = Dio();
  final src = DigestSources(dio);

  final results = await Future.wait([
    src.alJazeera(),
    src.aiNews(limit: 2),
    src.githubAdvisories(limit: 1),
    src.stockMovers(limit: 2),
  ]);
  final aj = results[0] as DigestItem?;
  final ai = results[1] as List<DigestItem>;
  final gh = results[2] as List<DigestItem>;
  final st = results[3] as List<DigestItem>;

  if (aj == null && ai.isEmpty && gh.isEmpty && st.isEmpty) {
    return ar ? 'تعذّر جلب المستجدات.' : 'Could not fetch updates.';
  }

  final raw = StringBuffer();
  if (aj != null) raw.writeln('الجزيرة: ${aj.title}');
  for (final a in ai) {
    raw.writeln('AI: ${a.title}');
  }
  for (final g in gh) {
    raw.writeln('GitHub [${g.metric}]: ${g.title}');
  }
  for (final x in st) {
    raw.writeln('أسهم: ${x.title} (${x.metric})');
  }

  final router = LlmRouter(settings: s, dio: dio);
  if (router.isCloud) {
    try {
      return await router.active.complete(
        [
          ChatMessage(
            'user',
            ar
                ? 'لخّص المستجدات في ٣ أسطر عربية قصيرة بلا مقدمات:\n$raw'
                : 'Summarize in 3 short lines, no intro:\n$raw',
          )
        ],
        system: ar ? 'أنت محرر أخبار موجز.' : 'You are a terse news editor.',
        temperature: 0.3,
        maxTokens: 600,
      );
    } catch (_) {}
  }

  final lines = <String>[];
  if (aj != null) lines.add('الجزيرة: ${aj.title}');
  for (final a in ai) {
    lines.add('AI: ${a.title}');
  }
  for (final g in gh) {
    lines.add('GitHub: ${g.title}');
  }
  for (final x in st) {
    lines.add('أسهم: ${x.title} ${x.metric}');
  }
  return lines.join('\n');
}

Future<void> _checkStocks(
  AppSettings s,
  NotificationService notifications,
) async {
  if (s.watchlist.isEmpty) return;
  final ar = s.isArabic;
  final quotes = await StockSkill.fetchQuotes(Dio(), s.watchlist);
  for (final q in quotes) {
    if (q.changePct.abs() >= s.stockThreshold) {
      await notifications.show(
        9000 + q.symbol.hashCode.remainder(500),
        ar ? 'تنبيه سهم' : 'Stock alert',
        ar
            ? '${q.symbol} تحرك ${q.changePct.toStringAsFixed(1)}% اليوم.'
            : '${q.symbol} moved ${q.changePct.toStringAsFixed(1)}% today.',
      );
    }
  }
}

class BackgroundScheduler {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Workmanager().initialize(callbackDispatcher);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static DateTime nextMorning(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, h, m);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  static Future<void> scheduleMorningBrief(AppSettings s) async {
    await init();
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(kMorningTask);
      if (!s.morningBrief) return;
      final delay = nextMorning(s.morningTime).difference(DateTime.now());
      await Workmanager().registerOneOffTask(
        kMorningTask,
        kMorningTask,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: {'city': s.city, 'lang': s.lang},
      );
    } catch (_) {}
  }

  static Future<void> scheduleHourlyDigest(AppSettings s) async {
    await init();
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(kDigestTask);
      if (!s.enabledSkills.contains('digest')) return;
      // WorkManager's floor is 15 min; 1h is the requested cadence.
      await Workmanager().registerPeriodicTask(
        kDigestTask,
        kDigestTask,
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {}
  }

  static Future<void> scheduleStockCheck(AppSettings s) async {
    await init();
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(kStockTask);
      if (s.watchlist.isEmpty) return;
      await Workmanager().registerPeriodicTask(
        kStockTask,
        kStockTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {}
  }
}
