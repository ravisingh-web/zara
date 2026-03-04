// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. — Neural Intelligence Controller v2.0
// ✅ God-Mode Command Detection (OPEN_APP, SCROLL, LIKE, YT_SEARCH, etc.)
// ✅ ZaraTtsService — hamesha bolegi, mood ke saath, idle bhi
// ✅ Personality-aware mood engine
// ✅ ChatGPT-style topic archive
// ✅ Hands-Free Mode — bina touch ke continuous conversation loop
// ✅ Floating ORB support — isSpeaking / isListening / isProcessing / handsFreeMode

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
  openApp,
  scrollReels,
  likeReel,
  ytSearch,
  instagramComment,
  flipkartBuy,
  whatsappSend,
  unknown,
}

class ParsedCommand {
  final GodCommand type;
  final Map<String, String> params;
  const ParsedCommand(this.type, this.params);
}

class ZaraController extends ChangeNotifier {

  // ── Services ──────────────────────────────────────────────────────────────
  final _ai       = AiApiService();
  final _camera   = CameraService();
  final _location = LocationService();
  final _access   = AccessibilityService();
  final _email    = EmailService();
  final _tts      = ZaraTtsService();
  final _notif    = NotificationService();
  final _whisper  = WhisperSttService();
  final _livekit  = LiveKitService();

  // ── Internal State ────────────────────────────────────────────────────────
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

  bool _disposed = false; // guard: post-dispose calls se bachao

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
      debugPrint('Gemini key  : ${ApiKeys.geminiKey.isNotEmpty ? "✅ SET" : "❌ EMPTY — Settings mein daalo!"}');
      debugPrint('ElevenLabs  : ${ApiKeys.elevenKey.isNotEmpty ? "✅ SET" : "❌ EMPTY — Awaaz nahi aayegi!"}');
      debugPrint('Mem0        : ${ApiKeys.mem0Key.isNotEmpty   ? "✅ SET" : "⚠️  EMPTY (optional)"}');
      debugPrint('Model       : ${ApiKeys.geminiModel}');
      debugPrint('=========================');
    }

    // ── TTS Callbacks → ORB react karega ──────────────────────────────────
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

    // Hands-free trigger: default null (OFF)
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
        orbScale:   1.0 + (targetPulse * 0.1),
      );
      notifyListeners();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ HANDS-FREE MODE TOGGLE
  // ORB tap → ON: Zara bolegi → mic auto ON → Tu bolta hai → reply → loop
  // ORB tap → OFF: Normal manual mode
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> toggleHandsFree() async {
    _handsFreeMode = !_handsFreeMode;
    _tts.setHandsFree(_handsFreeMode);

    if (_handsFreeMode) {
      // Hook: jab TTS khatam ho → auto mic ON
      _tts.onAutoListenTrigger = () async {
        if (_disposed)              return;
        if (!_handsFreeMode)       return;
        if (_isListening)          return;
        if (_state.isProcessing)   return;

        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || !_handsFreeMode) return;

        await startListening();

        // 6 second silence timeout — auto stop karo
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
  // MAIN COMMAND PROCESSOR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> receiveCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;

    // User ne bola — listen timer cancel karo
    _handsFreeListenTimer?.cancel();

    final userMsg    = ChatMessage.fromUser(cmd);
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

  // ── God-Mode Parser ────────────────────────────────────────────────────────
  ParsedCommand _parseGodCommand(String text) {
    final pattern = RegExp(r'\[COMMAND:(\w+)([^\]]*)\]');
    final match   = pattern.firstMatch(text);
    if (match == null) return const ParsedCommand(GodCommand.unknown, {});

    final cmdStr    = match.group(1)?.toUpperCase() ?? '';
    final rest      = match.group(2) ?? '';
    final params    = <String, String>{};
    final kvPattern = RegExp(r',\s*(\w+):([^,\]]+)');

    for (final kv in kvPattern.allMatches(rest)) {
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

  // ── God-Mode Executor ──────────────────────────────────────────────────────
  Future<void> _executeGodCommand(ParsedCommand cmd, String fullAiResponse) async {
    final clean = fullAiResponse.replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();

    switch (cmd.type) {
      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) {
          await _processResponse('$clean\n\n📱 *opens $pkg*');
          final ok = await _access.openApp(pkg);
          if (!ok) {
            await _processResponse(
              'Httttttt sitttt uufff... Sir, app khulne mein dikkat aayi. '
              'Accessibility Service enable hai? ⚙️',
            );
          }
        }
        break;

      case GodCommand.scrollReels:
        await _processResponse('$clean\n\n📜 *starts scrolling reels...*');
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
        final commentText = cmd.params['TEXT'] ?? '';
        await _processResponse('$clean\n\n💬 *commenting on Instagram...*');
        await _access.instagramPostComment(commentText);
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
        final contact = cmd.params['TO']  ?? '';
        final message = cmd.params['MSG'] ?? '';
        await _processResponse('$clean\n\n📤 *sending WhatsApp to $contact...*');
        await _access.whatsappSendMessage(contact, message);
        break;

      case GodCommand.unknown:
        await _processResponse(clean);
        break;
    }
  }

  // ── Proactive Notification ─────────────────────────────────────────────────
  void _handleProactiveNotification(NotificationAlert alert) {
    if (alert.zaraAlert.isEmpty) return;
    final zaraMsg = ChatMessage.fromZara(alert.zaraAlert);
    final msgs    = List<ChatMessage>.from(_state.messages)..add(zaraMsg);
    _state = _state.copyWith(
      messages:     msgs,
      lastResponse: alert.zaraAlert,
      isActive:     true,
      lastActivity: DateTime.now(),
    );
    notifyListeners();
    _tts.speak(alert.zaraAlert);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STT — Speech To Text
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> processAudio(String audioPath) async {
    _isListening = false;
    _state = _state.copyWith(lastResponse: '🎤 Ummm... sun rahi hoon...');
    notifyListeners();

    final text = await _ai.speechToText(audioPath: audioPath);
    if (text != null && text.trim().isNotEmpty) {
      await receiveCommand(text.trim());
    } else {
      await _processResponse('Hmm... Sir, kuch samajh nahi aaya. Zara louder bolein? 🎤');
    }
  }

  /// Legacy Gemini TTS path — backward compat
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
    await _tts.stop();
    _isListening = true;
    _state = _state.copyWith(
      lastResponse: '🎤 Bol Sir, sun rahi hoon...',
      isActive:     true,
      isListening:  true,
    );
    notifyListeners();

    final started = await _whisper.startRecording();
    if (!started) {
      _isListening = false;
      _state = _state.copyWith(
        isListening:  false,
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
    _state = _state.copyWith(
      isListening:  false,
      lastResponse: '🔄 Samajh rahi hoon...',
    );
    notifyListeners();

    final text = await _whisper.stopAndTranscribe();
    if (text != null && text.isNotEmpty) {
      await receiveCommand(text);
    } else {
      _state = _state.copyWith(lastResponse: 'Ummm, kuch suna nahi. Dobara bolna?');
      notifyListeners();

      // Hands-free: kuch nahi suna → phir bhi loop continue karo
      if (_handsFreeMode && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 800));
        _tts.onAutoListenTrigger?.call();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOOD ENGINE
  // ═══════════════════════════════════════════════════════════════════════════

  void _determineMoodFromSentiment(String cmd) {
    final lower = cmd.toLowerCase();
    if (lower.contains('pyar')  || lower.contains('love') ||
        lower.contains('thank') || lower.contains('miss')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel + 5).clamp(0, 100),
        mood:           Mood.romantic,
      );
    } else if (lower.contains('gussa') || lower.contains('angry') ||
               lower.contains('bad')   || lower.contains('hate')) {
      _state = _state.copyWith(
        affectionLevel: (_state.affectionLevel - 10).clamp(0, 100),
        mood:           Mood.ziddi,
      );
    }
    notifyListeners();
  }

  // ── Command Classifiers ────────────────────────────────────────────────────
  bool _isCodeCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('code')    || l.contains('dart')    ||
           l.contains('flutter') || l.contains('fix')     ||
           l.contains('error')   || l.contains('function');
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
    return l.contains('search')  || l.contains('news')   ||
           l.contains('weather') || l.contains('latest') ||
           l.contains('today');
  }

  // ── Response Processor ─────────────────────────────────────────────────────
  Future<void> _processResponse(String aiMessage) async {
    if (_disposed) return;

    final zaraMsg     = ChatMessage.fromZara(aiMessage);
    final newHistory  = List<String>.from(_state.dialogueHistory)
        ..add('Z.A.R.A.: $aiMessage');
    final newMessages = List<ChatMessage>.from(_state.messages)..add(zaraMsg);

    _state = _state.copyWith(
      lastResponse:    aiMessage,
      dialogueHistory: _trimHistory(newHistory),
      messages:        newMessages,
      lastActivity:    DateTime.now(),
      isProcessing:    false,
    );
    notifyListeners();

    _tts.setMood(_state.mood);
    _tts.resetIdleTimer();
    unawaited(_tts.speak(aiMessage, mood: _state.mood));
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
        await _processResponse(
          '🛡️ Guardian Mode ACTIVE, Sir! '
          'Aapka mobile ab mere paas safe hai. '
          'Koi bhi unknown touch kara toh main screenshot le lungi. 📸',
        );
      } else {
        await _processResponse(
          'Ummm... Sir, camera aur location permission chahiye Guardian Mode ke liye. '
          'Settings mein enable karein please. 🙏',
        );
      }
    } else {
      await _location.stopTracking();
      await _processResponse('Guardian Mode STANDBY. Sir, app safe hai. 💙');
    }
  }

  Future<void> reportIntruder(String photoPath) async {
    try {
      _state = _state.copyWith(
        lastIntruderPhoto: photoPath,
        mood:              Mood.angry,
        lastActivity:      DateTime.now(),
      );
      notifyListeners();
      await _saveNeuralMemory();
      _notif.updateOrb('idle');

      final loc  = await _location.getCurrentLocation();
      final link = loc != null ? _location.getGoogleMapsLink() : null;

      await _email.sendIntruderAlert(
        photoPath:    photoPath,
        locationLink: link,
        address:      _location.getFormattedAddress(),
      );
      await _processResponse(
        '🚨 Intruder alert bhej diya Sir! Ravi ji ko notification mil gayi. 🛡️',
      );
    } catch (e) {
      await _processResponse(
        '⚠️ Httttttt sitttt... alert bhejne mein problem aayi, Sir.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT ARCHIVE
  // ═══════════════════════════════════════════════════════════════════════════

  void newChat() {
    _animTimer?.cancel();
    final archives = List<ChatSession>.from(_state.chatArchives ?? []);

    if (_state.dialogueHistory.isNotEmpty) {
      final topicRaw = _state.lastCommand;
      final topic    = topicRaw.length > 30
          ? topicRaw.substring(0, 30)
          : topicRaw;
      archives.insert(
        0,
        ChatSession(
          id:        DateTime.now().millisecondsSinceEpoch.toString(),
          topic:     topic.isEmpty ? 'Baat cheet' : topic,
          messages:  List.from(_state.messages),
          timestamp: DateTime.now(),
        ),
      );
    }

    _state = ZaraState.initial().copyWith(
      chatArchives:   archives.take(20).toList(),
      affectionLevel: _state.affectionLevel,
      mood:           Mood.calm,
    );
    notifyListeners();
    _startNeuralVibration();
    _ai.clearHistory();
  }

  List<ChatSession> get chatArchives => _state.chatArchives ?? [];

  void loadSession(ChatSession session) {
    _state = _state.copyWith(
      messages:        session.messages,
      dialogueHistory: session.messages.map((m) => m.content).toList(),
      lastCommand:     session.topic,
      isActive:        true,
    );
    notifyListeners();
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
