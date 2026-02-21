// lib/features/zara_engine/models/zara_state.dart
// Z.A.R.A. — State Model

import '../../../core/enums/mood_enum.dart';

class ZaraState {
  final bool isActive;
  final Mood mood;
  final String lastCommand;
  final String lastResponse;
  final DateTime lastActivity;
  final double pulseProgress;
  final double orbScale;
  final double glowIntensity;
  final int affectionLevel;

  const ZaraState({
    required this.isActive,
    required this.mood,
    required this.lastCommand,
    required this.lastResponse,
    required this.lastActivity,
    required this.pulseProgress,
    required this.orbScale,
    required this.glowIntensity,
    required this.affectionLevel,
  });

  factory ZaraState.initial() => ZaraState(
    isActive: false,
    mood: Mood.calm,
    lastCommand: '',
    lastResponse: '',
    lastActivity: DateTime.now(),
    pulseProgress: 0,
    orbScale: 1.0,
    glowIntensity: 0.3,
    affectionLevel: 75,
  );

  ZaraState copyWith({
    bool? isActive,
    Mood? mood,
    String? lastCommand,
    String? lastResponse,
    DateTime? lastActivity,
    double? pulseProgress,
    double? orbScale,
    double? glowIntensity,
    int? affectionLevel,
  }) {
    return ZaraState(
      isActive: isActive ?? this.isActive,
      mood: mood ?? this.mood,
      lastCommand: lastCommand ?? this.lastCommand,
      lastResponse: lastResponse ?? this.lastResponse,
      lastActivity: lastActivity ?? this.lastActivity,
      pulseProgress: pulseProgress ?? this.pulseProgress,
      orbScale: orbScale ?? this.orbScale,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      affectionLevel: affectionLevel ?? this.affectionLevel,
    );
  }
}
