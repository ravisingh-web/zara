// lib/features/hologram_ui/painters/ring_data_painter.dart
// Z.A.R.A. — Orbital HUD Painter
// ✅ Video-Matched Neon Cyan Logic
// ✅ Dynamic Radar Ticks & Scanning Heads
// ✅ Guardian Mode Red Shift

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class RingConfig {
  final double radius;
  final double strokeWidth;
  final double sweepAngle;
  final double rotationSpeed;
  final Color color;
  final bool clockwise;
  final bool hasTicks;

  const RingConfig({
    required this.radius,
    this.strokeWidth = 1.2,
    this.sweepAngle = pi * 0.5,
    this.rotationSpeed = 1.0,
    this.color = AppColors.neonCyan,
    this.clockwise = true,
    this.hasTicks = false,
  });
}

class RingDataPainter extends CustomPainter {
  final double animationValue;
  final double pulseValue; // Linked to Z.A.R.A.'s voice energy
  final bool guardianMode;
  final List<RingConfig> rings;

  RingDataPainter({
    required this.animationValue,
    required this.pulseValue,
    this.guardianMode = false,
  }) : rings = _generateVideoMatchedRings();

  static List<RingConfig> _generateVideoMatchedRings() {
    return [
      const RingConfig(radius: 85, sweepAngle: pi * 0.6, rotationSpeed: 1.2, hasTicks: true),
      const RingConfig(radius: 105, sweepAngle: pi * 0.4, rotationSpeed: -0.8, clockwise: false),
      const RingConfig(radius: 125, sweepAngle: pi * 1.2, rotationSpeed: 0.5, hasTicks: true),
      const RingConfig(radius: 145, sweepAngle: pi * 0.3, rotationSpeed: -2.0, clockwise: false),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = guardianMode ? AppColors.alertRed : AppColors.neonCyan;

    for (var ring in rings) {
      _drawCyberRing(canvas, center, ring, baseColor);
    }

    _drawStaticDecorations(canvas, center, baseColor);
  }

  void _drawCyberRing(Canvas canvas, Offset center, RingConfig ring, Color color) {
    final direction = ring.clockwise ? 1.0 : -1.0;
    // Vibration effect based on pulseValue (Voice sync)
    final dynamicRadius = ring.radius + (pulseValue * 4);
    final rotation = animationValue * 2 * pi * ring.rotationSpeed * direction;

    final rect = Rect.fromCircle(center: center, radius: dynamicRadius);
    final opacity = 0.4 + (pulseValue * 0.6);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    // 1. Shadow Glow Layer
    final glowPaint = Paint()
      ..color = color.withOpacity(0.1 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring.strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawArc(rect, 0, ring.sweepAngle, false, glowPaint);

    // 2. Main High-Tech Arc
    final mainPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring.strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawArc(rect, 0, ring.sweepAngle, false, mainPaint);

    // 3. The "Scanning Head" (Bright dot at the edge)
    final headPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    final headPos = Offset(
      center.dx + dynamicRadius * cos(ring.sweepAngle),
      center.dy + dynamicRadius * sin(ring.sweepAngle),
    );
    canvas.drawCircle(headPos, 2.0, headPaint);

    // 4. HUD Ticks logic (Matched to video)
    if (ring.hasTicks) {
      _drawHudTicks(canvas, center, dynamicRadius, color.withOpacity(0.2));
    }

    canvas.restore();
  }

  void _drawHudTicks(Canvas canvas, Offset center, double radius, Color color) {
    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    for (var i = 0; i < 360; i += 10) {
      final angle = i * pi / 180;
      final start = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      final end = Offset(center.dx + (radius + 4) * cos(angle), center.dy + (radius + 4) * sin(angle));
      canvas.drawLine(start, end, tickPaint);
    }
  }

  void _drawStaticDecorations(Canvas canvas, Offset center, Color color) {
    // Crosshair logic for that "Biometric Interface" look
    final paint = Paint()
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 0.5;
    
    canvas.drawLine(Offset(center.dx - 200, center.dy), Offset(center.dx + 200, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 200), Offset(center.dx, center.dy + 200), paint);
  }

  @override
  bool shouldRepaint(covariant RingDataPainter oldDelegate) => true;
}
