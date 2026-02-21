// lib/core/constants/app_colors.dart
// Z.A.R.A. — Holographic Color Palette
// Sci-fi aesthetics optimized for dark mode

import 'package:flutter/material.dart';

/// Centralized color system for Z.A.R.A. holographic UI
abstract final class AppColors {
  // ========== Background & Surface ==========
  static const Color background = Color(0xFF0A0E17);      // Deep space black
  static const Color surface = Color(0xFF121826);          // Elevated panel
  static const Color surfaceElevated = Color(0xFF1A2235);  // Glass panel
  
  // ========== Primary Holographic Colors ==========
  static const Color cyanPrimary = Color(0xFF00F0FF);      // Main hologram cyan
  static const Color cyanGlow = Color(0xFF66FFFF);         // Soft cyan glow
  static const Color magentaAccent = Color(0xFFFF00AA);    // Romantic accent
  static const Color magentaSoft = Color(0xFFFF66CC);      // Soft magenta
  
  // ========== Mood-Based Dynamic Colors ==========
  static const Color moodCalm = Color(0xFF00F0FF);         // Calm: Cyan
  static const Color moodRomantic = Color(0xFFFF3399);     // Romantic: Pink-red
  static const Color moodZiddi = Color(0xFFFF6633);        // Ziddi: Orange-red
  static const Color moodAngry = Color(0xFFFF0033);        // Angry: Deep red
  static const Color moodExcited = Color(0xFFFFFFFF);      // Excited: White flare
  static const Color moodAnalysis = Color(0xFF66CCFF);     // Analysis: Blue
  static const Color moodAutomation = Color(0xFF00FFAA);   // Automation: Green-cyan
  static const Color moodCoding = Color(0xFFAA00FF);       // Coding: Purple
  
  // ========== Plasma Orb Colors (IDLE vs SPEAKING) ==========
  static const Color orbIdleGlow = Color(0xFF440000);      // Dim red idle glow
  static const Color orbIdleCore = Color(0xFF880000);      // Idle core
  static const Color orbSpeakingCore = Color(0xFFFFFFFF);  // White-hot speaking core
  static const Color orbSpeakingPlasma = Color(0xFFFF1A1A); // Red plasma lightning
  static const Color orbSpeakingAura = Color(0xFF8B0000);  // Expanding red aura
  
  // ========== Utility Colors ==========
  static const Color errorRed = Color(0xFFFF0033);
  static const Color successGreen = Color(0xFF00FFAA);
  static const Color warningOrange = Color(0xFFFF9933);
  static const Color textPrimary = Color(0xFFE0F7FF);
  static const Color textSecondary = Color(0xFFA0D0E0);
  static const Color textDim = Color(0xFF6688AA);
  
  // ========== Glassmorphism ==========
  static const Color glassBackground = Color(0x401A2235);  // 25% opacity surface
  static const Color glassBorder = Color(0x6600F0FF);      // 40% opacity cyan
  
  // ========== Gradients ==========
  static const LinearGradient romanticGradient = LinearGradient(
    colors: [moodRomantic, magentaAccent, cyanPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient holographicGradient = LinearGradient(
    colors: [cyanPrimary, magentaAccent, cyanPrimary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  // ========== Helper Methods ==========
  
  /// Get mood color by enum name (for dynamic theming)
  static Color getMoodColor(String moodName) {
    return switch (moodName.toLowerCase()) {
      'romantic' => moodRomantic,
      'ziddi' => moodZiddi,
      'angry' => moodAngry,
      'excited' => moodExcited,
      'analysis' => moodAnalysis,
      'automation' => moodAutomation,
      'coding' => moodCoding,
      _ => moodCalm, // Default: calm
    };
  }
  
  /// Calculate glow opacity based on intensity (0.0 - 1.0)
  static Color withGlow(Color base, {double intensity = 0.5}) {
    return base.withOpacity(0.3 + intensity * 0.5);
  }
  
  /// Create pulse animation color (for breathing effects)
  static Color pulseColor(Color base, double progress) {
    // progress: 0.0 to 1.0 (animation cycle)
    final opacity = 0.4 + (sin(progress * 2 * 3.14159) * 0.3 + 0.3);
    return base.withOpacity(opacity.clamp(0.0, 1.0));
  }
}
