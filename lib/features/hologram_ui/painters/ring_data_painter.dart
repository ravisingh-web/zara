// lib/features/hologram_ui/painters/ring_data_painter.dart
// Z.A.R.A. — Holographic Ring Data Painter
// ✅ Animated Hex Data Stream • Mood-Reactive Colors • Pulse Effects
// ✅ CustomPainter • 60fps Optimized • Sci-Fi Visuals

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Custom painter for animated holographic data rings around plasma orb
/// Renders floating hex characters (0-9, A-F) in circular pattern with pulse animation
/// Used in zara_orb_painter.dart for enhanced visual depth
class RingDataPainter extends CustomPainter {
  // ========== Configuration Properties ==========
  
  /// Primary color for data characters — typically mood.primaryColor
  final Color color;
  
  /// Number of characters to render around the ring (recommended: 24-48)
  final int density;
  
  /// Animation time value (0.0 to 1.0) — controls rotation and pulse effects
  final double time;
  
  /// Optional: Ring radius multiplier (1.0 = default, 1.2 = larger ring)
  final double radiusMultiplier;
  
  /// Optional: Character size range for variation
  final double minCharSize;
  final double maxCharSize;

  // ========== Internal State ==========
  
  /// Hex characters for data stream effect
  static const String _hexChars = '0123456789ABCDEF';
  
  /// Random seed based on time for deterministic animation
  late final Random _random;

  /// Constructor with required and optional parameters
  RingDataPainter({
    required this.color,
    required this.density,
    required this.time,
    this.radiusMultiplier = 1.0,
    this.minCharSize = 6,
    this.maxCharSize = 12,
  }) {
    // Initialize random with time-based seed for smooth animation
    _random = Random((time * 1000).toInt() % 10000);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate center and base radius
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.5 * radiusMultiplier;
    
    // Draw the animated data ring
    _drawDataRing(canvas, center, baseRadius);
    
    // Optional: Draw secondary inner ring for depth
    if (density > 30) {
      _drawInnerRing(canvas, center, baseRadius * 0.7);
    }
  }

  // ========== Main Ring Drawing ==========
  
  /// Draw primary data ring with animated hex characters
  void _drawDataRing(Canvas canvas, Offset center, double radius) {
    for (var i = 0; i < density; i++) {
      // Calculate position around circle with time-based rotation
      final angle = (i / density) * 2 * pi + (time * 0.3) % (2 * pi);
      
      // Pulse effect for character size and opacity
      final pulse = (sin(time * 2 + i * 0.5) * 0.3 + 0.7).clamp(0.4, 1.0);
      final charSize = minCharSize + (maxCharSize - minCharSize) * pulse;
      
      // Select random hex character (deterministic based on index + time)
      final charIndex = _random.nextInt(_hexChars.length);
      final character = _hexChars[charIndex];
      
      // Create text painter with mood-reactive styling
      final textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            color: color.withOpacity(0.3 + pulse * 0.4),
            fontSize: charSize,
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w500,
            // Subtle glow effect via shadows
            shadows: [
              Shadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Calculate position on ring circumference
      final pos = Offset(
        center.dx + cos(angle) * radius - textPainter.width / 2,
        center.dy + sin(angle) * radius - textPainter.height / 2,
      );
      
      // Draw character on canvas
      textPainter.paint(canvas, pos);
    }
  }

  // ========== Optional Inner Ring for Depth ==========
  
  /// Draw secondary inner ring with smaller, dimmer characters
  void _drawInnerRing(Canvas canvas, Offset center, double radius) {
    final innerDensity = (density * 0.7).round();
    
    for (var i = 0; i < innerDensity; i++) {
      // Offset angle for staggered effect
      final angle = (i / innerDensity) * 2 * pi + (time * 0.2) % (2 * pi) + 0.3;
      
      // Subtler pulse for inner ring
      final pulse = (sin(time * 1.5 + i * 0.3) * 0.2 + 0.5).clamp(0.3, 0.8);
      final charSize = minCharSize * 0.7 + (maxCharSize * 0.7 - minCharSize * 0.7) * pulse;
      
      final charIndex = _random.nextInt(_hexChars.length);
      final character = _hexChars[charIndex];
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            color: color.withOpacity(0.15 + pulse * 0.2),
            fontSize: charSize,
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      final pos = Offset(
        center.dx + cos(angle) * radius - textPainter.width / 2,
        center.dy + sin(angle) * radius - textPainter.height / 2,
      );
      
      textPainter.paint(canvas, pos);
    }
  }

  // ========== Optional: Particle Sparkles ==========
  
  /// Draw floating particle sparkles around ring for extra flair
  void _drawParticles(Canvas canvas, Offset center, double radius) {
    final particleCount = (density * 0.3).round();
    
    for (var i = 0; i < particleCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = radius * (0.9 + _random.nextDouble() * 0.2);
      final pulse = (sin(time * 3 + i) * 0.3 + 0.5).clamp(0.2, 0.9);
      
      final paint = Paint()
        ..color = color.withOpacity(0.2 + pulse * 0.3)
        ..style = PaintingStyle.fill;
      
      final particleRadius = 1.0 + pulse * 1.5;
      
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle + time * 0.5) * distance,
          center.dy + sin(angle + time * 0.5) * distance,
        ),
        particleRadius,
        paint,
      );
    }
  }

  // ========== Repaint Logic ==========
  
  @override
  bool shouldRepaint(RingDataPainter old) {
    // Only repaint if visual properties changed (optimizes performance)
    return old.color != color || 
           old.density != density || 
           old.time != time ||
           old.radiusMultiplier != radiusMultiplier;
  }

  // ========== Static Helpers ==========
  
  /// Create a painter with default values for quick setup
  static RingDataPainter defaultPainter({
    required Color color,
    required double time,
    int density = 32,
  }) {
    return RingDataPainter(
      color: color,
      density: density,
      time: time,
      radiusMultiplier: 1.0,
      minCharSize: 6,
      maxCharSize: 10,
    );
  }
  
  /// Create a painter optimized for high-energy moods (excited, angry)
  static RingDataPainter highEnergyPainter({
    required Color color,
    required double time,
    int density = 48,
  }) {
    return RingDataPainter(
      color: color,
      density: density,
      time: time,
      radiusMultiplier: 1.1,
      minCharSize: 7,
      maxCharSize: 12,
    );
  }
  
  /// Create a painter optimized for calm moods (calm, analysis)
  static RingDataPainter calmPainter({
    required Color color,
    required double time,
    int density = 24,
  }) {
    return RingDataPainter(
      color: color,
      density: density,
      time: time,
      radiusMultiplier: 0.9,
      minCharSize: 5,
      maxCharSize: 9,
    );
  }
}

// ========== Extension: Ring Animation Helpers ==========

/// Extension to add animation utilities for RingDataPainter
extension RingAnimationHelper on RingDataPainter {
  /// Calculate smooth animation progress with easing
  double easedProgress(double rawProgress, {Curve curve = Curves.easeInOut}) {
    return curve.transform(rawProgress);
  }
  
  /// Generate time value for continuous animation loop
  static double animationTime(Duration elapsed, {double speed = 1.0}) {
    return (elapsed.inMilliseconds / 1000 * speed) % 1.0;
  }
  
  /// Create color with pulse opacity based on time
  Color pulsedColor(Color base, double time, {double intensity = 0.3}) {
    final pulse = (sin(time * 2 * pi) * intensity + (1 - intensity)).clamp(0.0, 1.0);
    return base.withOpacity(pulse);
  }
}
