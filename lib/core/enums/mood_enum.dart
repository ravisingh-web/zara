// lib/core/enums/mood_enum.dart
// Z.A.R.A. — Emotional State Engine
// Mood-driven UI, dialogue & behavior system

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Z.A.R.A.'s 8 emotional states
/// Each mood affects: UI colors, animation speed, dialogue tone, pulse frequency
enum Mood {
  /// Calm: Default state • Gentle cyan glow • Slow breathing
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
  
  /// Romantic: Pink-red gradient • Heartbeat pulse • Loving tone
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
  
  /// Ziddi: Orange-red • Fast jitter • Playful stubbornness
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
  
  /// Angry: Deep red • Aggressive shake • Warning tone
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
  
  /// Excited: White flare • Shockwave bursts • Energetic
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
  
  /// Analysis: Blue matrix • Data rain • Focused processing
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
  
  /// Automation: Green-cyan • Progress arcs • Execution mode
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
  
  /// Coding: Purple • Syntax highlights • Developer mode
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
  final String name;
  final Color primaryColor;
  final int pulseBpm;           // Visual beats per minute (animation speed)
  final double ringSpeed;       // Ring rotation multiplier (0.0 - 2.0)
  final String dialoguePrefix;  // Prefix for all responses
  final double glowIntensity;   // Glow shader strength (0.0 - 1.0)
  final double orbScale;        // Max breathing scale (1.0 - 1.15)
  final String personality;     // Description for debugging/logs

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

  /// Get affectionate Hindi/Urdu greeting based on mood
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
    // Return random greeting based on time (deterministic for consistency)
    return greetings[DateTime.now().millisecondsSinceEpoch % greetings.length];
  }

  /// Get sci-fi flavored status text
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

  /// Calculate animation duration based on pulse BPM
  Duration get pulseDuration {
    // Convert BPM to milliseconds per beat
    final msPerBeat = (60000 / pulseBpm).round();
    return Duration(milliseconds: msPerBeat);
  }

  /// Get ring rotation speed in turns per second
  double get rotationsPerSecond => ringSpeed * 0.5;

  /// Check if mood is "high energy" (for animation intensity)
  bool get isHighEnergy => [Mood.excited, Mood.angry, Mood.ziddi].contains(this);

  /// Check if mood is "soft/romantic" (for gentle animations)
  bool get isSoft => [Mood.calm, Mood.romantic].contains(this);

  // ========== Static Helpers ==========

  /// Parse mood from string (case-insensitive)
  static Mood fromString(String moodName) {
    return switch (moodName.toLowerCase()) {
      'romantic' => Mood.romantic,
      'ziddi' => Mood.ziddi,
      'angry' => Mood.angry,
      'excited' => Mood.excited,
      'analysis' => Mood.analysis,
      'automation' => Mood.automation,
      'coding' => Mood.coding,
      _ => Mood.calm,
    };
  }

  /// Get all mood names for dropdown/picker UI
  static List<String> get allNames => Mood.values.map((m) => m.name).toList();

  /// Get mood by index (for sequential cycling)
  static Mood byIndex(int index) {
    return Mood.values[index % Mood.values.length];
  }
}
