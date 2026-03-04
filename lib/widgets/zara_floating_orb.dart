// lib/widgets/zara_floating_orb.dart
// Z.A.R.A. v7.0 — Floating Voice-Reactive ORB
//
// ✅ Draggable — screen pe kahan bhi rakh lo
// ✅ Speaking  → 3 cyan/purple/pink rings bahar expand hoti hain
// ✅ Speaking  → animated 3-bar wave icon andar
// ✅ Listening → green pulse ring + mic icon
// ✅ Processing→ chhota spinner bottom-right
// ✅ Hands-free ON → green dot top-right
// ✅ Idle      → breathing glow animation
// ✅ Tap ORB   → Hands-free ON/OFF toggle
//
// ─── USAGE ────────────────────────────────────────────────────────────────
// Tera main screen jahan bhi Scaffold hai, usse Stack mein wrap karo:
//
//   import 'package:zara/widgets/zara_floating_orb.dart';
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Scaffold(          // ← tera existing Scaffold as-is
//           ...
//         ),
//         const ZaraFloatingOrb(),  // ← bas ye ek line add karo
//       ],
//     );
//   }
// ──────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';

class ZaraFloatingOrb extends StatefulWidget {
  const ZaraFloatingOrb({super.key});

  @override
  State<ZaraFloatingOrb> createState() => _ZaraFloatingOrbState();
}

class _ZaraFloatingOrbState extends State<ZaraFloatingOrb>
    with TickerProviderStateMixin {

  // Speaking rings — expand outward in loop
  late AnimationController _ringCtrl;
  late Animation<double>   _ringAnim;

  // ORB itself gently pulses when speaking
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // Idle breathing glow
  late AnimationController _breathCtrl;
  late Animation<double>   _breathAnim;

  Offset _position    = const Offset(20, 130);
  bool   _wasDragging = false;

  @override
  void initState() {
    super.initState();

    // Voice rings: 0→750ms, expand 1.0→2.6, loop while speaking
    _ringCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 750),
    );
    _ringAnim = Tween<double>(begin: 1.0, end: 2.6).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );

    // Gentle ORB pulse
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Idle breathing glow
    _breathCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  void _startRings() {
    if (!_ringCtrl.isAnimating) _ringCtrl.repeat();
  }

  void _stopRings() {
    if (_ringCtrl.isAnimating) {
      _ringCtrl.stop();
      _ringCtrl.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Consumer<ZaraController>(
      builder: (ctx, zara, _) {
        final isSpeaking   = zara.state.isSpeaking;
        final isListening  = zara.isListening;
        final isProcessing = zara.state.isProcessing;
        final handsFree    = zara.handsFreeMode;

        // Start/stop voice rings
        isSpeaking ? _startRings() : _stopRings();

        return Positioned(
          left: _position.dx,
          top:  _position.dy,
          child: GestureDetector(
            // ── Drag to reposition ────────────────────────────────────────
            onPanStart:  (_) => _wasDragging = false,
            onPanUpdate: (d) {
              _wasDragging = true;
              setState(() {
                _position = Offset(
                  (_position.dx + d.delta.dx).clamp(0.0, screen.width  - 80),
                  (_position.dy + d.delta.dy).clamp(0.0, screen.height - 80),
                );
              });
            },
            onPanEnd: (_) {},
            // ── Tap to toggle hands-free ──────────────────────────────────
            onTap: () {
              if (!_wasDragging) zara.toggleHandsFree();
            },
            child: SizedBox(
              width:  80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // ── SPEAKING: 3 expanding ripple rings ───────────────────
                  if (isSpeaking) ...[
                    // Ring 1 — Cyan, primary
                    AnimatedBuilder(
                      animation: _ringAnim,
                      builder: (_, __) => _Ring(
                        scale:       _ringAnim.value,
                        opacity:     (1.0 - (_ringAnim.value - 1.0) / 1.6).clamp(0.0, 1.0),
                        color:       const Color(0xFF00E5FF),
                        size:        52,
                        strokeWidth: 2.0,
                      ),
                    ),
                    // Ring 2 — Purple, delayed by 0.35
                    AnimatedBuilder(
                      animation: _ringAnim,
                      builder: (_, __) {
                        final v = (_ringAnim.value - 0.35).clamp(1.0, 2.6);
                        return _Ring(
                          scale:       v,
                          opacity:     (1.0 - (v - 1.0) / 1.6).clamp(0.0, 0.75),
                          color:       const Color(0xFF7B61FF),
                          size:        52,
                          strokeWidth: 1.8,
                        );
                      },
                    ),
                    // Ring 3 — Pink, delayed by 0.65
                    AnimatedBuilder(
                      animation: _ringAnim,
                      builder: (_, __) {
                        final v = (_ringAnim.value - 0.65).clamp(1.0, 2.6);
                        return _Ring(
                          scale:       v,
                          opacity:     (1.0 - (v - 1.0) / 1.6).clamp(0.0, 0.45),
                          color:       const Color(0xFFFF6B9D),
                          size:        52,
                          strokeWidth: 1.5,
                        );
                      },
                    ),
                  ],

                  // ── LISTENING: pulsing green ring ─────────────────────────
                  if (isListening && !isSpeaking)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => _Ring(
                        scale:       _pulseAnim.value * 1.55,
                        opacity:     0.60,
                        color:       Colors.greenAccent,
                        size:        52,
                        strokeWidth: 2.0,
                      ),
                    ),

                  // ── IDLE: breathing glow ──────────────────────────────────
                  if (!isSpeaking && !isListening)
                    AnimatedBuilder(
                      animation: _breathAnim,
                      builder: (_, __) => Container(
                        width:  70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (handsFree
                                      ? const Color(0xFF7B61FF)
                                      : const Color(0xFF00E5FF))
                                  .withOpacity(0.08 + _breathAnim.value * 0.20),
                              blurRadius:   18 + _breathAnim.value * 14,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── MAIN ORB BODY ─────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) {
                      return Transform.scale(
                        scale: isSpeaking ? _pulseAnim.value : 1.0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          width:  54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.35),
                              radius: 0.85,
                              colors: _orbColors(
                                isSpeaking:  isSpeaking,
                                isListening: isListening,
                                handsFree:   handsFree,
                              ),
                              stops: const [0.0, 0.55, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _glowColor(
                                  isSpeaking:  isSpeaking,
                                  isListening: isListening,
                                  handsFree:   handsFree,
                                ).withOpacity(isSpeaking || isListening ? 0.75 : 0.35),
                                blurRadius:   isSpeaking ? 30 : 18,
                                spreadRadius: isSpeaking ? 4  : 1,
                              ),
                            ],
                            border: Border.all(
                              color: isSpeaking
                                  ? const Color(0xFF00E5FF).withOpacity(0.90)
                                  : isListening
                                      ? Colors.greenAccent.withOpacity(0.85)
                                      : Colors.white.withOpacity(0.12),
                              width: 1.6,
                            ),
                          ),
                          child: Center(
                            child: _OrbIcon(
                              isSpeaking:  isSpeaking,
                              isListening: isListening,
                              handsFree:   handsFree,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ── HANDS-FREE indicator: green dot top-right ─────────────
                  if (handsFree)
                    Positioned(
                      top:   5,
                      right: 5,
                      child: Container(
                        width:  11,
                        height: 11,
                        decoration: BoxDecoration(
                          color:  Colors.greenAccent,
                          shape:  BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:      Colors.greenAccent.withOpacity(0.90),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── PROCESSING: spinner bottom-right ──────────────────────
                  if (isProcessing)
                    Positioned(
                      bottom: 5,
                      right:  5,
                      child: SizedBox(
                        width:  13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.cyanAccent.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ),

                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── ORB gradient colors ────────────────────────────────────────────────────
  List<Color> _orbColors({
    required bool isSpeaking,
    required bool isListening,
    required bool handsFree,
  }) {
    if (isSpeaking) {
      return [
        const Color(0xFF00E5FF),
        const Color(0xFF7B61FF),
        const Color(0xFF0A0A1E),
      ];
    }
    if (isListening) {
      return [
        Colors.greenAccent.shade400,
        const Color(0xFF00897B),
        const Color(0xFF0A0A1E),
      ];
    }
    if (handsFree) {
      return [
        const Color(0xFF9C75FF),
        const Color(0xFF3D1A78),
        const Color(0xFF0A0A1E),
      ];
    }
    return [
      const Color(0xFF1E2A4A),
      const Color(0xFF0D1226),
      Colors.black,
    ];
  }

  // ── Glow color ─────────────────────────────────────────────────────────────
  Color _glowColor({
    required bool isSpeaking,
    required bool isListening,
    required bool handsFree,
  }) {
    if (isSpeaking)  return const Color(0xFF00E5FF);
    if (isListening) return Colors.greenAccent;
    if (handsFree)   return const Color(0xFF7B61FF);
    return const Color(0xFF00E5FF);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Expanding ring
// ═══════════════════════════════════════════════════════════════════════════

class _Ring extends StatelessWidget {
  final double scale;
  final double opacity;
  final Color  color;
  final double size;
  final double strokeWidth;

  const _Ring({
    required this.scale,
    required this.opacity,
    required this.color,
    required this.size,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(opacity.clamp(0.0, 1.0)),
            width: strokeWidth,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Center icon inside ORB
// ═══════════════════════════════════════════════════════════════════════════

class _OrbIcon extends StatelessWidget {
  final bool isSpeaking;
  final bool isListening;
  final bool handsFree;

  const _OrbIcon({
    required this.isSpeaking,
    required this.isListening,
    required this.handsFree,
  });

  @override
  Widget build(BuildContext context) {
    if (isSpeaking)  return const _WaveIcon();
    if (isListening) return const Icon(Icons.mic_rounded,           color: Colors.white,   size: 22);
    if (handsFree)   return const Icon(Icons.hearing_rounded,        color: Colors.white70, size: 20);
    return                   const Icon(Icons.blur_circular_rounded, color: Colors.white30, size: 20);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Animated 3-bar wave icon (shows when Zara is speaking)
// ═══════════════════════════════════════════════════════════════════════════

class _WaveIcon extends StatefulWidget {
  const _WaveIcon();

  @override
  State<_WaveIcon> createState() => _WaveIconState();
}

class _WaveIconState extends State<_WaveIcon>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 480),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.33) % 1.0;
            final h     = 5.0 + sin(phase * pi * 2).abs() * 14.0;
            return Container(
              width:  3.2,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.4),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
