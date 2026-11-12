import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/settings.dart';
import '../core/state.dart';
import 'face.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _busy = false;
  bool _listening = false;
  String _partial = '';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _busy = true;
      _partial = '';
    });
    await ref.read(ttsProvider).stop();
    await ref.read(engineProvider).handle(t);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleMic() async {
    final stt = ref.read(sttProvider);
    final settings = ref.read(settingsProvider);
    if (_listening) {
      await stt.stop();
      if (mounted) setState(() => _listening = false);
      if (_partial.trim().isNotEmpty) await _send(_partial);
      return;
    }

    await ref.read(ttsProvider).stop();
    final ok = await stt.listen(
      locale: settings.sttLocale,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _partial = text;
          _listening = !isFinal;
        });
        _controller.text = text;
        if (isFinal) {
          setState(() => _listening = false);
          _send(text);
        }
      },
    );
    if (!mounted) return;
    if (!ok) {
      _toast(settings.isArabic
          ? 'تعذّر تشغيل الميكروفون. تحقق من الصلاحية أو محرك التعرف على الكلام.'
          : 'Could not start the microphone. Check permission or the speech engine.');
      return;
    }
    setState(() => _listening = true);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final face = ref.watch(faceProvider);
    final ar = settings.isArabic;
    final messages = ref.watch(messagesProvider);
    final lastReply = messages.isNotEmpty && messages.last.who == 'model'
        ? messages.last.text
        : '';

    // iOS-style shortcuts: icon + accent color per action. Label is kept for
    // accessibility and as a small caption under the icon.
    final shortcuts = ar
        ? const [
            (label: 'الطقس', prompt: 'الطقس اليوم', icon: Icons.wb_sunny_outlined, color: Color(0xFF5AC8FA)),
            (label: 'أخبار AI', prompt: 'أخبار الذكاء الاصطناعي', icon: Icons.auto_awesome_outlined, color: Color(0xFFBF5AF2)),
            (label: 'أسهمي', prompt: 'أسهمي', icon: Icons.trending_up, color: Color(0xFF30D158)),
            (label: 'مواعيدي', prompt: 'مواعيدي', icon: Icons.calendar_month_outlined, color: Color(0xFFFF9F0A)),
            (label: 'البطارية', prompt: 'حالة البطارية', icon: Icons.battery_charging_full, color: Color(0xFFFF453A)),
          ]
        : const [
            (label: 'Weather', prompt: 'Weather today', icon: Icons.wb_sunny_outlined, color: Color(0xFF5AC8FA)),
            (label: 'AI News', prompt: 'AI news', icon: Icons.auto_awesome_outlined, color: Color(0xFFBF5AF2)),
            (label: 'Stocks', prompt: 'My stocks', icon: Icons.trending_up, color: Color(0xFF30D158)),
            (label: 'Calendar', prompt: 'My calendar', icon: Icons.calendar_month_outlined, color: Color(0xFFFF9F0A)),
            (label: 'Battery', prompt: 'Battery status', icon: Icons.battery_charging_full, color: Color(0xFFFF453A)),
          ];

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.2,
          colors: [Color(0xFF16233F), Color(0xFF0B1020)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: face.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: face.accent.withValues(alpha: 0.6), blurRadius: 10)
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    settings.companionName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _busy ? (ar ? 'يفكر…' : 'Thinking…') : (ar ? face.labelAr : face.labelEn),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: ar ? 'كتم الصوت' : 'Stop speaking',
                    onPressed: () => ref.read(ttsProvider).stop(),
                    icon: const Icon(Icons.volume_off_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CompanionFace(
                  state: _busy ? CompanionState.thinking : face,
                  variant: settings.variant,
                  name: settings.companionName,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: lastReply.isEmpty
                  ? Padding(
                      key: const ValueKey('empty'),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      child: Text(
                        ar
                            ? 'اضغط الميكروفون أو اكتب… أنا أسمعك.'
                            : 'Tap the mic or type… I am listening.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                      ),
                    )
                  : Container(
                      key: ValueKey(lastReply),
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151B2E).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: face.accent.withValues(alpha: 0.25)),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          lastReply,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15.5, height: 1.45),
                        ),
                      ),
                    ),
            ),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shortcuts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final s = shortcuts[i];
                  return _ShortcutButton(
                    icon: s.icon,
                    label: s.label,
                    color: s.color,
                    onTap: _busy ? null : () => _send(s.prompt),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: ar ? 'اكتب رسالة…' : 'Type a message…',
                        isDense: false,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _MicButton(
                    listening: _listening,
                    onTap: _busy ? null : _toggleMic,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, this.onTap});
  final bool listening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening ? const Color(0xFF7CFFB2) : const Color(0xFF1E2740),
          boxShadow: listening
              ? [
                  BoxShadow(
                    color: const Color(0xFF7CFFB2).withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: 4,
                  )
                ]
              : null,
        ),
        child: Icon(
          listening ? Icons.stop_rounded : Icons.mic_none_rounded,
          color: listening ? const Color(0xFF07130E) : Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

/// iOS-style rounded-square shortcut: a tinted glass tile with a coloured SF-like
/// glyph and a tiny caption underneath. Tapping sends the prompt.
class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: color.withValues(alpha: enabled ? 0.16 : 0.08),
                  border: Border.all(
                    color: color.withValues(alpha: enabled ? 0.45 : 0.20),
                    width: 1,
                  ),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.30),
                            blurRadius: 16,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
