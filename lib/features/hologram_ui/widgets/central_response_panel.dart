// lib/features/hologram_ui/widgets/central_response_panel.dart
// Z.A.R.A. — Central Response Panel
// ✅ Mood-Reactive Display • Security Alerts • Code Analysis • Automation Tasks
// ✅ Glassmorphic Design • Scrollable Content • Holographic Styling

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/enums/mood_enum.dart';
import '../../zara_engine/models/zara_state.dart';

/// Central response panel for Z.A.R.A. home screen
/// Displays: Dialogue responses, security alerts, code analysis results, automation tasks
/// Features glassmorphic design with mood-reactive borders and colors
class CentralResponsePanel extends StatelessWidget {
  // ========== Configuration Properties ==========
  
  /// Current emotional state — determines border color and accent styling
  final Mood mood;
  
  /// Main dialogue/content text from Z.A.R.A.
  final String content;
  
  /// List of active security alerts (from Guardian Mode)
  final List<SecurityAlert>? securityAlerts;
  
  /// Result of code analysis operation (if any)
  final CodeAnalysisResult? codeAnalysisResult;
  
  /// List of automation tasks (if any)
  final List<AutomationTask>? automationTasks;
  
  /// Device info for display (optional)
  final String? deviceModel;
  final String? androidVersion;
  final int? batteryLevel;

  /// Constructor with required and optional parameters
  const CentralResponsePanel({
    super.key,
    required this.mood,
    required this.content,
    this.securityAlerts,
    this.codeAnalysisResult,
    this.automationTasks,
    this.deviceModel,
    this.androidVersion,
    this.batteryLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mood.primaryColor.withOpacity(0.7),
          width: 1.5,
        ),
        color: AppColors.glassBackground,
        boxShadow: [
          BoxShadow(
            color: mood.primaryColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status indicator
            _buildHeader(),
            
            // Scrollable content area
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  // ========== Header Section ==========
  
  /// Build header with status dot, title, and optional device info
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mood.primaryColor.withOpacity(0.2),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: mood.primaryColor.withOpacity(0.25),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Animated status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: mood.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: mood.primaryColor.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Title
          Text(
            'Z.A.R.A. Response',
            style: AppTextStyles.sciFiTitle.copyWith(fontSize: 13),
          ),
          
          const Spacer(),
          
          // Optional device info badge
          if (deviceModel != null && androidVersion != null)
            _buildDeviceBadge(),
        ],
      ),
    );
  }
  
  /// Small badge showing device model and Android version
  Widget _buildDeviceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.textDim.withOpacity(0.3),
        ),
      ),
      child: Text(
        '$deviceModel • Android $androidVersion',
        style: const TextStyle(
          color: AppColors.textDim,
          fontSize: 9,
          fontFamily: 'RobotoMono',
        ),
      ),
    );
  }

  // ========== Content Section ==========
  
  /// Build scrollable content area with conditional sections
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main dialogue/content text
          if (content.isNotEmpty) _buildMainContent(),
          
          // Security alerts section (if any)
          if (securityAlerts != null && securityAlerts!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAlertsSection(),
          ],
          
          // Code analysis section (if any)
          if (codeAnalysisResult != null) ...[
            const SizedBox(height: 16),
            _buildCodeSection(),
          ],
          
          // Automation tasks section (if any)
          if (automationTasks != null && automationTasks!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAutomationSection(),
          ],
        ],
      ),
    );
  }
  
  /// Build main dialogue/content text with terminal styling
  Widget _buildMainContent() {
    return Text(
      content,
      style: AppTextStyles.terminalText.copyWith(
        fontSize: 13,
        height: 1.6,
      ),
    );
  }

  // ========== Security Alerts Section ==========
  
  /// Build section for displaying security alerts (Guardian Mode)
  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.errorRed.withOpacity(0.5),
          width: 1,
        ),
        color: AppColors.errorRed.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(
                Icons.warning_amber,
                color: AppColors.errorRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Security Alerts',
                style: AppTextStyles.sciFiTitle.copyWith(
                  fontSize: 12,
                  color: AppColors.errorRed,
                ),
              ),
              const Spacer(),
              Text(
                '${securityAlerts!.length}',
                style: TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Alert list
          ...securityAlerts!.map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildAlertItem(alert),
          )).toList(),
        ],
      ),
    );
  }
  
  /// Build individual alert item with timestamp and message
  Widget _buildAlertItem(SecurityAlert alert) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            color: AppColors.errorRed,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.message,
                style: AppTextStyles.terminalText.copyWith(
                  fontSize: 11,
                ),
              ),
              if (alert.photoPath != null) ...[
                const SizedBox(height: 4),
                Text(
                  '📸 Photo: ${alert.photoPath!.split('/').last}',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
              Text(
                _formatAlertTime(alert.timestamp),
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 9,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Format alert timestamp as relative time
  String _formatAlertTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ========== Code Analysis Section ==========
  
  /// Build section for displaying code analysis results
  Widget _buildCodeSection() {
    final result = codeAnalysisResult!;
    final isValid = result.isValid;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? AppColors.successGreen : AppColors.warningOrange,
          width: 1,
        ),
        color: isValid 
            ? AppColors.successGreen.withOpacity(0.1) 
            : AppColors.warningOrange.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.error_outline,
                color: isValid ? AppColors.successGreen : AppColors.warningOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isValid ? 'Code Valid ✓' : 'Issues Found ⚠️',
                style: AppTextStyles.sciFiTitle.copyWith(
                  fontSize: 12,
                  color: isValid ? AppColors.successGreen : AppColors.warningOrange,
                ),
              ),
              const Spacer(),
              Text(
                '${result.lineCount} lines',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 10,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Stats row
          if (result.classCount.isNotEmpty || result.functionCount.isNotEmpty)
            _buildCodeStats(result),
          
          const SizedBox(height: 8),
          
          // Suggestions/Issues list
          ...result.suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $suggestion',
              style: AppTextStyles.terminalText.copyWith(
                fontSize: 11,
              ),
            ),
          )).toList(),
          
          // Show issues if any
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Issues:',
              style: TextStyle(
                color: AppColors.warningOrange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'RobotoMono',
              ),
            ),
            ...result.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '  Line ${issue.line > 0 ? issue.line : '?'}: ${issue.message}',
                style: AppTextStyles.terminalText.copyWith(
                  color: AppColors.errorRed,
                  fontSize: 10,
                ),
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }
  
  /// Build code stats row (classes/functions count)
  Widget _buildCodeStats(CodeAnalysisResult result) {
    return Row(
      children: [
        if (result.classCount.isNotEmpty)
          _buildCodeStat('Classes', result.classCount.length.toString()),
        if (result.classCount.isNotEmpty && result.functionCount.isNotEmpty)
          const SizedBox(width: 12),
        if (result.functionCount.isNotEmpty)
          _buildCodeStat('Functions', result.functionCount.length.toString()),
      ],
    );
  }
  
  /// Build individual code stat badge
  Widget _buildCodeStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.textDim.withOpacity(0.3),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'RobotoMono'),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: AppColors.textDim,
                fontSize: 10,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: mood.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Automation Tasks Section ==========
  
  /// Build section for displaying automation tasks
  Widget _buildAutomationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.moodAutomation.withOpacity(0.5),
          width: 1,
        ),
        color: AppColors.moodAutomation.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.moodAutomation,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Automation Tasks',
                style: AppTextStyles.sciFiTitle.copyWith(
                  fontSize: 12,
                  color: AppColors.moodAutomation,
                ),
              ),
              const Spacer(),
              Text(
                '${automationTasks!.length} tasks',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 10,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Task list
          ...automationTasks!.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildTaskItem(task),
          )).toList(),
        ],
      ),
    );
  }
  
  /// Build individual automation task item
  Widget _buildTaskItem(AutomationTask task) {
    return Row(
      children: [
        // Status icon
        Icon(
          _getTaskStatusIcon(task.status),
          size: 14,
          color: _getTaskStatusColor(task.status),
        ),
        const SizedBox(width: 8),
        
        // Task description
        Expanded(
          child: Text(
            task.description,
            style: AppTextStyles.terminalText.copyWith(
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getTaskStatusColor(task.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _getTaskStatusColor(task.status).withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Text(
            task.status.name.toUpperCase(),
            style: TextStyle(
              color: _getTaskStatusColor(task.status),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              fontFamily: 'RobotoMono',
            ),
          ),
        ),
      ],
    );
  }
  
  /// Get icon for task status
  IconData _getTaskStatusIcon(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => Icons.circle_outlined,
      TaskStatus.running => Icons.hourglass_empty,
      TaskStatus.completed => Icons.check_circle,
      TaskStatus.failed => Icons.error_outline,
      TaskStatus.cancelled => Icons.cancel,
    };
  }
  
  /// Get color for task status
  Color _getTaskStatusColor(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => AppColors.textDim,
      TaskStatus.running => AppColors.warningOrange,
      TaskStatus.completed => AppColors.successGreen,
      TaskStatus.failed => AppColors.errorRed,
      TaskStatus.cancelled => AppColors.textDim,
    };
  }
}
