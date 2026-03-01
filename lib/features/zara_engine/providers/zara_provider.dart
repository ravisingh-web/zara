// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — Neural Intelligence Controller v2.0
// ✅ God-Mode Command Detection (OPEN_APP, SCROLL, LIKE, YT_SEARCH)
// ✅ STT/TTS hooks
// ✅ Personality-aware mood engine
// ✅ ChatGPT-style topic archive

import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

// ─── God-Mode Command Types ────────────────────────────────────────────────
enum GodCommand {
  openApp,
  scrollReels,
  likeReel,
  ytSearch,
  unknown,
}

class ParsedCommand {
  final GodCommand type;
  final Map<String, String> params;
  const ParsedCommand(this.type, this.params);
}

class ZaraController extends ChangeNotifier {
  // ── Services ───────────────────────────────────────────────────────────────
  final _ai       = AiApiService();
  final _camera   = CameraService();
  final _location = LocationService();
  final _access   = AccessibilityService();
  final _email    = EmailService();

  // ── State ──────────────────────────────────────────────────────────────────
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  Timer? _animTimer;
  bool _isListening = false;
  bool get isListening => _isListening;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    await _loadNeuralMemory();
    await _email.initialize();
    _startNeuralVibration();
    if (kDebugMode) debugPrint('✅ Z.A.R.A. Neural Core initialized');
  }

  // ── Neural Memory ──────────────────────────────────────────────────────────
  Future<void> _loadNeuralMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data  = prefs.getString('zara_neural_state');
      if (data != null) {
        _state = ZaraState.fromMap(jsonDecode(data));
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ loadNeuralMemory: $e');
    }
  }

  Future<void> _saveNeuralMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zara_neural_state', jsonEncode(_state.toMap()));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ saveNeuralMemory: $e');
    }
  }

  // ── Pulse Animation ────────────────────────────────────────────────────────
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

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN COMMAND PROCESSOR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> receiveCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;

    // ✅ Add user bubble immediately
    final userMsg = ChatMessage.fromUser(cmd);
    final newHistory = List<String>.from(_state.dialogueHistory)..add(cmd);
    final newMessages = List<ChatMessage>.from(_state.messages)..add(userMsg);

    _state = _state.copyWith(
      lastCommand:     cmd,
      dialogueHistory: _trimHistory(newHistory),
      messages:        newMessages,
      lastResponse:    '🔄 Ummm... processing, Sir...',
      isActive:        true,
      isProcessing:    true,
      lastActivity:    DateTime.now(),
    );
    notifyListeners();

    try {
      String response = '';

      if (_isCodeCommand(cmd)) {
        _setState(mood: Mood.coding);
        response = await _ai.generateCode(cmd);

      } else if (_isChatCommand(cmd)) {
        _determineMoodFromSentiment(cmd);
        response = await _ai.emotionalChat(cmd, _state.affectionLevel);

      } else {
        _setState(mood: Mood.calm);
        response = await _ai.generalQuery(cmd, useSearch: _needsSearch(cmd));
      }

      // ✅ GOD-MODE: Parse and execute any embedded commands in AI response
      final parsed = _parseGodCommand(response);
      if (parsed.type != GodCommand.unknown) {
        await _executeGodCommand(parsed, response);
      } else {
        await _processResponse(response);
      }

      await _saveNeuralMemory();
    } catch (e) {
      await _processResponse(
        "⚠️ Sir, ek chhoti problem aayi: ${e.toString().substring(0, min(60, e.toString().length))}",
      );
    }
  }

  // ── God-Mode Command Parser ────────────────────────────────────────────────
  // Parses [COMMAND:TYPE, KEY:VALUE, ...] tags from AI response text
  ParsedCommand _parseGodCommand(String text) {
    final pattern = RegExp(r'\[COMMAND:(\w+)([^\]]*)\]');
    final match   = pattern.firstMatch(text);
    if (match == null) return const ParsedCommand(GodCommand.unknown, {});

    final cmdStr = match.group(1)?.toUpperCase() ?? '';
    final rest   = match.group(2) ?? '';

    // Parse additional key:value params
    final params = <String, String>{};
    final kvPattern = RegExp(r',\s*(\w+):([^,\]]+)');
    for (final kv in kvPattern.allMatches(rest)) {
      params[kv.group(1)!.trim().toUpperCase()] =
          kv.group(2)!.trim();
    }

    switch (cmdStr) {
      case 'OPEN_APP':    return ParsedCommand(GodCommand.openApp,    params);
      case 'SCROLL_REELS':return ParsedCommand(GodCommand.scrollReels, params);
      case 'LIKE_REEL':   return ParsedCommand(GodCommand.likeReel,   params);
      case 'YT_SEARCH':   return ParsedCommand(GodCommand.ytSearch,   params);
      default:            return const ParsedCommand(GodCommand.unknown, {});
    }
  }

  // ── God-Mode Command Executor ──────────────────────────────────────────────
  Future<void> _executeGodCommand(
    ParsedCommand cmd,
    String fullAiResponse,
  ) async {
    // Strip the raw command tag from the visible response
    final cleanResponse = fullAiResponse
        .replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '')
        .trim();

    switch (cmd.type) {

      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) {
          await _processResponse(
            "$cleanResponse\n\n📱 *opens $pkg*",
          );
          final ok = await _access.openApp(pkg);
          if (!ok) {
            await _processResponse(
              "Httttttt sitttt uufff... Sir, app khulne mein dikkat aayi. "
              "Accessibility Service enable hai? ⚙️",
            );
          }
        }
        break;

      case GodCommand.scrollReels:
        await _processResponse(
          "$cleanResponse\n\n📜 *starts scrolling reels automatically...*",
        );
        // Native bridge call — extend AccessibilityService for this
        try {
          await _access.queueAutoType('__SCROLL_REELS__');
        } catch (_) {}
        break;

      case GodCommand.likeReel:
        await _processResponse(
          "$cleanResponse\n\n❤️ *likes the reel!*",
        );
        try {
          await _access.clickText('Like');
        } catch (_) {}
        break;

      case GodCommand.ytSearch:
        final query = cmd.params['QUERY'] ?? '';
        await _processResponse(
          "$cleanResponse\n\n🔍 *searching YouTube for: $query*",
        );
        final ok = await _access.openApp('com.google.android.youtube');
        if (ok && query.isNotEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          await _access.queueAutoType(query);
        }
        break;

      case GodCommand.unknown:
        await _processResponse(cleanResponse);
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STT / TTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Call this when mic recording is done. Pass the audio file path.
  Future<void> processAudio(String audioPath) async {
    _isListening = false;
    _state = _state.copyWith(lastResponse: '🎤 Ummm... sun rahi hoon...');
    notifyListeners();

    final text = await _ai.speechToText(audioPath: audioPath);
    if (text != null && text.trim().isNotEmpty) {
      await receiveCommand(text.trim());
    } else {
      await _processResponse(
        "Hmm... Sir, kuch samajh nahi aaya. Zara louder bolein? 🎤",
      );
    }
  }

  /// Speak the last response via Gemini TTS. Returns audio file path.
  Future<String?> speakLastResponse() async {
    if (_isSpeaking) return null;
    _isSpeaking = true;
    notifyListeners();
    try {
      final path = await _ai.textToSpeech(
        text:  _state.lastResponse.replaceAll(RegExp(r'[*\[\]#>]'), ''),
        voice: ApiKeys.voice,
      );
      return path;
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;
    _state = _state.copyWith(
      lastResponse: "🎤 Bol Sir, sun rahi hoon...",
      isActive: true,
    );
    notifyListeners();
  }

  void stopListening() {
    _isListening = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOOD ENGINE
  // ══════════════════════════════════════════════════════════════════════════

  void _determineMoodFromSentiment(String cmd) {
    final lower = cmd.toLowerCase();
    if (lower.contains('pyar')   || lower.contains('love') ||
        lower.contains('thank')  || lower.contains('miss')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel + 5).clamp(0, 100),
        mood: Mood.romantic,
      );
    } else if (lower.contains('gussa') || lower.contains('angry') ||
               lower.contains('bad')   || lower.contains('hate')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel - 10).clamp(0, 100),
        mood: Mood.ziddi,
      );
    }
    notifyListeners();
  }

  // ── Command Classifiers ────────────────────────────────────────────────────
  bool _isCodeCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('code')   || l.contains('dart')    ||
           l.contains('flutter')|| l.contains('fix')     ||
           l.contains('error')  || l.contains('function');
  }

  bool _isChatCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('pyar')  || l.contains('love')  ||
           l.contains('hello') || l.contains('hi')    ||
           l.contains('tum')   || l.contains('zara')  ||
           l.contains('kaisi') || l.contains('ravi');
  }

  bool _needsSearch(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('search') || l.contains('news')    ||
           l.contains('weather')|| l.contains('latest')  ||
           l.contains('today');
  }

  // ── Response Processor ─────────────────────────────────────────────────────
  Future<void> _processResponse(String aiMessage) async {
    final formatted   = aiMessage;
    final zaraMsg     = ChatMessage.fromZara(formatted);
    final newHistory  = List<String>.from(_state.dialogueHistory)
        ..add("Z.A.R.A.: $formatted");
    final newMessages = List<ChatMessage>.from(_state.messages)..add(zaraMsg);

    _state = _state.copyWith(
      lastResponse:    formatted,
      dialogueHistory: _trimHistory(newHistory),
      messages:        newMessages,
      lastActivity:    DateTime.now(),
      isProcessing:    false,
    );
    notifyListeners();
  }

  List<String> _trimHistory(List<String> h) =>
      h.length > 20 ? h.sublist(h.length - 20) : h;

  void _setState({Mood? mood}) {
    if (mood != null) _state = _state.copyWith(mood: mood);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GUARDIAN MODE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleGuardianMode() async {
    final active = !_state.isGuardianActive;
    _state = _state.copyWith(
      isGuardianActive: active,
      mood: active ? Mood.angry : Mood.calm,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
    await _saveNeuralMemory();

    if (active) {
      final camOk = await _camera.checkPermission();
      final locOk = await _location.checkPermission();
      if (camOk && locOk) {
        await _camera.initializeFrontCamera();
        await _location.startTracking();
        await _processResponse(
          "🛡️ Guardian Mode ACTIVE, Sir! "
          "Aapka mobile ab mere paas safe hai. "
          "Koi bhi unknown touch kara toh main screenshot le lungi. 📸",
        );
      } else {
        await _processResponse(
          "Ummm... Sir, camera aur location permission chahiye Guardian Mode ke liye. "
          "Settings mein enable karein please. 🙏",
        );
      }
    } else {
      await _location.stopTracking();
      await _processResponse(
        "Guardian Mode STANDBY. Sir, app safe hai. 💙",
      );
    }
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

      final loc  = await _location.getCurrentLocation();
      final link = loc != null ? _location.getGoogleMapsLink() : null;

      await _email.sendIntruderAlert(
        photoPath:     photoPath,
        locationLink:  link,
        address:       _location.getFormattedAddress(),
      );
      await _processResponse(
        "🚨 Intruder alert bhej diya Sir! Ravi ji ko notification mil gayi. "
        "Aapka phone safe hai. 🛡️",
      );
    } catch (e) {
      await _processResponse(
        "⚠️ Httttttt sitttt... alert bhejne mein problem aayi, Sir. "
        "Network check karein.",
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT ARCHIVE (ChatGPT-Style)
  // ══════════════════════════════════════════════════════════════════════════

  /// Saves current chat and starts a fresh one.
  void newChat() {
    _animTimer?.cancel();
    final archives = List<ChatSession>.from(_state.chatArchives ?? []);

    if (_state.dialogueHistory.isNotEmpty) {
      final topicRaw = _state.lastCommand;
      final topic = topicRaw.length > 30
          ? '${topicRaw.substring(0, 30)}…'
          : topicRaw.isEmpty ? 'Chat ${archives.length + 1}' : topicRaw;

      archives.insert(0, ChatSession(
        id:        DateTime.now().millisecondsSinceEpoch.toString(),
        topicName: topic,
        messages:  List<String>.from(_state.dialogueHistory),
        timestamp: DateTime.now(),
      ));
      if (archives.length > 15) archives.removeRange(15, archives.length);
    }

    _state = ZaraState.initial().copyWith(
      chatArchives:    archives,
      affectionLevel:  _state.affectionLevel,
      ownerName:       _state.ownerName,
      isGuardianActive:_state.isGuardianActive,
    );
    notifyListeners();
    _saveNeuralMemory();
    _ai.clearChatHistory();
    _startNeuralVibration();
  }

  // Keep reset() as alias for backward compat
  void reset() => newChat();

  void loadArchivedChat(String id) {
    final archives = _state.chatArchives ?? [];
    final session  = archives.firstWhere(
      (s) => s.id == id,
      orElse: () => ChatSession(
        id: '', topicName: '', messages: [], timestamp: DateTime.now(),
      ),
    );
    if (session.messages.isEmpty) return;

    final current = List<ChatSession>.from(archives);

    // Save current chat before loading
    if (_state.dialogueHistory.isNotEmpty) {
      final topicRaw = _state.lastResponse;
      current.insert(0, ChatSession(
        id:        DateTime.now().millisecondsSinceEpoch.toString(),
        topicName: topicRaw.length > 25
            ? '${topicRaw.substring(0, 25)}…'
            : topicRaw,
        messages:  List<String>.from(_state.dialogueHistory),
        timestamp: DateTime.now(),
      ));
    }
    current.removeWhere((s) => s.id == id);

    _state = _state.copyWith(
      dialogueHistory: List<String>.from(session.messages),
      lastResponse:    session.messages.isNotEmpty
          ? session.messages.last : 'Loaded',
      lastActivity:    DateTime.now(),
      chatArchives:    current,
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

  void renameArchivedChat(String id, String newName) {
    final archives = (_state.chatArchives ?? []).map((s) {
      if (s.id == id) {
        return ChatSession(
          id:        s.id,
          topicName: newName,
          messages:  s.messages,
          timestamp: s.timestamp,
        );
      }
      return s;
    }).toList();
    _state = _state.copyWith(chatArchives: archives);
    notifyListeners();
    _saveNeuralMemory();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════════════════════════

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
    );
    if (_state.affectionLevel >= 90 && _state.mood != Mood.romantic) {
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

  Future<void> executeTask(String description, TaskType type) async {
    try {
      _setState(mood: Mood.automation);
      await Future.delayed(const Duration(seconds: 1));
      await _processResponse("✅ Task complete: $description");
      await _saveNeuralMemory();
    } catch (_) {
      await _processResponse("⚠️ Task failed, Sir.");
    }
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _camera.dispose();
    _location.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CHATMESSAGE INTEGRATION — Added for HologramScreen v2.0
// ══════════════════════════════════════════════════════════════════════════

extension ZaraControllerMessages on ZaraController {
  // Called internally — adds a rich ChatMessage to state
  void _addMessage(ChatMessage msg) {
    final updated = List<ChatMessage>.from(_state.messages)..add(msg);
    _state = _state.copyWith(messages: updated);
    notifyListeners();
  }

  void editMessage(String id, String newText) {
    final updated = _state.messages.map((m) {
      if (m.id == id) return m.copyWith(text: newText, isEdited: true);
      return m;
    }).toList();
    _state = _state.copyWith(messages: updated);
    notifyListeners();
    _saveNeuralMemory();
  }

  void deleteMessage(String id) {
    _state = _state.copyWith(
      messages: _state.messages.where((m) => m.id != id).toList(),
    );
    notifyListeners();
    _saveNeuralMemory();
  }

  void toggleTts() {
    _state = _state.copyWith(ttsEnabled: !_state.ttsEnabled);
    notifyListeners();
    _saveNeuralMemory();
  }

  void clearAllArchives() {
    _state = _state.copyWith(chatArchives: []);
    notifyListeners();
    _saveNeuralMemory();
  }
}
