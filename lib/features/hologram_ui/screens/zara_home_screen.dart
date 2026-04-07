// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. v19.0 — Gemini Live UI
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/live/live_session.dart';
import 'package:zara/features/live/zara_controller.dart';
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
  late AnimationController _connectAnim;
  double _volume = 0.0;

  @override
  void initState() {
    super.initState();
    _breathAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _rotateAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat();
    _pulseAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _connectAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<ZaraController>();
      ctrl.onVolumeLevel = (v) { if (mounted) setState(() => _volume = v); };
    });
  }

  @override
  void dispose() {
    _breathAnim.dispose(); _rotateAnim.dispose();
    _pulseAnim.dispose();  _connectAnim.dispose();
    super.dispose();
  }

  Color _color(ZaraController c) {
    switch (c.liveState) {
      case LiveState.connecting: return const Color(0xFFFFAA00);
      case LiveState.listening:  return const Color(0xFF00FF88);
      case LiveState.speaking:   return const Color(0xFF00F0FF);
      case LiveState.error:      return const Color(0xFFFF3333);
      default:                   return Colors.white24;
    }
  }

  String _label(ZaraController c) {
    switch (c.liveState) {
      case LiveState.connecting: return 'CONNECTING...';
      case LiveState.listening:  return 'LISTENING — Bol Sir';
      case LiveState.speaking:   return 'SPEAKING';
      case LiveState.error:      return 'ERROR — Tap to retry';
      default:                   return 'TAP TO CONNECT';
    }
  }

  String _emoji(ZaraController c) {
    switch (c.liveState) {
      case LiveState.connecting: return '⏳';
      case LiveState.listening:  return '🎙️';
      case LiveState.speaking:   return '🔊';
      case LiveState.error:      return '⚠️';
      default:                   return '👁️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(builder: (ctx, ctrl, _) {
      final color = _color(ctrl);
      return Scaffold(
        backgroundColor: const Color(0xFF060A12),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBuilder(
            animation: _breathAnim,
            builder: (_, __) => CustomPaint(
              painter: _BgGlow(color: color, intensity: _breathAnim.value)),
          )),
          SafeArea(child: Column(children: [
            _topBar(ctx, ctrl),
            const Spacer(flex: 2),
            GestureDetector(
              onTap: ctrl.toggleConnection,
              child: AnimatedBuilder(
                animation: Listenable.merge([_breathAnim, _rotateAnim, _pulseAnim, _connectAnim]),
                builder: (_, __) => SizedBox(width: 260, height: 260,
                  child: CustomPaint(
                    painter: _OrbPainter(color: color, breathVal: _breathAnim.value,
                      rotateVal: _rotateAnim.value, pulseVal: _pulseAnim.value,
                      connectVal: _connectAnim.value, volume: _volume, state: ctrl.liveState),
                    child: Center(child: Text(_emoji(ctrl), style: const TextStyle(fontSize: 48))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Text(_label(ctrl),
                style: TextStyle(color: color.withOpacity(0.7 + _pulseAnim.value * 0.3),
                  fontSize: 13, letterSpacing: 3, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                ctrl.errorMsg.isNotEmpty ? ctrl.errorMsg : ctrl.lastText,
                style: TextStyle(
                  color: ctrl.errorMsg.isNotEmpty ? Colors.red.withOpacity(0.7) : Colors.white38,
                  fontSize: 11, fontFamily: 'monospace', height: 1.6),
                textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const Spacer(flex: 2),
            _connectBtn(ctrl),
            const SizedBox(height: 16),
            Text(
              ctrl.isConnected ? 'Live — Bolo, Zara sun rahi hai'
              : ctrl.liveState == LiveState.error ? 'Tap to retry'
              : 'Tap to connect',
              style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace'),
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
      Text('Z.A.R.A.', style: TextStyle(color: AppColors.cyanPrimary,
          fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace')),
      const SizedBox(width: 6),
      Text('v19', style: TextStyle(color: AppColors.cyanPrimary.withOpacity(0.4),
          fontSize: 9, fontFamily: 'monospace')),
      const Spacer(),
      _dot('ACC', ctrl.permissions['accessibility'] == true),
      const SizedBox(width: 8),
      _dot('LIVE', ctrl.isConnected),
      const SizedBox(width: 14),
      GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        child: const Icon(Icons.settings_outlined, color: Colors.white38, size: 20)),
    ]),
  );

  Widget _dot(String label, bool ok) => Row(children: [
    Container(width: 6, height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: ok ? const Color(0xFF00FF88) : Colors.red,
        boxShadow: ok ? [BoxShadow(color: const Color(0xFF00FF88).withOpacity(0.5), blurRadius: 6)] : [])),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(color: ok ? Colors.white38 : Colors.red.withOpacity(0.6),
        fontSize: 8, fontFamily: 'monospace')),
  ]);

  Widget _connectBtn(ZaraController ctrl) {
    final on   = ctrl.isConnected;
    final busy = ctrl.isConnecting;
    return GestureDetector(
      onTap: ctrl.toggleConnection,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut,
        width: 220, height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          gradient: LinearGradient(colors: on
              ? [const Color(0xFFFF3333), const Color(0xFFAA0000)]
              : busy ? [const Color(0xFFFFAA00), const Color(0xFFCC7700)]
              : [const Color(0xFF00F0FF), const Color(0xFF0066FF)]),
          boxShadow: [BoxShadow(
            color: (on ? Colors.red : busy ? Colors.orange : const Color(0xFF00F0FF)).withOpacity(0.45),
            blurRadius: 28, spreadRadius: 4)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(on ? Icons.stop_circle_outlined : busy ? Icons.hourglass_top : Icons.power_settings_new,
              color: Colors.black, size: 22),
          const SizedBox(width: 10),
          Text(on ? 'DISCONNECT' : busy ? 'CONNECTING...' : 'CONNECT',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold,
                fontSize: 14, letterSpacing: 2.5, fontFamily: 'monospace')),
        ]),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color color; final double breathVal, rotateVal, pulseVal, connectVal, volume;
  final LiveState state;
  const _OrbPainter({required this.color, required this.breathVal, required this.rotateVal,
    required this.pulseVal, required this.connectVal, required this.volume, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.28;
    final angle = rotateVal * 2 * pi;
    canvas.drawCircle(c, r * (0.95 + breathVal * 0.08),
      Paint()..shader = RadialGradient(colors: [color.withOpacity(0.25), Colors.transparent])
        .createShader(Rect.fromCircle(center: c, radius: r * 1.2)));
    canvas.drawCircle(c, r, Paint()..color = color.withOpacity(0.18 + breathVal * 0.1)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    if (state == LiveState.connecting) {
      for (int i = 0; i < 8; i++) {
        final a = connectVal * 2 * pi + (i * 2 * pi / 8);
        final op = (sin(connectVal * 2 * pi * 2 + i * pi / 4) + 1) / 2;
        canvas.drawCircle(Offset(c.dx + r * 1.4 * cos(a), c.dy + r * 1.4 * sin(a)), 4,
          Paint()..color = color.withOpacity(0.2 + op * 0.7));
      }
    }
    if (state == LiveState.listening) {
      _arc(canvas, c, r * 1.25, angle, pi * 1.5, color.withOpacity(0.7), 2.5);
      canvas.drawCircle(c, r * (1.5 + pulseVal * 0.18),
        Paint()..color = color.withOpacity(0.2 * pulseVal)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }
    if (state == LiveState.speaking) {
      _arc(canvas, c, r * 1.25, angle * 1.5, pi * 1.8, color.withOpacity(0.7), 2.5);
      for (int i = 0; i < 16; i++) {
        final a = angle * 1.5 + (i * 2 * pi / 16);
        final h = (volume * 35 * (0.4 + 0.6 * ((sin(angle * 8 + i * 1.2) + 1) / 2))).clamp(4.0, 40.0);
        canvas.drawLine(Offset(c.dx + r * 1.35 * cos(a), c.dy + r * 1.35 * sin(a)),
          Offset(c.dx + (r * 1.35 + h) * cos(a), c.dy + (r * 1.35 + h) * sin(a)),
          Paint()..color = color.withOpacity(0.5 + volume * 0.4)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
      }
    }
    if (state == LiveState.disconnected) {
      _arc(canvas, c, r * 1.2, angle * 0.3, pi * 0.8, color.withOpacity(0.15), 1.0);
    }
  }

  void _arc(Canvas c, Offset center, double r, double start, double sweep, Color col, double w) =>
    c.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false,
      Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round);

  @override bool shouldRepaint(_OrbPainter o) => true;
}

class _BgGlow extends CustomPainter {
  final Color color; final double intensity;
  const _BgGlow({required this.color, required this.intensity});
  @override void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width * 0.75, Paint()..shader = RadialGradient(
      colors: [color.withOpacity(0.04 + intensity * 0.03), Colors.transparent])
      .createShader(Rect.fromCircle(center: c, radius: size.width * 0.75)));
  }
  @override bool shouldRepaint(_BgGlow o) => intensity != o.intensity;
}
