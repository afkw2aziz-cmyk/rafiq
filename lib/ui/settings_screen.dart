import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/providers.dart';
import '../core/settings.dart';
import '../services/background_worker.dart';
import '../services/llm.dart';
import '../services/notification_insight_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _key;
  late final TextEditingController _watchlist;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _name = TextEditingController(text: s.companionName);
    _city = TextEditingController(text: s.city);
    _key = TextEditingController(text: s.geminiKey);
    _watchlist = TextEditingController(text: s.watchlist.join(', '));
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _key.dispose();
    _watchlist.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _testKey() async {
    final s = ref.read(settingsProvider);
    final key = _key.text.trim();
    if (key.isEmpty) {
      _toast(s.isArabic ? 'أدخل المفتاح أولًا.' : 'Enter a key first.');
      return;
    }
    setState(() => _testing = true);
    try {
      final provider = GeminiProvider(
        apiKey: key,
        model: s.geminiModel,
        dio: Dio(),
      );
      final reply = await provider.complete(
        const [ChatMessage('user', 'Reply with the single word: ok')],
        maxTokens: 10,
        temperature: 0,
      );
      if (!mounted) return;
      _toast(s.isArabic ? 'المفتاح يعمل ✅ ($reply)' : 'Key works ✅ ($reply)');
    } catch (e) {
      if (!mounted) return;
      _toast('${s.isArabic ? 'فشل' : 'Failed'}: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _pickTime() async {
    final s = ref.read(settingsProvider);
    final parts = s.morningTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final next = ref.read(settingsProvider).copyWith(morningTime: value);
    ref.read(settingsProvider.notifier).update(next);
    await BackgroundScheduler.scheduleMorningBrief(next);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ar = s.isArabic;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              ar ? 'الإعدادات' : 'Settings',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),

          _Section(
            title: ar ? 'الشخصية والمظهر' : 'Companion',
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: ar ? 'اسم الرفيق' : 'Companion name'),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  ref.read(settingsProvider.notifier).update(s.copyWith(companionName: v.trim()));
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(ar ? 'الشكل' : 'Variant'),
                  const Spacer(),
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: ChoiceChip(
                        label: Text('${i + 1}'),
                        selected: s.variant == i,
                        onSelected: (_) => ref
                            .read(settingsProvider.notifier)
                            .update(s.copyWith(variant: i)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: s.personality,
                decoration: InputDecoration(labelText: ar ? 'شخصية الرد' : 'Personality'),
                items: [
                  DropdownMenuItem(value: 'cheerful', child: Text(ar ? 'مرح' : 'Cheerful')),
                  DropdownMenuItem(value: 'calm', child: Text(ar ? 'هادئ' : 'Calm')),
                  DropdownMenuItem(value: 'brief', child: Text(ar ? 'مختصر' : 'Brief')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(settingsProvider.notifier).update(s.copyWith(personality: v));
                },
              ),
            ],
          ),

          _Section(
            title: ar ? 'اللغة والمدينة' : 'Language & city',
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {s.lang},
                onSelectionChanged: (v) {
                  final next = s.copyWith(lang: v.first);
                  ref.read(settingsProvider.notifier).update(next);
                  ref.read(ttsProvider).stop();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _city,
                decoration: InputDecoration(
                  labelText: ar ? 'المدينة (للطقس)' : 'City (weather)',
                  helperText: ar ? 'مثال: الرياض، جدة، Dubai' : 'e.g. Riyadh, Jeddah, Dubai',
                ),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) return;
                  ref.read(settingsProvider.notifier).update(s.copyWith(city: v.trim()));
                  _toast(ar ? 'تم حفظ المدينة.' : 'City saved.');
                },
              ),
            ],
          ),

          _Section(
            title: ar ? 'الذكاء الاصطناعي' : 'AI',
            children: [
              TextField(
                controller: _key,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Gemini API key',
                  helperText: ar
                      ? 'يُخزَّن في Keystore. بدونه يعمل الرفيق محليًا.'
                      : 'Stored in the Keystore. Without it the companion runs locally.',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () async {
                        await ref.read(settingsProvider.notifier).setGeminiKey(_key.text.trim());
                        if (!mounted) return;
                        _toast(ar ? 'حُفظ المفتاح.' : 'Key saved.');
                      },
                      child: Text(ar ? 'حفظ المفتاح' : 'Save key'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testing ? null : _testKey,
                      child: Text(_testing
                          ? (ar ? 'يختبر…' : 'Testing…')
                          : (ar ? 'اختبار' : 'Test')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: s.geminiModel,
                decoration: InputDecoration(labelText: ar ? 'الموديل' : 'Model'),
                items: const [
                  DropdownMenuItem(value: 'gemini-2.5-flash', child: Text('gemini-2.5-flash')),
                  DropdownMenuItem(value: 'gemini-2.5-pro', child: Text('gemini-2.5-pro')),
                  DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('gemini-2.0-flash')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(settingsProvider.notifier).update(s.copyWith(geminiModel: v));
                },
              ),
            ],
          ),

          _Section(
            title: ar ? 'الملخص الصباحي' : 'Morning brief',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ar ? 'ملخص صوتي/إشعار كل صباح' : 'Daily morning brief'),
                subtitle: Text(
                  ar ? 'الطقس + أهم عناوين التقنية' : 'Weather + top tech headlines',
                  style: const TextStyle(fontSize: 12),
                ),
                value: s.morningBrief,
                onChanged: (v) async {
                  final next = s.copyWith(morningBrief: v);
                  ref.read(settingsProvider.notifier).update(next);
                  await BackgroundScheduler.scheduleMorningBrief(next);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ar ? 'وقت الملخص' : 'Brief time'),
                trailing: Text(
                  s.morningTime,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                onTap: _pickTime,
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.podcasts_outlined, size: 20),
                title: Text(ar ? 'نشرة المستجدات كل ساعة' : 'Hourly updates digest'),
                subtitle: Text(
                  ar
                      ? 'الجزيرة + ذكاء اصطناعي + ثغرات GitHub + أسهم أمريكية'
                      : 'Al Jazeera + AI + GitHub advisories + US stocks',
                  style: const TextStyle(fontSize: 12),
                ),
                value: s.hourlyDigest,
                onChanged: (v) async {
                  final next = s.copyWith(hourlyDigest: v);
                  ref.read(settingsProvider.notifier).update(next);
                  await BackgroundScheduler.scheduleHourlyDigest(next);
                  if (!mounted) return;
                  _toast(v
                      ? (ar ? 'ستصلك نشرة كل ساعة تقريباً.' : 'You will get a digest about hourly.')
                      : (ar ? 'أُوقفت نشرة المستجدات.' : 'Hourly digest stopped.'));
                },
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.psychology_outlined, size: 20),
                title: Text(ar ? 'فهم الطلبات بالذكاء الاصطناعي' : 'Smart intent routing'),
                subtitle: Text(
                  ar
                      ? 'يفهم «كم تسوى تسلا الحين؟» ويحوّلها لسؤال سهم. يُوقف نفسه بلا مفتاح.'
                      : 'Understands natural phrasing. Falls back to rules with no key.',
                  style: const TextStyle(fontSize: 12),
                ),
                value: s.smartRouting,
                onChanged: (v) {
                  final next = s.copyWith(smartRouting: v);
                  ref.read(settingsProvider.notifier).update(next);
                  _toast(v
                      ? (ar ? 'صار يفهم طلباتك بلغة طبيعية.' : 'Natural phrasing enabled.')
                      : (ar ? 'رجعت للقواعد المحلية.' : 'Back to local rules.'));
                },
              ),
            ],
          ),

          _Section(
            title: ar ? 'الأسهم' : 'Stocks',
            children: [
              TextField(
                controller: _watchlist,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: ar ? 'رموز الأسهم' : 'Watchlist symbols',
                  helperText: ar ? 'افصل بفاصلة: AAPL, MSFT, NVDA' : 'Comma separated: AAPL, MSFT, NVDA',
                ),
                onSubmitted: (v) {
                  final list = v
                      .split(',')
                      .map((e) => e.trim().toUpperCase())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  final next = s.copyWith(watchlist: list);
                  ref.read(settingsProvider.notifier).update(next);
                  BackgroundScheduler.scheduleStockCheck(next);
                  _toast(ar ? 'حُفظت القائمة.' : 'Watchlist saved.');
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(ar ? 'حد التنبيه' : 'Alert threshold'),
                  const Spacer(),
                  Text('${s.stockThreshold.toStringAsFixed(1)}%'),
                ],
              ),
              Slider(
                value: s.stockThreshold.clamp(1, 10),
                min: 1,
                max: 10,
                divisions: 18,
                label: '${s.stockThreshold.toStringAsFixed(1)}%',
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .update(s.copyWith(stockThreshold: v)),
              ),
            ],
          ),

          _Section(
            title: ar ? 'الصلاحيات والخصوصية' : 'Permissions & privacy',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_active_outlined, size: 20),
                title: Text(ar ? 'الوعي بالإشعارات (اختياري)' : 'Notification insight (opt-in)'),
                subtitle: Text(
                  ar
                      ? 'يقرأ اسم التطبيق وعنوان الإشعار فقط — بدون النص. مطفأ افتراضيًا.'
                      : 'Reads app name + notification title only — never the body. Off by default.',
                  style: const TextStyle(fontSize: 12),
                ),
                value: s.notificationInsight,
                onChanged: (v) async {
                  ref.read(settingsProvider.notifier).update(
                        s.copyWith(notificationInsight: v),
                      );
                  if (v) {
                    final granted = await NotificationInsightService().isGranted();
                    if (!mounted) return;
                    if (!granted) {
                      _toast(ar
                          ? 'فعّل صلاحية الإشعارات من إعدادات أندرويد لتعمل.'
                          : 'Enable Notification Access in Android settings to use it.');
                    }
                  }
                },
              ),
              if (s.notificationInsight)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(ar ? 'صلاحية الإشعارات' : 'Notification access'),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final btn in [
                    (
                      icon: Icons.notifications_outlined,
                      label: ar ? 'إشعارات' : 'Notifications',
                      onTap: () => ref.read(notificationsProvider).requestPermission(),
                    ),
                    (
                      icon: Icons.calendar_month,
                      label: ar ? 'تقويم' : 'Calendar',
                      onTap: () async {
                        final status = await Permission.calendarFullAccess.request();
                        if (!mounted) return;
                        _toast(status.isGranted
                            ? (ar ? 'تم منح إذن التقويم ✅' : 'Calendar permission granted ✅')
                            : (ar ? 'لم يُمنح إذن التقويم.' : 'Calendar permission denied.'));
                      },
                    ),
                    (
                      icon: Icons.mic_none,
                      label: ar ? 'ميكروفون' : 'Microphone',
                      onTap: () async {
                        final status = await Permission.microphone.request();
                        if (!mounted) return;
                        _toast(status.isGranted
                            ? (ar ? 'تم منح إذن الميكروفون ✅' : 'Microphone granted ✅')
                            : (ar ? 'لم يُمنح إذن الميكروفون.' : 'Microphone denied.'));
                      },
                    ),
                    (
                      icon: Icons.open_in_new,
                      label: ar ? 'إعدادات النظام' : 'App settings',
                      onTap: openAppSettings,
                    ),
                  ])
                    OutlinedButton.icon(
                      onPressed: btn.onTap,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: Icon(btn.icon, size: 20),
                      label: Text(btn.label, style: const TextStyle(fontSize: 14)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ar
                    ? 'لا يُرسل أي شيء للسحابة إلا عند استخدام Gemini أو جلب الطقس/الأخبار/الأسهم. سجل الشبكة أدناه.'
                    : 'Nothing leaves the device except Gemini calls and weather/news/stock fetches. See the network log below.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(ar ? 'سجل الشبكة' : 'Network log', style: const TextStyle(fontSize: 14)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      ar
                          ? '• generativelanguage.googleapis.com — نص المحادثة\n'
                              '• api.open-meteo.com — اسم المدينة فقط\n'
                              '• hn.algolia.com — استعلام أخبار عام\n'
                              '• stooq.com — رموز الأسهم'
                          : '• generativelanguage.googleapis.com — chat text\n'
                              '• api.open-meteo.com — city name only\n'
                              '• hn.algolia.com — public news query\n'
                              '• stooq.com — stock symbols',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ar ? 'مسح سجل المحادثة' : 'Clear chat history'),
                trailing: const Icon(Icons.delete_outline),
                onTap: () => ref.read(messagesProvider.notifier).clear(),
              ),
            ],
          ),

          _Section(
            title: ar ? 'حول' : 'About',
            children: [
              Text(
                ar
                    ? 'PixelCompanion 1.4.0 — مشروع مستقل مستوحى وظيفيًا من فكرة LOOI، وليس تابعًا لـ Tangible Future. '
                        'الشخصية والكود والأصوات أصلية. الرخصة Apache-2.0.'
                    : 'PixelCompanion 1.4.0 — an independent project functionally inspired by LOOI; not affiliated with Tangible Future. '
                        'Character, code and sounds are original. Apache-2.0.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6EE7F9)),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
