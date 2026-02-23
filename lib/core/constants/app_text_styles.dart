// lib/core/constants/app_text_styles.dart
// Z.A.R.A. — Typography System
// ✅ Sci-Fi Aesthetics • RobotoMono Font • Holographic Text Effects
// ✅ Mood-Responsive • Terminal-Style • Prompt Chip Styling

import 'dart:math';  // ✅ Added for sin() in pulseOpacity()
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography system for Z.A.R.A.'s holographic UI
/// All text styles optimized for dark mode with cyan accent theme
abstract final class AppTextStyles {
  /// Primary font family for all Z.A.R.A. text (monospace for sci-fi feel)
  static const String fontFamily = 'RobotoMono';

  /// Fallback font when RobotoMono is not available
  static const String fallbackFont = 'monospace';

  // ========== Base TextTheme for Material Components ==========

  /// Light-themed TextTheme for Material 3 components
  /// Uses cyan primary color with monospace font for holographic effect
  static const TextTheme baseTheme = TextTheme(
    // Headings
    displayLarge: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      fontFamily: fontFamily,
      height: 1.1,
    ),
    displayMedium: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      fontFamily: fontFamily,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      fontFamily: fontFamily,
      height: 1.3,
    ),

    // Titles
    titleLarge: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      fontFamily: fontFamily,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      fontFamily: fontFamily,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      fontFamily: fontFamily,
      height: 1.5,
    ),

    // Body text
    bodyLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.4,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      color: AppColors.textDim,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      fontFamily: fontFamily,
      height: 1.6,
    ),

    // Labels
    labelLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      fontFamily: fontFamily,
    ),
    labelMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      color: AppColors.textDim,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      fontFamily: fontFamily,
    ),
  );

  // ========== Custom Z.A.R.A. Text Styles ==========

  /// Sci-Fi Title Style — for Z.A.R.A. logo, section headers
  /// Features: Cyan color, glow shadow, wide letter spacing
  static const TextStyle sciFiTitle = TextStyle(
    color: AppColors.cyanPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
    fontFamily: fontFamily,
    shadows: [
      Shadow(
        color: AppColors.cyanGlow,
        blurRadius: 8,
        offset: Offset(0, 0),
      ),
    ],
  );

  /// Sci-Fi Title Large — for main app title
  static const TextStyle sciFiTitleLarge = TextStyle(
    color: AppColors.cyanPrimary,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 4.0,
    fontFamily: fontFamily,
    shadows: [
      Shadow(
        color: AppColors.cyanGlow,
        blurRadius: 12,
        offset: Offset(0, 0),
      ),
    ],
  );

  /// Mood Label Style — for mood indicator chips, status text
  /// Features: Cyan color, compact size, wide spacing
  static const TextStyle moodLabel = TextStyle(
    color: AppColors.cyanPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    fontFamily: fontFamily,
  );

  /// Terminal Text Style — for code output, command responses
  /// Features: Primary text color, monospace, readable line height
  static const TextStyle terminalText = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontFamily: fontFamily,
    height: 1.6,
  );

  /// Terminal Text Small — for debug logs, metadata
  static const TextStyle terminalTextSmall = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontFamily: fontFamily,
    height: 1.5,
  );

  /// Prompt Chip Style — for suggestion buttons, quick actions
  /// Features: Primary text, compact, subtle weight
  static const TextStyle promptChip = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
  );

  /// Status Text Style — for battery, network, integrity indicators
  static const TextStyle statusText = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    letterSpacing: 0.5,
  );

  /// Code Snippet Style — for inline code, syntax highlights
  static const TextStyle codeSnippet = TextStyle(
    color: AppColors.moodCoding,
    fontSize: 11,
    fontFamily: fontFamily,
    backgroundColor: AppColors.surface,
  );

  /// Error Text Style — for validation errors, failure messages
  static const TextStyle errorText = TextStyle(
    color: AppColors.errorRed,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
  );

  /// Success Text Style — for confirmations, completed tasks
  static const TextStyle successText = TextStyle(
    color: AppColors.successGreen,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
  );

  /// Warning Text Style — for cautions, pending actions
  static const TextStyle warningText = TextStyle(
    color: AppColors.warningOrange,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
  );

  /// Affection Text Style — for romantic/ziddi dialogue
  static const TextStyle affectionText = TextStyle(
    color: AppColors.moodRomantic,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    fontStyle: FontStyle.italic,
  );

  /// Dialogue Prefix Style — for "Sir", "Ji Sir" prefixes
  static const TextStyle dialoguePrefix = TextStyle(
    color: AppColors.cyanPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
  );

  // ========== Helper Methods ==========

  /// Create a mood-colored text style dynamically
  static TextStyle moodTextStyle(Color moodColor, {double fontSize = 13}) {
    return TextStyle(
      color: moodColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      fontFamily: fontFamily,
    );
  }

  /// Create a glowing text style with shadow
  static TextStyle glowingText({
    required Color color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    double blurRadius = 8,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      shadows: [
        Shadow(
          color: color.withOpacity(0.5),
          blurRadius: blurRadius,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  /// Create a terminal-style text with optional syntax color
  static TextStyle terminalStyle({
    Color? color,
    double fontSize = 12,
    bool isCode = false,
  }) {
    return TextStyle(
      color: color ?? (isCode ? AppColors.moodCoding : AppColors.textPrimary),
      fontSize: fontSize,
      fontFamily: fontFamily,
      height: 1.6,
    );
  }

  /// Get animated pulse opacity for text (for breathing effects)
  static double pulseOpacity(double progress) {
    return 0.6 + (sin(progress * 2 * pi) * 0.2);  // ✅ sin() now works with dart:math import
  }
}
