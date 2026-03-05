// lib/features/hologram_ui/widgets/zara_orb_painter.dart
// Z.A.R.A. Floating Voice-Reactive Orb
// Reacts to: idle (slow pulse), listening (fast green), speaking (purple wave)

import 'dart:math';
import 'package:flutter/material.dart';

// ── ORB STATES ─────────────────────────────────────────────────────────────
enum OrbState { idle, listening, speaking, thinking }

class ZaraFloatingOrb extends StatefulWidget {
  final OrbState state;
  final double   volumeLevel; // 0.0–1.0 from TTS
  final VoidCallback? onTap;

  const ZaraFloatingOrb({
    super.key,
    this.state       = OrbState.idle,
    this.volumeLevel = 0.0,
    this.onTap,
  });

  @override
  State<ZaraFloatingOrb> createState() => _ZaraFloatingOrbState();
}

class _ZaraFloatingOrbState extends State<ZaraFloatingOrb>
    with TickerProviderStateMixin {

  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _waveCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _ringAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _ringAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(ZaraFloatingOrb old) {
    super.didUpdateWidget(old);
    _updateAnimationSpeed();
  }

  void _updateAnimationSpeed() {
    switch (widget.state) {
      case OrbState.listening:
        _pulseCtrl.duration = const Duration(milliseconds: 400);
        _pulseCtrl.repeat(reverse: true);
        break;
      case OrbState.speaking:
        _pulseCtrl.duration = const Duration(milliseconds: 600);
        _pulseCtrl.repeat(reverse: true);
        break;
      case OrbState.thinking:
        _pulseCtrl.duration = const Duration(milliseconds: 900);
        _pulseCtrl.repeat(reverse: true);
        break;
      case OrbState.idle:
        _pulseCtrl.duration = const Duration(milliseconds: 1800);
        _pulseCtrl.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  // ── COLORS per state ──────────────────────────────────────────────────────
  Color get _coreColor {
    switch (widget.state) {
      case OrbState.listening: return const Color(0xFF00FF88);
      case OrbState.speaking:  return const Color(0xFFBB00FF);
      case OrbState.thinking:  return const Color(0xFFFFAA00);
      case OrbState.idle:      return const Color(0xFF00F0FF);
    }
  }

  Color get _glowColor {
    switch (widget.state) {
      case OrbState.listening: return const Color(0xFF00FF88).withOpacity(0.4);
      case OrbState.speaking:  return const Color(0xFFBB00FF).withOpacity(0.5);
      case OrbState.thinking:  return const Color(0xFFFFAA00).withOpacity(0.4);
      case OrbState.idle:      return const Color(0xFF00F0FF).withOpacity(0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _ringAnim, _waveCtrl]),
        builder: (_, __) {
          // Volume boosts pulse when speaking
          final volumeBoost = widget.state == OrbState.speaking
              ? (1.0 + widget.volumeLevel * 0.4)
              : 1.0;
          final scale = _pulseAnim.value * volumeBoost;

          return SizedBox(
            width: 80, height: 80,
            child: CustomPaint(
              painter: _OrbPainter(
                scale:      scale,
                ringProgress: _ringAnim.value,
                wavePhase:  _waveCtrl.value,
                coreColor:  _coreColor,
                glowColor:  _glowColor,
                state:      widget.state,
                volume:     widget.volumeLevel,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── CUSTOM PAINTER ─────────────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final double   scale;
  final double   ringProgress;
  final double   wavePhase;
  final Color    coreColor;
  final Color    glowColor;
  final OrbState state;
  final double   volume;

  _OrbPainter({
    required this.scale,
    required this.ringProgress,
    required this.wavePhase,
    required this.coreColor,
    required this.glowColor,
    required this.state,
    required this.volume,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.30 * scale;

    final paint = Paint()..isAntiAlias = true;

    // 1. Outer glow ring
    if (state == OrbState.speaking || state == OrbState.listening) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = glowColor.withOpacity(1.0 - ringProgress);
      canvas.drawCircle(Offset(cx, cy), r + (12 * ringProgress), paint);
    }

    // 2. Glow halo
    paint
      ..style  = PaintingStyle.fill
      ..shader = RadialGradient(
          colors: [glowColor, Colors.transparent],
          stops:  const [0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.6));
    canvas.drawCircle(Offset(cx, cy), r * 1.6, paint);

    // 3. Core orb
    paint.shader = RadialGradient(
      colors: [Colors.white.withOpacity(0.9), coreColor, coreColor.withOpacity(0.3)],
      stops:  const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.shader = null;

    // 4. Voice wave bars when speaking
    if (state == OrbState.speaking && volume > 0.05) {
      paint
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap   = StrokeCap.round
        ..color       = Colors.white.withOpacity(0.7);

      const bars   = 5;
      const barW   = 3.0;
      final totalW = bars * barW * 2.5;
      final startX = cx - totalW / 2;

      for (int i = 0; i < bars; i++) {
        final x      = startX + i * barW * 2.5;
        final phase  = wavePhase * 2 * pi + i * 0.8;
        final height = r * 0.5 * (0.3 + 0.7 * (sin(phase).abs() * volume));
        canvas.drawLine(
          Offset(x, cy - height),
          Offset(x, cy + height),
          paint,
        );
      }
    }

    // 5. Inner bright spot
    paint
      ..style  = PaintingStyle.fill
      ..color  = Colors.white.withOpacity(0.8);
    canvas.drawCircle(Offset(cx - r * 0.2, cy - r * 0.2), r * 0.18, paint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}
