import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/state.dart';
import 'skill.dart';

class StockQuote {
  const StockQuote({
    required this.symbol,
    required this.price,
    required this.prevClose,
    required this.name,
    required this.currency,
  });
  final String symbol;
  final double price;
  final double prevClose;
  final String name;
  final String currency;

  double get changePct =>
      prevClose == 0 ? 0 : (price - prevClose) / prevClose * 100;
}

/// Maps common Arabic (and some English) company names to tickers, so a spoken
/// question like «كم سعر أرامكو؟» resolves without the user typing a symbol.
const Map<String, String> _nameToTicker = {
  'أرامكو': '2222.SR',
  'ارامكو': '2222.SR',
  'سابك': '2010.SR',
  'الراجحي': '1120.SR',
  'الأهلي': '1180.SR',
  'الاتصالات': '7010.SR',
  'stc': '7010.SR',
  'تسلا': 'TSLA',
  'ابل': 'AAPL',
  'آبل': 'AAPL',
  'ابل ': 'AAPL',
  'أبل': 'AAPL',
  'مايكروسوفت': 'MSFT',
  'جوجل': 'GOOGL',
  'ألفابت': 'GOOGL',
  'امازون': 'AMZN',
  'أمازون': 'AMZN',
  'نيفيديا': 'NVDA',
  'إنفيديا': 'NVDA',
  'ميتا': 'META',
  'فيسبوك': 'META',
  'نتفلكس': 'NFLX',
  'بيتكوين': 'BTC-USD',
  'ايثيريوم': 'ETH-USD',
};

class StockSkill extends Skill {
  @override
  String get id => 'stock';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'stock',
        nameAr: 'الأسهم',
        nameEn: 'Stocks',
        descriptionAr:
            'اسأل عن سعر أي سهم بالاسم أو الرمز، أو راجع قائمة أسهمك وتنبيهاتها.',
        descriptionEn:
            'Ask the price of any stock by name or symbol, or review your watchlist.',
        icon: Icons.show_chart,
        permissions: {'notifications'},
        triggers: [
          r'أسهم|اسهم|سهم|بورصة|stocks?|watchlist|market',
          r'سعر|كم سعر|كم يسوى|كم وصل|price|quote',
        ],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    req.ctx.setFace(CompanionState.thinking);

    // 1) Try to resolve a specific ticker from the question.
    final explicit = await _resolveTarget(req.text, req.ctx.http);

    if (explicit != null) {
      try {
        final q = await fetchQuote(req.ctx.http, explicit);
        if (q == null) {
          return SkillResponse(
            text: ar
                ? 'ما لقيت سهمًا بالرمز «$explicit». تأكد من الرمز.'
                : 'I could not find a stock for “$explicit”. Check the symbol.',
            face: CompanionState.sad,
          );
        }
        final up = q.changePct >= 0;
        final arrow = up ? '▲' : '▼';
        final pct = '${up ? '+' : ''}${q.changePct.toStringAsFixed(2)}%';
        final price = q.price.toStringAsFixed(2);
        final namePart = q.name.isNotEmpty ? ' (${q.name})' : '';
        final text = ar
            ? '${q.symbol}$namePart: $price ${q.currency} $arrow $pct'
            : '${q.symbol}$namePart: $price ${q.currency} $arrow $pct';
        return SkillResponse(
          text: text,
          face: up ? CompanionState.happy : CompanionState.sad,
        );
      } catch (_) {
        return SkillResponse(
          text: ar ? 'تعذّر جلب سعر $explicit.' : 'Could not fetch $explicit.',
          face: CompanionState.sad,
        );
      }
    }

    // 2) No explicit ticker → fall back to the watchlist summary.
    final symbols = req.ctx.settings.watchlist;
    if (symbols.isEmpty) {
      return SkillResponse(
        text: ar
            ? 'قل لي اسم السهم أو رمزه، مثل: «سعر AAPL» أو «كم سعر أرامكو؟»'
            : 'Tell me a stock name or symbol, e.g. “price of AAPL”.',
        face: CompanionState.sad,
      );
    }
    try {
      final quotes = await fetchQuotes(req.ctx.http, symbols);
      if (quotes.isEmpty) {
        return SkillResponse(
          text: ar ? 'ما وصلتني أسعار الآن.' : 'No quotes right now.',
          face: CompanionState.sad,
        );
      }
      final threshold = req.ctx.settings.stockThreshold;
      final alerts = quotes.where((q) => q.changePct.abs() >= threshold).toList();

      final lines = quotes
          .map((q) => '• ${q.symbol}: ${q.price.toStringAsFixed(2)} '
              '(${q.changePct >= 0 ? '+' : ''}${q.changePct.toStringAsFixed(1)}%)')
          .join('\n');

      if (alerts.isNotEmpty) {
        final a = alerts.first;
        await req.ctx.notifications.show(
          9000 + a.symbol.hashCode.remainder(500),
          ar ? 'تنبيه سهم' : 'Stock alert',
          ar
              ? '${a.symbol} تحرك ${a.changePct.toStringAsFixed(1)}% اليوم.'
              : '${a.symbol} moved ${a.changePct.toStringAsFixed(1)}% today.',
        );
      }

      return SkillResponse(
        text: ar ? 'أسهمك اليوم:\n$lines' : 'Your watchlist:\n$lines',
        face: alerts.isEmpty ? CompanionState.happy : CompanionState.surprised,
      );
    } catch (_) {
      return SkillResponse(
        text: ar ? 'تعذّر جلب الأسعار.' : 'Could not fetch quotes.',
        face: CompanionState.sad,
      );
    }
  }

  /// Extracts a ticker from the utterance: explicit symbol, known Arabic/English
  /// company name, or a Yahoo symbol lookup for a plain English word.
  static Future<String?> _resolveTarget(String text, Dio dio) async {
    final lower = text.toLowerCase().trim();

    // A) Known company names (Arabic or the English ones we mapped).
    for (final entry in _nameToTicker.entries) {
      if (lower.contains(entry.key.toLowerCase())) return entry.value;
    }

    // B) Something that looks like an explicit ticker: 1–5 Latin letters
    //    (optionally with a market suffix), or a crypto like BTC-USD.
    final symbolMatch = RegExp(
      r'\b([A-Za-z]{1,5}(?:[-.][A-Za-z]{1,3})?)\b',
    ).allMatches(text);
    // Words that are part of the question, not a ticker.
    const stop = {
      'price', 'quote', 'stock', 'stocks', 'market', 'watchlist', 'share',
      'shares', 'what', 'is', 'the', 'of', 'a', 'an', 'pls', 'please', 'sir',
      'how', 'much', 'tell', 'me', 'about', 'and', 'to', 'does', 'do', 'show',
      'get', 'today', 'now', 'my', 'in', 'on', 'at', 'for',
      'كم', 'سعر', 'سهم', 'أسهم', 'هل', 'عن', 'في', 'و', 'اليوم', 'بورصة',
      'قيمة', 'يسوى', 'وصل',
    };
    for (final m in symbolMatch) {
      final w = m.group(1)!;
      final lw = w.toLowerCase();
      if (stop.contains(lw)) continue;
      // Prefer ALL-CAPS tokens (AAPL, TSLA) — likely an explicit symbol.
      if (w == w.toUpperCase() && w.length >= 2) return w.toUpperCase();
    }

    // C) English company name → Yahoo search lookup (free, no key).
    //    Only attempted when every meaningful word was filtered out above,
    //    so generic words like "stocks" never trigger a lookup.
    final words = RegExp(r'[A-Za-z]{2,}')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((w) => !stop.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return null; // pure "stocks"/"market" question
    // Require a single, name-like word to avoid noisy multi-word lookups.
    if (words.length == 1 && words.first.length >= 3) {
      final hit = await _yahooSearch(words.first, dio);
      if (hit != null) return hit;
    }
    return null;
  }

  static Future<String?> _yahooSearch(String query, Dio dio) async {
    try {
      final res = await dio.get<dynamic>(
        'https://query2.finance.yahoo.com/v1/finance/search',
        queryParameters: {'q': query, 'quotesCount': 1, 'newsCount': 0},
        options: Options(
          receiveTimeout: const Duration(seconds: 12),
          headers: const {'User-Agent': 'Mozilla/5.0 (PixelCompanion)'},
        ),
      );
      final data = res.data;
      if (data is! Map) return null;
      final quotes = data['quotes'];
      if (quotes is! List || quotes.isEmpty) return null;
      final first = quotes.first;
      if (first is! Map) return null;
      final sym = first['symbol'];
      final type = (first['quoteType'] ?? '').toString().toUpperCase();
      // Only equity/ETF/crypto make sense here.
      if (sym is! String || sym.isEmpty) return null;
      if (type.isNotEmpty && !type.contains('EQUITY') && !type.contains('ETF') && !type.contains('CRYPT')) {
        return null;
      }
      return sym.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  /// Fetches a single quote via Yahoo's chart endpoint (free, no API key).
  static Future<StockQuote?> fetchQuote(Dio dio, String symbol) async {
    final clean = symbol.trim().toUpperCase();
    if (clean.isEmpty) return null;
    final res = await dio.get<dynamic>(
      'https://query1.finance.yahoo.com/v8/finance/chart/$clean',
      queryParameters: {'interval': '1d', 'range': '1d'},
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'User-Agent': 'Mozilla/5.0 (PixelCompanion)'},
      ),
    );
    final data = res.data;
    if (data is! Map) return null;
    final chart = data['chart'];
    if (chart is! Map) return null;
    final result = chart['result'];
    if (result is! List || result.isEmpty) return null;
    final first = result.first;
    if (first is! Map) return null;
    final meta = first['meta'];
    if (meta is! Map) return null;

    final price = (meta['regularMarketPrice'] as num?)?.toDouble();
    var prev = (meta['chartPreviousClose'] as num?)?.toDouble() ??
        (meta['previousClose'] as num?)?.toDouble();
    // Fallback: derive prev close from the single candle's open if missing.
    if (prev == null || prev == 0) {
      final ind = first['indicators'];
      if (ind is Map && ind['quote'] is List && (ind['quote'] as List).isNotEmpty) {
        final q0 = (ind['quote'] as List).first;
        if (q0 is Map) {
          prev = (q0['open'] as List?)?.isNotEmpty == true
              ? ((q0['open'] as List).first as num?)?.toDouble()
              : null;
        }
      }
    }
    if (price == null) return null;
    return StockQuote(
      symbol: (meta['symbol'] as String?)?.toUpperCase() ?? clean,
      price: price,
      prevClose: prev ?? price,
      name: (meta['shortName'] as String?) ?? (meta['longName'] as String?) ?? '',
      currency: (meta['currency'] as String?) ?? '',
    );
  }

  /// Fetches several quotes in parallel; silently drops failures.
  static Future<List<StockQuote>> fetchQuotes(
    Dio dio,
    List<String> symbols,
  ) async {
    final out = <StockQuote>[];
    for (final s in symbols) {
      try {
        final q = await fetchQuote(dio, s);
        if (q != null) out.add(q);
      } catch (_) {
        // skip this symbol on failure
      }
    }
    return out;
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
