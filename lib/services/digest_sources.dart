import 'package:dio/dio.dart';

/// One line in the hourly digest, from any source.
class DigestItem {
  const DigestItem({
    required this.source,
    required this.title,
    this.url = '',
    this.metric = '',
    required this.at,
  });

  /// Short source tag shown to the user, e.g. «الجزيرة», «AI», «GitHub», «أسهم».
  final String source;
  final String title;
  final String url;

  /// Optional trailing metric, e.g. «+24.7%» or «high».
  final String metric;
  final DateTime at;
}

/// Fetches the four digest sources. Every network call is individually guarded
/// so one failing source never sinks the whole digest.
class DigestSources {
  DigestSources(this._dio);
  final Dio _dio;

  static const _ua = {'User-Agent': 'Mozilla/5.0 (PixelCompanion)'};

  /// Al Jazeera Arabic — the freshest headline of the last day.
  Future<DigestItem?> alJazeera() async {
    try {
      final res = await _dio.get<String>(
        'https://www.aljazeera.net/aljazeerarss/a7c186be-1baa-4bd4-9d80-a84db769f779/73d0e1b4-532f-45ef-b135-bfdff8b8cab9',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 15),
          headers: _ua,
        ),
      );
      final items = _parseRssItems(res.data ?? '');
      if (items.isEmpty) return null;
      final first = items.first;
      return DigestItem(
        source: 'الجزيرة',
        title: first.title,
        url: first.link,
        at: first.date,
      );
    } catch (_) {
      return null;
    }
  }

  /// AI news from Hacker News, last 24h, ranked by points.
  Future<List<DigestItem>> aiNews({int limit = 3}) async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch ~/ 1000;
      final res = await _dio.get<Map<String, dynamic>>(
        'https://hn.algolia.com/api/v1/search',
        queryParameters: {
          'query': 'AI',
          'tags': 'story',
          'hitsPerPage': limit * 3,
          'numericFilters': 'points>20,created_at_i>$since',
        },
        options: Options(receiveTimeout: const Duration(seconds: 15), headers: _ua),
      );
      final hits = (res.data?['hits'] as List?) ?? const [];
      final out = <DigestItem>[];
      for (final h in hits) {
        final m = h as Map;
        final title = (m['title'] ?? m['story_title'] ?? '').toString().trim();
        if (title.isEmpty) continue;
        final pts = (m['points'] as num?)?.toInt() ?? 0;
        final created = (m['created_at_i'] as num?)?.toInt() ?? 0;
        out.add(DigestItem(
          source: 'AI',
          title: title,
          url: (m['url'] ?? '').toString(),
          metric: '$pts▲',
          at: DateTime.fromMillisecondsSinceEpoch(created * 1000),
        ));
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Top GitHub security advisories (recent, high severity first).
  Future<List<DigestItem>> githubAdvisories({int limit = 2}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://api.github.com/advisories',
        queryParameters: {'per_page': limit * 4, 'direction': 'desc'},
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/vnd.github+json', ..._ua},
        ),
      );
      final list = res.data ?? const [];
      final out = <DigestItem>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final sev = (raw['severity'] ?? '').toString();
        final summary = (raw['summary'] ?? '').toString().trim();
        if (summary.isEmpty) continue;
        final published = DateTime.tryParse((raw['published_at'] ?? '').toString());
        out.add(DigestItem(
          source: 'GitHub',
          title: summary,
          url: (raw['html_url'] ?? '').toString(),
          metric: sev,
          at: published ?? DateTime.now(),
        ));
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Biggest US daily gainers from Yahoo's predefined screener.
  Future<List<DigestItem>> stockMovers({int limit = 2}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://query1.finance.yahoo.com/v1/finance/screener/predefined/saved',
        queryParameters: {'scrIds': 'day_gainers', 'count': limit * 3},
        options: Options(receiveTimeout: const Duration(seconds: 15), headers: _ua),
      );
      final results = res.data?['finance']?['result'];
      if (results is! List || results.isEmpty) return [];
      final quotes = (results.first as Map)['quotes'];
      if (quotes is! List) return [];
      final out = <DigestItem>[];
      for (final q in quotes) {
        if (q is! Map) continue;
        final sym = (q['symbol'] ?? '').toString();
        final pct = (q['regularMarketChangePercent'] as num?)?.toDouble();
        if (sym.isEmpty || pct == null) continue;
        final price = (q['regularMarketPrice'] as num?)?.toDouble();
        out.add(DigestItem(
          source: 'أسهم',
          title: '$sym${price != null ? ' \$${price.toStringAsFixed(2)}' : ''}',
          metric: '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
          at: DateTime.now(),
        ));
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Minimal RSS `<item>` reader (title, link, pubDate). Enough for news feeds.
  static List<_RssItem> _parseRssItems(String xml) {
    final out = <_RssItem>[];
    final itemRe = RegExp(r'<item>(.*?)</item>', dotAll: true);
    for (final m in itemRe.allMatches(xml)) {
      final body = m.group(1) ?? '';
      final title = _tag(body, 'title');
      if (title.isEmpty) continue;
      out.add(_RssItem(
        title: _decodeEntities(title),
        link: _decodeEntities(_tag(body, 'link')),
        date: _parseDate(_tag(body, 'pubDate')),
      ));
    }
    return out;
  }

  static String _tag(String body, String tag) {
    final m = RegExp('<$tag>(?:\\s*<!\\[CDATA\\[)?(.*?)(?:\\]\\]>)?</$tag>',
            dotAll: true)
        .firstMatch(body);
    return m?.group(1)?.trim() ?? '';
  }

  static DateTime _parseDate(String raw) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    // e.g. "Thu, 12 Nov 2026 04:17:54 +0300"
    final m = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (m == null) return DateTime.now();
    final day = int.parse(m.group(1)!);
    final mon = months[m.group(2)!] ?? 1;
    final year = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = int.parse(m.group(6)!);
    final offM = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(raw);
    var dt = DateTime.utc(year, mon, day, h, mi, s);
    if (offM != null) {
      final sign = offM.group(1) == '-' ? -1 : 1;
      final offMin =
          sign * (int.parse(offM.group(2)!) * 60 + int.parse(offM.group(3)!));
      dt = dt.subtract(Duration(minutes: offMin));
    }
    return dt.toLocal();
  }

  static String _decodeEntities(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}

class _RssItem {
  const _RssItem({required this.title, required this.link, required this.date});
  final String title;
  final String link;
  final DateTime date;
}
