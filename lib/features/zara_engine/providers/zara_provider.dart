// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — State Management
// ✅ Fixed: Correct import paths

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/enums/mood_enum.dart';


class ZaraController extends ChangeNotifier {
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;
  
  Timer? _pulseTimer;

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  void activate() {
    final greeting = _state.mood.getAffectionateGreeting();
    _state = _state.copyWith(
      isActive: true,
      lastResponse: '${_state.mood.dialoguePrefix}, $greeting',
      lastActivity: DateTime.now(),
      affectionLevel: (_state.affectionLevel + 2).clamp(0, 100),
    );
    _startPulseTimer();
    notifyListeners();
  }

  void deactivate() {
    _pulseTimer?.cancel();
    _state = _state.copyWith(isActive: false);
    notifyListeners();
  }

  void _startPulseTimer() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final progress = (_state.pulseProgress + 0.05) % 1.0;
      final scale = _calculatePulseScale(progress);
      _state = _state.copyWith(
        pulseProgress: progress,
        orbScale: scale,
        glowIntensity: _state.mood.glowIntensity * (0.8 + progress * 0.4),
      );
      notifyListeners();
    });
  }

  double _calculatePulseScale(double progress) {
    final bpm = _state.mood.pulseBpm;
    final cycleSpeed = bpm / 60.0;
    final pulse = sin(progress * cycleSpeed * 2 * pi) * 0.5 + 0.5;
    final baseScale = 1.0;
    final maxScale = _state.mood.orbScale;
    return baseScale + pulse * (maxScale - baseScale);
  }

  void changeMood(Mood newMood) {
    if (_state.mood == newMood) return;
    _state = _state.copyWith(
      mood: newMood,
      lastActivity: DateTime.now(),
      pulseProgress: 0,
      orbScale: 1.0,
      glowIntensity: newMood.glowIntensity,
    );
    notifyListeners();
  }

  void receiveCommand(String command) {
    if (command.trim().isEmpty) return;
    final lower = command.toLowerCase();
    _state = _state.copyWith(lastCommand: command, lastActivity: DateTime.now());
    
    if (lower.contains('romantic') || lower.contains('pyar')) {
      changeMood(Mood.romantic);
    } else if (lower.contains('ziddi') || lower.contains('aggressive')) {
      changeMood(Mood.ziddi);
    } else if (lower.contains('guardian') || lower.contains('security')) {
      changeMood(Mood.angry);
    } else if (lower.contains('code') || lower.contains('dart')) {
      changeMood(Mood.coding);
    } else {
      changeMood(Mood.calm);
    }
    notifyListeners();
  }

  Future<void> updateStorageMetrics() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Storage logic here
    } catch (e) {
      debugPrint('Storage error: $e');
    }
  }
}

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
