// lib/features/hologram_ui/widgets/zara_orb_painter.dart
// Z.A.R.A. — The Holographic Core & DNA Helix
// ✅ Video-Matched Vertical DNA Logic
// ✅ Breathing Neon Core (Voice Synced)
// ✅ 0% Dummy — High-Performance Custom Rendering

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/hologram_ui/painters/ring_data_painter.dart';

class ZaraOrbWidget extends StatefulWidget {
  final bool guardianMode;
  final double pulseValue; // From Provider: Synced with Audio

  const ZaraOrbWidget({
    super.key,
    this.guardianMode = false,
    this.pulseValue = 0.0,
  });

  @override
  State<ZaraOrbWidget> createState() => _ZaraOrbWidgetState();
}

class _ZaraOrbWidgetState extends State<ZaraOrbWidget> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _glowController]),
      builder: (context, child) {
        // Combined pulse from breathing animation + real voice energy
        final combinedPulse = (_glowController.value * 0.3) + (widget.pulseValue * 0.7);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. BACKGROUND: Holographic DNA Helix (Vertical)
            Positioned.fill(
              child: CustomPaint(
                painter: _DNAHelixPainter(
                  progress: _rotationController.value,
                  opacity: 0.15,
                  guardianMode: widget.guardianMode,
                ),
              ),
            ),

            // 2. MIDDLE: The Orbital Rings (From RingDataPainter)
            SizedBox(
              width: 320,
              height: 320,
              child: CustomPaint(
                painter: RingDataPainter(
                  animationValue: _rotationController.value,
                  pulseValue: combinedPulse,
                  guardianMode: widget.guardianMode,
                ),
              ),
            ),

            // 3. CORE: The High-Intensity Glowing Center
            _buildGlowingCore(combinedPulse),

            // 4. PARTICLES: Cyber-Static floating around
            Positioned.fill(
              child: CustomPaint(
                painter: _ParticleFieldPainter(
                  progress: _rotationController.value,
                  pulseValue: combinedPulse,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlowingCore(double pulse) {
    final color = widget.guardianMode ? AppColors.alertRed : AppColors.neonCyan;
    return Container(
      width: 60 + (pulse * 15), // Breathes with voice
      height: 60 + (pulse * 15),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            color.withOpacity(0.8),
            color.withOpacity(0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 30 * pulse,
            spreadRadius: 5 * pulse,
          ),
        ],
      ),
    );
  }
}

// 🧬 THE REAL DNA HELIX PAINTER (Matched to Video)
class _DNAHelixPainter extends CustomPainter {
  final double progress;
  final double opacity;
  final bool guardianMode;

  _DNAHelixPainter({required this.progress, required this.opacity, this.guardianMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = (guardianMode ? AppColors.alertRed : AppColors.neonCyan).withOpacity(opacity);
    final paint = Paint()..color = color..strokeWidth = 1.0..style = PaintingStyle.stroke;

    const xSpacing = 120.0; // Helix width
    for (double y = 0; y < size.height; y += 4) {
      // Sin wave logic for the vertical helix
      final waveValue = sin((y * 0.02) + (progress * 2 * pi));
      final x1 = center.dx + (waveValue * xSpacing / 2);
      final x2 = center.dx - (waveValue * xSpacing / 2);

      // Draw horizontal bonds (bars)
      if (y % 20 == 0) {
        canvas.drawLine(Offset(x1, y), Offset(x2, y), paint..strokeWidth = 0.5);
      }
      
      // Draw strands
      canvas.drawCircle(Offset(x1, y), 1, paint..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x2, y), 1, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DNAHelixPainter oldDelegate) => true;
}

// ✨ THE CYBER PARTICLE PAINTER
class _ParticleFieldPainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final Random _rnd = Random(42);

  _ParticleFieldPainter({required this.progress, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = AppColors.neonCyan.withOpacity(0.3 * pulseValue);

    for (int i = 0; i < 25; i++) {
      final angle = _rnd.nextDouble() * 2 * pi + (progress * pi);
      final radius = 90 + _rnd.nextDouble() * 100;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(x, y), _rnd.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) => true;
}
