// lib/features/hologram_ui/widgets/central_response_panel.dart
// Z.A.R.A. — Central Response Panel
// ✅ Fixed: Added Mood import

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/mood_enum.dart';

class CentralResponsePanel extends StatelessWidget {
  final Mood mood;
  final String content;
  final List? securityAlerts;
  final Map? codeAnalysisResult;
  final List? automationTasks;
  
  const CentralResponsePanel({
    super.key,
    required this.mood,
    required this.content,
    this.securityAlerts,
    this.codeAnalysisResult,
    this.automationTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mood.primaryColor.withOpacity(0.7), width: 1.5),
        color: AppColors.glassBackground,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mood.primaryColor.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: mood.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text('Z.A.R.A. Response', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.isNotEmpty)
            Text(content, style: AppTextStyles.terminalText.copyWith(fontSize: 13)),
          if (securityAlerts != null && securityAlerts!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAlertsSection(),
          ],
          if (codeAnalysisResult != null) ...[
            const SizedBox(height: 16),
            _buildCodeSection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.5), width: 1),
        color: AppColors.errorRed.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: AppColors.errorRed, size: 18),
              const SizedBox(width: 8),
              Text('Security Alerts', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 12, color: AppColors.errorRed)),
            ],
          ),
          const SizedBox(height: 8),
          ...(securityAlerts ?? []).map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${alert['message'] ?? 'Alert'}', style: AppTextStyles.terminalText.copyWith(fontSize: 11)),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildCodeSection() {
    final isValid = codeAnalysisResult?['isValid'] ?? true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isValid ? AppColors.successGreen : AppColors.warningOrange, width: 1),
        color: isValid ? AppColors.successGreen.withOpacity(0.1) : AppColors.warningOrange.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isValid ? Icons.check_circle : Icons.error_outline, color: isValid ? AppColors.successGreen : AppColors.warningOrange, size: 18),
              const SizedBox(width: 8),
              Text(isValid ? 'Code Valid ✓' : 'Issues Found ⚠️', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 12, color: isValid ? AppColors.successGreen : AppColors.warningOrange)),
            ],
          ),
          const SizedBox(height: 8),
          ...(codeAnalysisResult?['suggestions'] as List? ?? []).map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $s', style: AppTextStyles.terminalText.copyWith(fontSize: 11)),
          )).toList(),
        ],
      ),
    );
  }
}
