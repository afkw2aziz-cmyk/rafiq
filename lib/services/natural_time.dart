class WhenResult {
  const WhenResult({this.when, required this.title});
  final DateTime? when;
  final String title;
}

const _arDigits = {
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};

const _weekdays = <String, int>{
  'sunday': 7,
  'sun': 7,
  'الأحد': 7,
  'الاحد': 7,
  'monday': 1,
  'mon': 1,
  'الاثنين': 1,
  'الإثنين': 1,
  'tuesday': 2,
  'tue': 2,
  'الثلاثاء': 2,
  'wednesday': 3,
  'wed': 3,
  'الأربعاء': 3,
  'الاربعاء': 3,
  'thursday': 4,
  'thu': 4,
  'الخميس': 4,
  'friday': 5,
  'fri': 5,
  'الجمعة': 5,
  'saturday': 6,
  'sat': 6,
  'السبت': 6,
};

WhenResult parseWhen(
  String input, {
  DateTime? nowOverride,
  bool defaultTomorrow = false,
}) {
  var text = input;
  for (final e in _arDigits.entries) {
    text = text.replaceAll(e.key, e.value);
  }
  final lower = text.toLowerCase();
  final now = nowOverride ?? DateTime.now();
  var date = DateTime(now.year, now.month, now.day);
  var dateFound = false;
  var timeFound = false;
  var hour = 9;
  var minute = 0;

  // Relative time: "in 2 hours" / "بعد ساعتين" / "بعد 30 دقيقة"
  final rel = RegExp(
    r'(?:in\s+(\d+)\s*(min|mins|minutes?|hours?|hrs?|days?)|بعد\s+(\d+)\s*(دقيقة|دقائق|دقيقتين|ساعة|ساعات|ساعتين|يوم|أيام))',
    caseSensitive: false,
  ).firstMatch(lower);
  if (rel != null) {
    final n = int.tryParse(rel.group(1) ?? rel.group(3) ?? '') ?? 0;
    final unit = (rel.group(2) ?? rel.group(4) ?? '').toLowerCase();
    var result = now;
    if (unit.startsWith('min') || unit.startsWith('دقيق')) {
      result = now.add(Duration(minutes: n));
    } else if (unit.startsWith('hour') ||
        unit.startsWith('hr') ||
        unit.startsWith('ساع')) {
      result = now.add(Duration(hours: n));
    } else {
      result = now.add(Duration(days: n));
    }
    return WhenResult(when: result, title: _cleanTitle(text, lower));
  }
  final arWordRelative = RegExp(r'بعد\s+(ساعتين|ساعة|نصف\s*ساعة|دقيقة)')
      .firstMatch(lower);
  if (arWordRelative != null) {
    final w = arWordRelative.group(1)!;
    final delta = w.contains('ساعتين')
        ? const Duration(hours: 2)
        : w.contains('نصف')
            ? const Duration(minutes: 30)
            : w.contains('ساعة')
                ? const Duration(hours: 1)
                : const Duration(minutes: 1);
    return WhenResult(when: now.add(delta), title: _cleanTitle(text, lower));
  }

  // Explicit date words
  if (RegExp(r'(بعد\s*بكرة|after\s*tomorrow|day\s*after\s*tomorrow)')
      .hasMatch(lower)) {
    date = date.add(const Duration(days: 2));
    dateFound = true;
  } else if (RegExp(r'(بكرة|غدا|غداً|غدًا|tomorrow)').hasMatch(lower)) {
    date = date.add(const Duration(days: 1));
    dateFound = true;
  } else if (RegExp(r'(اليوم|today|tonight|الليلة)').hasMatch(lower)) {
    dateFound = true;
  } else {
    for (final e in _weekdays.entries) {
      if (RegExp('(^|\\s)${RegExp.escape(e.key)}(\\s|\$)').hasMatch(lower)) {
        final target = e.value % 7; // DateTime.weekday uses 1..7
        var delta = (target - now.weekday) % 7;
        if (delta == 0) delta = 7;
        date = date.add(Duration(days: delta));
        dateFound = true;
        break;
      }
    }
  }

  // Explicit clock time
  final explicit = RegExp(
    r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.?|p\.m\.?|صباحا|صباحاً|مساء|مساءً|ص|م)\b',
    caseSensitive: false,
  ).firstMatch(lower);
  final withAt = RegExp(
    r'(?:الساعة|at|@)\s*(\d{1,2})(?::(\d{2}))?',
    caseSensitive: false,
  ).firstMatch(lower);
  final colonTime =
      RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(lower);

  String? suffix;
  if (explicit != null) {
    hour = int.tryParse(explicit.group(1)!) ?? 9;
    minute = int.tryParse(explicit.group(2) ?? '0') ?? 0;
    suffix = (explicit.group(3) ?? '').toLowerCase();
    timeFound = true;
  } else if (withAt != null) {
    hour = int.tryParse(withAt.group(1)!) ?? 9;
    minute = int.tryParse(withAt.group(2) ?? '0') ?? 0;
    timeFound = true;
  } else if (colonTime != null) {
    hour = int.tryParse(colonTime.group(1)!) ?? 9;
    minute = int.tryParse(colonTime.group(2)!) ?? 0;
    timeFound = true;
  }

  if (timeFound) {
    final isPm = suffix != null &&
        (suffix.contains('pm') ||
            suffix.contains('p.m') ||
            suffix == 'م' ||
            suffix.contains('مساء'));
    final isAm = suffix != null &&
        (suffix.contains('am') ||
            suffix.contains('a.m') ||
            suffix == 'ص' ||
            suffix.contains('صباح'));
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    if (!isPm && !isAm && suffix == null && hour <= 7) {
      hour += 12; // "at 3" in speech is almost always 3 PM
    }
    hour = hour.clamp(0, 23);
    minute = minute.clamp(0, 59);
  }

  DateTime? when;
  if (dateFound || timeFound) {
    when = DateTime(date.year, date.month, date.day, hour, minute);
    if (!timeFound && dateFound) {
      when = DateTime(date.year, date.month, date.day, 9, 0);
    }
    if (!dateFound && timeFound && when.isBefore(now)) {
      when = when.add(const Duration(days: 1));
    }
    if (dateFound && !timeFound && when.isBefore(now)) {
      when = when.add(const Duration(days: 1));
    }
  } else if (defaultTomorrow) {
    when = DateTime(now.year, now.month, now.day, 9, 0)
        .add(const Duration(days: 1));
  }

  return WhenResult(when: when, title: _cleanTitle(text, lower));
}

String _cleanTitle(String original, String lower) {
  var t = original;
  final patterns = <RegExp>[
    RegExp(r'^\s*(please\s+)?(remind me to|remind me|remember to|ذكرني أن|ذكرني ان|ذكرني)\s*',
        caseSensitive: false),
    RegExp(r'^\s*(please\s+)?(add|create|schedule|set up|أضف|أضيفي|اضف|أنشئ|انشئ)\s*',
        caseSensitive: false),
    RegExp(r'^\s*(an?\s+)\b', caseSensitive: false),
    RegExp(r'\b(in|after|بعد)\s+\d+\s*(min|mins|minutes?|hours?|hrs?|days?|دقيقة|دقائق|ساعة|ساعات|يوم|أيام)\b',
        caseSensitive: false),
    RegExp(r'\b(today|tomorrow|tonight|after tomorrow|بكرة|غدا|غداً|اليوم|الليلة|بعد بكرة)\b',
        caseSensitive: false),
    RegExp(r'\b(on\s+)?(sunday|monday|tuesday|wednesday|thursday|friday|saturday|sun|mon|tue|wed|thu|fri|sat)\b',
        caseSensitive: false),
    RegExp(r'يوم\s+(الأحد|الاحد|الاثنين|الإثنين|الثلاثاء|الأربعاء|الاربعاء|الخميس|الجمعة|السبت)',
        caseSensitive: false),
    RegExp(r'(?:الساعة|at|@)\s*\d{1,2}(?::\d{2})?\s*(am|pm|a\.m\.?|p\.m\.?|صباحا|صباحاً|مساء|مساءً|ص|م)?',
        caseSensitive: false),
    RegExp(r'\b\d{1,2}(?::\d{2})?\s*(am|pm|a\.m\.?|p\.m\.?|صباحا|صباحاً|مساء|مساءً)\b',
        caseSensitive: false),
    RegExp(r'\b\d{1,2}:\d{2}\b'),
  ];
  for (final p in patterns) {
    t = t.replaceAll(p, ' ');
  }
  t = t
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s،,.\-–:]+|[\s،,.\-–:]+$'), '')
      .trim();
  if (t.isEmpty) return '';
  if (t.length == 1) return t;
  return t[0].toUpperCase() + t.substring(1);
}
