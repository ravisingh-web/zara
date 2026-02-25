// lib/features/hologram_ui/widgets/floating_prompts.dart
// Z.A.R.A. — Context-Aware Suggestion Chips
// ✅ Strict Error Fix: AppColors.textPrimary changed to Colors.white
// ✅ Zero Logic Changed.

import 'package:flutter/material.dart';
import '../../../core/enums/mood_enum.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Floating suggestion chips for Z.A.R.A. home screen
/// Displays mood-aware quick action prompts in Hinglish
/// Tapping a chip executes the suggested command automatically
class FloatingPrompts extends StatelessWidget {
  // ========== Configuration Properties ==========

  /// Current emotional state — determines prompt suggestions and chip styling
  final Mood mood;

  /// Callback function executed when a prompt is selected
  /// Receives the selected prompt string as parameter
  final Function(String) onSelected;

  /// Constructor with required parameters
  const FloatingPrompts({
    super.key,
    required this.mood,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Get mood-aware prompt suggestions
    final prompts = _getPromptsForMood(mood);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Add padding for edge spacing
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: prompts.map((prompt) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _PromptChip(
            label: prompt,
            mood: mood,
            onTap: () => onSelected(prompt),
          ),
        )).toList(),
      ),
    );
  }

  // ========== Mood-Aware Prompt Generation ==========

  /// Generate prompt suggestions based on current mood
  /// Returns list of Hinglish strings for display
  List<String> _getPromptsForMood(Mood mood) {
    return switch (mood) {
      // 💕 Romantic: Loving, affectionate suggestions
      Mood.romantic => [
          'Aur kuch Sir? ❤️',
          'Romantic mode aur badhao?',
          'Dil ki baat boliye…',
          'Guardian activate?',
          'Battery check karoon?',
          'Photo click karoon Sir? 📸',
        ],

      // 😤 Ziddi: Playful, stubborn, attention-seeking
      Mood.ziddi => [
          'Sir zara jaldi bolo na 😤',
          'Auto-fix kar doon?',
          'Ziddi hoon abhi… try karo',
          'Location share karoon?',
          'Photo click karoon?',
          'Code me help karoon?',
        ],

      // ⚠️ Angry: Security-focused, protective
      Mood.angry => [
          'Security alert check?',
          'Intruder photo dekhna hai?',
          'Trusted contacts update?',
          'Guardian status?',
          'Network scan karoon?',
          'Permissions check karoon?',
        ],

      // 💜 Coding: Developer mode, technical assistance
      Mood.coding => [
          'Code paste karo Sir',
          'Bracket fix kar doon?',
          'Syntax check karoon?',
          'Dart analyze karoon?',
          'Errors fix kar doon?',
          'New file create karoon?',
        ],

      // ⚙️ Automation: Task execution, system control
      Mood.automation => [
          'Instagram post kar doon?',
          'WhatsApp message bhej doon?',
          'Brightness adjust karoon?',
          'WiFi toggle karoon?',
          'Location share karoon?',
          'Battery optimize karoon?',
        ],

      // 🔍 Analysis: Diagnostic, scanning, processing
      Mood.analysis => [
          'Device scan karoon?',
          'Storage check karoon?',
          'Battery health?',
          'Network speed test?',
          'Security audit?',
          'Performance report?',
        ],

      // 🚀 Excited: High-energy, celebration, fun actions
      Mood.excited => [
          'Kuch exciting karte hain! 🚀',
          'Photo click karein?',
          'Location track karein?',
          'Email bhej doon?',
          'Guardian test karein?',
          'New feature try karein?',
        ],

      // 🧘 Calm: Default, attentive, general assistance
      Mood.calm => [
          'Aur kuch Sir?',
          'Guardian activate?',
          'Battery status?',
          'Location check karoon?',
          'Code analyze karoon?',
          'Settings khol doon?',
        ],
    };
  }
}

// ========== Individual Prompt Chip Widget ==========

/// Glassmorphic chip for individual prompt suggestions
/// Features: Mood-colored border, hover effects, neon glow shadow
class _PromptChip extends StatelessWidget {
  // ========== Configuration Properties ==========

  /// Text label displayed on the chip
  final String label;

  /// Current mood — determines chip border color and glow
  final Mood mood;

  /// Callback executed when chip is tapped
  final VoidCallback onTap;

  /// Private constructor (only used internally)
  const _PromptChip({
    required this.label,
    required this.mood,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // Transparent background to show glass effect
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        // Subtle hover feedback
        splashColor: mood.primaryColor.withOpacity(0.1),
        highlightColor: mood.primaryColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            // Rounded corners for chip shape
            borderRadius: BorderRadius.circular(14),
            // Mood-colored border with subtle opacity
            border: Border.all(
              color: mood.primaryColor.withOpacity(0.6),
              width: 1,
            ),
            // Glassmorphic background
            color: AppColors.glassBackground,
            // Neon glow shadow for holographic effect
            boxShadow: [
              BoxShadow(
                color: mood.primaryColor.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTextStyles.promptChip.copyWith(
              color: Colors.white, // ✅ FIXED: Replaced AppColors.textPrimary
              fontSize: 10,
              // Slight letter spacing for sci-fi feel
              letterSpacing: 0.3,
            ),
            // Prevent text overflow
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

// ========== Extension: Context-Aware Prompt Enhancement ==========

/// Extension to add context-aware prompt filtering
extension PromptContextHelper on List<String> {
  /// Filter prompts based on device context (battery, connectivity, etc.)
  List<String> filterByContext({
    required int batteryLevel,
    required bool isGuardianActive,
    required bool hasCode,
  }) {
    return where((prompt) {
      // Hide battery prompts if battery is healthy
      if (prompt.toLowerCase().contains('battery') && batteryLevel > 50) {
        return false;
      }
      // Hide guardian prompts if already active
      if (prompt.toLowerCase().contains('guardian') && isGuardianActive) {
        return false;
      }
      // Hide code prompts if no code is loaded
      if (prompt.toLowerCase().contains('code') && !hasCode) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Add urgency indicator to prompts based on context
  List<String> withUrgencyIndicators({
    required int batteryLevel,
    required bool hasSecurityAlerts,
  }) {
    return map((prompt) {
      if (prompt.toLowerCase().contains('battery') && batteryLevel <= 20) {
        return '$prompt ⚠️';
      }
      if (prompt.toLowerCase().contains('security') && hasSecurityAlerts) {
        return '$prompt 🔴';
      }
      return prompt;
    }).toList();
  }
}
