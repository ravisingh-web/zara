// lib/features/hologram_ui/widgets/floating_prompts.dart
// Z.A.R.A. — Context-Aware Suggestion Chips
// ✅ Strict Error Fix: AppColors.textPrimary changed to Colors.white
// ✅ Zero Logic Changed.

import 'package:flutter/material.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/app_text_styles.dart';

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
    final prompts = _getPromptsForMood(mood);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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

  List<String> _getPromptsForMood(Mood mood) {
    return switch (mood) {
      Mood.romantic => [
          'Aur kuch Sir? ❤️',
          'Romantic mode aur badhao?',
          'Dil ki baat boliye…',
          'Guardian activate?',
          'Battery check karoon?',
          'Photo click karoon Sir? 📸',
        ],
      Mood.ziddi => [          'Sir zara jaldi bolo na 😤',
          'Auto-fix kar doon?',
          'Ziddi hoon abhi… try karo',
          'Location share karoon?',
          'Photo click karoon?',
          'Code me help karoon?',
        ],
      Mood.angry => [
          'Security alert check?',
          'Intruder photo dekhna hai?',
          'Trusted contacts update?',
          'Guardian status?',
          'Network scan karoon?',
          'Permissions check karoon?',
        ],
      Mood.coding => [
          'Code paste karo Sir',
          'Bracket fix kar doon?',
          'Syntax check karoon?',
          'Dart analyze karoon?',
          'Errors fix kar doon?',
          'New file create karoon?',
        ],
      Mood.automation => [
          'Instagram post kar doon?',
          'WhatsApp message bhej doon?',
          'Brightness adjust karoon?',
          'WiFi toggle karoon?',
          'Location share karoon?',
          'Battery optimize karoon?',
        ],
      Mood.analysis => [
          'Device scan karoon?',
          'Storage check karoon?',
          'Battery health?',
          'Network speed test?',
          'Security audit?',
          'Performance report?',
        ],
      Mood.excited => [
          'Kuch exciting karte hain! 🚀',
          'Photo click karein?',
          'Location track karein?',
          'Email bhej doon?',
          'Guardian test karein?',
          'New feature try karein?',
        ],
      Mood.calm => [
          'Aur kuch Sir?',
          'Guardian activate?',          'Battery status?',
          'Location check karoon?',
          'Code analyze karoon?',
          'Settings khol doon?',
        ],
    };
  }
}

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
        splashColor: mood.primaryColor.withValues(alpha: 0.1),
        highlightColor: mood.primaryColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mood.primaryColor.withValues(alpha: 0.6),
              width: 1,
            ),
            color: AppColors.glassBackground,
            boxShadow: [
              BoxShadow(
                color: mood.primaryColor.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTextStyles.promptChip.copyWith(
              color: Colors.white,              fontSize: 10,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

extension PromptContextHelper on List<String> {
  List<String> filterByContext({
    required int batteryLevel,
    required bool isGuardianActive,
    required bool hasCode,
  }) {
    return where((prompt) {
      if (prompt.toLowerCase().contains('battery') && batteryLevel > 50) {
        return false;
      }
      if (prompt.toLowerCase().contains('guardian') && isGuardianActive) {
        return false;
      }
      if (prompt.toLowerCase().contains('code') && !hasCode) {
        return false;
      }
      return true;
    }).toList();
  }

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
