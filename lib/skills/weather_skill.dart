import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/state.dart';
import 'skill.dart';

class WeatherSkill extends Skill {
  @override
  String get id => 'weather';

  @override
  SkillManifest get manifest => const SkillManifest(
        id: 'weather',
        nameAr: 'الطقس',
        nameEn: 'Weather',
        descriptionAr: 'حالة الطقس اليوم وغدًا لمدينتك (Open-Meteo، بلا مفتاح).',
        descriptionEn: 'Today and tomorrow weather for your city (Open-Meteo, no key).',
        icon: Icons.wb_sunny_outlined,
        triggers: [r'طقس|الجو|مطر|حرارة|weather|forecast|temperature|rain'],
      );

  @override
  Future<SkillResponse> invoke(SkillRequest req) async {
    final ar = req.ctx.isArabic;
    req.ctx.setFace(CompanionState.thinking);
    try {
      final text = await fetchBrief(
        req.ctx.http,
        city: req.ctx.settings.city,
        ar: ar,
      );
      return SkillResponse(text: text, face: CompanionState.happy);
    } catch (e) {
      return SkillResponse(
        text: ar
            ? 'ما قدرت أجيب الطقس الآن. تأكد من الإنترنت أو اسم المدينة في الإعدادات.'
            : 'I could not fetch the weather. Check the connection or the city in Settings.',
        face: CompanionState.sad,
      );
    }
  }

  static Future<String> fetchBrief(
    Dio dio, {
    required String city,
    required bool ar,
  }) async {
    final geo = await dio.get<Map<String, dynamic>>(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': city,
        'count': 1,
        'language': ar ? 'ar' : 'en',
        'format': 'json',
      },
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    final results = geo.data?['results'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('City not found');
    }
    final place = results.first as Map;
    final lat = place['latitude'];
    final lon = place['longitude'];
    final label = (place['name'] ?? city).toString();

    final res = await dio.get<Map<String, dynamic>>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': 'temperature_2m,apparent_temperature,weather_code,wind_speed_10m',
        'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': 2,
      },
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    final data = res.data ?? const {};
    final cur = (data['current'] as Map?) ?? const {};
    final daily = (data['daily'] as Map?) ?? const {};
    final temp = (cur['temperature_2m'] as num?)?.round();
    final feels = (cur['apparent_temperature'] as num?)?.round();
    final code = (cur['weather_code'] as num?)?.toInt() ?? 0;
    final desc = describe(code, ar);
    final max = (daily['temperature_2m_max'] as List?)?.first;
    final min = (daily['temperature_2m_min'] as List?)?.first;
    final rain = (daily['precipitation_probability_max'] as List?)?.first;

    if (ar) {
      return '$label: $temp°، $desc. الحس بها $feels°. '
          'العظمى ${max ?? '—'} والصغرى ${min ?? '—'}، '
          'احتمال المطر ${rain ?? 0}%.';
    }
    return '$label: $temp°C, $desc. Feels like $feels°C. '
        'High ${max ?? '—'}, low ${min ?? '—'}, rain chance ${rain ?? 0}%.';
  }

  static String describe(int code, bool ar) {
    String en;
    String a;
    if (code == 0) {
      en = 'clear sky';
      a = 'صحو';
    } else if (code <= 3) {
      en = 'partly cloudy';
      a = 'غائم جزئيًا';
    } else if (code == 45 || code == 48) {
      en = 'foggy';
      a = 'ضباب';
    } else if (code >= 51 && code <= 57) {
      en = 'drizzle';
      a = 'رذاذ';
    } else if (code >= 61 && code <= 67) {
      en = 'rain';
      a = 'مطر';
    } else if (code >= 71 && code <= 77) {
      en = 'snow';
      a = 'ثلج';
    } else if (code >= 80 && code <= 82) {
      en = 'rain showers';
      a = 'زخات مطر';
    } else if (code >= 85 && code <= 86) {
      en = 'snow showers';
      a = 'زخات ثلج';
    } else if (code >= 95) {
      en = 'thunderstorm';
      a = 'عاصفة رعدية';
    } else {
      en = 'mixed conditions';
      a = 'أجواء متقلبة';
    }
    return ar ? a : en;
  }

  @override
  Widget? buildSettings(BuildContext context) => null;
}
