// lib/features/hologram_ui/widgets/zara_orb_painter.dart
// Z.A.R.A. — Holographic Plasma Orb Painter
// ✅ Mood + Battery Reactive • Idle/Active/Speaking Modes • Real-Time Animation
// ✅ Energy Filaments • Particle Effects • Plasma Lightning • Shockwave Ripples

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/enums/mood_enum.dart';
import '../../../core/constants/app_colors.dart';

/// Custom painter for Z.A.R.A.'s signature plasma orb visualization
/// Creates a dynamic, mood-reactive holographic sphere with multiple visual states
class ZaraOrbPainter extends CustomPainter {
  // ========== Configuration Properties ==========
  
  /// Current emotional state — determines colors and animation behavior
  final Mood mood;
  
  /// Animation cycle progress (0.0 to 1.0) — controls breathing/pulse timing
  final double pulseProgress;
  
  /// Current scale multiplier for orb size (1.0 to 1.15) — from controller
  final double orbScale;
  
  /// Glow intensity (0.0 to 1.0) — controls blur radius and opacity
  final double glowIntensity;
  
  /// Real battery percentage (0-100) — for battery ring indicator
  final int batteryLevel;
  
  /// Whether Z.A.R.A. is currently active/engaged
  final bool isActive;
  
  /// Whether Z.A.R.A. is speaking (voice activity detected)
  final bool isSpeaking;
  
  /// Audio amplitude (0.0 to 1.0) — for voice-reactive animations
  final double amplitude;

  // ========== Internal State ==========
  
  /// Timestamp for deterministic random effects (particles, lightning)
  final DateTime _time = DateTime.now();

  /// Constructor with required and optional parameters
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

  // ========== Main Paint Method ==========
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate center and radius based on canvas size
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.4;
    final radius = baseRadius * orbScale;

    // Draw orb based on current state
    if (isSpeaking) {
      _drawSpeakingOrb(canvas, center, radius);
    } else if (isActive) {
      _drawActiveOrb(canvas, center, radius);
    } else {
      _drawIdleOrb(canvas, center, radius);
    }

    // Draw battery indicator ring around orb (always visible)
    _drawBatteryRing(canvas, center, radius * 1.3);
  }

  // ========== Visual State: IDLE (Low Power / Waiting) ==========
  
  /// Draw subtle breathing orb for idle/waiting state
  /// Features: Dim red glow, slow pulse, minimal effects
  void _drawIdleOrb(Canvas canvas, Offset center, double radius) {
    // Outer breathing glow (low power mode)
    final glowPaint = Paint()
      ..color = AppColors.orbIdleGlow.withOpacity(0.3 + pulseProgress * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Core with radial gradient breathing effect
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

  // ========== Visual State: ACTIVE (Engaged / Listening) ==========
  
  /// Draw vibrant mood-colored orb for active/engaged state
  /// Features: Mood-based colors, energy filaments, particle effects
  void _drawActiveOrb(Canvas canvas, Offset center, double radius) {
    // Mood-based outer glow with blur
    final glowPaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.3 + glowIntensity * 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + glowIntensity * 20);
    canvas.drawCircle(center, radius * 2.0, glowPaint);

    // Multi-layer radial gradient core
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

    // Animated energy filaments around core
    _drawFilaments(canvas, center, radius * 0.8);

    // Floating particle effects
    _drawParticles(canvas, center, radius);
  }

  // ========== Visual State: SPEAKING (Voice Output / High Energy) ==========
  
  /// Draw intense plasma orb for speaking/voice output state
  /// Features: White-hot core, plasma lightning, shockwave ripples, amplitude-reactive
  void _drawSpeakingOrb(Canvas canvas, Offset center, double radius) {
    // Dynamic scale based on voice amplitude (reactive animation)
    final scale = 1.0 + amplitude * 0.35;
    final speakingRadius = radius * scale;

    // Outer expanding aura with amplitude-based intensity
    final auraPaint = Paint()
      ..color = AppColors.orbSpeakingAura.withOpacity(0.4 + amplitude * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 25 + amplitude * 20);
    canvas.drawCircle(center, speakingRadius * 2.2, auraPaint);

    // Plasma lightning branches (electric effect)
    _drawPlasmaLightning(canvas, center, speakingRadius);

    // White-hot core with plasma gradient
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

    // Expanding shockwave ripples (pulse effect)
    _drawShockwaves(canvas, center, speakingRadius);
  }

  // ========== Visual Effect: Energy Filaments ==========
  
  /// Draw animated energy filaments around orb core
  /// Creates flowing, curved lines that pulse with animation
  void _drawFilaments(Canvas canvas, Offset center, double radius) {
    final filamentPaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw 8 filaments evenly spaced around circle
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

      // Create curved path with animated control point
      final path = Path()..moveTo(start.dx, start.dy);
      final control = Offset(
        (start.dx + end.dx) / 2 + sin(pulseProgress * 3 + i) * 15,
        (start.dy + end.dy) / 2 + cos(pulseProgress * 3 + i) * 15,
      );
      path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      
      canvas.drawPath(path, filamentPaint);
    }
  }

  // ========== Visual Effect: Floating Particles ==========
  
  /// Draw floating particle effects around orb
  /// Creates subtle, randomized dots that orbit the core
  void _drawParticles(Canvas canvas, Offset center, double radius) {
    final random = Random(_time.millisecondsSinceEpoch % 10000);
    final particlePaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.15)
      ..strokeWidth = 0.8;

    // Draw 12 particles with randomized positions
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

  // ========== Visual Effect: Plasma Lightning ==========
  
  /// Draw electric plasma lightning branches for speaking state
  /// Creates jagged, randomized lightning bolts radiating from core
  void _drawPlasmaLightning(Canvas canvas, Offset center, double radius) {
    final plasmaPaint = Paint()
      ..color = AppColors.orbSpeakingPlasma
      ..strokeWidth = 2.0 + amplitude * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = Random(_time.millisecondsSinceEpoch % 10000);

    // Draw 12 lightning branches evenly spaced
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi;
      final path = Path()..moveTo(center.dx, center.dy);

      var currentAngle = angle;
      var currentRadius = 0.0;

      // Generate jagged lightning path
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

  // ========== Visual Effect: Shockwave Ripples ==========
  
  /// Draw expanding shockwave ripples for speaking state
  /// Creates concentric circles that pulse outward from core
  void _drawShockwaves(Canvas canvas, Offset center, double radius) {
    final ripplePaint = Paint()
      ..color = AppColors.cyanPrimary.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw 3 delayed ripples for wave effect
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

  // ========== Visual Element: Battery Indicator Ring ==========
  
  /// Draw circular battery level indicator around orb
  /// Shows real battery percentage with color-coded warnings
  void _drawBatteryRing(Canvas canvas, Offset center, double radius) {
    final batteryPercent = batteryLevel / 100.0;

    // Background ring (full circle, dim)
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, bgPaint);

    // Battery level arc (colored, shows percentage)
    final batteryPaint = Paint()
      ..color = _getBatteryColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,  // Start at top (12 o'clock)
      2 * pi * batteryPercent,  // Sweep based on battery %
      false,  // Not a pie slice
      batteryPaint,
    );

    // Low battery warning pulse (red flashing ring)
    if (batteryLevel <= 20) {
      final warningPaint = Paint()
        ..color = AppColors.errorRed.withOpacity(0.6 + pulseProgress * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius * 1.15, warningPaint);
    }
  }

  // ========== Helper: Battery Color Logic ==========
  
  /// Get color for battery indicator based on level
  Color _getBatteryColor() {
    if (batteryLevel <= 20) return AppColors.errorRed;
    if (batteryLevel <= 50) return AppColors.warningOrange;
    return AppColors.successGreen;
  }

  // ========== Repaint Logic ==========
  
  @override
  bool shouldRepaint(ZaraOrbPainter old) {
    // Only repaint if any visual property changed
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
