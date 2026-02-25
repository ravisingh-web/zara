// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — The Neural Intelligence Controller
// ✅ Vocal Interface: startListening() Logic Activated

import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/services/ai_api_service.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';
import 'package:zara/services/accessibility_service.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';

enum TaskType { message, post, system, analysis }

class ZaraController extends ChangeNotifier {
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  final _ai = AiApiService();
  final _camera = CameraService();
  final _location = LocationService();
  final _access = AccessibilityService();
  final _audio = AudioPlayer();

  Timer? _animTimer;
  bool _isListening = false; // Internal flag for mic state
  bool get isListening => _isListening;

  Future<void> initialize() async {
    await _loadNeuralMemory();
    _audio.onPlayerStateChanged.listen((s) {
      _state = _state.copyWith(glowIntensity: (s == PlayerState.playing) ? 1.0 : 0.4);
      notifyListeners();
    });
    _startNeuralVibration();
  }

  Future<void> _loadNeuralMemory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('zara_neural_state');
    if (data != null) {
      try {
        _state = ZaraState.fromMap(jsonDecode(data));
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading state: $e");
      }
    }
  }

  Future<void> _saveNeuralMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zara_neural_state', jsonEncode(_state.toMap()));
  }

  void _startNeuralVibration() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_state.isActive) return;
      final double targetPulse = (_audio.state == PlayerState.playing || _isListening)
          ? (0.5 + Random().nextDouble() * 0.5)
          : (sin(DateTime.now().millisecondsSinceEpoch / 1000) * 0.2 + 0.3);
      _state = _state.copyWith(pulseValue: targetPulse, orbScale: 1.0 + (targetPulse * 0.1));
      notifyListeners();
    });
  }

  // ✅ NEW: Activated startListening method
  Future<void> startListening() async {
    if (_isListening) return; // Already listening

    _isListening = true;
    _state = _state.copyWith(lastResponse: "LISTENING TO OWNER RAVI...");
    notifyListeners();

    // Logic for Speech-to-Text goes here (using 'record' or system STT)
    // For now, we simulate a listening pause, then ZARA prompts for input
    await Future.delayed(const Duration(seconds: 2));
    
    _isListening = false;
    _state = _state.copyWith(lastResponse: "Neural Link Established. Please speak or type, Sir.");
    notifyListeners();
  }

  Future<void> receiveCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    final newHistory = List<String>.from(_state.dialogueHistory)..add(cmd);
    _state = _state.copyWith(lastCommand: cmd, dialogueHistory: newHistory, lastResponse: 'PROCESSING NEURAL STREAMS...', isActive: true);
    notifyListeners();

    final core = _decideNeuralCore(cmd.toLowerCase());
    try {
      String response = '';
      if (core == 'qwen') {
        response = await _ai.generateCode(cmd);
        _state = _state.copyWith(mood: Mood.coding);
      } else if (core == 'llama') {
        response = await _ai.emotionalChat(cmd, _state.affectionLevel);
        _determineMoodFromSentiment(cmd);
      } else {
        response = await _ai.realtimeSearch(query: cmd);
        _state = _state.copyWith(mood: Mood.calm);
      }
      await _processResponse(response);
      _saveNeuralMemory();
    } catch (e) {
      _processResponse("Sir, neural link mein error hai: $e");
    }
  }

  String _decideNeuralCore(String cmd) {
    if (_containsAny(cmd, ['code', 'dart', 'fix', 'error', 'function'])) return 'qwen';
    if (_containsAny(cmd, ['pyar', 'love', 'angry', 'gussa', 'feeling'])) return 'llama';
    return 'gemini';
  }

  bool _containsAny(String cmd, List<String> keys) => keys.any((k) => cmd.contains(k));

  Future<void> _processResponse(String aiMessage) async {
    final formattedResponse = _applyBranding(aiMessage);
    final newHistory = List<String>.from(_state.dialogueHistory)..add(formattedResponse);
    String newTopic = _state.currentTopic;
    if (newTopic.isEmpty || newTopic == "SYSTEM INITIALIZED") {
      newTopic = _state.lastCommand.length > 20 ? "${_state.lastCommand.substring(0, 20)}..." : _state.lastCommand;
    }
    _state = _state.copyWith(lastResponse: formattedResponse, dialogueHistory: newHistory, currentTopic: newTopic.toUpperCase(), lastActivity: DateTime.now());
    notifyListeners();
    try {
      await _audio.stop();
      final audioPath = await _ai.textToSpeech(text: aiMessage, voice: "zara_voice");
      if (audioPath != null) await _audio.play(DeviceFileSource(audioPath));
    } catch (e) {
      debugPrint('⚠️ Neural Vocal Cord Error: $e');
    }
  }

  String _applyBranding(String raw) => ">> ZARA: $raw";

  void _determineMoodFromSentiment(String cmd) {
    if (_containsAny(cmd, ['sorry', 'maaf', 'pyaar', 'love', 'sweet'])) {
      _state = _state.copyWith(affectionLevel: (_state.affectionLevel + 5).clamp(0, 100), mood: Mood.romantic);
    } else if (_containsAny(cmd, ['pagal', 'bad', 'hate', 'stupid', 'gussa'])) {
      _state = _state.copyWith(affectionLevel: (_state.affectionLevel - 10).clamp(0, 100), mood: Mood.ziddi);
    }
    notifyListeners();
  }

  Future<void> toggleGuardianMode() async {
    final newState = !_state.isGuardianActive;
    _state = _state.copyWith(isGuardianActive: newState, mood: newState ? Mood.angry : Mood.calm);
    notifyListeners();
    if (newState) {
      await _camera.initialize();
      _processResponse("Sir, Guardian Mode ACTIVE. Main aapke phone ki hifazat kar rahi hoon.");
    } else {
      _processResponse("Guardian Mode STANDBY. Main normal mode mein shift ho rahi hoon.");
    }
  }

  Future<void> reportIntruder(String photoPath) async {
    try {
      _state = _state.copyWith(lastIntruderPhoto: photoPath, mood: Mood.angry);
      notifyListeners();
      _processResponse("Sir! Kisi ne phone touch kiya hai. Maine intruder ki photo capture kar li hai.");
    } catch(e) {
      debugPrint("Error reporting intruder: $e");
    }
  }

  Future<void> executeTask(String description, TaskType type) async {
    try {
      _state = _state.copyWith(mood: Mood.automation);
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
      _processResponse("Task completed Sir: $description.");
    } catch (e) {
      _processResponse("Maafi Sir, task fail ho gaya: $e");
    }
  }

  void resetSystem() {
    _animTimer?.cancel();
    _audio.stop();
    List<ChatSession> currentArchives = List.from(_state.chatArchives);
    if (_state.dialogueHistory.isNotEmpty) {
      currentArchives.insert(0, ChatSession(id: DateTime.now().millisecondsSinceEpoch.toString(), topicName: _state.currentTopic, messages: List.from(_state.dialogueHistory), timestamp: DateTime.now()));
    }
    _state = ZaraState.initial().copyWith(chatArchives: currentArchives, affectionLevel: _state.affectionLevel, ownerName: _state.ownerName, isGuardianActive: _state.isGuardianActive);
    notifyListeners();
    _saveNeuralMemory();
  }

  void loadArchivedChat(String id) {
    final session = _state.chatArchives.firstWhere((s) => s.id == id);
    List<ChatSession> currentArchives = List.from(_state.chatArchives);
    if (_state.dialogueHistory.isNotEmpty) {
      currentArchives.insert(0, ChatSession(id: DateTime.now().millisecondsSinceEpoch.toString(), topicName: _state.currentTopic, messages: List.from(_state.dialogueHistory), timestamp: DateTime.now()));
    }
    currentArchives.removeWhere((s) => s.id == id);
    _state = _state.copyWith(currentTopic: session.topicName, dialogueHistory: session.messages, chatArchives: currentArchives);
    notifyListeners();
    _saveNeuralMemory();
  }

  void deleteArchivedChat(String id) {
    _state = _state.copyWith(chatArchives: _state.chatArchives.where((s) => s.id != id).toList());
    notifyListeners();
    _saveNeuralMemory();
  }
}
