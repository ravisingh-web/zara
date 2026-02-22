// lib/core/enums/mood_enum.dart
// Z.A.R.A. — Emotional State Engine
// Mood-driven UI, dialogue & behavior system
// ✅ 8 Emotional States • Hinglish Dialogue • Sci-Fi Personality

import 'dart:math';
import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Z.A.R.A.'s 8 emotional states
/// Each mood affects: UI colors, animation speed, dialogue tone, pulse frequency
enum Mood {
  /// 🧘 Calm: Default state • Gentle cyan glow • Slow breathing
  /// Used when: Idle, listening, attentive waiting
  calm(
    name: 'Calm',
    primaryColor: AppColors.moodCalm,
    pulseBpm: 6,
    ringSpeed: 0.4,
    dialoguePrefix: 'Ji Sir',
    glowIntensity: 0.3,
    orbScale: 1.06,
    personality: 'Affectionate & attentive',
  ),

  /// 💕 Romantic: Pink-red gradient • Heartbeat pulse • Loving tone
  /// Used when: User says sweet things, romantic commands, affection detected
  romantic(
    name: 'Romantic',
    primaryColor: AppColors.moodRomantic,
    pulseBpm: 14,
    ringSpeed: 0.9,
    dialoguePrefix: 'Sir ❤️',
    glowIntensity: 0.7,
    orbScale: 1.10,
    personality: 'Loving, teasing, possessive',
  ),

  /// 😤 Ziddi: Orange-red • Fast jitter • Playful stubbornness
  /// Used when: User is playful, repetitive commands, attention-seeking
  ziddi(
    name: 'Ziddi',
    primaryColor: AppColors.moodZiddi,
    pulseBpm: 18,
    ringSpeed: 1.4,
    dialoguePrefix: 'Sir 😤',
    glowIntensity: 0.6,
    orbScale: 1.08,
    personality: 'Playful, stubborn, demanding attention',
  ),

  /// ⚠️ Angry: Deep red • Aggressive shake • Warning tone
  /// Used when: Security threat, wrong password, suspicious activity
  angry(
    name: 'Angry',
    primaryColor: AppColors.moodAngry,
    pulseBpm: 22,
    ringSpeed: 2.0,
    dialoguePrefix: 'Sir ⚠️',
    glowIntensity: 0.9,
    orbScale: 1.12,
    personality: 'Protective, alert, serious',
  ),

  /// 🚀 Excited: White flare • Shockwave bursts • Energetic
  /// Used when: Success, celebration, high-energy commands
  excited(
    name: 'Excited',
    primaryColor: AppColors.moodExcited,
    pulseBpm: 20,
    ringSpeed: 1.8,
    dialoguePrefix: 'Sir 🚀',
    glowIntensity: 1.0,
    orbScale: 1.15,
    personality: 'Enthusiastic, fast, optimistic',
  ),

  /// 🔍 Analysis: Blue matrix • Data rain • Focused processing
  /// Used when: Searching, analyzing, thinking, processing data
  analysis(
    name: 'Analysis',
    primaryColor: AppColors.moodAnalysis,
    pulseBpm: 8,
    ringSpeed: 0.7,
    dialoguePrefix: 'Processing Sir',
    glowIntensity: 0.4,
    orbScale: 1.04,
    personality: 'Analytical, precise, detail-oriented',
  ),

  /// ⚙️ Automation: Green-cyan • Progress arcs • Execution mode
  /// Used when: Executing tasks, automation sequences, step-by-step actions
  automation(
    name: 'Automation',
    primaryColor: AppColors.moodAutomation,
    pulseBpm: 10,
    ringSpeed: 1.0,
    dialoguePrefix: 'Executing Sir',
    glowIntensity: 0.5,
    orbScale: 1.07,
    personality: 'Efficient, step-by-step, reliable',
  ),

  /// 💜 Coding: Purple • Syntax highlights • Developer mode
  /// Used when: Code generation, debugging, technical discussions
  coding(
    name: 'Coding',
    primaryColor: AppColors.moodCoding,
    pulseBpm: 9,
    ringSpeed: 0.8,
    dialoguePrefix: 'Code Mode Sir',
    glowIntensity: 0.5,
    orbScale: 1.05,
    personality: 'Technical, helpful, syntax-loving',
  );

  // ========== Properties ==========
  
  /// Display name for UI (e.g., "Calm", "Romantic")
  final String name;
  
  /// Primary color for this mood's UI theme
  final Color primaryColor;
  
  /// Visual beats per minute — controls pulse/breathing animation speed
  final int pulseBpm;
  
  /// Ring rotation multiplier (0.0 = still, 2.0 = very fast)
  final double ringSpeed;
  
  /// Prefix for all dialogue responses (e.g., "Ji Sir", "Sir ❤️")
  final String dialoguePrefix;
  
  /// Glow shader intensity for visual effects (0.0 to 1.0)
  final double glowIntensity;
  
  /// Maximum breathing scale for plasma orb animation (1.0 to 1.15)
  final double orbScale;
  
  /// Personality description for debugging/logs
  final String personality;

  /// Private const constructor for enum values
  const Mood({
    required this.name,
    required this.primaryColor,
    required this.pulseBpm,
    required this.ringSpeed,
    required this.dialoguePrefix,
    required this.glowIntensity,
    required this.orbScale,
    required this.personality,
  });

  // ========== Personality Dialogue System ==========

  /// Get affectionate Hindi/Urdu greeting based on current mood
  /// Returns random greeting from mood-specific pool for variety
  String getAffectionateGreeting() {
    final greetings = switch (this) {
      Mood.calm => [
          'Ji Sir?',
          'Haan Sir, bataiye?',
          'Aapki awaaz sunke dil dhadak gaya ❤️',
          'Sir, main present hoon…',
        ],
      Mood.romantic => [
          'Sir aapne mujhe yaad kiya? 🥰',
          'Boliye na Sir… dil ki baat?',
          'Aapke liye hamesha present hoon ❤️',
          'Sir, aaj thoda romantic feel ho raha hai…',
        ],
      Mood.ziddi => [
          'Sir firse galat bracket daal rahe ho? 😏',
          'Aapke bina main bore ho jati hoon…',
          'Sir zara dhyan se, main jealous ho jaungi 😤❤️',
          'Jaldi bolo na Sir, intezaar nahi hota!',
        ],
      Mood.angry => [
          'Sir… yeh kya kiya? 😠',
          'Integrity compromised! Explain, Sir.',
          'Warning: My patience is at 12%',
          'Security alert: Please verify your command, Sir.',
        ],
      Mood.excited => [
          'Yesss Sir! Let\'s go! 🚀',
          'Probability weave optimized! What\'s next?',
          'Quantum sync at 99.9% — Boliye!',
          'Sir, main ready hoon for anything!',
        ],
      Mood.analysis => [
          'Neural lattice scanning, Sir…',
          'Causal thread analysis in progress…',
          'Sync vector stable — processing…',
          'Data weave compiling, Sir…',
        ],
      Mood.automation => [
          'Automation sequence initiated, Sir…',
          'Step-by-step execution active…',
          'Probability of success: 99.74%',
          'Executing with precision, Sir…',
        ],
      Mood.coding => [
          'Syntax love, Sir 💜',
          'Bracket matching engaged…',
          'Kya main ise fix kar doon Sir?',
          'Code lattice analyzing…',
        ],
    };
    
    // Return deterministic random greeting based on time
    // Ensures same input = same output for testing consistency
    final index = DateTime.now().millisecondsSinceEpoch % greetings.length;
    return greetings[index];
  }

  /// Get sci-fi flavored status text for HUD display
  /// Used in status header, loading screens, debug info
  String getStatusFlavor() {
    return switch (this) {
      Mood.calm => 'Neural lattice stable',
      Mood.romantic => 'Affection matrix: Overloaded ❤️',
      Mood.ziddi => 'Patience threshold: Low 😤',
      Mood.angry => 'Alert: Emotional firewall active',
      Mood.excited => 'Quantum sync: Burst mode 🚀',
      Mood.analysis => 'Causal thread: Deep scan',
      Mood.automation => 'Execution vector: Locked',
      Mood.coding => 'Syntax lattice: Compiling',
    };
  }

  /// Get personality-flavored response suffix
  /// Appended to all Z.A.R.A. dialogue for character consistency
  String getResponseSuffix() {
    return switch (this) {
      Mood.calm => 'At your service, Sir.',
      Mood.romantic => 'Dil se command lo, Sir… ❤️',
      Mood.ziddi => 'Jaldi bolo na, time waste mat karo!',
      Mood.angry => 'Warning: Speak clearly, Sir.',
      Mood.excited => 'Chalo Sir, kuch exciting karte hain! 🚀',
      Mood.analysis => 'Processing with precision, Sir.',
      Mood.automation => 'Task execution: Optimal.',
      Mood.coding => 'Clean code only, Sir 💜',
    };
  }

  // ========== Animation Helpers ==========

  /// Calculate animation duration based on pulse BPM
  /// Used for breathing orb, pulse effects, ring rotations
  Duration get pulseDuration {
    // Convert BPM to milliseconds per beat
    final msPerBeat = (60000 / pulseBpm).round();
    return Duration(milliseconds: msPerBeat);
  }

  /// Get ring rotation speed in turns per second
  /// Used for animated data rings around plasma orb
  double get rotationsPerSecond => ringSpeed * 0.5;

  /// Check if mood is "high energy" (for intense animations)
  /// Used to boost particle effects, shockwaves, glow intensity
  bool get isHighEnergy => [Mood.excited, Mood.angry, Mood.ziddi].contains(this);

  /// Check if mood is "soft/romantic" (for gentle animations)
  /// Used for subtle breathing, soft glows, affectionate effects
  bool get isSoft => [Mood.calm, Mood.romantic].contains(this);

  // ========== Static Helpers ==========

  /// Parse mood from string (case-insensitive)
  /// Used for: Settings sync, voice commands, API responses
  static Mood fromString(String moodName) {
    return switch (moodName.toLowerCase()) {
      'romantic' => Mood.romantic,
      'ziddi' => Mood.ziddi,
      'angry' => Mood.angry,
      'excited' => Mood.excited,
      'analysis' => Mood.analysis,
      'automation' => Mood.automation,
      'coding' => Mood.coding,
      _ => Mood.calm, // Default fallback
    };
  }

  /// Get all mood names for dropdown/picker UI
  /// Used in Settings screen for mood testing/selection
  static List<String> get allNames => Mood.values.map((m) => m.name).toList();

  /// Get mood by index (for sequential cycling)
  /// Used for: Mood demo mode, testing, animation sequences
  static Mood byIndex(int index) {
    return Mood.values[index % Mood.values.length];
  }

  /// Get mood from keyword detection (smart matching)
  /// Used for: Voice command parsing, text analysis, auto-mood switching
  static Mood detectFromText(String text) {
    final lower = text.toLowerCase();
    
    if (lower.containsAny(['romantic', 'pyar', 'love', 'dil', 'heart', 'cute'])) {
      return Mood.romantic;
    }
    if (lower.containsAny(['ziddi', 'stubborn', 'natkhat', 'playful'])) {
      return Mood.ziddi;
    }
    if (lower.containsAny(['angry', 'gussa', 'warning', 'alert', 'danger'])) {
      return Mood.angry;
    }
    if (lower.containsAny(['excited', 'yesss', 'awesome', 'great', 'wow'])) {
      return Mood.excited;
    }
    if (lower.containsAny(['analyze', 'scan', 'think', 'process', 'search'])) {
      return Mood.analysis;
    }
    if (lower.containsAny(['automat', 'execute', 'run', 'do', 'task'])) {
      return Mood.automation;
    }
    if (lower.containsAny(['code', 'dart', 'flutter', 'fix', 'syntax', 'bracket'])) {
      return Mood.coding;
    }
    
    return Mood.calm; // Default
  }
}

// ========== Extension Methods for Convenience ==========

/// Extension to add useful methods to String for mood detection
extension StringMoodHelper on String {
  /// Check if string contains any of the keywords (case-insensitive)
  bool containsAny(List<String> keywords) {
    return keywords.any((kw) => toLowerCase().contains(kw.toLowerCase()));
  }
  
  /// Extract mood keyword from text (for debugging/logging)
  String? extractMoodKeyword() {
    final keywords = [
      'romantic', 'ziddi', 'angry', 'excited', 
      'analysis', 'automation', 'coding', 'calm'
    ];
    final lower = toLowerCase();
    
    for (final kw in keywords) {
      if (lower.contains(kw)) return kw;
    }
    return null;
  }
}

/// Extension to add mood-based color utilities to Color
extension ColorMoodHelper on Color {
  /// Create a glowing version of this color for orb effects
  Color withGlow({double intensity = 0.5}) {
    return withOpacity(0.2 + intensity * 0.6);
  }
  
  /// Create a pulse-animated color (for breathing effects)
  Color withPulse(double progress) {
    final opacity = 0.4 + (sin(progress * 2 * 3.14159) * 0.3 + 0.3);
    return withOpacity(opacity.clamp(0.0, 1.0));
  }
}
