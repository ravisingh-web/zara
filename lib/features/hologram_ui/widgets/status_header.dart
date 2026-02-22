// lib/features/hologram_ui/widgets/status_header.dart
// Z.A.R.A. — Status Header HUD (Heads-Up Display)
// ✅ Real-Time Metrics • Mood Indicator • Battery/Network/Integrity • Holographic Styling
// ✅ Exhaustive BatteryState Switch • Glassmorphic Design • Responsive Layout

import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../../core/enums/mood_enum.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Status header HUD for Z.A.R.A. home screen
/// Displays: App name, mood chip, integrity %, battery, network, time, status flavor
/// Updates in real-time via Provider state changes
class StatusHeader extends StatelessWidget {
  // ========== Configuration Properties ==========
  
  /// Current emotional state — determines accent colors and status text
  final Mood mood;
  
  /// Real battery percentage from battery_plus (0-100)
  final int batteryLevel;
  
  /// Real battery state from battery_plus (charging, full, discharging, etc.)
  final BatteryState batteryState;
  
  /// WiFi connectivity status from connectivity_plus
  final bool isWifiConnected;
  
  /// Mobile data connectivity status from connectivity_plus
  final bool isMobileConnected;
  
  /// Calculated system integrity (0-100) based on device health
  final double integrity;
  
  /// Current timestamp for display
  final DateTime timestamp;

  /// Constructor with required parameters
  const StatusHeader({
    super.key,
    required this.mood,
    required this.batteryLevel,
    required this.batteryState,
    required this.isWifiConnected,
    required this.isMobileConnected,
    required this.integrity,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: mood.primaryColor.withOpacity(0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: Logo, Mood, Integrity, Battery, Network, Time
          _buildTopRow(),
          
          // Bottom row: Battery state, Connection type, Status flavor
          _buildBottomRow(),
        ],
      ),
    );
  }

  // ========== Top Row: Logo + Chips + Indicators ==========
  
  /// Build top row with logo, mood chip, integrity, battery, network, time
  Widget _buildTopRow() {
    return Row(
      children: [
        // Z.A.R.A. Logo
        Text(
          'Z.A.R.A.',
          style: AppTextStyles.sciFiTitle.copyWith(fontSize: 14),
        ),
        const SizedBox(width: 10),
        
        // Mood indicator chip
        _buildStatusChip(
          label: mood.name.toUpperCase(),
          color: mood.primaryColor,
        ),
        const SizedBox(width: 6),
        
        // Integrity percentage chip
        _buildStatusChip(
          label: '${integrity.toStringAsFixed(1)}%',
          color: _getIntegrityColor(integrity),
        ),
        
        const Spacer(),
        
        // Battery indicator
        _buildBatteryIndicator(),
        const SizedBox(width: 6),
        
        // Network indicator
        _buildNetworkIndicator(),
        const SizedBox(width: 8),
        
        // Current time
        Text(
          _formatTime(timestamp),
          style: AppTextStyles.moodLabel.copyWith(
            color: mood.primaryColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ========== Bottom Row: Status Details ==========
  
  /// Build bottom row with battery state, connection type, mood flavor
  Widget _buildBottomRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          // Battery state text (e.g., "⚡ Charging")
          Text(
            _getBatteryStateText(),
            style: TextStyle(
              color: _getBatteryColor(batteryLevel),
              fontSize: 9,
              fontFamily: 'RobotoMono',
            ),
          ),
          const SizedBox(width: 10),
          
          // Connection type (WiFi/Mobile/Offline)
          Text(
            _getConnectionTypeText(),
            style: TextStyle(
              color: _getConnectionColor(),
              fontSize: 9,
              fontFamily: 'RobotoMono',
            ),
          ),
          
          const Spacer(),
          
          // Mood status flavor (e.g., "Neural lattice stable")
          Text(
            mood.getStatusFlavor(),
            style: TextStyle(
              color: mood.primaryColor.withOpacity(0.7),
              fontSize: 9,
              fontFamily: 'RobotoMono',
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Status Chip Widget ==========
  
  /// Reusable chip for mood and integrity display
  Widget _buildStatusChip({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.08),
      ),
      child: Text(
        label,
        style: AppTextStyles.moodLabel.copyWith(
          color: color,
          fontSize: 8,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ========== Battery Indicator ==========
  
  /// Battery icon + percentage + charging indicator
  Widget _buildBatteryIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Battery icon based on level
        Icon(
          _getBatteryIcon(),
          size: 14,
          color: _getBatteryColor(batteryLevel),
        ),
        const SizedBox(width: 3),
        
        // Percentage text
        Text(
          '$batteryLevel%',
          style: TextStyle(
            color: _getBatteryColor(batteryLevel),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            fontFamily: 'RobotoMono',
          ),
        ),
        
        // Charging lightning bolt (if applicable)
        if (batteryState == BatteryState.charging) ...[
          const SizedBox(width: 2),
          const Icon(
            Icons.flash_on,
            size: 10,
            color: AppColors.successGreen,
          ),
        ],
      ],
    );
  }

  // ========== Network Indicator ==========
  
  /// WiFi/Mobile/Offline icon with color coding
  Widget _buildNetworkIndicator() {
    return Icon(
      _getNetworkIcon(),
      size: 14,
      color: _getConnectionColor(),
    );
  }
  
  /// Get appropriate network icon based on connectivity
  IconData _getNetworkIcon() {
    if (isWifiConnected) return Icons.wifi;
    if (isMobileConnected) return Icons.signal_cellular_4_bar;
    return Icons.signal_cellular_off;
  }
  
  /// Get connection type text for bottom row
  String _getConnectionTypeText() {
    if (isWifiConnected) return 'WiFi';
    if (isMobileConnected) return 'Mobile';
    return 'Offline';
  }
  
  /// Get color for connection indicator
  Color _getConnectionColor() {
    if (isWifiConnected) return AppColors.successGreen;
    if (isMobileConnected) return AppColors.warningOrange;
    return AppColors.textDim;
  }

  // ========== Battery Helpers ==========
  
  /// Get battery icon based on level
  IconData _getBatteryIcon() {
    if (batteryLevel <= 20) return Icons.battery_alert;
    if (batteryLevel <= 50) return Icons.battery_3_bar;
    if (batteryLevel <= 80) return Icons.battery_4_bar;
    return Icons.battery_full;
  }
  
  /// Get color for battery indicator based on level
  Color _getBatteryColor(int level) {
    if (level <= 20) return AppColors.errorRed;
    if (level <= 50) return AppColors.warningOrange;
    return AppColors.successGreen;
  }
  
  /// Get human-readable battery state text
  /// Handles all BatteryState enum values exhaustively
  String _getBatteryStateText() {
    return switch (batteryState) {
      BatteryState.charging => '⚡ Charging',
      BatteryState.full => '✓ Full',
      BatteryState.discharging => '🔋 Discharging',
      BatteryState.connectedNotCharging => '⚡ Connected',
      BatteryState.unknown => 'Unknown',
    };
  }

  // ========== Integrity Helpers ==========
  
  /// Get color for integrity chip based on value
  Color _getIntegrityColor(double integrity) {
    if (integrity <= 70) return AppColors.errorRed;
    if (integrity <= 85) return AppColors.warningOrange;
    return AppColors.successGreen;
  }

  // ========== Time Formatting ==========
  
  /// Format DateTime as HH:MM (24-hour format)
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
