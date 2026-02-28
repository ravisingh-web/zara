// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — The Neural Intelligence Controller
// ✅ Clean • Minimal • Compiles • Logic Same • Package Imports

import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/services/ai_api_service.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';
import 'package:zara/services/accessibility_service.dart';
import 'package:zara/services/email_service.dart';

import 'package:zara/features/zara_engine/models/zara_state.dart';

enum TaskType { message, post, system, analysis }

class ZaraController extends ChangeNotifier {
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  final _ai = AiApiService();
  final _camera = CameraService();
  final _location = LocationService();
  final _access = AccessibilityService();
  final _email = EmailService();

  Timer? _animTimer;
  bool _isListening = false;
  bool get isListening => _isListening;

  Future<void> initialize() async {
    await _loadNeuralMemory();
    await _email.initialize();
    _startNeuralVibration();
  }

  Future<void> _loadNeuralMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('zara_neural_state');
      if (data != null) {
        _state = ZaraState.fromMap(jsonDecode(data));        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveNeuralMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zara_neural_state', jsonEncode(_state.toMap()));
    } catch (_) {}
  }

  void _startNeuralVibration() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_state.isActive) return;
      final targetPulse = _isListening
          ? (0.5 + Random().nextDouble() * 0.5)
          : (sin(DateTime.now().millisecondsSinceEpoch / 1000) * 0.2 + 0.3);
      _state = _state.copyWith(
        pulseValue: targetPulse,
        orbScale: 1.0 + (targetPulse * 0.1),
      );
      notifyListeners();
    });
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;
    _state = _state.copyWith(
      lastResponse: "🎤 Listening...",
      isActive: true,
    );
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _isListening = false;
    _state = _state.copyWith(
      lastResponse: "Type your command, Sir.",
    );
    notifyListeners();
  }

  Future<void> receiveCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    final newHistory = List<String>.from(_state.dialogueHistory)..add(cmd);
    _state = _state.copyWith(
      lastCommand: cmd,
      dialogueHistory: newHistory.length > 20
          ? newHistory.sublist(newHistory.length - 20)          : newHistory,
      lastResponse: '🔄 Processing...',
      isActive: true,
      lastActivity: DateTime.now(),
    );
    notifyListeners();

    try {
      String response = '';
      if (_isCodeCommand(cmd)) {
        _state = _state.copyWith(mood: Mood.coding);
        notifyListeners();
        response = await _ai.generateCode(cmd);
      } else if (_isChatCommand(cmd)) {
        _determineMoodFromSentiment(cmd);
        response = await _ai.emotionalChat(cmd, _state.affectionLevel);
      } else {
        _state = _state.copyWith(mood: Mood.calm);
        notifyListeners();
        response = await _ai.generalQuery(cmd, useSearch: _needsSearch(cmd));
      }
      await _processResponse(response);
      await _saveNeuralMemory();
    } catch (e) {
      await _processResponse("⚠️ Error: ${e.toString().substring(0, 50)}");
    }
  }

  bool _isCodeCommand(String cmd) =>
      cmd.toLowerCase().contains('code') ||
      cmd.toLowerCase().contains('dart') ||
      cmd.toLowerCase().contains('flutter');

  bool _isChatCommand(String cmd) =>
      cmd.toLowerCase().contains('pyar') ||
      cmd.toLowerCase().contains('love') ||
      cmd.toLowerCase().contains('hello');

  bool _needsSearch(String cmd) =>
      cmd.toLowerCase().contains('search') ||
      cmd.toLowerCase().contains('news') ||
      cmd.toLowerCase().contains('weather');

  Future<void> _processResponse(String aiMessage) async {
    final formatted = ">> Z.A.R.A.: $aiMessage";
    final newHistory = List<String>.from(_state.dialogueHistory)..add(formatted);
    final trimmed = newHistory.length > 20
        ? newHistory.sublist(newHistory.length - 20)
        : newHistory;
    _state = _state.copyWith(      lastResponse: formatted,
      dialogueHistory: trimmed,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
  }

  void _determineMoodFromSentiment(String cmd) {
    final lower = cmd.toLowerCase();
    if (lower.contains('pyar') ||
        lower.contains('love') ||
        lower.contains('thank')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel + 5).clamp(0, 100),
        mood: Mood.romantic,
      );
    } else if (lower.contains('gussa') ||
        lower.contains('angry') ||
        lower.contains('bad')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel - 10).clamp(0, 100),
        mood: Mood.ziddi,
      );
    }
    notifyListeners();
  }

  Future<void> toggleGuardianMode() async {
    final newState = !_state.isGuardianActive;
    _state = _state.copyWith(
      isGuardianActive: newState,
      mood: newState ? Mood.angry : Mood.calm,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
    await _saveNeuralMemory();

    if (newState) {
      final camOk = await _camera.checkPermission();
      final locOk = await _location.checkPermission();
      if (camOk && locOk) {
        await _camera.initializeFrontCamera();
        await _location.startTracking();
        await _processResponse("🛡️ Guardian ACTIVE");
      } else {
        await _processResponse("⚠️ Permissions needed");
      }
    } else {
      await _location.stopTracking();
      await _processResponse("Guardian STANDBY");    }
  }

  Future<void> reportIntruder(String photoPath) async {
    try {
      _state = _state.copyWith(
        lastIntruderPhoto: photoPath,
        mood: Mood.angry,
        lastActivity: DateTime.now(),
      );
      notifyListeners();
      await _saveNeuralMemory();

      final loc = await _location.getCurrentLocation();
      final link = loc != null ? _location.getGoogleMapsLink() : null;
      await _email.sendIntruderAlert(
        photoPath: photoPath,
        locationLink: link,
        address: _location.getFormattedAddress(),
      );
      await _processResponse("🚨 Alert sent!");
    } catch (_) {
      await _processResponse("⚠️ Alert failed");
    }
  }

  Future<void> executeTask(String description, TaskType type) async {
    try {
      _state = _state.copyWith(
        mood: Mood.automation,
        lastActivity: DateTime.now(),
      );
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      await _processResponse("✅ Task: $description");
      await _saveNeuralMemory();
    } catch (_) {
      await _processResponse("⚠️ Task failed");
    }
  }

  // ========== Archive Methods ==========
  void reset() {
    _animTimer?.cancel();
    final archives = List<ChatSession>.from(_state.chatArchives ?? []);
    if (_state.dialogueHistory.isNotEmpty) {
      archives.insert(
        0,
        ChatSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),          topicName: _state.lastCommand.isEmpty
              ? 'Untitled'
              : _state.lastCommand.substring(0, 20),
          messages: List<String>.from(_state.dialogueHistory),
          timestamp: DateTime.now(),
        ),
      );
      if (archives.length > 10) archives.removeRange(10, archives.length);
    }
    _state = ZaraState.initial().copyWith(
      chatArchives: archives,
      affectionLevel: _state.affectionLevel,
      ownerName: _state.ownerName,
      isGuardianActive: _state.isGuardianActive,
    );
    notifyListeners();
    _saveNeuralMemory();
  }

  void loadArchivedChat(String id) {
    final archives = _state.chatArchives ?? [];
    final session = archives.firstWhere(
      (s) => s.id == id,
      orElse: () => ChatSession(
        id: '',
        topicName: '',
        messages: [],
        timestamp: DateTime.now(),
      ),
    );
    if (session.messages.isEmpty) return;

    final current = List<ChatSession>.from(archives);
    if (_state.dialogueHistory.isNotEmpty) {
      current.insert(
        0,
        ChatSession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          topicName: _state.lastResponse.substring(0, 20),
          messages: List<String>.from(_state.dialogueHistory),
          timestamp: DateTime.now(),
        ),
      );
    }
    current.removeWhere((s) => s.id == id);

    _state = _state.copyWith(
      dialogueHistory: List<String>.from(session.messages),
      lastResponse:
          session.messages.isNotEmpty ? session.messages.last : 'Loaded',      lastActivity: DateTime.now(),
      chatArchives: current,
    );
    notifyListeners();
    _saveNeuralMemory();
  }

  void deleteArchivedChat(String id) {
    _state = _state.copyWith(
      chatArchives: (_state.chatArchives ?? [])
          .where((s) => s.id != id)
          .toList(),
    );
    notifyListeners();
    _saveNeuralMemory();
  }

  // ========== Utility Methods ==========
  void activate() {
    _state = _state.copyWith(
      isActive: true,
      lastActivity: DateTime.now(),
      affectionLevel: (_state.affectionLevel + 2).clamp(0, 100),
    );
    _startNeuralVibration();
    notifyListeners();
  }

  void deactivate() {
    _animTimer?.cancel();
    _state = _state.copyWith(isActive: false);
    notifyListeners();
  }

  void changeMood(Mood newMood) {
    if (_state.mood == newMood) return;
    _state = _state.copyWith(
      mood: newMood,
      lastActivity: DateTime.now(),
      pulseValue: 0,
      orbScale: 1.0,
    );
    notifyListeners();
  }

  void addAffection({int amount = 5}) {
    _state = _state.copyWith(
      affectionLevel: (_state.affectionLevel + amount).clamp(0, 100),
      lastActivity: DateTime.now(),
    );    if (_state.affectionLevel >= 90 && _state.mood != Mood.romantic) {
      changeMood(Mood.romantic);
    }
    notifyListeners();
  }

  void generateResponse(String message) {
    _state = _state.copyWith(
      lastResponse: message,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _camera.dispose();
    _location.dispose();
    super.dispose();
  }
}
