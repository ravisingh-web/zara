// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. v15.0 — Neural Intelligence Controller
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  STATE MACHINE                                                          ║
// ║                                                                         ║
// ║  ZaraMode.wakeWord ──── Vosk offline scanning (screen-off safe)        ║
// ║       │  "Hii Zara" heard                                              ║
// ║       ▼                                                                 ║
// ║  [MIC HANDOVER]  vosk.stop() → 200ms OS release → whisper.start()     ║
// ║       │                                                                 ║
// ║  ZaraMode.command ───── Whisper recording (8s window)                  ║
// ║       │  command transcribed                                            ║
// ║       ▼                                                                 ║
// ║  ZaraMode.thinking ──── Gemini 2.5 Flash                               ║
// ║       │  response + screenLayout JSON (VISION)                         ║
// ║       ▼                                                                 ║
// ║  ZaraMode.speaking ──── ElevenLabs eleven_turbo_v2_5 streaming         ║
// ║       │  TTS done + 800ms buffer                                       ║
// ║       ▼                                                                 ║
// ║  ZaraMode.wakeWord ──── loop restarts                                  ║
// ║                                                                         ║
// ║  VISION PIPELINE: scanScreen() JSON → Gemini system prompt             ║
// ║  MIC HANDOVER: vosk.stop() + 200ms → whisper.startRecording()         ║
// ║  VOICE CALLS: whatsappVoiceCall + whatsappVideoCall                    ║
// ╚══════════════════════════════════════════════════════════════════════════╝
// ❌ n8n         — REMOVED
// ❌ Sheets      — REMOVED
// ❌ PipeDream   — REMOVED
// ❌ AutomationService — REMOVED
// ✅ Vosk        — wake word (offline)
// ✅ Whisper     — command STT
// ✅ Gemini      — AI brain
// ✅ ElevenLabs  — Anjura TTS (streaming)
// ✅ Vision      — scanScreen() → Gemini eyes

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
import 'package:zara/services/vosk_service.dart';
import 'package:zara/services/livekit_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// GOD MODE COMMAND TYPES
// ══════════════════════════════════════════════════════════════════════════════

enum GodCommand {
  openApp,
  scrollReels,
  likeReel,
  ytSearch,
  instagramComment,
  flipkartBuy,
  whatsappSend,
  whatsappVoiceCall,
  whatsappVideoCall,
  // ── Vision commands ────────────────────────────────────────────────────────
  clickById,        // [COMMAND:CLICK_BY_ID,ID:com.pkg:id/element]
  clickByText,      // [COMMAND:CLICK_BY_TEXT,TEXT:button label]
  tapAt,            // [COMMAND:TAP_AT,X:540,Y:960]
  typeText,         // [COMMAND:TYPE_TEXT,TEXT:jo likhna hai]
  pressBack,        // [COMMAND:PRESS_BACK]
  pressHome,        // [COMMAND:PRESS_HOME]
  unknown,
}

class ParsedCommand {
  final GodCommand            type;
  final Map<String, String>   params;
  const ParsedCommand(this.type, this.params);
}

// ══════════════════════════════════════════════════════════════════════════════
// ZARA CONTROLLER
// ══════════════════════════════════════════════════════════════════════════════

class ZaraController extends ChangeNotifier {

  // ── Services ───────────────────────────────────────────────────────────────
  final _ai       = AiApiService();
  final _camera   = CameraService();
  final _location = LocationService();
  final _access   = AccessibilityService();
  final _email    = EmailService();
  final _tts      = ZaraTtsService();
  final _notif    = NotificationService();
  final _whisper  = WhisperSttService();
  final _vosk     = VoskService();
  final _livekit  = LiveKitService();

  // ── State ──────────────────────────────────────────────────────────────────
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  bool _isListening       = false;
  bool get isListening    => _isListening;

  bool _isSpeaking        = false;
  bool get isSpeaking     => _isSpeaking;

  bool _handsFreeMode     = false;
  bool get handsFreeMode  => _handsFreeMode;

  bool _realtimeActive    = false;
  bool get realtimeActive => _realtimeActive;

  bool _wakeWordListening    = false;
  bool get wakeWordListening => _wakeWordListening;

  Map<String, bool> _permissions = {};
  Map<String, bool> get permissions          => _permissions;
  bool get allPermissionsGranted =>
      _permissions.values.every((v) => v);

  Timer? _handsFreeListenTimer;
  Timer? _silenceTimer;

  bool _disposed = false;

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    await _loadNeuralMemory();

    try { await _email.initialize(); } catch (_) {}

    // ── TTS ──────────────────────────────────────────────────────────────────
    try {
      await _tts.initialize();
      _tts.setEnabled(true);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init: $e');
    }

    _tts.onSpeakStart = () {
      if (_disposed) return;
      _isSpeaking = true;
      _state = _state.copyWith(isSpeaking: true);
      _notif.updateOrb('speaking');
      _vosk.enterSpeakingMode(); // ← suppress wake detection while Zara speaks
      notifyListeners();
    };

    _tts.onVolumeLevel = (v) {
      if (_disposed) return;
      onVolumeLevel?.call(v);
    };

    _tts.onSpeakDone = () {
      if (_disposed) return;
      _isSpeaking = false;
      _state = _state.copyWith(isSpeaking: false);
      _notif.updateOrb('still');
      notifyListeners();

      // After speaking, restart Vosk wake word engine
      // 800ms buffer prevents Zara hearing her own TTS echo
      if (!_realtimeActive) {
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (!_disposed && !_realtimeActive) {
            _vosk.enterWakeWordMode();
            await _vosk.start();
          }
        });
      }

      // Realtime loop: auto-listen after speaking
      if (_realtimeActive && !_disposed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_realtimeActive && !_disposed && !_isListening) {
            _startRealtimeListen();
          }
        });
      }
    };

    _tts.startIdleSystem();

    // ── Notification service ──────────────────────────────────────────────────
    try {
      await _notif.initialize();
      await _notif.startForegroundService();
      _notif.onProactiveAlert = (alert) => _handleProactiveNotification(alert);
      _notif.onRequestWakeWordStart = () {
        if (!_disposed && !_wakeWordListening) startWakeWordEngine();
      };
    } catch (e) {
      if (kDebugMode) debugPrint('NotifService: $e');
    }

    // ══════════════════════════════════════════════════════════════════════════
    // VOSK STATE MACHINE CALLBACKS
    // ══════════════════════════════════════════════════════════════════════════

    // Vosk heard "Hii Zara" / "Sunna"
    _vosk.onWakeDetected = (word) {
      if (_disposed || _isSpeaking) {
        _vosk.enterWakeWordMode();
        return;
      }
      if (kDebugMode) debugPrint('🔔 "$word" → command mode');
      _onWakeWordDetected(word);
    };

    // VAD fallback (Vosk model missing) — PCM → Whisper → wake word check
    _vosk.onPcmReady = (pcmBase64, sampleRate) async {
      if (_disposed || _isSpeaking || _vosk.mode != ZaraMode.wakeWord) return;
      final text = await _whisper.transcribePcmBase64(pcmBase64, sampleRate);
      if (text == null || text.trim().isEmpty) return;
      final lower = text.toLowerCase().trim();
      final isWake = [
        'hii zara', 'hi zara', 'hey zara', 'zara', 'sunna', 'suno',
      ].any((w) => lower.contains(w));
      if (isWake) {
        _onWakeWordDetected(text);
      } else if (_realtimeActive) {
        receiveCommand(text);
      }
    };

    _vosk.onEngineChanged = (active) {
      _wakeWordListening = active;
      notifyListeners();
    };

    _vosk.onError = (err) {
      if (kDebugMode) debugPrint('Vosk: $err');
    };

    // ── Agent mode ────────────────────────────────────────────────────────────
    _access.setAgentMessageHandler((contact, message) {
      if (!_disposed) handleAgentMessage(contact, message);
    });

    // ── Auto-start Vosk — fully offline, no key needed ────────────────────────
    // 2s delay gives FlutterEngine / MethodChannel time to be ready
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) startWakeWordEngine();
    });

    // ── Permission check ──────────────────────────────────────────────────────
    _checkAndGuidePermissions();

    if (kDebugMode) {
      debugPrint('╔══ ZARA v15.0 ════════════════════════╗');
      debugPrint('║ Gemini    : ${ApiKeys.geminiReady  ? "✅" : "❌ MISSING"}');
      debugPrint('║ ElevenLabs: ${ApiKeys.elevenReady  ? "✅" : "❌ MISSING"}');
      debugPrint('║ OpenAI    : ${ApiKeys.openaiReady  ? "✅" : "— optional"}');
      debugPrint('║ LiveKit   : ${ApiKeys.livekitReady ? "✅" : "— optional"}');
      debugPrint('║ Vosk      : ✅ offline');
      debugPrint('║ n8n/Sheets: ❌ removed');
      debugPrint('║ Model     : ${ApiKeys.geminiModel}');
      debugPrint('╚══════════════════════════════════════╝');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WAKE WORD ENGINE CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> startWakeWordEngine() async {
    // Release Whisper mic before Vosk starts (exclusive resource)
    if (_whisper.alwaysOnActive) await _whisper.stopAlwaysOn();

    final ok = await _vosk.start();
    _wakeWordListening = ok;
    notifyListeners();
    if (kDebugMode) debugPrint('🎙️ Vosk engine: $ok');
  }

  Future<void> stopWakeWordEngine() async {
    await _vosk.stop();
    _wakeWordListening = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MIC HANDOVER — "Hii Zara" detected
  //
  // CRITICAL SEQUENCE — do NOT reorder:
  //   1. _vosk.stop()         → releases AudioRecord lock
  //   2. delay(200ms)         → OS teardown is async on OEMs:
  //                             Pixel ~80ms · Samsung Exynos ~150ms
  //                             OnePlus Snapdragon ~180ms
  //                             200ms = safe across all devices
  //   3. _whisper.startRecording() → AudioRecord.startRecording() succeeds
  //
  // WITHOUT step 1+2: Whisper gets AudioRecord.ERROR_INVALID_OPERATION
  // on Exynos or AUDIOFOCUS_LOSS on Snapdragon
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _onWakeWordDetected(String transcript) async {
    if (_disposed || _isSpeaking) {
      _vosk.enterWakeWordMode();
      return;
    }
    if (kDebugMode) debugPrint('🔔 Wake: "$transcript"');
    _notif.updateOrb('listening');

    // Step 1: Release Vosk AudioRecord
    await _vosk.stop();

    // Step 2: Wait for OS to fully release AudioRecord hardware
    await Future.delayed(const Duration(milliseconds: 200));

    // Quick ack — sayQuick uses existing player, doesn't block mic
    final acks = ['Ji Sir?', 'Hmm?', 'Haan boliye?', 'Ji?', 'Haan Sir?'];
    unawaited(_tts.sayQuick(acks[DateTime.now().millisecond % acks.length]));

    // Step 3: Whisper can now safely open AudioRecord
    if (!_realtimeActive && !_isListening && !_disposed) {
      _realtimeActive = true;
      await _startRealtimeListen();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REALTIME MODE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleRealtime() async {
    if (_realtimeActive) await _stopRealtime();
    else                 await _startRealtime();
  }

  Future<void> _startRealtime() async {
    _realtimeActive = true;
    _handsFreeMode  = false;
    _tts.setHandsFree(false);
    _tts.onAutoListenTrigger = null;
    notifyListeners();
    await _tts.stop();
    unawaited(_tts.speak('Haan Sir, bol!'));
    await _startRealtimeListen();
  }

  Future<void> _stopRealtime() async {
    _realtimeActive = false;
    _silenceTimer?.cancel();
    _handsFreeListenTimer?.cancel();
    if (_isListening) {
      _isListening = false;
      _whisper.cancelRecording();
    }
    _notif.updateOrb('still');
    _state = _state.copyWith(isListening: false, isSpeaking: false);
    notifyListeners();
    unawaited(_tts.speak('Okay Sir, ruk gayi.'));
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!_disposed) _vosk.enterWakeWordMode();
    });
  }

  Future<void> _startRealtimeListen() async {
    if (_disposed || !_realtimeActive || _isListening || _isSpeaking) return;

    _isListening = true;
    _state = _state.copyWith(
        isListening: true, lastResponse: 'Bol Sir, sun rahi hoon...');
    _notif.updateOrb('listening');
    notifyListeners();

    final started = await _whisper.startRecording();
    if (!started) {
      _isListening = false;
      _state = _state.copyWith(
          isListening: false, lastResponse: 'Mic permission do Sir.');
      notifyListeners();
      return;
    }

    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 8), () {
      if (_isListening && _realtimeActive) _stopRealtimeListen();
    });
  }

  Future<void> _stopRealtimeListen() async {
    if (!_isListening) return;
    _silenceTimer?.cancel();
    _isListening = false;
    _notif.updateOrb('thinking');
    _vosk.enterThinkingMode();
    _state = _state.copyWith(
        isListening: false, lastResponse: 'Samajh rahi hoon...');
    notifyListeners();

    final text = await _whisper.stopAndTranscribe();
    if (text != null && text.trim().isNotEmpty) {
      await receiveCommand(text.trim());
    } else {
      _state = _state.copyWith(lastResponse: 'Hmm, kuch sunai nahi diya Sir.');
      _notif.updateOrb('still');
      notifyListeners();
      if (!_realtimeActive) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!_disposed) _vosk.enterWakeWordMode();
        });
        return;
      }
      await Future.delayed(const Duration(milliseconds: 600));
      await _startRealtimeListen();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HANDS-FREE MODE (legacy — kept for compatibility)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleHandsFree() async {
    if (_realtimeActive) { await _stopRealtime(); return; }
    _handsFreeMode = !_handsFreeMode;
    _tts.setHandsFree(_handsFreeMode);

    if (_handsFreeMode) {
      _tts.onAutoListenTrigger = () async {
        if (_disposed || !_handsFreeMode || _isListening || _state.isProcessing) return;
        await Future.delayed(const Duration(milliseconds: 300));
        if (_disposed || !_handsFreeMode) return;
        await startListening();
        _handsFreeListenTimer?.cancel();
        _handsFreeListenTimer = Timer(const Duration(seconds: 6), () {
          if (_isListening && _handsFreeMode && !_disposed) stopListening();
        });
      };
      notifyListeners();
      await _processResponse('Hands-free ON! Bolna shuru karo Sir.');
    } else {
      _handsFreeListenTimer?.cancel();
      _tts.onAutoListenTrigger = null;
      if (_isListening) {
        _isListening = false;
        _state = _state.copyWith(isListening: false);
      }
      notifyListeners();
      await _processResponse('Okay Sir, hands-free band.');
    }
  }

  void toggleTts() {
    final v = !_state.ttsEnabled;
    _state = _state.copyWith(ttsEnabled: v);
    _tts.setEnabled(v);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN COMMAND PROCESSOR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> receiveCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    _handsFreeListenTimer?.cancel();
    _tts.resetIdleTimer();

    final userMsg    = ChatMessage.fromUser(cmd);
    final newHistory = List<String>.from(_state.dialogueHistory)..add(cmd);
    final newMsgs    = List<ChatMessage>.from(_state.messages)..add(userMsg);

    _state = _state.copyWith(
      lastCommand:     cmd,
      dialogueHistory: _trimHistory(newHistory),
      messages:        newMsgs,
      lastResponse:    'Ummm...',
      isActive:        true,
      isProcessing:    true,
      lastActivity:    DateTime.now(),
    );
    notifyListeners();

    await _tts.stop();
    _notif.updateOrb('thinking');
    _vosk.enterThinkingMode();

    try {
      String response = '';

      if (_isCodeCommand(cmd)) {
        _setMood(Mood.coding);
        response = await _ai.generateCode(cmd);

      } else if (_isScreenQuery(cmd)) {
        response = await _handleScreenQuery(cmd);

      } else if (_isChatCommand(cmd)) {
        _determineMood(cmd);
        response = await _ai.emotionalChat(cmd, _state.affectionLevel);

      } else {
        _setMood(Mood.calm);
        response = await _ai.generalQuery(
          cmd,
          useSearch:   _needsSearch(cmd),
          screenLayout: '', // no vision needed for generic queries
        );
      }

      final parsed = _parseGodCommand(response);
      if (parsed.type != GodCommand.unknown) {
        await _executeGodCommand(parsed, response);
      } else {
        await _processResponse(response);
      }

      await _saveNeuralMemory();

    } catch (e) {
      await _processResponse(
          'Sir, thodi problem aayi: '
          '${e.toString().substring(0, min(60, e.toString().length))}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VISION PIPELINE — "The Eyes"
  //
  // 1. scanScreen() runs on AccessibilityService → returns JSON with ALL
  //    interactive elements: {id, text, desc, x, y, w, h, clickable, editable}
  // 2. getScreenContext() → plain text of everything visible
  // 3. scanScreen JSON is injected into Gemini's SYSTEM PROMPT (not user msg)
  //    so AI treats it as factual context about current phone state
  //
  // Gemini response may contain vision commands:
  //   [COMMAND:CLICK_BY_ID,ID:com.whatsapp:id/send]
  //   [COMMAND:TAP_AT,X:980,Y:1840]
  //   [COMMAND:CLICK_BY_TEXT,TEXT:Send]
  //   [COMMAND:TYPE_TEXT,TEXT:Haan bhai kal milte hain]
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _handleScreenQuery(String cmd) async {
    // Run both scans in parallel — max 3s timeout each
    final results = await Future.wait([
      _access.scanScreen()
          .timeout(const Duration(seconds: 3), onTimeout: () => '{}'),
      _access.getScreenContext()
          .timeout(const Duration(seconds: 2), onTimeout: () => ''),
    ]);

    final scanJson  = results[0]; // structured JSON → Gemini system prompt
    final plainText = results[1]; // plain text     → appended to user message

    // User message = command + visible plain text
    final userMsg = plainText.isNotEmpty
        ? '$cmd\n\n[VISIBLE TEXT: $plainText]'
        : cmd;

    // scanJson → Gemini system prompt via screenLayout param
    // This is cleaner than embedding raw JSON in user message
    _setMood(Mood.calm);
    return await _ai.generalQuery(
      userMsg,
      screenLayout: scanJson, // ← Gemini "sees" screen elements
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — COMMAND PARSER
  // ══════════════════════════════════════════════════════════════════════════

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
      case 'OPEN_APP':       return ParsedCommand(GodCommand.openApp,           params);
      case 'SCROLL_REELS':   return ParsedCommand(GodCommand.scrollReels,       params);
      case 'LIKE_REEL':      return ParsedCommand(GodCommand.likeReel,          params);
      case 'YT_SEARCH':      return ParsedCommand(GodCommand.ytSearch,          params);
      case 'IG_COMMENT':     return ParsedCommand(GodCommand.instagramComment,  params);
      case 'FLIPKART_BUY':   return ParsedCommand(GodCommand.flipkartBuy,       params);
      case 'WHATSAPP_SEND':  return ParsedCommand(GodCommand.whatsappSend,      params);
      case 'WHATSAPP_CALL':  return ParsedCommand(GodCommand.whatsappVoiceCall, params);
      case 'WHATSAPP_VIDEO': return ParsedCommand(GodCommand.whatsappVideoCall, params);
      // Vision
      case 'CLICK_BY_ID':    return ParsedCommand(GodCommand.clickById,   params);
      case 'CLICK_BY_TEXT':  return ParsedCommand(GodCommand.clickByText, params);
      case 'TAP_AT':         return ParsedCommand(GodCommand.tapAt,       params);
      case 'TYPE_TEXT':      return ParsedCommand(GodCommand.typeText,    params);
      case 'PRESS_BACK':     return ParsedCommand(GodCommand.pressBack,   params);
      case 'PRESS_HOME':     return ParsedCommand(GodCommand.pressHome,   params);
      default:               return const ParsedCommand(GodCommand.unknown, {});
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — COMMAND EXECUTOR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _executeGodCommand(ParsedCommand cmd, String fullAiResponse) async {
    final clean = fullAiResponse
        .replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();

    switch (cmd.type) {

      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) {
          await _processResponse('$clean\n\n📱 App khol rahi hoon…');
          final ok = await _access.openApp(pkg);
          if (!ok) await _processResponse(
              'Accessibility Service enable karo Sir → Settings → God Mode.');
        }

      case GodCommand.scrollReels:
        await _processResponse('$clean\n\nScroll kar rahi hoon…');
        await _access.scrollDown(steps: 3);

      case GodCommand.likeReel:
        await _processResponse('$clean\n\n❤️ Like kar diya!');
        await _access.instagramLikeReel();

      case GodCommand.ytSearch:
        final query = cmd.params['QUERY'] ?? '';
        if (query.isNotEmpty) {
          await _processResponse('$clean\n\n🔍 YouTube pe dhoondh rahi hoon: "$query"');
          final ok = await _access.youtubeSearch(query);
          if (!ok) await _processResponse(
              'YouTube search mein problem. Accessibility enable hai?');
        }

      case GodCommand.instagramComment:
        final txt = cmd.params['TEXT'] ?? '';
        await _processResponse('$clean\n\n💬 Comment kar rahi hoon…');
        await _access.instagramPostComment(txt);

      case GodCommand.flipkartBuy:
        final product = cmd.params['PRODUCT'] ?? '';
        final size    = cmd.params['SIZE']    ?? 'M';
        await _processResponse('$clean\n\n🛍️ Flipkart pe search: $product');
        await _access.flipkartSearchProduct(product);
        await Future.delayed(const Duration(seconds: 3));
        await _access.flipkartSelectSize(size);
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartAddToCart();
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartGoToPayment();

      case GodCommand.whatsappSend:
        final to  = cmd.params['TO']  ?? '';
        final msg = cmd.params['MSG'] ?? '';
        await _processResponse('$clean\n\n📤 $to ko message bhej rahi hoon…');
        await _access.whatsappSendMessage(to, msg);

      case GodCommand.whatsappVoiceCall:
        final to = cmd.params['TO'] ?? '';
        if (to.isNotEmpty) {
          await _processResponse('$clean\n\n📞 $to ko call kar rahi hoon…');
          await _access.whatsappVoiceCall(to);
        }

      case GodCommand.whatsappVideoCall:
        final to = cmd.params['TO'] ?? '';
        if (to.isNotEmpty) {
          await _processResponse('$clean\n\n📹 $to ko video call kar rahi hoon…');
          await _access.whatsappVideoCall(to);
        }

      // ── Vision commands ─────────────────────────────────────────────────────

      case GodCommand.clickById:
        final id = cmd.params['ID'] ?? '';
        if (id.isNotEmpty) {
          await _access.clickById(id);
          await _processResponse(clean);
        }

      case GodCommand.clickByText:
        final text = cmd.params['TEXT'] ?? '';
        if (text.isNotEmpty) {
          await _access.clickText(text);
          await _processResponse(clean);
        }

      case GodCommand.tapAt:
        final x = int.tryParse(cmd.params['X'] ?? '0') ?? 0;
        final y = int.tryParse(cmd.params['Y'] ?? '0') ?? 0;
        if (x > 0 && y > 0) {
          await _access.tapAt(x, y);
          await _processResponse(clean);
        }

      case GodCommand.typeText:
        final text = cmd.params['TEXT'] ?? '';
        if (text.isNotEmpty) {
          await _access.typeText(text);
          await _processResponse(clean);
        }

      case GodCommand.pressBack:
        await _access.pressBack();
        await _processResponse(clean);

      case GodCommand.pressHome:
        await _access.pressHome();
        await _processResponse(clean);

      case GodCommand.unknown:
        await _processResponse(clean);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STT — manual mic button (tap to speak)
  // ══════════════════════════════════════════════════════════════════════════

  void Function(String)? _oneTimeTranscribeCallback;

  Future<void> startListening({void Function(String text)? onTranscribed}) async {
    _oneTimeTranscribeCallback = onTranscribed;
    if (_realtimeActive) { await _startRealtimeListen(); return; }
    if (_isListening) return;

    await _tts.stop();
    _isListening = true;
    _state = _state.copyWith(
        isListening: true, lastResponse: 'Bol Sir, sun rahi hoon…',
        isActive: true);
    _notif.updateOrb('listening');
    notifyListeners();

    final started = await _whisper.startRecording();
    if (!started) {
      _isListening = false;
      _oneTimeTranscribeCallback = null;
      _state = _state.copyWith(
          isListening: false,
          lastResponse: 'Mic start nahi hua. Permission check karo.');
      _notif.updateOrb('still');
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    if (_realtimeActive) { await _stopRealtimeListen(); return; }

    _handsFreeListenTimer?.cancel();
    _isListening = false;
    _tts.resetIdleTimer();
    _state = _state.copyWith(
        isListening: false, lastResponse: 'Samajh rahi hoon…');
    _notif.updateOrb('thinking');
    notifyListeners();

    final text = await _whisper.stopAndTranscribe();
    if (text != null && text.isNotEmpty) {
      final cb = _oneTimeTranscribeCallback;
      _oneTimeTranscribeCallback = null;
      if (cb != null) { cb(text); }
      else { await receiveCommand(text); }
    } else {
      _oneTimeTranscribeCallback = null;
      _state = _state.copyWith(
          lastResponse: 'Kuch suna nahi Sir, dobara bolein?');
      _notif.updateOrb('still');
      notifyListeners();
      if (_handsFreeMode && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 800));
        _tts.onAutoListenTrigger?.call();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERMISSION CHECK
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _checkAndGuidePermissions() async {
    try {
      final perms = await _access.checkAllPermissions();
      _permissions = {
        'accessibility':        perms['accessibility']        ?? false,
        'overlay':              perms['overlay']              ?? false,
        'notificationListener': perms['notificationListener'] ?? false,
        'foregroundService':    perms['foregroundService']    ?? false,
      };
      notifyListeners();

      final missing = <String>[];
      if (_permissions['accessibility'] != true) missing.add('Accessibility Service');
      if (_permissions['overlay']       != true) missing.add('Overlay Permission');

      if (missing.isEmpty) {
        if (kDebugMode) debugPrint('✅ All permissions granted');
        return;
      }

      await _processResponse(
        'Sir, permissions missing hain: ${missing.join(", ")}. '
        'Settings → Z.A.R.A. → Permissions mein enable kar do.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('_checkAndGuidePermissions: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AGENT MODE — auto-reply WhatsApp as proxy
  // ══════════════════════════════════════════════════════════════════════════

  bool   _agentModeActive  = false;
  bool   get agentModeActive => _agentModeActive;
  String _agentContactName = '';
  String get agentContact  => _agentContactName;

  Future<void> startAgentMode(String contact) async {
    _agentModeActive  = true;
    _agentContactName = contact;
    notifyListeners();
    final persona =
        'Tu Ravi ka AI assistant hai. '
        '$contact ke WhatsApp messages ka reply de as Ravi. '
        'Natural, friendly Hinglish mein. Short rakho.';
    await _access.whatsappStartAgent(contact, persona);
    await _processResponse(
        'Agent Mode ON! Ab main $contact ke messages ka reply karungi Sir.');
  }

  Future<void> stopAgentMode() async {
    _agentModeActive  = false;
    _agentContactName = '';
    notifyListeners();
    await _access.whatsappStopAgent();
    await _processResponse('Agent Mode OFF. Wapas aa gaye Sir!');
  }

  Future<void> handleAgentMessage(String contact, String message) async {
    if (!_agentModeActive) return;
    final reply = await _ai.emotionalChat(
        '$contact ne WhatsApp pe bheja: "$message"\n'
        'Reply karo as Ravi — short, natural Hinglish.',
        _state.affectionLevel);
    final clean = reply.replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();
    if (clean.isNotEmpty) await _access.whatsappSendMessage(contact, clean);
  }

  // ── Generic action ─────────────────────────────────────────────────────────
  Future<bool> performGenericAction(
    String action,
    String target, {
    String target2 = '',
    int    steps   = 3,
  }) => _access.performGenericAction(action, target,
           target2: target2, steps: steps);

  // ── Command chain ──────────────────────────────────────────────────────────
  Future<void> executeCommandChain(List<Map<String, dynamic>> commands) async {
    await _access.executeChain(commands);
  }

  // ── Volume callback ────────────────────────────────────────────────────────
  void Function(double)? onVolumeLevel;

  Future<String?> speakLastResponse() async {
    if (_isSpeaking) return null;
    final text = _state.lastResponse
        .replaceAll(RegExp(r'[\*\[\]#>]'), '').trim();
    if (text.isEmpty) return null;
    unawaited(_tts.speak(text, mood: _state.mood));
    return text;
  }

  Future<void> processAudio(String audioPath) async {
    _isListening = false;
    _state = _state.copyWith(lastResponse: 'Sun rahi hoon…');
    notifyListeners();
    final text = await _ai.speechToText(audioPath: audioPath);
    if (text != null && text.trim().isNotEmpty) {
      await receiveCommand(text.trim());
    } else {
      await _processResponse('Hmm Sir, kuch samajh nahi aaya. Louder bolein?');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESPONSE PROCESSOR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _processResponse(String aiMessage) async {
    if (_disposed) return;

    final zaraMsg    = ChatMessage.fromZara(aiMessage);
    final newHistory = List<String>.from(_state.dialogueHistory)
      ..add('Z.A.R.A.: $aiMessage');
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
    if (_state.ttsEnabled) unawaited(_tts.speak(aiMessage, mood: _state.mood));
  }

  // ── Proactive notifications ────────────────────────────────────────────────
  PendingReply? _pendingReply;
  PendingReply? get pendingReply => _pendingReply;

  void _handleProactiveNotification(NotificationAlert alert) {
    if (alert.zaraAlert.isEmpty) return;
    if (alert.package_.contains('whatsapp')   ||
        alert.package_.contains('telegram')   ||
        alert.package_.contains('instagram')  ||
        alert.package_.contains('messaging')) {
      _pendingReply = PendingReply(
        app:     alert.app,
        pkg:     alert.package_,
        contact: alert.title,
        message: alert.text,
      );
    }
    final zaraMsg = ChatMessage.fromZara(alert.zaraAlert);
    final msgs    = List<ChatMessage>.from(_state.messages)..add(zaraMsg);
    _state = _state.copyWith(
        messages: msgs, lastResponse: alert.zaraAlert,
        isActive: true, lastActivity: DateTime.now());
    notifyListeners();
    if (_state.ttsEnabled) unawaited(_tts.speak(alert.zaraAlert));
  }

  Future<void> approvePendingReply(String replyText) async {
    final pending = _pendingReply;
    if (pending == null) return;
    _pendingReply = null;
    notifyListeners();

    String reply = replyText.trim();
    if (reply.isEmpty) {
      reply = await _ai.emotionalChat(
        'User ne approve kiya reply "${pending.message}" ko '
        '"${pending.contact}" ke liye. '
        'Short natural Hinglish reply generate karo.',
        _state.affectionLevel) ?? '';
    }
    if (reply.isEmpty) return;

    if (pending.pkg.contains('whatsapp')) {
      await _access.whatsappSendMessage(pending.contact, reply);
      await _processResponse(
          'Done Sir! "${pending.contact}" ko reply: "$reply"');
    } else {
      await _processResponse(
          'Reply: "$reply" — Sir manually paste kar do ${pending.app} mein.');
    }
  }

  void dismissPendingReply() { _pendingReply = null; notifyListeners(); }

  // ══════════════════════════════════════════════════════════════════════════
  // GUARDIAN MODE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleGuardianMode() async {
    final active = !_state.isGuardianActive;
    _state = _state.copyWith(
        isGuardianActive: active,
        mood: active ? Mood.angry : Mood.calm,
        lastActivity: DateTime.now());
    notifyListeners();
    await _saveNeuralMemory();

    if (active) {
      final camOk = await _camera.checkPermission();
      final locOk = await _location.checkPermission();
      if (camOk && locOk) {
        await _camera.initializeFrontCamera();
        await _location.startTracking();
        await _processResponse(
            'Guardian Mode ACTIVE Sir! Koi phone haath bhi lagaye toh pakad lungi! 😤');
      } else {
        await _processResponse(
            'Camera aur location permission chahiye. Settings mein enable karo.');
      }
    } else {
      await _location.stopTracking();
      await _processResponse('Guardian Mode STANDBY. Aap safe hain Sir.');
    }
  }

  Future<void> reportIntruder(String photoPath) async {
    try {
      _state = _state.copyWith(
          lastIntruderPhoto: photoPath, mood: Mood.angry,
          lastActivity: DateTime.now());
      notifyListeners();
      await _saveNeuralMemory();
      final loc  = await _location.getCurrentLocation();
      final link = loc != null ? _location.getGoogleMapsLink() : null;
      await _email.sendIntruderAlert(
          photoPath: photoPath, locationLink: link,
          address: _location.getFormattedAddress());
      await _processResponse('Intruder alert aur photo bhej diya Sir! 📸');
    } catch (_) {
      await _processResponse('Alert mein problem aayi Sir.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  void editMessage(String id, String newText) {
    final msgs = _state.messages
        .map((m) => m.id == id ? m.copyWith(text: newText, isEdited: true) : m)
        .toList();
    _state = _state.copyWith(messages: msgs);
    notifyListeners(); _saveNeuralMemory();
  }

  void deleteMessage(String id) {
    _state = _state.copyWith(
        messages: _state.messages.where((m) => m.id != id).toList());
    notifyListeners(); _saveNeuralMemory();
  }

  void newChat() {
    final archives = List<ChatSession>.from(_state.chatArchives);
    if (_state.messages.isNotEmpty) {
      final topic = _state.lastCommand.length > 30
          ? _state.lastCommand.substring(0, 30) : _state.lastCommand;
      archives.insert(0, ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        topicName: topic.isEmpty ? 'Baat cheet' : topic,
        messages: List<String>.from(_state.dialogueHistory),
        chatMessages: List<ChatMessage>.from(_state.messages),
        timestamp: DateTime.now(),
      ));
    }
    _state = ZaraState.initial().copyWith(
      chatArchives:   archives.take(20).toList(),
      affectionLevel: _state.affectionLevel,
      mood:           Mood.calm,
      ttsEnabled:     _state.ttsEnabled,
    );
    notifyListeners();
    _ai.clearHistory();
  }

  List<ChatSession> get chatArchives => _state.chatArchives;

  void loadArchivedChat(String sessionId) {
    final session = _state.chatArchives.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => ChatSession(
            id: '', topicName: '', messages: [],
            timestamp: DateTime.now()));
    if (session.id.isEmpty) return;
    final msgs = session.chatMessages.isNotEmpty
        ? session.chatMessages
        : session.messages.map((t) => ChatMessage.system(t)).toList();
    _state = _state.copyWith(
        messages: msgs, dialogueHistory: session.messages,
        lastCommand: session.topicName, isActive: true);
    notifyListeners();
  }

  void loadSession(ChatSession s) => loadArchivedChat(s.id);

  void deleteArchivedChat(String id) {
    _state = _state.copyWith(
        chatArchives: _state.chatArchives.where((s) => s.id != id).toList());
    notifyListeners(); _saveNeuralMemory();
  }

  void clearAllArchives() {
    _state = _state.copyWith(chatArchives: []);
    notifyListeners(); _saveNeuralMemory();
  }

  void renameArchivedChat(String id, String name) {
    if (name.trim().isEmpty) return;
    final a = _state.chatArchives.map((s) => s.id != id ? s : ChatSession(
        id: s.id, topicName: name.trim(), messages: s.messages,
        chatMessages: s.chatMessages, timestamp: s.timestamp)).toList();
    _state = _state.copyWith(chatArchives: a);
    notifyListeners(); _saveNeuralMemory();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLASSIFIERS
  // ══════════════════════════════════════════════════════════════════════════

  bool _isCodeCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('code')     || l.contains('dart')     ||
           l.contains('flutter')  || l.contains('fix')      ||
           l.contains('error')    || l.contains('function');
  }

  bool _isChatCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('pyar')  || l.contains('love')  || l.contains('hello') ||
           l.contains('hi')    || l.contains('tum')   || l.contains('zara')  ||
           l.contains('kaisi') || l.contains('ravi');
  }

  bool _needsSearch(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('search') || l.contains('news')   ||
           l.contains('weather')|| l.contains('latest') ||
           l.contains('today');
  }

  bool _isScreenQuery(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('screen')      || l.contains('dikha')      ||
           l.contains('dikh raha')   || l.contains('yahan kya')  ||
           l.contains('kya open')    || l.contains('abhi kya')   ||
           l.contains('is app mein') || l.contains('kya likha')  ||
           l.contains('page pe')     || l.contains('click karo') ||
           l.contains('tap karo')    || l.contains('press karo') ||
           l.contains('button dabao');
  }

  void _determineMood(String cmd) {
    final l = cmd.toLowerCase();
    if (l.contains('pyar')  || l.contains('love') ||
        l.contains('thank') || l.contains('miss')) {
      _state = _state.copyWith(
          affectionLevel: (_state.affectionLevel + 5).clamp(0, 100),
          mood: Mood.romantic);
    } else if (l.contains('gussa') || l.contains('angry') ||
               l.contains('hate')) {
      _state = _state.copyWith(
          affectionLevel: (_state.affectionLevel - 10).clamp(0, 100),
          mood: Mood.ziddi);
    }
    notifyListeners();
  }

  void _setMood(Mood m) => _state = _state.copyWith(mood: m);

  // ══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadNeuralMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data  = prefs.getString('zara_neural_state');
      if (data != null) {
        _state = ZaraState.fromMap(jsonDecode(data));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveNeuralMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zara_neural_state', jsonEncode(_state.toMap()));
    } catch (_) {}
  }

  List<String> _trimHistory(List<String> h) =>
      h.length > 20 ? h.sublist(h.length - 20) : h;

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> dispose() async {
    _disposed       = true;
    _realtimeActive = false;
    _silenceTimer?.cancel();
    _handsFreeListenTimer?.cancel();
    _tts.onAutoListenTrigger = null;
    await _vosk.dispose();           // releases WakeLock + stops AudioRecord
    await _whisper.stopAlwaysOn();
    await _tts.dispose();
    super.dispose();
  }
}

// ── Pending Reply ──────────────────────────────────────────────────────────────
class PendingReply {
  final String app;
  final String pkg;
  final String contact;
  final String message;
  const PendingReply({
    required this.app,
    required this.pkg,
    required this.contact,
    required this.message,
  });
}
