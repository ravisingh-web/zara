import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 🌌 The Deep Space Void (From Video Background)
  static const Color deepSpaceBlack = Color(0xFF020410);
  static const Color deepSpaceBlue = Color(0xFF050816);

  // 💎 The Exact Cyber Cyan (Matched to 1000150011.png)
  static const Color neonCyan = Color(0xFF00FFFF);
  static const Color neonCyanDim = Color(0xFF00A8B5);
  static const Color neonCyanGlow = Color(0x6600FFFF);
  static const Color neonCyanSubtle = Color(0x2200FFFF);

  // 🟢 System Online Green (Matched to Video Dot)
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonGreenGlow = Color(0x4439FF14);

  // 🔴 Guardian / Angry Mode (Glitch Red)
  static const Color alertRed = Color(0xFFFF0040);
  static const Color alertRedGlow = Color(0x66FF0040);

  // 🪟 Glass UI Elements
  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x3300FFFF);

  // 🌈 Dynamic Background Gradient
  static const LinearGradient mainBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF050816),
      Color(0xFF020410),
      Colors.black,
    ],
  );

  // 🔆 The Orbital Core Glow
  static const RadialGradient orbGlowGradient = RadialGradient(
    colors: [
      Color(0xFF00FFFF),
      Color(0xAA00FFFF),
      Color(0x0000FFFF),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  // =========================================================
  // 🔥 ALIASES FOR COMPATIBILITY (0% COLOR CHANGE) 🔥
  // =========================================================
  
  static const Color cyanPrimary = neonCyan;
  static const Color cyanGlow = neonCyanGlow; // Solves the BoxShadow vs Color clash
  static const Color errorRed = alertRed;
  static const Color successGreen = neonGreen;
  static const Color warningOrange = Colors.orangeAccent;
  static const Color surface = deepSpaceBlue;

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textDim = Colors.white54;

  static const Color moodCoding = Colors.purpleAccent;
  static const Color moodRomantic = Colors.pinkAccent;

  // Retained the BoxShadow generator with a safe name
  static BoxShadow cyanGlowShadow({double blur = 20}) => BoxShadow(
    color: neonCyanGlow,
    blurRadius: blur,
    spreadRadius: 1,
  );
}
