// lib/core/constants/app_text_styles.dart
// Z.A.R.A. — Typography System
// ✅ Fixed: Direct TextTheme (no GoogleFonts.copyWith)

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const String _fontFamily = 'monospace';
  
  static const TextTheme lightTheme = TextTheme(
    displayLarge: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      fontFamily: _fontFamily,
    ),
    titleLarge: TextStyle(
      color: AppColors.cyanPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      fontFamily: _fontFamily,
    ),
    bodyLarge: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.4,
      fontFamily: _fontFamily,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      fontFamily: _fontFamily,
    ),
    labelSmall: TextStyle(
      color: AppColors.textDim,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      fontFamily: _fontFamily,
    ),
  );
  
  static const TextStyle sciFiTitle = TextStyle(
    color: AppColors.cyanPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
    fontFamily: _fontFamily,
  );
  
  static const TextStyle moodLabel = TextStyle(
    color: AppColors.cyanPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    fontFamily: _fontFamily,
  );
  
  static const TextStyle terminalText = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 12,
    fontFamily: _fontFamily,
    height: 1.6,
  );
  
  static const TextStyle promptChip = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontFamily: _fontFamily,
  );
}
