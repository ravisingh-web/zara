// lib/features/hologram_ui/widgets/status_header.dart
// Z.A.R.A. — Status Header HUD
// ✅ Fixed: Exhaustive BatteryState switch

import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import '../../../core/enums/mood_enum.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class StatusHeader extends StatelessWidget {
  final Mood mood;
  final int batteryLevel;
  final BatteryState batteryState;
  final bool isWifiConnected;
  final bool isMobileConnected;
  final double integrity;
  final DateTime timestamp;
  
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
          bottom: BorderSide(color: mood.primaryColor.withOpacity(0.4), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Z.A.R.A.', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 14)),
              const SizedBox(width: 10),
              _buildStatusChip(label: mood.name.toUpperCase(), color: mood.primaryColor),
              const SizedBox(width: 6),
              _buildStatusChip(label: '${integrity.toStringAsFixed(1)}%', color: _getIntegrityColor(integrity)),
              const Spacer(),
              _buildBatteryIndicator(),
              const SizedBox(width: 6),
              _buildNetworkIndicator(),
              const SizedBox(width: 8),
              Text(_formatTime(timestamp), style: AppTextStyles.moodLabel.copyWith(color: mood.primaryColor, fontSize: 10)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(_getBatteryStateText(), style: TextStyle(color: _getBatteryColor(batteryLevel), fontSize: 9, fontFamily: 'RobotoMono')),
                const SizedBox(width: 10),
                Text(isWifiConnected ? 'WiFi' : (isMobileConnected ? 'Mobile' : 'Offline'), style: TextStyle(color: isWifiConnected ? AppColors.successGreen : (isMobileConnected ? AppColors.warningOrange : AppColors.textDim), fontSize: 9, fontFamily: 'RobotoMono')),
                const Spacer(),
                Text(mood.getStatusFlavor(), style: TextStyle(color: mood.primaryColor.withOpacity(0.7), fontSize: 9, fontFamily: 'RobotoMono', fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.08),
      ),
      child: Text(label, style: AppTextStyles.moodLabel.copyWith(color: color, fontSize: 8, letterSpacing: 1.2)),
    );
  }
  
  Widget _buildBatteryIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getBatteryIcon(), size: 14, color: _getBatteryColor(batteryLevel)),
        const SizedBox(width: 3),
        Text('$batteryLevel%', style: TextStyle(color: _getBatteryColor(batteryLevel), fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono')),
        if (batteryState == BatteryState.charging) const Icon(Icons.flash_on, size: 10, color: AppColors.successGreen),
      ],
    );
  }
  
  Widget _buildNetworkIndicator() {
    return Icon(isWifiConnected ? Icons.wifi : (isMobileConnected ? Icons.signal_cellular_4_bar : Icons.signal_cellular_off), size: 14, color: isWifiConnected ? AppColors.successGreen : (isMobileConnected ? AppColors.warningOrange : AppColors.textDim));
  }
  
  IconData _getBatteryIcon() {
    if (batteryLevel <= 20) return Icons.battery_alert;
    if (batteryLevel <= 50) return Icons.battery_3_bar;
    if (batteryLevel <= 80) return Icons.battery_4_bar;
    return Icons.battery_full;
  }
  
  Color _getBatteryColor(int level) {
    if (level <= 20) return AppColors.errorRed;
    if (level <= 50) return AppColors.warningOrange;
    return AppColors.successGreen;
  }
  
  Color _getIntegrityColor(double integrity) {
    if (integrity <= 70) return AppColors.errorRed;
    if (integrity <= 85) return AppColors.warningOrange;
    return AppColors.successGreen;
  }
  
  String _getBatteryStateText() {
    return switch (batteryState) {
      BatteryState.charging => '⚡ Charging',
      BatteryState.full => '✓ Full',
      BatteryState.discharging => '🔋 Discharging',
      BatteryState.connectedNotCharging => '⚡ Connected',
      BatteryState.unknown => 'Unknown',
    };
  }
  
  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
