// lib/core/constants/app_colors.dart
// Z.A.R.A. — Holographic Color Palette
// ✅ Sci-Fi Aesthetics • Dark Mode Optimized • Mood-Responsive
// ✅ Glassmorphism • Plasma Effects • Gradient Presets

import 'dart:math';
import 'package:flutter/material.dart';

/// Centralized color system for Z.A.R.A.'s holographic UI
/// All colors optimized for dark mode with cyan/magenta accent theme
abstract final class AppColors {
  // ========== Background & Surface Colors ==========
  
  /// Deep space black — main app background
  static const Color background = Color(0xFF0A0E17);
  
  /// Elevated panel background — cards, dialogs
  static const Color surface = Color(0xFF121826);
  
  /// Higher elevation surface — modals, overlays
  static const Color surfaceElevated = Color(0xFF1A2235);
  
  /// Subtle divider/separator color
  static const Color divider = Color(0xFF1E2A3A);

  // ========== Primary Holographic Colors ==========
  
  /// Main hologram cyan — primary action color
  static const Color cyanPrimary = Color(0xFF00F0FF);
  
  /// Soft cyan glow — for blur effects, halos
  static const Color cyanGlow = Color(0xFF66FFFF);
  
  /// Romantic magenta accent — for love/affection states
  static const Color magentaAccent = Color(0xFFFF00AA);
  
  /// Soft magenta — for subtle romantic hints
  static const Color magentaSoft = Color(0xFFFF66CC);
  
  /// Electric purple — for coding/technical states
  static const Color electricPurple = Color(0xFFAA00FF);

  // ========== Mood-Based Dynamic Colors ==========
  /// Each mood has a unique color for UI theming
  
  /// Calm: Gentle cyan — default attentive state
  static const Color moodCalm = Color(0xFF00F0FF);
  
  /// Romantic: Pink-red gradient — loving, affectionate state
  static const Color moodRomantic = Color(0xFFFF3399);
  
  /// Ziddi: Orange-red — playful stubborn state
  static const Color moodZiddi = Color(0xFFFF6633);
  
  /// Angry: Deep red — protective, alert state
  static const Color moodAngry = Color(0xFFFF0033);
  
  /// Excited: White flare — energetic, burst state
  static const Color moodExcited = Color(0xFFFFFFFF);
  
  /// Analysis: Blue matrix — focused processing state
  static const Color moodAnalysis = Color(0xFF66CCFF);
  
  /// Automation: Green-cyan — execution, step-by-step state
  static const Color moodAutomation = Color(0xFF00FFAA);
  
  /// Coding: Purple — developer mode, syntax love
  static const Color moodCoding = Color(0xFFAA00FF);

  // ========== Plasma Orb Colors (Idle vs Speaking) ==========
  
  /// IDLE Mode — Subtle breathing glow
  static const Color orbIdleGlow = Color(0xFF440000);
  static const Color orbIdleCore = Color(0xFF880000);
  
  /// SPEAKING Mode — Active plasma animation
  static const Color orbSpeakingCore = Color(0xFFFFFFFF);
  static const Color orbSpeakingPlasma = Color(0xFFFF1A1A);
  static const Color orbSpeakingAura = Color(0xFF8B0000);
  
  /// Orb animation helper colors
  static const Color orbParticle = Color(0xFF00F0FF);
  static const Color orbFilament = Color(0xFF66FFFF);

  // ========== Utility & Status Colors ==========
  
  /// Error state — critical warnings, failures
  static const Color errorRed = Color(0xFFFF0033);
  
  /// Success state — completed tasks, confirmations
  static const Color successGreen = Color(0xFF00FFAA);
  
  /// Warning state — cautions, pending actions
  static const Color warningOrange = Color(0xFFFF9933);
  
  /// Info state — neutral information, hints
  static const Color infoBlue = Color(0xFF00CCFF);
  
  /// Primary text — main content, headings
  static const Color textPrimary = Color(0xFFE0F7FF);
  
  /// Secondary text — subtitles, descriptions
  static const Color textSecondary = Color(0xFFA0D0E0);
  
  /// Dim text — placeholders, disabled states
  static const Color textDim = Color(0xFF6688AA);
  
  /// Disabled/Inactive state
  static const Color disabled = Color(0xFF3A4A5A);

  // ========== Glassmorphism Colors ==========
  
  /// Frosted glass background — 25% opacity surface
  static const Color glassBackground = Color(0x401A2235);
  
  /// Glass border — 40% opacity cyan edge
  static const Color glassBorder = Color(0x6600F0FF);
  
  /// Glass highlight — subtle inner glow
  static const Color glassHighlight = Color(0x20FFFFFF);
  
  /// Glass shadow — subtle outer blur
  static const Color glassShadow = Color(0x30000000);

  // ========== Gradient Presets ==========
  
  /// Romantic gradient — pink to cyan diagonal flow
  static const LinearGradient romanticGradient = LinearGradient(
    colors: [moodRomantic, magentaAccent, cyanPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );
  
  /// Holographic gradient — cyan pulse effect
  static const LinearGradient holographicGradient = LinearGradient(
    colors: [cyanPrimary, magentaAccent, cyanPrimary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.5, 1.0],
  );
  
  /// Plasma gradient — orb core animation
  static const RadialGradient plasmaGradient = RadialGradient(
    colors: [orbSpeakingCore, orbSpeakingPlasma, Colors.transparent],
    center: Alignment.center,
    radius: 0.8,
    stops: [0.0, 0.6, 1.0],
  );
  
  /// Background mesh gradient — subtle animated backdrop
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFF0F1420), background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ========== Helper Methods ==========
  
  /// Safe opacity wrapper (avoids precision loss warnings)
  static Color withOpacitySafe(Color color, double opacity) {
    return color.withOpacity(opacity.clamp(0.0, 1.0));
  }
  
  /// Calculate pulse animation color based on progress (0.0 - 1.0)
  static Color pulseColor(Color base, double progress) {
    final opacity = 0.4 + (sin(progress * 2 * pi) * 0.3 + 0.3);
    return base.withOpacity(opacity.clamp(0.0, 1.0));
  }
  
  /// Calculate glow intensity based on mood + activity
  static Color withGlow(Color base, {double intensity = 0.5}) {
    final opacity = 0.2 + intensity * 0.6;
    return base.withOpacity(opacity.clamp(0.0, 1.0));
  }
  
  /// Blend two colors with ratio (0.0 = color1, 1.0 = color2)
  static Color blendColors(Color color1, Color color2, double ratio) {
    final r = color1.red + (color2.red - color1.red) * ratio;
    final g = color1.green + (color2.green - color1.green) * ratio;
    final b = color1.blue + (color2.blue - color1.blue) * ratio;
    final a = color1.opacity + (color2.opacity - color1.opacity) * ratio;
    return Color.fromARGB(
      (a * 255).round(),
      (r).round(),
      (g).round(),
      (b).round(),
    );
  }
  
  /// Get mood color by name (for dynamic theming)
  static Color getMoodColor(String moodName) {
    return switch (moodName.toLowerCase()) {
      'romantic' => moodRomantic,
      'ziddi' => moodZiddi,
      'angry' => moodAngry,
      'excited' => moodExcited,
      'analysis' => moodAnalysis,
      'automation' => moodAutomation,
      'coding' => moodCoding,
      _ => moodCalm, // Default
    };
  }
  
  /// Get complementary color for contrast
  static Color getComplement(Color color) {
    return Color.fromARGB(
      color.alpha,
      255 - color.red,
      255 - color.green,
      255 - color.blue,
    );
  }
  
  /// Get shadow color for elevation effects
  static Color getShadowColor({Color base = cyanPrimary, double opacity = 0.3}) {
    return base.withOpacity(opacity);
  }
  
  /// Get border color for glassmorphism cards
  static Color getGlassBorderColor({double opacity = 0.4}) {
    return cyanPrimary.withOpacity(opacity);
  }
}
