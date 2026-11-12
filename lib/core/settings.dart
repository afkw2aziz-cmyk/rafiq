import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kAllSkills = <String>{
  'system',
  'weather',
  'reminder',
  'calendar',
  'chat',
  'news',
  'stock',
  'notifications',
  'digest',
};

/// Skills that exist but are OFF by default (privacy-sensitive). The user
/// must opt in from Settings before they run.
const kOptInSkills = <String>{'notifications'};

/// The default enabled set = everything except opt-in skills. Written as a
/// const literal so it can be used as a default parameter value.
const kDefaultEnabledSkills = <String>{
  'system',
  'weather',
  'reminder',
  'calendar',
  'chat',
  'news',
  'stock',
  'digest',
};

class AppSettings {
  const AppSettings({
    this.lang = 'ar',
    this.companionName = 'Pixel',
    this.variant = 0,
    this.personality = 'cheerful',
    this.city = 'Riyadh',
    this.countryCode = 'SA',
    this.morningBrief = true,
    this.hourlyDigest = false,
    this.smartRouting = true,
    this.morningTime = '08:00',
    this.enabledSkills = kDefaultEnabledSkills,
    this.watchlist = const ['AAPL', 'MSFT', 'NVDA'],
    this.stockThreshold = 3.0,
    this.handsFree = false,
    this.notificationInsight = false,
    this.ttsRate = 0.5,
    this.geminiModel = 'gemini-2.5-flash',
    this.geminiKey = '',
  });

  final String lang;
  final String companionName;
  final int variant;
  final String personality;
  final String city;
  final String countryCode;
  final bool morningBrief;
  final bool hourlyDigest;
  final bool smartRouting;
  final String morningTime;
  final Set<String> enabledSkills;
  final List<String> watchlist;
  final double stockThreshold;
  final bool handsFree;
  final bool notificationInsight;
  final double ttsRate;
  final String geminiModel;
  final String geminiKey;

  bool get isArabic => lang == 'ar';
  String get ttsLocale => isArabic ? 'ar-SA' : 'en-US';
  String get sttLocale => isArabic ? 'ar-SA' : 'en-US';

  AppSettings copyWith({
    String? lang,
    String? companionName,
    int? variant,
    String? personality,
    String? city,
    String? countryCode,
    bool? morningBrief,
    bool? hourlyDigest,
    bool? smartRouting,
    String? morningTime,
    Set<String>? enabledSkills,
    List<String>? watchlist,
    double? stockThreshold,
    bool? handsFree,
    bool? notificationInsight,
    double? ttsRate,
    String? geminiModel,
    String? geminiKey,
  }) {
    return AppSettings(
      lang: lang ?? this.lang,
      companionName: companionName ?? this.companionName,
      variant: variant ?? this.variant,
      personality: personality ?? this.personality,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
      morningBrief: morningBrief ?? this.morningBrief,
      hourlyDigest: hourlyDigest ?? this.hourlyDigest,
      smartRouting: smartRouting ?? this.smartRouting,
      morningTime: morningTime ?? this.morningTime,
      enabledSkills: enabledSkills ?? this.enabledSkills,
      watchlist: watchlist ?? this.watchlist,
      stockThreshold: stockThreshold ?? this.stockThreshold,
      handsFree: handsFree ?? this.handsFree,
      notificationInsight: notificationInsight ?? this.notificationInsight,
      ttsRate: ttsRate ?? this.ttsRate,
      geminiModel: geminiModel ?? this.geminiModel,
      geminiKey: geminiKey ?? this.geminiKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'lang': lang,
        'companionName': companionName,
        'variant': variant,
        'personality': personality,
        'city': city,
        'countryCode': countryCode,
        'morningBrief': morningBrief,
        'hourlyDigest': hourlyDigest,
        'smartRouting': smartRouting,
        'morningTime': morningTime,
        'enabledSkills': enabledSkills.toList(),
        'watchlist': watchlist,
        'stockThreshold': stockThreshold,
        'handsFree': handsFree,
        'notificationInsight': notificationInsight,
        'ttsRate': ttsRate,
        'geminiModel': geminiModel,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        lang: j['lang'] as String? ?? 'ar',
        companionName: j['companionName'] as String? ?? 'Pixel',
        variant: j['variant'] as int? ?? 0,
        personality: j['personality'] as String? ?? 'cheerful',
        city: j['city'] as String? ?? 'Riyadh',
        countryCode: j['countryCode'] as String? ?? 'SA',
        morningBrief: j['morningBrief'] as bool? ?? true,
        hourlyDigest: j['hourlyDigest'] as bool? ?? false,
        smartRouting: j['smartRouting'] as bool? ?? true,
        morningTime: j['morningTime'] as String? ?? '08:00',
        enabledSkills:
            (j['enabledSkills'] as List?)?.cast<String>().toSet() ??
                kDefaultEnabledSkills,
        watchlist: (j['watchlist'] as List?)?.cast<String>() ??
            const ['AAPL', 'MSFT', 'NVDA'],
        stockThreshold: (j['stockThreshold'] as num?)?.toDouble() ?? 3.0,
        handsFree: j['handsFree'] as bool? ?? false,
        notificationInsight: j['notificationInsight'] as bool? ?? false,
        ttsRate: (j['ttsRate'] as num?)?.toDouble() ?? 0.5,
        geminiModel: j['geminiModel'] as String? ?? 'gemini-2.5-flash',
      );
}

class SettingsStore {
  static const _prefsKey = 'pixel_companion_settings_v1';
  static const _secureKey = 'pixel_companion_gemini_key';
  static const _secure = FlutterSecureStorage();

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    var s = const AppSettings();
    if (raw != null) {
      try {
        s = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    try {
      final key = await _secure.read(key: _secureKey);
      if (key != null && key.isNotEmpty) s = s.copyWith(geminiKey: key);
    } catch (_) {}
    return s;
  }

  static Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(s.toJson()));
  }

  static Future<void> saveKey(String key) async {
    try {
      if (key.isEmpty) {
        await _secure.delete(key: _secureKey);
      } else {
        await _secure.write(key: _secureKey, value: key);
      }
    } catch (_) {}
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(super.initial);

  void update(AppSettings next) {
    state = next;
    SettingsStore.save(next);
  }

  AppSettings mutate(AppSettings Function(AppSettings) f) {
    final next = f(state);
    update(next);
    return next;
  }

  Future<void> setGeminiKey(String key) async {
    await SettingsStore.saveKey(key);
    state = state.copyWith(geminiKey: key);
  }

  void toggleSkill(String id, bool on) {
    final next = {...state.enabledSkills};
    on ? next.add(id) : next.remove(id);
    update(state.copyWith(enabledSkills: next));
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  throw UnimplementedError('overridden in main');
});
