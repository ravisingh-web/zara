// lib/core/constants/app_colors.dart
// Z.A.R.A. — Holographic Color Palette
// ✅ Fixed: Added dart:math import

import 'dart:math';
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Background & Surface
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF121826);
  static const Color surfaceElevated = Color(0xFF1A2235);
  
  // Primary Holographic Colors
  static const Color cyanPrimary = Color(0xFF00F0FF);
  static const Color cyanGlow = Color(0xFF66FFFF);
  static const Color magentaAccent = Color(0xFFFF00AA);
  static const Color magentaSoft = Color(0xFFFF66CC);
  
  // Mood-Based Colors
  static const Color moodCalm = Color(0xFF00F0FF);
  static const Color moodRomantic = Color(0xFFFF3399);
  static const Color moodZiddi = Color(0xFFFF6633);
  static const Color moodAngry = Color(0xFFFF0033);
  static const Color moodExcited = Color(0xFFFFFFFF);
  static const Color moodAnalysis = Color(0xFF66CCFF);
  static const Color moodAutomation = Color(0xFF00FFAA);
  static const Color moodCoding = Color(0xFFAA00FF);
  
  // Plasma Orb Colors
  static const Color orbIdleGlow = Color(0xFF440000);
  static const Color orbIdleCore = Color(0xFF880000);
  static const Color orbSpeakingCore = Color(0xFFFFFFFF);
  static const Color orbSpeakingPlasma = Color(0xFFFF1A1A);
  static const Color orbSpeakingAura = Color(0xFF8B0000);
  
  // Utility Colors
  static const Color errorRed = Color(0xFFFF0033);
  static const Color successGreen = Color(0xFF00FFAA);
  static const Color warningOrange = Color(0xFFFF9933);
  static const Color textPrimary = Color(0xFFE0F7FF);
  static const Color textSecondary = Color(0xFFA0D0E0);
  static const Color textDim = Color(0xFF6688AA);
  static const Color infoBlue = Color(0xFF00CCFF); // ✅ Added
  
  // Glassmorphism
  static const Color glassBackground = Color(0x401A2235);
  static const Color glassBorder = Color(0x6600F0FF);
  
  // Helper Methods
  static Color withOpacityFixed(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  static Color pulseColor(Color base, double progress) {
    final opacity = 0.4 + (sin(progress * 2 * pi) * 0.3 + 0.3);
    return base.withOpacity(opacity.clamp(0.0, 1.0));
  }
}
