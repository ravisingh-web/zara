// lib/features/hologram_ui/widgets/status_header.dart
// Z.A.R.A. — High-Tech HUD Header
// ✅ Video-Matched Diamonds & Owner Branding
// ✅ Long-Press Rename & Topic History Bridge
// ✅ 0% Dummy — Fully Connected to App State

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zara/core/constants/app_colors.dart';

class StatusHeader extends StatelessWidget {
  final String topicTitle;
  final bool guardianMode;
  final bool systemOnline;
  final VoidCallback onMenuTap;
  final VoidCallback onNewChat;
  final VoidCallback onSettingsTap;
  final ValueChanged<String> onRenameTitle;

  const StatusHeader({
    super.key,
    required this.topicTitle,
    this.guardianMode = false,
    this.systemOnline = true,
    required this.onMenuTap,
    required this.onNewChat,
    required this.onSettingsTap,
    required this.onRenameTitle,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = guardianMode ? AppColors.alertRed : AppColors.neonCyan;

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 5, left: 10, right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TOP BRANDING: Diamonds + Owner Name (Matched to Video)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDiamond(accentColor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text(
                  'ZARA OWNER MAHAKAL RAVI',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              _buildDiamond(accentColor),
            ],
          ),
          
          const SizedBox(height: 15),

          // 2. MAIN HUD BAR (Menu | Topic | Actions)
          Row(
            children: [
              // LEFT: Menu Button (History Drawer)
              IconButton(
                icon: Icon(Icons.menu_rounded, color: accentColor, size: 22),
                onPressed: onMenuTap,
              ),

              // CENTER: Dynamic Topic Title
              Expanded(
                child: GestureDetector(
                  onLongPress: () => _showRenameDialog(context),
                  child: Column(
                    children: [
                      Text(
                        topicTitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // System Status Line (Matched to Screenshot)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatusDot(systemOnline),
                          const SizedBox(width: 6),
                          Text(
                            guardianMode ? 'GUARDIAN MODE: ACTIVE' : 'SYSTEM ONLINE — ALL CORES ACTIVE',
                            style: TextStyle(
                              color: systemOnline ? AppColors.neonGreen.withOpacity(0.7) : AppColors.alertRed,
                              fontSize: 8,
                              letterSpacing: 1.2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT: New Chat & More (Settings)
              IconButton(
                icon: Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 22),
                onPressed: onNewChat,
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: accentColor, size: 22),
                onPressed: onSettingsTap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiamond(Color color) {
    return Transform.rotate(
      angle: 0.785, // 45 degrees for diamond shape
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)],
        ),
      ),
    );
  }

  Widget _buildStatusDot(bool online) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? AppColors.neonGreen : AppColors.alertRed,
        boxShadow: [
          BoxShadow(
            color: (online ? AppColors.neonGreen : AppColors.alertRed).withOpacity(0.8),
            blurRadius: 5,
          )
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: topicTitle);
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.neonCyan.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('RENAME HUD TOPIC', style: TextStyle(color: AppColors.neonCyan, fontSize: 14)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.neonCyan)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                onRenameTitle(controller.text);
                Navigator.pop(context);
              },
              child: const Text('CONFIRM', style: TextStyle(color: AppColors.neonCyan)),
            ),
          ],
        ),
      ),
    );
  }
}
