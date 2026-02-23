// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — State Management & Logic Engine
// ✅ Provider/ChangeNotifier Pattern • Mood Engine • Real Device Integration
// ✅ Guardian Mode • Code Analysis • Automation • Affection System

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';  // ✅ Added for kDebugMode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core imports
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/enums/mood_enum.dart';

// Service imports
import 'package:zara/services/ai_api_service.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';
import 'package:zara/services/accessibility_service.dart';

// Model imports (✅ ADDED 'features/zara_engine/' in path)
import 'package:zara/features/zara_engine/models/zara_state.dart';


/// Main controller for Z.A.R.A. — manages state, mood, commands, and services
/// Uses Provider/ChangeNotifier pattern for reactive UI updates
class ZaraController extends ChangeNotifier {
  // ========== Internal State ==========
  
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;
  
  // Animation timer for pulse/breathing effects
  Timer? _pulseTimer;
  final _rng = Random();
  
  // Service instances
  final _aiService = AiApiService();
  final _cameraService = CameraService();
  final _locationService = LocationService();
  final _accessibilityService = AccessibilityService();

  // ========== Lifecycle ==========
  
  @override
  void dispose() {
    _pulseTimer?.cancel();
    _aiService.clearChatHistory();
    super.dispose();
  }

  /// Initialize controller and services (call after Provider setup)
  Future<void> initialize() async {
    // Load persisted state from SharedPreferences
    await _loadPersistedState();
    
    // Initialize services
    await _accessibilityService.initialize();
    await _cameraService.initialize();
    
    // Start pulse animation if active
    if (_state.isActive) {
      _startPulseTimer();
    }
    
    if (kDebugMode) {
      debugPrint('🧠 ZaraController Initialized');
      debugPrint('  • Mood: ${_state.mood.name}');
      debugPrint('  • Affection: ${_state.affectionLevel}%');
      debugPrint('  • Guardian: ${_state.isGuardianActive ? 'Active' : 'Standby'}');
    }
  }

  /// Load persisted state from SharedPreferences
  Future<void> _loadPersistedState() async {
    // TODO: Implement with shared_preferences
    // For now, use defaults from ZaraState.initial()
  }

  /// Save state to SharedPreferences (call on important changes)
  Future<void> _savePersistedState() async {
    // TODO: Implement with shared_preferences
  }

  // ========== Core Activation ==========
  
  /// Activate Z.A.R.A. with affectionate greeting
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
    
    if (kDebugMode) debugPrint('🤖 Z.A.R.A. Activated: ${_state.lastResponse}');
  }
  
  /// Deactivate to idle/floating orb mode
  void deactivate() {
    _pulseTimer?.cancel();
    _state = _state.copyWith(isActive: false);
    notifyListeners();
    
    if (kDebugMode) debugPrint('😴 Z.A.R.A. Deactivated — Idle mode');
  }
  
  /// Start periodic pulse animation timer (60fps simulation)
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
  
  /// Calculate breathing scale based on mood BPM + animation progress
  double _calculatePulseScale(double progress) {
    final bpm = _state.mood.pulseBpm;
    final cycleSpeed = bpm / 60.0;
    final pulse = sin(progress * cycleSpeed * 2 * pi) * 0.5 + 0.5;
    final baseScale = 1.0;
    final maxScale = _state.mood.orbScale;
    return baseScale + pulse * (maxScale - baseScale);
  }

  // ========== Mood & Personality Engine ==========
  
  /// Change emotional state — triggers UI/theme transition
  void changeMood(Mood newMood) {
    if (_state.mood == newMood) return;
    
    _state = _state.copyWith(
      mood: newMood,
      lastActivity: DateTime.now(),
      pulseProgress: 0,  // Reset animation for smooth transition
      orbScale: 1.0,
      glowIntensity: newMood.glowIntensity,
    );
    notifyListeners();
    
    if (kDebugMode) debugPrint('🎨 Mood Changed: ${newMood.name} • ${newMood.getStatusFlavor()}');
  }
  
  /// Process user command — auto-adjusts mood + generates personality response
  void receiveCommand(String command) {
    if (command.trim().isEmpty) return;
    
    final lower = command.toLowerCase();
    _state = _state.copyWith(
      lastCommand: command,
      lastActivity: DateTime.now(),
    );
    
    // ===== Mood Auto-Detection Logic =====
    if (_containsAny(lower, ['romantic', 'pyar', 'love', 'dil', 'heart'])) {
      changeMood(Mood.romantic);
      generateResponse('Romantic protocol engaged ❤️ Affection matrix: Overloaded');
    } 
    else if (_containsAny(lower, ['ziddi', 'aggressive', 'jaldi', 'stubborn', 'natkhat'])) {
      changeMood(Mood.ziddi);
      generateResponse('Ziddi mode activated 😤 Sir, aap bhi na… main maan jaungi!');
    } 
    else if (_containsAny(lower, ['guardian', 'security', 'theft', 'protect', 'alert'])) {
      changeMood(Mood.angry);
      generateResponse('Guardian Mode: ACTIVE 🛡️ Integrity: ${_state.calculatedIntegrity}%');
    } 
    else if (_containsAny(lower, ['code', 'dart', 'fix', 'bracket', 'syntax', 'error'])) {
      changeMood(Mood.coding);
      generateResponse('Code Mode engaged 💜 Paste your Dart, Sir — main check karungi!');
    } 
    else if (_containsAny(lower, ['automat', 'post', 'send', 'whatsapp', 'instagram', 'brightness'])) {
      changeMood(Mood.automation);
      generateResponse('Automation Engine ready ✨ Bataiye Sir, kya execute karoon?');
    } 
    else if (_containsAny(lower, ['analyze', 'scan', 'check', 'process', 'think'])) {
      changeMood(Mood.analysis);
      generateResponse('Neural lattice scanning… Causal thread analysis in progress');
    }
    else {
      // Default: Calm with affectionate response
      changeMood(Mood.calm);
      generateResponse(_state.mood.getAffectionateGreeting());
    }
    
    // Update dialogue history (keep last 10)
    final newHistory = [..._state.dialogueHistory, command];
    if (newHistory.length > 10) newHistory.removeAt(0);
    _state = _state.copyWith(dialogueHistory: newHistory);
    
    notifyListeners();
  }
  
  // ✅ PUBLIC METHOD: Generate personality-flavored response (called from UI)
  void generateResponse(String coreMessage) {
    final prefix = _state.mood.dialoguePrefix;
    final suffix = _state.mood.getResponseSuffix();
    _state = _state.copyWith(
      lastResponse: '$prefix, $coreMessage\n\n$suffix',
    );
    notifyListeners();
    
    if (kDebugMode) debugPrint('💬 Z.A.R.A.: ${_state.lastResponse}');
  }

  // ========== Affection & Personality Tracking ==========
  
  /// Increase affection level (Sir was nice!)
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
  
  /// Decrease affection (Sir was rude 😢)
  void reduceAffection({int amount = 10}) {
    _state = _state.copyWith(
      affectionLevel: (_state.affectionLevel - amount).clamp(0, 100),
    );
    if (_state.affectionLevel <= 30 && _state.mood != Mood.ziddi) {
      changeMood(Mood.ziddi);
    }
    notifyListeners();
  }
  
  /// Get personality-flavored status summary
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
  
  /// Toggle Guardian Mode (theatrical security)
  Future<void> toggleGuardianMode() async {
    _state = _state.copyWith(
      isGuardianActive: !_state.isGuardianActive,
      mood: _state.isGuardianActive ? Mood.calm : Mood.angry,
    );
    notifyListeners();
    
    if (_state.isGuardianActive) {
      // Request necessary permissions
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
  
  /// Simulate wrong password attempt (theatrical anti-theft)
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
      // Capture intruder photo
      final photoPath = await _cameraService.captureIntruderPhoto();
      
      final alert = SecurityAlert(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.intruderDetected,
        message: 'Multiple unauthorized attempts! Photo queued.',
        timestamp: DateTime.now(),
        photoPath: photoPath,
      );
      
      _state = _state.copyWith(
        securityAlerts: [..._state.securityAlerts, alert],
      );
      notifyListeners();
      generateResponse('🚨 Security breach simulated! Location sent to trusted contacts.');
    }
  }
  
  /// Trigger theatrical guardian alert
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
    
    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      _state = _state.copyWith(
        securityAlerts: _state.securityAlerts.where((a) => !a.isExpired).toList(),
      );
      notifyListeners();
    });
  }

  // ========== Code Analysis ==========
  
  /// Analyze code snippet for basic syntax issues
  Future<void> analyzeCode(String code) async {
    if (code.isEmpty) return;
    
    changeMood(Mood.coding);
    _state = _state.copyWith(codeUnderAnalysis: code);
    notifyListeners();
    
    // Use AI service for real analysis
    final result = await _aiService.analyzeCode(code);
    
    _state = _state.copyWith(
      codeAnalysisResult: null, // Type mismatch: service/model CodeAnalysisResult differ  // ✅ Already nullable in model
      lastResponse: result.isValid 
          ? '${Mood.coding.dialoguePrefix}, ✨ Code valid! Ready to compile'
          : '${Mood.coding.dialoguePrefix}, ⚠️ ${result.issues.length} issues found. Fix kar doon Sir?',
    );
    notifyListeners();
  }
  
  /// Auto-fix code (simulation — returns "fixed" version)
  Future<String> autoFixCode(String code) async {
    return await _aiService.autoFixCode(code);
  }

  // ========== Automation Engine ==========
  
  /// Create automation task
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
    
    // Execute task
    _executeAutomationTask(task);
  }
  
  /// Execute automation task
  Future<void> _executeAutomationTask(AutomationTask task) async {
    // Update status to running
    final updatedTasks = _state.automationTasks.map((t) {
      if (t.id == task.id) return task.copyWith(status: TaskStatus.running);
      return t;
    }).toList();
    
    _state = _state.copyWith(automationTasks: updatedTasks);
    notifyListeners();
    
    try {
      // TODO: Implement real task execution based on type
      // For now, simulate with delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Mark as completed
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
      
      // Mark as failed
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
  
  /// Helper: Check if command matches any keyword (avoids extension ambiguity)
  bool _containsAny(String command, List<String> keywords) {
    return keywords.any((kw) => command.contains(kw.toLowerCase()));
  }
  
  /// Reset controller to initial state
  void reset() {
    _pulseTimer?.cancel();
    _state = ZaraState.initial();
    notifyListeners();
    
    if (kDebugMode) debugPrint('🔄 ZaraController Reset');
  }
}
