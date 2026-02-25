// lib/features/zara_engine/models/zara_state.dart
// Z.A.R.A. — High-Performance Immutable State Model
// ✅ Real Persistence (JSON Mapping) • Corrected CopyWith
// ✅ Advanced Tactical Models • Neural Sync Ready

import 'package:battery_plus/battery_plus.dart';
import 'package:zara/core/enums/mood_enum.dart';

class ZaraState {
  final bool isActive;
  final Mood mood;
  final String currentTopic;
  final String lastCommand;
  final String lastResponse;
  final DateTime lastActivity;
  final double pulseValue;
  final double orbScale;
  final double glowIntensity;
  final int affectionLevel;
  final String ownerName;
  final List<String> dialogueHistory;
  final int batteryLevel;
  final BatteryState batteryState;
  final String deviceModel;
  final bool isWifiConnected;
  final int availableStorageMB;
  final int totalStorageMB;
  final bool isGuardianActive;
  final int intruderAttempts;
  final List<SecurityAlert> alerts;
  final String? lastIntruderPhoto;
  final List<AutomationTask> tasks;
  final bool isAnalyzingCode;

  const ZaraState({
    required this.isActive,
    required this.mood,
    required this.currentTopic,
    required this.lastCommand,
    required this.lastResponse,
    required this.lastActivity,
    required this.pulseValue,
    required this.orbScale,
    required this.glowIntensity,
    required this.affectionLevel,
    required this.ownerName,
    required this.dialogueHistory,
    required this.batteryLevel,
    required this.batteryState,
    required this.deviceModel,
    required this.isWifiConnected,
    required this.availableStorageMB,
    required this.totalStorageMB,
    required this.isGuardianActive,
    required this.intruderAttempts,
    required this.alerts,
    this.lastIntruderPhoto,
    required this.tasks,
    required this.isAnalyzingCode,
  });

  factory ZaraState.initial() => ZaraState(
    isActive: false,
    mood: Mood.calm,
    currentTopic: 'SYSTEM INITIALIZED',
    lastCommand: '',
    lastResponse: 'System Online. Ready for commands, Sir.',
    lastActivity: DateTime.now(),
    pulseValue: 0.0,
    orbScale: 1.0,
    glowIntensity: 0.5,
    affectionLevel: 85,
    ownerName: 'OWNER RAVI',
    dialogueHistory: [],
    batteryLevel: 0,
    batteryState: BatteryState.unknown,
    deviceModel: 'SYNCHRONIZING...',
    isWifiConnected: false,
    availableStorageMB: 0,
    totalStorageMB: 0,
    isGuardianActive: false,
    intruderAttempts: 0,
    alerts: [],
    tasks: [],
    isAnalyzingCode: false,
  );

  // ========== THE PERSISTENCE ENGINE (Missing Logic Added) ==========
  
  Map<String, dynamic> toMap() {
    return {
      'affectionLevel': affectionLevel,
      'ownerName': ownerName,
      'dialogueHistory': dialogueHistory,
      'isGuardianActive': isGuardianActive,
      'currentTopic': currentTopic,
    };
  }

  factory ZaraState.fromMap(Map<String, dynamic> map) {
    final initial = ZaraState.initial();
    return initial.copyWith(
      affectionLevel: map['affectionLevel'] ?? 85,
      ownerName: map['ownerName'] ?? 'OWNER RAVI',
      dialogueHistory: List<String>.from(map['dialogueHistory'] ?? []),
      isGuardianActive: map['isGuardianActive'] ?? false,
      currentTopic: map['currentTopic'] ?? 'SYSTEM INITIALIZED',
    );
  }

  double get systemIntegrity {
    double base = 100.0;
    if (batteryLevel < 15) base -= 20;
    if (isGuardianActive) base += 5;
    if (alerts.isNotEmpty) base -= (alerts.length * 10);
    return base.clamp(0, 100);
  }

  ZaraState copyWith({
    bool? isActive,
    Mood? mood,
    String? currentTopic,
    String? lastCommand,
    String? lastResponse,
    DateTime? lastActivity,
    double? pulseValue,
    double? orbScale,
    double? glowIntensity,
    int? affectionLevel,
    String? ownerName, // Fixed: Now you can rename the owner
    List<String>? dialogueHistory,
    int? batteryLevel,
    BatteryState? batteryState,
    String? deviceModel,
    bool? isWifiConnected,
    int? availableStorageMB,
    int? totalStorageMB,
    bool? isGuardianActive,
    int? intruderAttempts,
    List<SecurityAlert>? alerts,
    String? lastIntruderPhoto,
    List<AutomationTask>? tasks,
    bool? isAnalyzingCode,
  }) {
    return ZaraState(
      isActive: isActive ?? this.isActive,
      mood: mood ?? this.mood,
      currentTopic: currentTopic ?? this.currentTopic,
      lastCommand: lastCommand ?? this.lastCommand,
      lastResponse: lastResponse ?? this.lastResponse,
      lastActivity: lastActivity ?? this.lastActivity,
      pulseValue: pulseValue ?? this.pulseValue,
      orbScale: orbScale ?? this.orbScale,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      affectionLevel: affectionLevel ?? this.affectionLevel,
      ownerName: ownerName ?? this.ownerName, // Logic Fixed
      dialogueHistory: dialogueHistory ?? this.dialogueHistory,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryState: batteryState ?? this.batteryState,
      deviceModel: deviceModel ?? this.deviceModel,
      isWifiConnected: isWifiConnected ?? this.isWifiConnected,
      availableStorageMB: availableStorageMB ?? this.availableStorageMB,
      totalStorageMB: totalStorageMB ?? this.totalStorageMB,
      isGuardianActive: isGuardianActive ?? this.isGuardianActive,
      intruderAttempts: intruderAttempts ?? this.intruderAttempts,
      alerts: alerts ?? this.alerts,
      lastIntruderPhoto: lastIntruderPhoto ?? this.lastIntruderPhoto,
      tasks: tasks ?? this.tasks,
      isAnalyzingCode: isAnalyzingCode ?? this.isAnalyzingCode,
    );
  }
}

// ========== REFINED TACTICAL MODELS ==========

enum AlertSeverity { low, medium, high, critical }

class SecurityAlert {
  final String id;
  final String message;
  final AlertSeverity severity;
  final DateTime time;

  SecurityAlert({
    required this.id, 
    required this.message, 
    this.severity = AlertSeverity.medium, 
    required this.time
  });
}

class AutomationTask {
  final String id;
  final String description;
  final String status; // pending, running, completed, failed
  final DateTime timestamp;

  AutomationTask({
    required this.id, 
    required this.description, 
    required this.status, 
    required this.timestamp
  });
}
