import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state.dart';

class CompanionFace extends StatefulWidget {
  const CompanionFace({
    super.key,
    required this.state,
    this.variant = 0,
    this.name = 'Pixel',
  });

  final CompanionState state;
  final int variant;
  final String name;

  @override
  State<CompanionFace> createState() => _CompanionFaceState();
}

/// Idle micro-behaviours that make the face feel alive when nothing is
/// happening. Each has its own duration and affects a specific facial channel.
enum IdleMood {
  none,
  glanceLeft,
  glanceRight,
  doubleBlink,
  yawn,
  smile,
  sigh,
  eyeOrbit,
}

class _CompanionFaceState extends State<CompanionFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final math.Random _rand = math.Random();
  Timer? _blinkTimer;
  Timer? _moodTimer;
  bool _blink = false;

  IdleMood _mood = IdleMood.none;
  double _moodT = 0; // 0..1 progress of the active mood
  int _moodMs = 0;

  // Micro-animation bookkeeping.
  DateTime _idleSince = DateTime.now();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )
      ..addListener(_onTick)
      ..repeat();
    _scheduleBlink();
    _scheduleMood();
  }

  void _onTick() {
    if (_mood == IdleMood.none) return;
    setState(() {
      _moodT += 16.0 / _moodMs; // ~16ms per frame
      if (_moodT >= 1.0) {
        _mood = IdleMood.none;
        _moodT = 0;
        _idleSince = DateTime.now();
      }
    });
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final ms = 2200 + _rand.nextInt(3200);
    _blinkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _blink = true);
      Timer(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() => _blink = false);
        _scheduleBlink();
      });
    });
  }

  bool get _isIdle => widget.state == CompanionState.idle;

  void _scheduleMood() {
    _moodTimer?.cancel();
    // Moods only fire while genuinely idle; re-checked on every tick.
    final ms = 2600 + _rand.nextInt(4200);
    _moodTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (_isIdle && _mood == IdleMood.none) _triggerMood();
      _scheduleMood();
    });
  }

  void _triggerMood() {
    final idleFor = DateTime.now().difference(_idleSince);
    // If idle long enough, a yawn becomes likely; otherwise pick a light mood.
    final pool = <IdleMood>[
      IdleMood.glanceLeft,
      IdleMood.glanceRight,
      IdleMood.doubleBlink,
      IdleMood.smile,
      IdleMood.eyeOrbit,
      if (idleFor.inSeconds > 120) IdleMood.yawn,
      if (idleFor.inSeconds > 60) IdleMood.sigh,
    ];
    final mood = pool[_rand.nextInt(pool.length)];
    _moodMs = switch (mood) {
      IdleMood.doubleBlink => 520,
      IdleMood.yawn => 1400,
      IdleMood.sigh => 1100,
      IdleMood.smile => 900,
      IdleMood.glanceLeft || IdleMood.glanceRight => 850,
      IdleMood.eyeOrbit => 1600,
      IdleMood.none => 1,
    };
    setState(() {
      _mood = mood;
      _moodT = 0;
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _moodTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          painter: _FacePainter(
            t: _c.value,
            state: widget.state,
            variant: widget.variant,
            blink: _blink,
            label: widget.name,
            mood: _isIdle ? _mood : IdleMood.none,
            moodT: _moodT,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.t,
    required this.state,
    required this.variant,
    required this.blink,
    required this.label,
    this.mood = IdleMood.none,
    this.moodT = 0,
  });

  final double t;
  final CompanionState state;
  final int variant;
  final bool blink;
  final String label;
  final IdleMood mood;
  final double moodT;

  static const _palettes = [
    [Color(0xFF7CE0C3), Color(0xFF3FB8A0), Color(0xFF0E2A28)],
    [Color(0xFFB9A7FF), Color(0xFF7B63E8), Color(0xFF17132E)],
    [Color(0xFFFFB08A), Color(0xFFF07B5A), Color(0xFF2A1510)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _palettes[variant % _palettes.length];
    final body = palette[0];
    final bodyDark = palette[1];
    final screen = palette[2];
    final accent = state.accent;

    final cx = size.width / 2;
    final breathing = 1 + math.sin(t * math.pi * 2) * 0.012;
    final bodyW = math.min(size.width * 0.72, size.height * 0.58) * breathing;
    final bodyH = bodyW * (variant == 1 ? 0.92 : 1.12);
    final cy = size.height * 0.5;

    _glow(canvas, size, cx, cy, bodyW, accent);

    canvas.save();
    canvas.translate(cx, cy);

    // antenna
    if (variant != 1) {
      final antennaPaint = Paint()
        ..color = bodyDark
        ..strokeWidth = bodyW * 0.035
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final top = -bodyH / 2;
      final sway = math.sin(t * math.pi * 2) * bodyW * 0.012;
      canvas.drawLine(
        Offset(0, top),
        Offset(sway, top - bodyH * 0.14),
        antennaPaint,
      );
      canvas.drawCircle(
        Offset(sway, top - bodyH * 0.15),
        bodyW * 0.045,
        Paint()..color = accent.withValues(alpha: 0.95),
      );
    }

    // body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: bodyW, height: bodyH),
      Radius.circular(bodyW * (variant == 1 ? 0.26 : 0.30)),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [body, bodyDark],
        ).createShader(bodyRect.outerRect),
    );

    // screen
    final screenW = bodyW * 0.78;
    final screenH = bodyH * 0.62;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -bodyH * 0.03), width: screenW, height: screenH),
      Radius.circular(screenW * 0.24),
    );
    canvas.drawRRect(screenRect, Paint()..color = screen);

    // face
    final eyeY = -screenH * 0.10;
    final eyeDx = screenW * 0.20;
    _drawEye(canvas, Offset(-eyeDx, eyeY), screenW, screenH, accent, true);
    _drawEye(canvas, Offset(eyeDx, eyeY), screenW, screenH, accent, false);

    _drawMouth(canvas, screenW, screenH, accent);
    _drawBlush(canvas, screenW, screenH);
    _drawStatus(canvas, screenW, screenH, accent);

    canvas.restore();

    if (state == CompanionState.thinking) {
      _drawThinking(canvas, cx, cy - bodyH * 0.62, accent);
    }
  }

  void _glow(Canvas canvas, Size size, double cx, double cy, double w, Color accent) {
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    final radius = w * (0.78 + pulse * 0.06);
    final shader = RadialGradient(
      colors: [accent.withValues(alpha: 0.16), Colors.transparent],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..shader = shader);

    if (state == CompanionState.listening) {
      for (var i = 0; i < 3; i++) {
        final phase = (t + i / 3) % 1.0;
        canvas.drawCircle(
          Offset(cx, cy),
          w * (0.55 + phase * 0.45),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = accent.withValues(alpha: (1 - phase) * 0.35),
        );
      }
    }
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    double sw,
    double sh,
    Color accent,
    bool left,
  ) {
    final eyeW = sw * 0.13;
    final eyeH = sh * 0.17;
    final paint = Paint()..color = accent.withValues(alpha: 0.95);

    // Double-blink: two quick closes inside the mood window.
    final dblBlink = mood == IdleMood.doubleBlink &&
        ((moodT < 0.25) || (moodT > 0.4 && moodT < 0.62));
    // Yawn squints the eyes shut for the middle of the window.
    final yawnSquint = mood == IdleMood.yawn &&
        moodT > 0.15 &&
        moodT < 0.85;

    final closed = state == CompanionState.sleeping ||
        state == CompanionState.happy ||
        blink ||
        dblBlink ||
        yawnSquint;

    if (closed) {
      final path = Path()
        ..moveTo(center.dx - eyeW / 2, center.dy)
        ..quadraticBezierTo(
          center.dx,
          center.dy + (state == CompanionState.sleeping ? -eyeH * 0.35 : eyeH * 0.55),
          center.dx + eyeW / 2,
          center.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = eyeW * 0.22
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final wide = state == CompanionState.surprised;
    final squint = state == CompanionState.sad;
    final h = eyeH * (wide ? 1.35 : squint ? 0.55 : 1.0);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: eyeW, height: h),
      Radius.circular(eyeW / 2),
    );
    canvas.drawRRect(rect, paint);

    // pupil gaze — driven by the active idle mood when one is playing.
    double gazeX = math.sin(t * math.pi * 2) * eyeW * 0.10;
    double gazeY = state == CompanionState.thinking ? -h * 0.10 : 0.0;

    // A gentle eased curve so the glance reads as intentional, not jittery.
    double ease(double x) => math.sin(x * math.pi);

    switch (mood) {
      case IdleMood.glanceLeft:
        gazeX = -eyeW * 0.42 * ease(moodT);
      case IdleMood.glanceRight:
        gazeX = eyeW * 0.42 * ease(moodT);
      case IdleMood.eyeOrbit:
        final a = moodT * math.pi * 2;
        gazeX = math.cos(a) * eyeW * 0.30;
        gazeY = math.sin(a) * h * 0.28;
      case IdleMood.yawn:
        gazeY = -h * 0.18 * ease(moodT);
      case IdleMood.sigh:
        gazeY = h * 0.10 * ease(moodT);
      case IdleMood.smile:
      case IdleMood.doubleBlink:
      case IdleMood.none:
        break;
    }

    canvas.drawCircle(
      Offset(center.dx + gazeX, center.dy + gazeY),
      eyeW * 0.30,
      Paint()..color = const Color(0xFF0B1020),
    );
    canvas.drawCircle(
      Offset(center.dx + gazeX - eyeW * 0.08, center.dy + gazeY - eyeW * 0.10),
      eyeW * 0.08,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawMouth(Canvas canvas, double sw, double sh, Color accent) {
    final y = sh * 0.16;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.022
      ..strokeCap = StrokeCap.round;

    if (state == CompanionState.speaking) {
      final open = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 2 * 7));
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, y),
          width: sw * 0.20,
          height: sh * 0.10 * open + sh * 0.02,
        ),
        Radius.circular(sw * 0.05),
      );
      canvas.drawRRect(rect, Paint()..color = accent.withValues(alpha: 0.75));
      return;
    }

    var h = switch (state) {
      CompanionState.happy => sh * 0.10,
      CompanionState.sad => -sh * 0.05,
      CompanionState.surprised => sh * 0.07,
      _ => sh * 0.02,
    };

    // Idle mouth moods override the resting smile line.
    double mouthW = sw * 0.10;
    double ease(double x) => math.sin(x * math.pi);
    switch (mood) {
      case IdleMood.smile:
        h = sh * 0.11 * ease(moodT);
        mouthW = sw * (0.10 + 0.05 * ease(moodT));
      case IdleMood.yawn:
        // Wide open "O" mouth during the middle of a yawn.
        if (moodT > 0.2 && moodT < 0.8) {
          final open = math.sin((moodT - 0.2) / 0.6 * math.pi);
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, y),
              width: sw * 0.14,
              height: sh * 0.16 * open,
            ),
            Radius.circular(sw * 0.06),
          );
          canvas.drawRRect(rect, Paint()..color = accent.withValues(alpha: 0.72));
          return;
        }
      case IdleMood.sigh:
        h = -sh * 0.045 * ease(moodT);
      case IdleMood.glanceLeft:
      case IdleMood.glanceRight:
      case IdleMood.doubleBlink:
      case IdleMood.eyeOrbit:
      case IdleMood.none:
        break;
    }

    final path = Path()
      ..moveTo(-mouthW, y)
      ..quadraticBezierTo(0, y + h, mouthW, y);
    canvas.drawPath(path, paint);
  }

  void _drawBlush(Canvas canvas, double sw, double sh) {
    if (state == CompanionState.sad || state == CompanionState.sleeping) return;
    final paint = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.18);
    canvas.drawCircle(Offset(-sw * 0.28, sh * 0.08), sw * 0.07, paint);
    canvas.drawCircle(Offset(sw * 0.28, sh * 0.08), sw * 0.07, paint);
  }

  void _drawStatus(Canvas canvas, double sw, double sh, Color accent) {
    final text = switch (state) {
      CompanionState.listening => '•••',
      CompanionState.thinking => '···',
      CompanionState.surprised => '!',
      CompanionState.sleeping => 'z z',
      _ => '',
    };
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: accent.withValues(alpha: 0.55),
          fontSize: sw * 0.075,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, sh * 0.30));
  }

  void _drawThinking(Canvas canvas, double cx, double top, Color accent) {
    for (var i = 0; i < 3; i++) {
      final phase = (t + i * 0.18) % 1.0;
      final y = top - phase * 26;
      canvas.drawCircle(
        Offset(cx + (i - 1) * 18.0, y),
        4 + 2 * (1 - phase),
        Paint()..color = accent.withValues(alpha: (1 - phase) * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.t != t ||
      old.state != state ||
      old.variant != variant ||
      old.blink != blink ||
      old.label != label ||
      old.mood != mood ||
      old.moodT != moodT;
}
