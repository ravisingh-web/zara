// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — Neural Intelligence Controller v2.0
// ✅ God-Mode Commands
// ✅ Hands-Free Mode
// ✅ Floating ORB support
// ✅ toggleTts, editMessage, deleteMessage
// ✅ loadArchivedChat, deleteArchivedChat, clearAllArchives, renameArchivedChat
// ✅ ChatSession correct fields: topicName, chatMessages, messages(List<String>)

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
import 'package:zara/services/tts_service.dart';
import 'package:zara/services/notification_service.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/services/whisper_stt_service.dart';
import 'package:zara/services/livekit_service.dart';

enum TaskType { message, post, system, analysis }

enum GodCommand {
  openApp, scrollReels, likeReel, ytSearch,
  instagramComment, flipkartBuy, whatsappSend, unknown,
}

class ParsedCommand {
  final GodCommand type;
  final Map<String, String> params;
  const ParsedCommand(this.type, this.params);
}

class ZaraController extends ChangeNotifier {

  final _ai       = AiApiService();
  final _camera   = CameraService();
  final _location = LocationService();
  final _access   = AccessibilityService();
  final _email    = EmailService();
  final _tts      = ZaraTtsService();
  final _notif    = NotificationService();
  final _whisper  = WhisperSttService();
  final _livekit  = LiveKitService();

  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  Timer? _animTimer;
  Timer? _handsFreeListenTimer;

  bool _isListening    = false;
  bool get isListening => _isListening;

  bool _isSpeaking    = false;
  bool get isSpeaking => _isSpeaking;

  bool _handsFreeMode    = false;
  bool get handsFreeMode => _handsFreeMode;

  bool _disposed = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    await _loadNeuralMemory();

    try { await _email.initialize(); } catch (e) {
      if (kDebugMode) debugPrint('EmailService init error: $e');
    }

    try {
      await _tts.initialize();
      _tts.setEnabled(true);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }

    if (kDebugMode) {
      debugPrint('=== ZARA STARTUP CHECK ===');
      debugPrint('Gemini    : ${ApiKeys.geminiKey.isNotEmpty ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('ElevenLabs: ${ApiKeys.elevenKey.isNotEmpty ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('Mem0      : ${ApiKeys.mem0Key.isNotEmpty   ? "✅ SET" : "⚠️  optional"}');
      debugPrint('Model     : ${ApiKeys.geminiModel}');
      debugPrint('=========================');
    }

    _tts.onSpeakStart = () {
      if (_disposed) return;
      _isSpeaking = true;
      _state = _state.copyWith(isSpeaking: true);
      notifyListeners();
    };

    _tts.onSpeakDone = () {
      if (_disposed) return;
      _isSpeaking = false;
      _state = _state.copyWith(isSpeaking: false);
      notifyListeners();
    };

    _tts.onAutoListenTrigger = null;
    _tts.startIdleSystem();

    try {
      await _notif.initialize();
      await _notif.startForegroundService();
      _notif.onProactiveAlert = (alert) => _handleProactiveNotification(alert);
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService init error: $e');
    }

    try { _startNeuralVibration(); } catch (e) {
      if (kDebugMode) debugPrint('Vibration init error: $e');
    }

    if (kDebugMode) debugPrint('✅ Z.A.R.A. Neural Core initialized');
  }

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

  void _startNeuralVibration() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_state.isActive) return;
      final targetPulse = _isListening
          ? (0.5 + Random().nextDouble() * 0.5)
          : (sin(DateTime.now().millisecondsSinceEpoch / 1000) * 0.2 + 0.3);
      _state = _state.copyWith(
        pulseValue: targetPulse,
        orbScale:   1.0 + (targetPulse * 0.1),
      );
      notifyListeners();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ HANDS-FREE MODE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> toggleHandsFree() async {
    _handsFreeMode = !_handsFreeMode;
    _tts.setHandsFree(_handsFreeMode);

    if (_handsFreeMode) {
      _tts.onAutoListenTrigger = () async {
        if (_disposed)           return;
        if (!_handsFreeMode)     return;
        if (_isListening)        return;
        if (_state.isProcessing) return;

        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || !_handsFreeMode) return;

        await startListening();

        _handsFreeListenTimer?.cancel();
        _handsFreeListenTimer = Timer(const Duration(seconds: 6), () {
          if (_isListening && _handsFreeMode && !_disposed) {
            stopListening();
          }
        });
      };

      notifyListeners();
      await _processResponse(
        'Hands-free mode ON kar diya Sir! 🎙️ '
        'Ab main sunti rahungi automatically. '
        'Bas bolna shuru karo. ORB dobara tap karo band karne ke liye.',
      );
    } else {
      _handsFreeListenTimer?.cancel();
      _tts.onAutoListenTrigger = null;
      if (_isListening) {
        _isListening = false;
        _state = _state.copyWith(isListening: false);
      }
      notifyListeners();
      await _processResponse('Okay Sir, hands-free band kar diya. 💙');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ TTS TOGGLE
  // ═══════════════════════════════════════════════════════════════════════════

  void toggleTts() {
    final newVal = !_state.ttsEnabled;
    _state = _state.copyWith(ttsEnabled: newVal);
    _tts.setEnabled(newVal);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN COMMAND PROCESSOR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> receiveCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    _handsFreeListenTimer?.cancel();

    final userMsg     = ChatMessage.fromUser(cmd);
    final newHistory  = List<String>.from(_state.dialogueHistory)..add(cmd);
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

    await _tts.stop();
    _tts.resetIdleTimer();
    _notif.updateOrb('thinking');

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

      final parsed = _parseGodCommand(response);
      if (parsed.type != GodCommand.unknown) {
        await _executeGodCommand(parsed, response);
      } else {
        await _processResponse(response);
      }

      await _saveNeuralMemory();
      _notif.updateOrb('idle');
    } catch (e) {
      await _processResponse(
        '⚠️ Sir, ek chhoti problem aayi: ${e.toString().substring(0, min(60, e.toString().length))}',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ EDIT / DELETE MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  void editMessage(String messageId, String newText) {
    final msgs = _state.messages.map((m) {
      if (m.id == messageId) return m.copyWith(text: newText, isEdited: true);
      return m;
    }).toList();
    _state = _state.copyWith(messages: msgs);
    notifyListeners();
    _saveNeuralMemory();
  }

  void deleteMessage(String messageId) {
    final msgs = _state.messages.where((m) => m.id != messageId).toList();
    _state = _state.copyWith(messages: msgs);
    notifyListeners();
    _saveNeuralMemory();
  }

  // ── God-Mode Parser ────────────────────────────────────────────────────────
  ParsedCommand _parseGodCommand(String text) {
    final match = RegExp(r'\[COMMAND:(\w+)([^\]]*)\]').firstMatch(text);
    if (match == null) return const ParsedCommand(GodCommand.unknown, {});

    final cmdStr = match.group(1)?.toUpperCase() ?? '';
    final rest   = match.group(2) ?? '';
    final params = <String, String>{};

    for (final kv in RegExp(r',\s*(\w+):([^,\]]+)').allMatches(rest)) {
      params[kv.group(1)!.trim().toUpperCase()] = kv.group(2)!.trim();
    }

    switch (cmdStr) {
      case 'OPEN_APP':      return ParsedCommand(GodCommand.openApp,          params);
      case 'SCROLL_REELS':  return ParsedCommand(GodCommand.scrollReels,      params);
      case 'LIKE_REEL':     return ParsedCommand(GodCommand.likeReel,         params);
      case 'YT_SEARCH':     return ParsedCommand(GodCommand.ytSearch,         params);
      case 'IG_COMMENT':    return ParsedCommand(GodCommand.instagramComment, params);
      case 'FLIPKART_BUY':  return ParsedCommand(GodCommand.flipkartBuy,      params);
      case 'WHATSAPP_SEND': return ParsedCommand(GodCommand.whatsappSend,     params);
      default:              return const ParsedCommand(GodCommand.unknown,    {});
    }
  }

  Future<void> _executeGodCommand(ParsedCommand cmd, String fullAiResponse) async {
    final clean = fullAiResponse.replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();

    switch (cmd.type) {
      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) {
          await _processResponse('$clean\n\n📱 *opens $pkg*');
          final ok = await _access.openApp(pkg);
          if (!ok) await _processResponse('Accessibility Service enable hai? ⚙️');
        }
        break;
      case GodCommand.scrollReels:
        await _processResponse('$clean\n\n📜 *scrolling reels...*');
        try { await _access.scrollDown(steps: 3); } catch (_) {}
        break;
      case GodCommand.likeReel:
        await _processResponse('$clean\n\n❤️ *likes the reel!*');
        try { await _access.clickText('Like'); } catch (_) {}
        break;
      case GodCommand.ytSearch:
        final query = cmd.params['QUERY'] ?? '';
        await _processResponse('$clean\n\n🔍 *searching YouTube: $query*');
        final ok = await _access.openApp('com.google.android.youtube');
        if (ok && query.isNotEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          await _access.typeText(query);
        }
        break;
      case GodCommand.instagramComment:
        await _processResponse('$clean\n\n💬 *commenting on Instagram...*');
        await _access.instagramPostComment(cmd.params['TEXT'] ?? '');
        break;
      case GodCommand.flipkartBuy:
        final product = cmd.params['PRODUCT'] ?? '';
        final size    = cmd.params['SIZE'] ?? 'M';
        await _processResponse('$clean\n\n🛍️ *searching Flipkart for $product...*');
        await _access.flipkartSearchProduct(product);
        await Future.delayed(const Duration(seconds: 3));
        await _access.flipkartSelectSize(size);
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartAddToCart();
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartGoToPayment();
        break;
      case GodCommand.whatsappSend:
        await _processResponse('$clean\n\n📤 *sending WhatsApp to ${cmd.params['TO']}...*');
        await _access.whatsappSendMessage(cmd.params['TO'] ?? '', cmd.params['MSG'] ?? '');
        break;
      case GodCommand.unknown:
        await _processResponse(clean);
        break;
    }
  }

  void _handleProactiveNotification(NotificationAlert alert) {
    if (alert.zaraAlert.isEmpty) return;
    final zaraMsg = ChatMessage.fromZara(alert.zaraAlert);
    final msgs    = List<ChatMessage>.from(_state.messages)..add(zaraMsg);
    _state = _state.copyWith(
      messages: msgs, lastResponse: alert.zaraAlert,
      isActive: true, lastActivity: DateTime.now(),
    );
    notifyListeners();
    if (_state.ttsEnabled) _tts.speak(alert.zaraAlert);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> processAudio(String audioPath) async {
    _isListening = false;
    _state = _state.copyWith(lastResponse: '🎤 Ummm... sun rahi hoon...');
    notifyListeners();
    final text = await _ai.speechToText(audioPath: audioPath);
    if (text != null && text.trim().isNotEmpty) {
      await receiveCommand(text.trim());
    } else {
      await _processResponse('Hmm... Sir, kuch samajh nahi aaya. Louder bolein? 🎤');
    }
  }

  Future<String?> speakLastResponse() async {
    if (_isSpeaking) return null;
    _isSpeaking = true;
    notifyListeners();
    try {
      return await _ai.textToSpeech(
        text:  _state.lastResponse.replaceAll(RegExp(r'[*\[\]#>]'), ''),
        voice: ApiKeys.voice,
      );
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;
    await _tts.stop();
    _isListening = true;
    _state = _state.copyWith(
      lastResponse: '🎤 Bol Sir, sun rahi hoon...',
      isActive: true, isListening: true,
    );
    notifyListeners();
    final started = await _whisper.startRecording();
    if (!started) {
      _isListening = false;
      _state = _state.copyWith(
        isListening: false,
        lastResponse: '⚠️ Mic start nahi hua. Permission check karo.',
      );
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _handsFreeListenTimer?.cancel();
    _isListening = false;
    _tts.resetIdleTimer();
    _state = _state.copyWith(isListening: false, lastResponse: '🔄 Samajh rahi hoon...');
    notifyListeners();

    final text = await _whisper.stopAndTranscribe();
    if (text != null && text.isNotEmpty) {
      await receiveCommand(text);
    } else {
      _state = _state.copyWith(lastResponse: 'Ummm, kuch suna nahi. Dobara bolna?');
      notifyListeners();
      if (_handsFreeMode && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 800));
        _tts.onAutoListenTrigger?.call();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOOD
  // ═══════════════════════════════════════════════════════════════════════════

  void _determineMoodFromSentiment(String cmd) {
    final l = cmd.toLowerCase();
    if (l.contains('pyar') || l.contains('love') || l.contains('thank') || l.contains('miss')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel + 5).clamp(0, 100),
        mood: Mood.romantic,
      );
    } else if (l.contains('gussa') || l.contains('angry') || l.contains('bad') || l.contains('hate')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel - 10).clamp(0, 100),
        mood: Mood.ziddi,
      );
    }
    notifyListeners();
  }

  bool _isCodeCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('code') || l.contains('dart') || l.contains('flutter') ||
           l.contains('fix')  || l.contains('error') || l.contains('function');
  }

  bool _isChatCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('pyar') || l.contains('love')  || l.contains('hello') ||
           l.contains('hi')   || l.contains('tum')   || l.contains('zara')  ||
           l.contains('kaisi')|| l.contains('ravi');
  }

  bool _needsSearch(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('search') || l.contains('news') || l.contains('weather') ||
           l.contains('latest') || l.contains('today');
  }

  Future<void> _processResponse(String aiMessage) async {
    if (_disposed) return;
    final zaraMsg    = ChatMessage.fromZara(aiMessage);
    final newHistory = List<String>.from(_state.dialogueHistory)..add('Z.A.R.A.: $aiMessage');
    final newMsgs    = List<ChatMessage>.from(_state.messages)..add(zaraMsg);

    _state = _state.copyWith(
      lastResponse:    aiMessage,
      dialogueHistory: _trimHistory(newHistory),
      messages:        newMsgs,
      lastActivity:    DateTime.now(),
      isProcessing:    false,
    );
    notifyListeners();

    _tts.setMood(_state.mood);
    _tts.resetIdleTimer();
    if (_state.ttsEnabled) {
      unawaited(_tts.speak(aiMessage, mood: _state.mood));
    }
  }

  List<String> _trimHistory(List<String> h) =>
      h.length > 20 ? h.sublist(h.length - 20) : h;

  void _setState({Mood? mood}) {
    if (mood != null) _state = _state.copyWith(mood: mood);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GUARDIAN MODE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> toggleGuardianMode() async {
    final active = !_state.isGuardianActive;
    _state = _state.copyWith(
      isGuardianActive: active,
      mood:             active ? Mood.angry : Mood.calm,
      lastActivity:     DateTime.now(),
    );
    notifyListeners();
    await _saveNeuralMemory();

    if (active) {
      final camOk = await _camera.checkPermission();
      final locOk = await _location.checkPermission();
      if (camOk && locOk) {
        await _camera.initializeFrontCamera();
        await _location.startTracking();
        await _processResponse('🛡️ Guardian Mode ACTIVE, Sir! 📸');
      } else {
        await _processResponse('Camera aur location permission chahiye. Settings mein enable karo. 🙏');
      }
    } else {
      await _location.stopTracking();
      await _processResponse('Guardian Mode STANDBY. 💙');
    }
  }

  Future<void> reportIntruder(String photoPath) async {
    try {
      _state = _state.copyWith(
        lastIntruderPhoto: photoPath, mood: Mood.angry, lastActivity: DateTime.now(),
      );
      notifyListeners();
      await _saveNeuralMemory();
      _notif.updateOrb('idle');
      final loc  = await _location.getCurrentLocation();
      final link = loc != null ? _location.getGoogleMapsLink() : null;
      await _email.sendIntruderAlert(
        photoPath: photoPath, locationLink: link, address: _location.getFormattedAddress(),
      );
      await _processResponse('🚨 Intruder alert bhej diya Sir! 🛡️');
    } catch (e) {
      await _processResponse('⚠️ Alert bhejne mein problem aayi, Sir.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ CHAT ARCHIVE — ALL METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void newChat() {
    _animTimer?.cancel();
    final archives = List<ChatSession>.from(_state.chatArchives);

    if (_state.messages.isNotEmpty) {
      final topicRaw = _state.lastCommand;
      final topic    = topicRaw.length > 30 ? topicRaw.substring(0, 30) : topicRaw;
      archives.insert(0, ChatSession(
        id:           DateTime.now().millisecondsSinceEpoch.toString(),
        topicName:    topic.isEmpty ? 'Baat cheet' : topic,
        messages:     List<String>.from(_state.dialogueHistory),
        chatMessages: List<ChatMessage>.from(_state.messages),
        timestamp:    DateTime.now(),
      ));
    }

    _state = ZaraState.initial().copyWith(
      chatArchives:   archives.take(20).toList(),
      affectionLevel: _state.affectionLevel,
      mood:           Mood.calm,
      ttsEnabled:     _state.ttsEnabled,
    );
    notifyListeners();
    _startNeuralVibration();
    _ai.clearHistory();
  }

  List<ChatSession> get chatArchives => _state.chatArchives;

  // ✅ Load session by ID
  void loadArchivedChat(String sessionId) {
    final session = _state.chatArchives.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => ChatSession(id: '', topicName: '', messages: [], timestamp: DateTime.now()),
    );
    if (session.id.isEmpty) return;

    final msgs = session.chatMessages.isNotEmpty
        ? session.chatMessages
        : session.messages.map((t) => ChatMessage.system(t)).toList();

    _state = _state.copyWith(
      messages:        msgs,
      dialogueHistory: session.messages,
      lastCommand:     session.topicName,
      isActive:        true,
    );
    notifyListeners();
  }

  // Legacy alias
  void loadSession(ChatSession session) => loadArchivedChat(session.id);

  // ✅ Delete one session
  void deleteArchivedChat(String sessionId) {
    _state = _state.copyWith(
      chatArchives: _state.chatArchives.where((s) => s.id != sessionId).toList(),
    );
    notifyListeners();
    _saveNeuralMemory();
  }

  // ✅ Delete all
  void clearAllArchives() {
    _state = _state.copyWith(chatArchives: []);
    notifyListeners();
    _saveNeuralMemory();
  }

  // ✅ Rename session
  void renameArchivedChat(String sessionId, String newName) {
    if (newName.trim().isEmpty) return;
    final archives = _state.chatArchives.map((s) {
      if (s.id != sessionId) return s;
      return ChatSession(
        id:           s.id,
        topicName:    newName.trim(),
        messages:     s.messages,
        chatMessages: s.chatMessages,
        timestamp:    s.timestamp,
      );
    }).toList();
    _state = _state.copyWith(chatArchives: archives);
    notifyListeners();
    _saveNeuralMemory();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> dispose() async {
    _disposed = true;
    _handsFreeListenTimer?.cancel();
    _animTimer?.cancel();
    _tts.onAutoListenTrigger = null;
    await _tts.dispose();
    super.dispose();
  }
}
