// lib/features/hologram_ui/widgets/central_response_panel.dart
// Z.A.R.A. — High-Performance Neural HUD Response Panel
// ✅ Fixed: Radius.zero syntax errors resolved
// ✅ Cyberpunk Chat UI (WhatsApp/Insta Style)
// ✅ Glassmorphic Bubbles • Left (ZARA) / Right (USER) Alignment

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';

class CentralResponsePanel extends StatelessWidget {
  const CentralResponsePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final zara = context.watch<ZaraController>();
    final state = zara.state;

    return Stack(
      children: [
        // 1. 🛡️ CENTRAL BRANDING (Background Logo)
        _buildNeuralLogo(),

        // 2. 💬 CYBERPUNK CHAT BOX (Scrollable Left/Right Bubbles)
        Positioned.fill(
          top: 90,
          bottom: 80,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            reverse: true,
            itemCount: state.dialogueHistory.length,
            itemBuilder: (context, index) {
              final message = state.dialogueHistory.reversed.toList()[index];
              final isZara = message.startsWith('>> ZARA:');
              final displayText = isZara
                  ? message.replaceAll('>> ZARA: ', '')
                  : message;

              return _buildChatBubble(
                displayText,
                isZara,
                state.mood.primaryColor,
              );
            },
          ),
        ),
      ],    );
  }

  Widget _buildNeuralLogo() {
    return Align(
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 50),
            const Text(
              'BIOMETRIC INTELLIGENCE INTERFACE',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 8,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ZARA AI',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 12,
                fontFamily: 'monospace',
                shadows: [
                  Shadow(
                    color: AppColors.neonCyan.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'ADVANCED NEURAL COMMAND SYSTEM',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 10,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),    );
  }

  Widget _buildChatBubble(String text, bool isZara, Color moodColor) {
    final borderColor = isZara
        ? moodColor.withOpacity(0.5)
        : AppColors.neonGreen.withOpacity(0.5);
    final shadowColor = isZara
        ? moodColor.withOpacity(0.15)
        : AppColors.neonGreen.withOpacity(0.15);
    final alignment = isZara ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final bubbleAlign = isZara ? Alignment.centerLeft : Alignment.centerRight;

    return Align(
      alignment: bubbleAlign,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: alignment,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                child: Text(
                  isZara ? 'Z.A.R.A.' : 'OWNER RAVI',
                  style: TextStyle(
                    color: isZara ? moodColor : AppColors.neonGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isZara ? Radius.zero : const Radius.circular(16),
                  bottomRight: !isZara ? Radius.zero : const Radius.circular(16),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),                      border: Border.all(color: borderColor, width: 1),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isZara ? Radius.zero : const Radius.circular(16),
                        bottomRight: !isZara ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
