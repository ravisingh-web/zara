// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. v16.0 — JARVIS MODE (No Chat UI)
//
// ✅ Single ACTIVATE/DEACTIVATE button
// ✅ Voice reactive ORB with rotating rings
// ✅ Wake word status + listening indicator
// ✅ Last response shown briefly below orb
// ✅ Settings accessible via top-right icon

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/screens/settings_screen.dart';

class ZaraHomeScreen extends StatefulWidget {
  const ZaraHomeScreen({super.key});
  @override
  State<ZaraHomeScreen> createState() => _ZaraHomeScreenState();
}

class _ZaraHomeScreenState extends State<ZaraHomeScreen>
    with TickerProviderStateMixin {

  late AnimationController _breathAnim;
  late AnimationController _rotateAnim;
  late AnimationController _pulseAnim;
  double _volumeLevel = 0.0;

  @override
  void initState() {
    super.initState();

    _breathAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    _rotateAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);

    // Wire volume from TTS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<ZaraController>();
      ctrl.onVolumeLevel = (v) {
        if (mounted) setState(() => _volumeLevel = v);
      };
    });
  }

  @override
  void dispose() {
    _breathAnim.dispose();
    _rotateAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  Color _stateColor(ZaraController c) {
    if (c.isSpeaking)          return const Color(0xFFFF00FF);
    if (c.state.isProcessing)  return const Color(0xFFFFAA00);
    if (c.isListening)         return const Color(0xFF00FF88);
    if (c.wakeWordListening)   return const Color(0xFF00F0FF);
    return Colors.white24;
  }

  String _stateLabel(ZaraController c) {
    if (c.isSpeaking)          return 'SPEAKING';
    if (c.state.isProcessing)  return 'THINKING...';
    if (c.isListening)         return 'LISTENING';
    if (c.wakeWordListening)   return '"Hii Zara" — I\'m ready';
    return 'STANDBY';
  }

  String _stateEmoji(ZaraController c) {
    if (c.isSpeaking)          return '🔊';
    if (c.state.isProcessing)  return '🧠';
    if (c.isListening)         return '🎙️';
    if (c.wakeWordListening)   return '👁️';
    return '⚡';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(builder: (ctx, ctrl, _) {
      final color = _stateColor(ctrl);
      return Scaffold(
        backgroundColor: const Color(0xFF060A12),
        body: Stack(children: [
          // Radial bg glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breathAnim,
              builder: (_, __) => CustomPaint(
                painter: _BgGlowPainter(
                    color: color, intensity: _breathAnim.value),
              ),
            ),
          ),

          SafeArea(child: Column(children: [
            _topBar(ctx, ctrl),
            const Spacer(flex: 2),
            // ── Central ORB ──────────────────────────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge([_breathAnim, _rotateAnim, _pulseAnim]),
              builder: (_, __) => SizedBox(
                width: 260, height: 260,
                child: CustomPaint(
                  painter: _OrbPainter(
                    color:       color,
                    breathVal:   _breathAnim.value,
                    rotateVal:   _rotateAnim.value,
                    pulseVal:    _pulseAnim.value,
                    volume:      _volumeLevel,
                    isSpeaking:  ctrl.isSpeaking,
                    isListening: ctrl.isListening,
                    isThinking:  ctrl.state.isProcessing,
                    isActive:    ctrl.wakeWordListening,
                  ),
                  child: Center(
                    child: Text(_stateEmoji(ctrl),
                        style: const TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // ── State label ──────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Text(
                _stateLabel(ctrl),
                style: TextStyle(
                  color: color.withOpacity(0.7 + _pulseAnim.value * 0.3),
                  fontSize: 13,
                  letterSpacing: 3,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Last response ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                ctrl.state.lastResponse.isNotEmpty &&
                    ctrl.state.lastResponse != 'Ummm...'
                    ? ctrl.state.lastResponse
                    : '',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(flex: 2),
            // ── ACTIVATE BUTTON ──────────────────────────────────────────────
            _activateButton(ctrl),
            const SizedBox(height: 16),
            // ── Permission warning ───────────────────────────────────────────
            if (!ctrl.wakeWordListening && !ctrl.state.isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Accessibility Service + Mic permission zaroori hai',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 48),
          ])),
        ]),
      );
    });
  }

  Widget _topBar(BuildContext ctx, ZaraController ctrl) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      // Logo
      Text('Z.A.R.A.',
        style: TextStyle(
          color: AppColors.cyanPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
          fontFamily: 'monospace',
        )),
      const SizedBox(width: 8),
      Text('v16', style: TextStyle(
          color: AppColors.cyanPrimary.withOpacity(0.4),
          fontSize: 9, fontFamily: 'monospace')),
      const Spacer(),
      // Accessibility status dot
      _statusDot('ACC', ctrl.permissions['accessibility'] == true),
      const SizedBox(width: 8),
      _statusDot('MIC', ctrl.permissions['microphone'] == true),
      const SizedBox(width: 14),
      GestureDetector(
        onTap: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const SettingsScreen())),
        child: const Icon(Icons.settings_outlined,
            color: Colors.white38, size: 20),
      ),
    ]),
  );

  Widget _statusDot(String label, bool ok) => Row(children: [
    Container(width: 6, height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ok ? const Color(0xFF00FF88) : Colors.red,
      )),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(
        color: ok ? Colors.white38 : Colors.red.withOpacity(0.6),
        fontSize: 8, fontFamily: 'monospace')),
  ]);

  Widget _activateButton(ZaraController ctrl) {
    final on = ctrl.wakeWordListening;
    return GestureDetector(
      onTap: () => on
          ? ctrl.stopWakeWordEngine()
          : ctrl.startWakeWordEngine(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: 220,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          gradient: LinearGradient(
            colors: on
                ? [const Color(0xFFFF3333), const Color(0xFFAA0000)]
                : [const Color(0xFF00F0FF), const Color(0xFF0066FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: (on ? Colors.red : const Color(0xFF00F0FF))
                  .withOpacity(0.45),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(on ? Icons.stop_circle_outlined : Icons.power_settings_new,
              color: Colors.black, size: 24),
          const SizedBox(width: 10),
          Text(on ? 'DEACTIVATE' : 'ACTIVATE',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 2.5,
              fontFamily: 'monospace',
            )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ORB PAINTER — Voice reactive rings + rotation
// ══════════════════════════════════════════════════════════════════════════════

class _OrbPainter extends CustomPainter {
  final Color  color;
  final double breathVal, rotateVal, pulseVal, volume;
  final bool   isSpeaking, isListening, isThinking, isActive;

  const _OrbPainter({
    required this.color,
    required this.breathVal,
    required this.rotateVal,
    required this.pulseVal,
    required this.volume,
    required this.isSpeaking,
    required this.isListening,
    required this.isThinking,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c  = Offset(size.width / 2, size.height / 2);
    final r  = size.width * 0.30;
    final angle = rotateVal * 2 * pi;

    // Core glow
    canvas.drawCircle(c, r * (0.95 + breathVal * 0.08),
        Paint()..shader = RadialGradient(colors: [
          color.withOpacity(0.25),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: c, radius: r * 1.2)));

    // Inner solid ring
    canvas.drawCircle(c, r,
        Paint()
          ..color = color.withOpacity(0.15 + breathVal * 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Rotating arc (always when active)
    if (isActive || isSpeaking || isListening) {
      _arc(canvas, c, r * 1.25, angle, pi * 1.4,
          color.withOpacity(0.6), 2.0);
      _arc(canvas, c, r * 1.25, angle + pi, pi * 0.6,
          color.withOpacity(0.25), 1.5);
    }

    // Voice bars (when speaking)
    if (isSpeaking) {
      final bars = 12;
      for (int i = 0; i < bars; i++) {
        final a   = angle + (i * 2 * pi / bars);
        final h   = volume * 30 * (0.5 + sin(angle * 6 + i) * 0.5);
        final r1  = r * 1.35;
        final r2  = r1 + h.clamp(4.0, 35.0);
        canvas.drawLine(
          Offset(c.dx + r1 * cos(a), c.dy + r1 * sin(a)),
          Offset(c.dx + r2 * cos(a), c.dy + r2 * sin(a)),
          Paint()
            ..color = color.withOpacity(0.5 + volume * 0.4)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Pulse ring (listening)
    if (isListening && !isSpeaking) {
      canvas.drawCircle(c, r * (1.4 + pulseVal * 0.2),
          Paint()
            ..color = color.withOpacity(0.3 * pulseVal)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
    }

    // Thinking dots
    if (isThinking) {
      const n = 6;
      for (int i = 0; i < n; i++) {
        final a  = angle * 2 + (i * 2 * pi / n);
        final br = r * 1.5;
        final op = (sin(angle * 8 + i * pi / 3) + 1) / 2;
        canvas.drawCircle(
          Offset(c.dx + br * cos(a), c.dy + br * sin(a)), 3.5,
          Paint()..color = color.withOpacity(0.3 + op * 0.6),
        );
      }
    }
  }

  void _arc(Canvas canvas, Offset c, double r, double start,
      double sweep, Color col, double w) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start, sweep, false,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_OrbPainter o) => true;
}

// ── Background glow painter ────────────────────────────────────────────────
class _BgGlowPainter extends CustomPainter {
  final Color  color;
  final double intensity;
  const _BgGlowPainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width * 0.7,
        Paint()..shader = RadialGradient(colors: [
          color.withOpacity(0.04 + intensity * 0.03),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.7)));
  }

  @override
  bool shouldRepaint(_BgGlowPainter o) => intensity != o.intensity;
}
