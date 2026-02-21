// lib/features/hologram_ui/painters/ring_data_painter.dart
// Z.A.R.A. — Holographic Ring Data Painter

import 'dart:math';
import 'package:flutter/material.dart';

class RingDataPainter extends CustomPainter {
  final Color color;
  final int density;
  final double time;
  
  RingDataPainter({
    required this.color,
    required this.density,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.5;
    _drawDataRing(canvas, center, radius);
  }

  void _drawDataRing(Canvas canvas, Offset center, double radius) {
    const chars = '01ABCDEF';
    final random = Random((time * 500).toInt());

    for (var i = 0; i < density; i++) {
      final angle = (i / density) * 2 * pi + (time * 0.3) % (2 * pi);
      final pulse = (sin(time * 2 + i) * 0.3 + 0.7);
      final charSize = 8 + pulse * 3;

      final textPainter = TextPainter(
        text: TextSpan(
          text: chars[random.nextInt(chars.length)],
          style: TextStyle(
            color: color.withOpacity(pulse),
            fontSize: charSize,
            fontFamily: 'RobotoMono',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final pos = Offset(
        center.dx + cos(angle) * radius - charSize / 2,
        center.dy + sin(angle) * radius - charSize / 2,
      );
      textPainter.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(RingDataPainter old) {
    return old.color != color || old.density != density || old.time != time;
  }
}
