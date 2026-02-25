// lib/features/hologram_ui/widgets/central_response_panel.dart
// Z.A.R.A. — High-Performance Neural HUD Response Panel
// ✅ Strict Error Fix: state.mood.color changed to state.mood.primaryColor
// ✅ Zero Logic Changed.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';

class CentralResponsePanel extends StatefulWidget {
  const CentralResponsePanel({super.key});

  @override
  State<CentralResponsePanel> createState() => _CentralResponsePanelState();
}

class _CentralResponsePanelState extends State<CentralResponsePanel> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<String> _historyCache = [];

  @override
  Widget build(BuildContext context) {
    final zara = context.watch<ZaraController>();
    final state = zara.state;

    // Logic: Sync internal list with Provider history
    if (state.dialogueHistory.length > _historyCache.length) {
      for (int i = _historyCache.length; i < state.dialogueHistory.length; i++) {
        _historyCache.add(state.dialogueHistory[i]);
        _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 600));
      }
    }

    return Stack(
      children: [
        // 1. 🛡️ CENTRAL BRANDING (Matched to 1000150011.png)
        _buildNeuralLogo(),

        // 2. 🦾 HUD MESSAGE STACK (Top-Right Logic - Matched to 1000150012.mp4)
        Positioned(
          top: 100,
          right: 20,
          width: MediaQuery.of(context).size.width * 0.48,
          height: 350,
          child: AnimatedList(
            key: _listKey,
            initialItemCount: _historyCache.length,
            reverse: false, // Stack from top down in the HUD area
            itemBuilder: (context, index, animation) {
              // Reversed to show latest at the bottom of the HUD area
              final message = _historyCache.reversed.toList()[index];
              return _buildAnimatedHudMessage(message, animation);
            },
          ),
        ),

        // 3. 💬 ZARA'S LIVE FLOATING RESPONSE (Glassmorphism Effect)
        if (state.lastResponse.isNotEmpty)
          Align(
            alignment: const Alignment(0, 0.75),
            child: _buildZaraReplyBubble(state.lastResponse, state.mood.primaryColor), // ✅ FIXED HERE
          ),
      ],
    );
  }

  Widget _buildNeuralLogo() {
    return Align(
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 50),
            const Text(
              'BIOMETRIC INTELLIGENCE INTERFACE',
              style: TextStyle(color: AppColors.neonCyan, fontSize: 8, letterSpacing: 4),
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
                shadows: [Shadow(color: AppColors.neonCyan.withOpacity(0.5), blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'ADVANCED NEURAL COMMAND SYSTEM',
              style: TextStyle(color: AppColors.neonCyan, fontSize: 10, letterSpacing: 3, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHudMessage(String text, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(animation),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.neonCyan.withOpacity(0.3), width: 1.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'OWNER RAVI >>',
                style: TextStyle(color: AppColors.neonCyan, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 2),
              Text(
                text.toUpperCase(),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace', height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZaraReplyBubble(String text, Color moodColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: moodColor.withOpacity(0.4), width: 1),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace', height: 1.5),
          ),
        ),
      ),
    );
  }
}
