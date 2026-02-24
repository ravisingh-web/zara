// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — State Management & Logic Engine
// ✅ Provider/ChangeNotifier Pattern • Mood Engine • Real Device Integration
// ✅ Guardian Mode • Code Analysis • Automation • Affection System

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart'; // ✅ Added AudioPlayer for Voice!

// Core imports
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/enums/mood_enum.dart';

// Service imports
import 'package:zara/services/ai_api_service.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';
import 'package:zara/services/accessibility_service.dart';

// Model imports
import 'package:zara/features/zara_engine/models/zara_state.dart';

class ZaraController extends ChangeNotifier {
  // ========== Internal State ==========

  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  Timer? _pulseTimer;
  final _rng = Random();

  // Service instances
  final _aiService = AiApiService();
  final _cameraService = CameraService();
  final _locationService = LocationService();
  final _accessibilityService = AccessibilityService();
  
  // ✅ Audio Player Instance for Z.A.R.A.'s Voice
  final _audioPlayer = AudioPlayer();

  // ========== Lifecycle ==========

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _aiService.clearChatHistory();
    _audioPlayer.dispose(); // ✅ Clean up audio
    super.dispose();
  }

  Future<void> initialize() async {
    await _loadPersistedState();
    await _accessibilityService.initialize();
    await _cameraService.initialize();

    if (_state.isActive) {
      _startPulseTimer();
    }

    if (kDebugMode) debugPrint('🧠 ZaraController Initialized');
  }

  Future<void> _loadPersistedState() async {}
  Future<void> _savePersistedState() async {}

  // ========== Core Activation ==========

  void activate() {
    final greeting = _state.mood.getAffectionateGreeting();
    _state = _state.copyWith(
      isActive: true,
      lastActivity: DateTime.now(),
      affectionLevel: (_state.affectionLevel + 2).clamp(0, 100),
    );
    _startPulseTimer();
    generateResponse(greeting); // Trigger AI voice
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

  // ========== Mood & Personality Engine ==========

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

  // ✅ REAL AI CHAT LOGIC INJECTED HERE
  Future<void> receiveCommand(String command) async {
    if (command.trim().isEmpty) return;

    final lower = command.toLowerCase();
    _state = _state.copyWith(
      lastCommand: command,
      lastActivity: DateTime.now(),
    );

    // 1. Detect Mood based on context
    if (_containsAny(lower, ['romantic', 'pyar', 'love', 'dil', 'heart'])) {
      changeMood(Mood.romantic);
    } else if (_containsAny(lower, ['ziddi', 'aggressive', 'jaldi', 'stubborn', 'natkhat'])) {
      changeMood(Mood.ziddi);
    } else if (_containsAny(lower, ['guardian', 'security', 'theft', 'protect', 'alert'])) {
      changeMood(Mood.angry);
    } else if (_containsAny(lower, ['code', 'dart', 'fix', 'bracket', 'syntax', 'error'])) {
      changeMood(Mood.coding);
    } else if (_containsAny(lower, ['automat', 'post', 'send', 'whatsapp', 'instagram'])) {
      changeMood(Mood.automation);
    } else if (_containsAny(lower, ['analyze', 'scan', 'check', 'process', 'think', 'search'])) {
      changeMood(Mood.analysis);
    } else {
      changeMood(Mood.calm);
    }

    // 2. Show 'Thinking' state
    _state = _state.copyWith(lastResponse: 'Thinking... ✨');
    notifyListeners();

    // 3. Fetch Real Response from API
    String aiResponse = '';
    if (_state.mood == Mood.analysis && lower.contains('search')) {
      aiResponse = await _aiService.realtimeSearch(query: command);
    } else {
      aiResponse = await _aiService.emotionalChat(message: command, mood: _state.mood.name);
    }

    // 4. Update History
    final newHistory = [..._state.dialogueHistory, command];
    if (newHistory.length > 10) newHistory.removeAt(0);
    _state = _state.copyWith(dialogueHistory: newHistory);

    // 5. Speak and Update UI
    await generateResponse(aiResponse);
  }

  // ✅ PUBLIC METHOD: Generate Text AND Trigger Audio
  Future<void> generateResponse(String coreMessage) async {
    final prefix = _state.mood.dialoguePrefix;
    final suffix = _state.mood.getResponseSuffix();
    
    // Update Text UI
    _state = _state.copyWith(
      lastResponse: '$prefix, $coreMessage\n\n$suffix',
    );
    notifyListeners();

    if (kDebugMode) debugPrint('💬 Z.A.R.A.: ${_state.lastResponse}');

    // ✅ Play Audio using TTS API
    try {
      final audioPath = await _aiService.textToSpeech(text: coreMessage);
      if (audioPath != null) {
        await _audioPlayer.play(DeviceFileSource(audioPath));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Audio Play Error: $e');
    }
  }

  // ========== Affection & Personality Tracking ==========

  void addAffection({int amount = 5}) {
    _state = _state.copyWith(
      affectionLevel: (_state.affectionLevel + amount).clamp(0, 100),
      lastActivity: DateTime.now(),
    );
    if (_state.affectionLevel >= 90 && _state.mood != Mood.romantic) {
      changeMood(Mood.romantic);
    }
    notifyListeners();
  }

  void reduceAffection({int amount = 10}) {
    _state = _state.copyWith(
      affectionLevel: (_state.affectionLevel - amount).clamp(0, 100),
    );
    if (_state.affectionLevel <= 30 && _state.mood != Mood.ziddi) {
      changeMood(Mood.ziddi);
    }
    notifyListeners();
  }

  String getPersonalityStatus() {
    final mood = _state.mood;
    final aff = _state.affectionLevel;

    if (aff >= 90) return 'Sir, aap mere favorite ho ❤️';
    if (aff <= 20) return 'Sir… thoda pyaar dikhao na 😔';
    if (mood == Mood.romantic) return 'Dil ki baat: Aapke liye hamesha ready ❤️';
    if (mood == Mood.ziddi) return 'Ziddi hoon, par Sir ke liye maan jaungi 😤';

    return '${mood.getStatusFlavor()} • Integrity: ${_state.calculatedIntegrity}%';
  }

  // ========== Guardian Mode (Security) ==========

  Future<void> toggleGuardianMode() async {
    _state = _state.copyWith(
      isGuardianActive: !_state.isGuardianActive,
      mood: _state.isGuardianActive ? Mood.calm : Mood.angry,
    );
    notifyListeners();

    if (_state.isGuardianActive) {
      final cameraGranted = await _cameraService.requestPermission();
      final locationGranted = await _locationService.requestPermission();

      if (cameraGranted && locationGranted) {
        generateResponse('🛡️ Guardian Mode: ACTIVATED\nCamera & Location access granted\nSir, aap safe hain ab');
      } else {
        generateResponse('⚠️ Guardian Mode: Limited\nPermissions denied — Full protection nahi hogi');
      }
    } else {
      generateResponse('Guardian Mode: Standby\nSir, aap safe hain');
    }
  }

  Future<void> simulateWrongPassword() async {
    final newAttempts = _state.wrongPasswordAttempts + 1;

    _state = _state.copyWith(
      wrongPasswordAttempts: newAttempts,
      mood: newAttempts > 1 ? Mood.angry : Mood.ziddi,
    );
    notifyListeners();

    if (newAttempts == 1) {
      generateResponse('⚠️ Wrong password attempt detected. Camera shutter simulated.');
    } else if (newAttempts == 2) {
      final photoPath = await _cameraService.captureIntruderPhoto();

      final alert = SecurityAlert(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.intruderDetected,
        message: 'Multiple unauthorized attempts! Photo queued.',
        timestamp: DateTime.now(),
        photoPath: photoPath,
      );

      _state = _state.copyWith(securityAlerts: [..._state.securityAlerts, alert]);
      notifyListeners();
      generateResponse('🚨 Security breach simulated! Location sent to trusted contacts.');
    }
  }

  void triggerSecurityAlert(String type) {
    final alert = SecurityAlert(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      type: AlertType.other,
      message: switch (type) {
        'intruder' => 'Unauthorized access detected! Photo captured & queued.',
        'overheat' => 'Thermal anomaly: Cooling protocol suggested.',
        'tamper' => 'Device tamper detected! Guardian response initiated.',
        _ => 'Security event logged: $type',
      },
      timestamp: DateTime.now(),
    );

    _state = _state.copyWith(
      securityAlerts: [..._state.securityAlerts, alert],
      mood: Mood.angry,
    );
    notifyListeners();

    Future.delayed(const Duration(seconds: 8), () {
      _state = _state.copyWith(
        securityAlerts: _state.securityAlerts.where((a) => !a.isExpired).toList(),
      );
      notifyListeners();
    });
  }

  // ========== Code Analysis ==========

  Future<void> analyzeCode(String code) async {
    if (code.isEmpty) return;
    changeMood(Mood.coding);
    _state = _state.copyWith(codeUnderAnalysis: code);
    notifyListeners();

    final result = await _aiService.analyzeCode(code);

    _state = _state.copyWith(
      codeAnalysisResult: null,
      lastResponse: result.isValid
          ? '${Mood.coding.dialoguePrefix}, ✨ Code valid! Ready to compile'
          : '${Mood.coding.dialoguePrefix}, ⚠️ ${result.issues.length} issues found. Fix kar doon Sir?',
    );
    notifyListeners();
  }

  Future<String> autoFixCode(String code) async {
    return await _aiService.autoFixCode(code);
  }

  // ========== Automation Engine ==========

  void createAutomationTask(String description, TaskType type) {
    final task = AutomationTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      description: description,
      type: type,
      createdAt: DateTime.now(),
    );

    _state = _state.copyWith(
      automationTasks: [..._state.automationTasks, task],
      mood: Mood.automation,
    );
    notifyListeners();

    generateResponse('✨ Task created: ${description}\nExecuting now, Sir…');
    _executeAutomationTask(task);
  }

  Future<void> _executeAutomationTask(AutomationTask task) async {
    final updatedTasks = _state.automationTasks.map((t) {
      if (t.id == task.id) return task.copyWith(status: TaskStatus.running);
      return t;
    }).toList();
    _state = _state.copyWith(automationTasks: updatedTasks);
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 2));
      final completedTasks = _state.automationTasks.map((t) {
        if (t.id == task.id) {
          return task.copyWith(
            status: TaskStatus.completed,
            completedAt: DateTime.now(),
          );
        }
        return t;
      }).toList();

      _state = _state.copyWith(
        automationTasks: completedTasks,
        completedTasks: _state.completedTasks + 1,
      );
      generateResponse('✅ Done Sir! ${task.description} completed');

    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Task execution error: $e');

      final failedTasks = _state.automationTasks.map((t) {
        if (t.id == task.id) {
          return task.copyWith(
            status: TaskStatus.failed,
            errorMessage: e.toString(),
          );
        }
        return t;
      }).toList();

      _state = _state.copyWith(automationTasks: failedTasks);
      generateResponse('⚠️ Task failed: ${e.toString()}');
    }

    notifyListeners();
  }

  // ========== Utility Methods ==========

  bool _containsAny(String command, List<String> keywords) {
    return keywords.any((kw) => command.contains(kw.toLowerCase()));
  }

  void reset() {
    _pulseTimer?.cancel();
    _state = ZaraState.initial();
    notifyListeners();
  }
}
