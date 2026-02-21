// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. — Home Screen

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_keys.dart';
import '../../../../screens/settings_screen.dart';

class ZaraHomeScreen extends StatelessWidget {
  const ZaraHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Z.A.R.A.', style: TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.cyanPrimary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🤖 Z.A.R.A.', style: TextStyle(color: AppColors.cyanPrimary, fontSize: 32, fontWeight: FontWeight.w700, fontFamily: 'RobotoMono', letterSpacing: 4)),
            const SizedBox(height: 12),
            Text('Zenith Autonomous Reasoning Array', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'RobotoMono', letterSpacing: 2)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cyanPrimary, width: 1.5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.cyanPrimary.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
              ),
              child: const Text('Ji Sir, Ready Hoon ❤️', style: TextStyle(color: AppColors.cyanPrimary, fontSize: 14, fontFamily: 'RobotoMono')),
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final configured = ApiKeys.isConfigured;
                return Text(
                  configured ? '✅ All APIs Configured' : '⚠️ Configure APIs in Settings',
                  style: TextStyle(color: configured ? AppColors.successGreen : AppColors.warningOrange, fontSize: 11, fontFamily: 'RobotoMono'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
