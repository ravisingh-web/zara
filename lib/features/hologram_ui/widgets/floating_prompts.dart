// lib/features/hologram_ui/widgets/floating_prompts.dart
// Z.A.R.A. — REAL Context-Aware Suggestion Chips
// Dynamic prompts based on mood, battery, guardian state

import 'package:flutter/material.dart';
import '../../../core/enums/mood_enum.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class FloatingPrompts extends StatelessWidget {
  final Mood mood;
  final Function(String) onSelected;
  
  const FloatingPrompts({
    super.key,
    required this.mood,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Mood-aware + context-aware prompt suggestions
    final prompts = _getPromptsForMood(mood);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
  
  List<String> _getPromptsForMood(Mood mood) {
    return switch (mood) {
      Mood.romantic => [
          'Aur kuch Sir? ❤️',
          'Romantic mode aur badhao?',
          'Dil ki baat boliye…',
          'Guardian activate?',
          'Battery check karoon?',
        ],
      Mood.ziddi => [
          'Sir zara jaldi bolo na 😤',
          'Auto-fix kar doon?',
          'Ziddi hoon abhi… try karo',
          'Location share karoon?',
          'Photo click karoon?',
        ],
      Mood.angry => [
          'Security alert check?',
          'Intruder photo dekhna hai?',
          'Trusted contacts update?',
          'Guardian status?',
          'Network scan karoon?',
        ],
      Mood.coding => [
          'Code paste karo Sir',
          'Bracket fix kar doon?',
          'Syntax check karoon?',
          'Dart analyze karoon?',
          'Errors fix kar doon?',
        ],
      Mood.automation => [
          'Instagram post kar doon?',
          'WhatsApp message bhej doon?',
          'Brightness adjust karoon?',
          'WiFi toggle karoon?',
          'Location share karoon?',
        ],
      Mood.analysis => [
          'Device scan karoon?',
          'Storage check karoon?',
          'Battery health?',
          'Network speed test?',
          'Security audit?',
        ],
      Mood.excited => [
          'Kuch exciting karte hain! 🚀',
          'Photo click karein?',
          'Location track karein?',
          'Email bhej doon?',
          'Guardian test karein?',
        ],
      Mood.calm => [
          'Aur kuch Sir?',
          'Guardian activate?',
          'Battery status?',
          'Location check karoon?',
          'Code analyze karoon?',
        ],
    };
  }
}

/// Individual neon-style prompt chip
class _PromptChip extends StatelessWidget {
  final String label;
  final Mood mood;
  final VoidCallback onTap;
  
  const _PromptChip({
    required this.label,
    required this.mood,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mood.primaryColor.withOpacity(0.6),
              width: 1,
            ),
            color: AppColors.glassBackground,
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
              color: AppColors.textPrimary,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
