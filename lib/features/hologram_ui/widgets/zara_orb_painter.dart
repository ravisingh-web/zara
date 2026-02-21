// lib/features/hologram_ui/widgets/zara_orb_painter.dart
// Z.A.R.A. — REAL Plasma Orb Painter
// Mood + Battery Reactive • No Fake Stuff

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/enums/mood_enum.dart';
import '../../../core/constants/app_colors.dart';

class ZaraOrbPainter extends CustomPainter {
  final Mood mood;
  final double pulseProgress;        // 0.0 - 1.0 animation cycle
  final double orbScale;             // Current scale from controller
  final double glowIntensity;        // 0.0 - 1.0
  final int batteryLevel;            // REAL battery %
  final bool isActive;
  final bool isSpeaking;             // Voice activity
  final double amplitude;            // Audio amplitude (0.0 - 1.0)
  
  final DateTime _time = DateTime.now();
  
  ZaraOrbPainter({
    required this.mood,
    required this.pulseProgress,
    required this.orbScale,
    required this.glowIntensity,
    required this.batteryLevel,
    required this.isActive,
    this.isSpeaking = false,
    this.amplitude = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.4;
    final radius = baseRadius * orbScale;
    
    if (isSpeaking) {
      _drawSpeakingOrb(canvas, center, radius);
    } else if (isActive) {
      _drawActiveOrb(canvas, center, radius);
    } else {
      _drawIdleOrb(canvas, center, radius);
    }
    
    // Battery indicator ring (REAL)
    _drawBatteryRing(canvas, center, radius * 1.3);
  }
  
  void _drawIdleOrb(Canvas canvas, Offset center, double radius) {
    // Subtle breathing glow (low power mode)
    final glowPaint = Paint()
      ..color = AppColors.orbIdleGlow.withOpacity(0.3 + pulseProgress * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius * 1.5, glowPaint);
    
    // Core with breathing
    final coreGradient = RadialGradient(
      colors: [
        AppColors.orbIdleCore.withOpacity(0.8),
        AppColors.orbIdleGlow.withOpacity(0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    final corePaint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: center, radius: radius * 0.9),
      );
    canvas.drawCircle(center, radius * 0.9, corePaint);
  }
  
  void _drawActiveOrb(Canvas canvas, Offset center, double radius) {
    // Mood-based outer glow
    final glowPaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.3 + glowIntensity * 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + glowIntensity * 20);
    canvas.drawCircle(center, radius * 2.0, glowPaint);
    
    // Multi-layer gradient core
    final coreGradient = RadialGradient(
      colors: [
        mood.primaryColor.withOpacity(0.95),
        mood.primaryColor.withOpacity(0.6),
        mood.primaryColor.withOpacity(0.2),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 0.85, 1.0],
    );
    final corePaint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, corePaint);
    
    // Energy filaments (animated)
    _drawFilaments(canvas, center, radius * 0.8);
    
    // Particle effects
    _drawParticles(canvas, center, radius);
  }
  
  void _drawSpeakingOrb(Canvas canvas, Offset center, double radius) {
    // Dynamic scale based on amplitude (REAL voice reaction)
    final scale = 1.0 + amplitude * 0.35;
    final speakingRadius = radius * scale;
    
    // Outer expanding aura
    final auraPaint = Paint()
      ..color = AppColors.orbSpeakingAura.withOpacity(0.4 + amplitude * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 25 + amplitude * 20);
    canvas.drawCircle(center, speakingRadius * 2.2, auraPaint);
    
    // Plasma lightning branches
    _drawPlasmaLightning(canvas, center, speakingRadius);
    
    // White-hot core
    final coreGradient = RadialGradient(
      colors: [
        AppColors.orbSpeakingCore,
        AppColors.orbSpeakingCore.withOpacity(0.8),
        AppColors.orbSpeakingPlasma.withOpacity(0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 0.8, 1.0],
    );
    final corePaint = Paint()
      ..shader = coreGradient.createShader(
        Rect.fromCircle(center: center, radius: speakingRadius * 0.85),
      );
    canvas.drawCircle(center, speakingRadius * 0.85, corePaint);
    
    // Shockwave ripples
    _drawShockwaves(canvas, center, speakingRadius);
  }
  
  void _drawFilaments(Canvas canvas, Offset center, double radius) {
    final filamentPaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    for (var i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + pulseProgress * 2 * pi * 0.3;
      final start = Offset(
        center.dx + cos(angle) * radius * 0.3,
        center.dy + sin(angle) * radius * 0.3,
      );
      final end = Offset(
        center.dx + cos(angle + sin(pulseProgress * 2) * 0.2) * radius * 0.95,
        center.dy + sin(angle + sin(pulseProgress * 2) * 0.2) * radius * 0.95,
      );
      
      final path = Path()..moveTo(start.dx, start.dy);
      final control = Offset(
        (start.dx + end.dx) / 2 + sin(pulseProgress * 3 + i) * 15,
        (start.dy + end.dy) / 2 + cos(pulseProgress * 3 + i) * 15,
      );
      path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, filamentPaint);
    }
  }
  
  void _drawParticles(Canvas canvas, Offset center, double radius) {
    final random = Random(_time.millisecondsSinceEpoch % 10000);
    final particlePaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.15)
      ..strokeWidth = 0.8;
    
    for (var i = 0; i < 12; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = random.nextDouble() * radius * 0.8;
      final particleSize = random.nextDouble() * 2 + 0.5;
      final offset = Offset(
        center.dx + cos(angle + pulseProgress) * dist,
        center.dy + sin(angle + pulseProgress) * dist,
      );
      canvas.drawCircle(offset, particleSize, particlePaint);
    }
  }
  
  void _drawPlasmaLightning(Canvas canvas, Offset center, double radius) {
    final plasmaPaint = Paint()
      ..color = AppColors.orbSpeakingPlasma
      ..strokeWidth = 2.0 + amplitude * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final random = Random(_time.millisecondsSinceEpoch % 10000);
    
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi;
      final path = Path()..moveTo(center.dx, center.dy);
      
      var currentAngle = angle;
      var currentRadius = 0.0;
      
      while (currentRadius < radius * 0.9) {
        currentRadius += 15 + random.nextDouble() * 10;
        currentAngle += (random.nextDouble() - 0.5) * 0.3;
        
        final x = center.dx + cos(currentAngle) * currentRadius;
        final y = center.dy + sin(currentAngle) * currentRadius;
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, plasmaPaint);
    }
  }
  
  void _drawShockwaves(Canvas canvas, Offset center, double radius) {
    final ripplePaint = Paint()
      ..color = AppColors.cyanPrimary.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    for (var i = 0; i < 3; i++) {
      final delay = i * 0.15;
      final progress = ((pulseProgress - delay) % 1.0).clamp(0.0, 1.0);
      final rippleRadius = radius * (1.2 + progress * 0.8);
      
      if (progress > 0.05) {
        canvas.drawCircle(
          center,
          rippleRadius,
          ripplePaint..color = ripplePaint.color.withOpacity(0.3 * (1 - progress)),
        );
      }
    }
  }
  
  void _drawBatteryRing(Canvas canvas, Offset center, double radius) {
    // Battery level ring (REAL from battery_plus)
    final batteryPercent = batteryLevel / 100.0;
    
    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, bgPaint);
    
    // Battery level arc
    final batteryPaint = Paint()
      ..color = _getBatteryColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * batteryPercent,
      false,
      batteryPaint,
    );
    
    // Low battery warning
    if (batteryLevel <= 20) {
      final warningPaint = Paint()
        ..color = AppColors.errorRed.withOpacity(0.6 + pulseProgress * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(center, radius * 1.15, warningPaint);
    }
  }
  
  Color _getBatteryColor() {
    if (batteryLevel <= 20) return AppColors.errorRed;
    if (batteryLevel <= 50) return AppColors.warningOrange;
    return AppColors.successGreen;
  }

  @override
  bool shouldRepaint(ZaraOrbPainter old) {
    return old.mood != mood ||
        old.pulseProgress != pulseProgress ||
        old.orbScale != orbScale ||
        old.glowIntensity != glowIntensity ||
        old.batteryLevel != batteryLevel ||
        old.isActive != isActive ||
        old.isSpeaking != isSpeaking ||
        old.amplitude != amplitude;
  }
}
