import 'dart:math';
import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const String fontFamily = 'RobotoMono';
  static const String fallbackFont = 'monospace';

  static const TextTheme baseTheme = TextTheme(
    displayLarge: TextStyle(
      color: AppColors.neonCyan, fontSize: 32, fontWeight: FontWeight.w900,
      letterSpacing: 2.5, fontFamily: fontFamily, height: 1.1,
      shadows: [Shadow(color: AppColors.neonCyan, blurRadius: 15)],
    ),
    displayMedium: TextStyle(
      color: AppColors.neonCyan, fontSize: 28, fontWeight: FontWeight.w800,
      letterSpacing: 2.0, fontFamily: fontFamily, height: 1.2,
      shadows: [Shadow(color: AppColors.neonCyan, blurRadius: 10)],
    ),
    displaySmall: TextStyle(
      color: AppColors.neonCyan, fontSize: 24, fontWeight: FontWeight.w700,
      letterSpacing: 1.5, fontFamily: fontFamily, height: 1.3,
    ),
    titleLarge: TextStyle(
      color: AppColors.neonCyan, fontSize: 18, fontWeight: FontWeight.w700,
      letterSpacing: 1.2, fontFamily: fontFamily, height: 1.4,
    ),
    titleMedium: TextStyle(
      color: AppColors.neonCyan, fontSize: 16, fontWeight: FontWeight.w600,
      letterSpacing: 1.0, fontFamily: fontFamily, height: 1.4,
    ),
    titleSmall: TextStyle(
      color: AppColors.neonCyan, fontSize: 14, fontWeight: FontWeight.w600,
      letterSpacing: 0.8, fontFamily: fontFamily, height: 1.5,
    ),
    bodyLarge: TextStyle(
      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500,
      fontFamily: fontFamily, height: 1.5, letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500,
      fontFamily: fontFamily, height: 1.5, letterSpacing: 0.5,
    ),
    bodySmall: TextStyle(
      color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500,
      fontFamily: fontFamily, height: 1.6, letterSpacing: 0.5,
    ),
    labelLarge: TextStyle(
      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
      letterSpacing: 1.5, fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600,
      letterSpacing: 1.2, fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600,
      letterSpacing: 2.0, fontFamily: fontFamily,
    ),
  );

  static const TextStyle sciFiTitle = TextStyle(
    color: AppColors.neonCyan, fontSize: 20, fontWeight: FontWeight.w900,
    letterSpacing: 4.0, fontFamily: fontFamily,
    shadows: [
      Shadow(color: AppColors.neonCyanGlow, blurRadius: 10, offset: Offset(0, 0)),
      Shadow(color: AppColors.neonCyanGlow, blurRadius: 20, offset: Offset(0, 0)),
    ],
  );

  static const TextStyle sciFiTitleLarge = TextStyle(
    color: AppColors.neonCyan, fontSize: 28, fontWeight: FontWeight.w900,
    letterSpacing: 6.0, fontFamily: fontFamily,
    shadows: [
      Shadow(color: AppColors.neonCyanGlow, blurRadius: 15, offset: Offset(0, 0)),
      Shadow(color: AppColors.neonCyanGlow, blurRadius: 30, offset: Offset(0, 0)),
    ],
  );

  static const TextStyle moodLabel = TextStyle(
    color: AppColors.neonCyan, fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 2.5, fontFamily: fontFamily,
  );

  static const TextStyle terminalText = TextStyle(
    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500,
    fontFamily: fontFamily, height: 1.6, letterSpacing: 0.5,
  );

  static const TextStyle terminalTextSmall = TextStyle(
    color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500,
    fontFamily: fontFamily, height: 1.5, letterSpacing: 0.5,
  );

  static const TextStyle promptChip = TextStyle(
    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 1.0, fontFamily: fontFamily,
  );

  static const TextStyle statusText = TextStyle(
    color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600,
    fontFamily: fontFamily, letterSpacing: 1.5,
  );

  static const TextStyle codeSnippet = TextStyle(
    color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.w600,
    fontFamily: fontFamily, backgroundColor: AppColors.deepSpaceBlue, letterSpacing: 0.2,
  );

  static const TextStyle errorText = TextStyle(
    color: AppColors.alertRed, fontSize: 12, fontWeight: FontWeight.w700,
    fontFamily: fontFamily, letterSpacing: 1.0,
    shadows: [Shadow(color: AppColors.alertRed, blurRadius: 8)],
  );

  static const TextStyle successText = TextStyle(
    color: AppColors.neonGreen, fontSize: 12, fontWeight: FontWeight.w700,
    fontFamily: fontFamily, letterSpacing: 1.0,
    shadows: [Shadow(color: AppColors.neonGreen, blurRadius: 8)],
  );

  static const TextStyle warningText = TextStyle(
    color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w700,
    fontFamily: fontFamily, letterSpacing: 1.0,
  );

  static const TextStyle affectionText = TextStyle(
    color: Colors.pinkAccent, fontSize: 13, fontWeight: FontWeight.w600,
    fontFamily: fontFamily, fontStyle: FontStyle.italic, letterSpacing: 0.5,
    shadows: [Shadow(color: Colors.pinkAccent, blurRadius: 10)],
  );

  static const TextStyle dialoguePrefix = TextStyle(
    color: AppColors.neonCyan, fontSize: 13, fontWeight: FontWeight.w800,
    fontFamily: fontFamily, letterSpacing: 1.5,
  );

  static TextStyle moodTextStyle(Color moodColor, {double fontSize = 13}) {
    return TextStyle(
      color: moodColor, fontSize: fontSize, fontWeight: FontWeight.w700,
      fontFamily: fontFamily, letterSpacing: 1.0,
      shadows: [Shadow(color: moodColor.withOpacity(0.6), blurRadius: 8)],
    );
  }

  static TextStyle glowingText({
    required Color color, double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700, double blurRadius = 12,
  }) {
    return TextStyle(
      color: color, fontSize: fontSize, fontWeight: fontWeight,
      fontFamily: fontFamily, letterSpacing: 1.5,
      shadows: [
        Shadow(color: color.withOpacity(0.8), blurRadius: blurRadius, offset: const Offset(0, 0)),
        Shadow(color: color.withOpacity(0.4), blurRadius: blurRadius * 2, offset: const Offset(0, 0)),
      ],
    );
  }

  static TextStyle terminalStyle({Color? color, double fontSize = 12, bool isCode = false}) {
    return TextStyle(
      color: color ?? (isCode ? Colors.purpleAccent : Colors.white),
      fontSize: fontSize, fontFamily: fontFamily, height: 1.6, letterSpacing: 0.5,
    );
  }

  static double pulseOpacity(double progress) {
    return 0.6 + (sin(progress * 2 * pi) * 0.4);
  }
}
