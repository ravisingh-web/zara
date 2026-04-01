// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. v16.0 — Neural Intelligence Controller
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIXES v16:                                                             ║
// ║                                                                         ║
// ║  🔴 BUG 1: MethodChannel conflict — VoskService + AccessibilityService  ║
// ║     both called setMethodCallHandler() on same channel                  ║
// ║     FIX: _access.setupChannelHandler() called FIRST in initialize()    ║
// ║           VoskService.dispatchNativeCall() used for vosk events        ║
// ║                                                                         ║
// ║  🔴 BUG 2: TTS errors silently swallowed, UI shows nothing             ║
// ║     FIX: _tts.onError wired → _processResponse(errorMsg)              ║
// ║           User hears/sees actual error in Hindi                        ║
// ║                                                                         ║
// ║  🔴 BUG 3: sayQuick() called even when ElevenLabs key missing          ║
// ║     FIX: isTtsConfigured check before ack speak on wake word           ║
// ║                                                                         ║
// ║  🔴 BUG 4: Vosk restart fails after TTS error (mode stays 'speaking')  ║
// ║     FIX: _vosk.enterWakeWordMode() always in onSpeakDone finally block ║
// ║                                                                         ║
// ║  🔴 BUG 5: initialize() order issue — VoskService.start() called       ║
// ║     BEFORE setupChannelHandler() → events lost on startup             ║
// ║     FIX: setupChannelHandler() is first thing in initialize()         ║
// ╚══════════════════════════════════════════════════════════════════════════╝

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
  facebookPost,
  clickById,
  clickByText,
  tapAt,
  typeText,
  pressBack,
  pressHome,
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

    // ✅ FIX BUG 1 + BUG 5: Setup channel handler FIRST before anything else
    // This ensures events from native side are not lost during startup
    _access.setupChannelHandler();

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
      _vosk.enterSpeakingMode();
      notifyListeners();
    };

    _tts.onVolumeLevel = (v) {
      if (_disposed) return;
      onVolumeLevel?.call(v);
    };

    // ✅ FIX BUG 2: Wire TTS errors to UI so user knows what went wrong
    _tts.onError = (errorMsg) {
      if (_disposed) return;
      if (kDebugMode) debugPrint('TTS ERROR → UI: $errorMsg');
      _state = _state.copyWith(
        lastResponse: errorMsg,
        isProcessing: false,
      );
      // ✅ FIX BUG 4: Always reset vosk mode on TTS error
      _vosk.enterWakeWordMode();
      notifyListeners();
      // Also restart vosk so wake word detection resumes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_disposed && !_wakeWordListening && !_realtimeActive) {
          startWakeWordEngine();
        }
      });
    };

    _tts.onSpeakDone = () {
      if (_disposed) return;
      _isSpeaking = false;
      _state = _state.copyWith(isSpeaking: false);
      _notif.updateOrb('still');

      // ✅ FIX BUG 4: Always call enterWakeWordMode here — was missing on error path
      _vosk.enterWakeWordMode();
      notifyListeners();

      if (!_realtimeActive) {
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (!_disposed && !_realtimeActive) {
            await _vosk.start();
          }
        });
      }

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

    _vosk.onWakeDetected = (word) {
      if (_disposed || _isSpeaking) {
        _vosk.enterWakeWordMode();
        return;
      }
      if (kDebugMode) debugPrint('🔔 "$word" → command mode');
      _onWakeWordDetected(word);
    };

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
        final cleaned = _stripWakeWord(text);
        if (cleaned.isNotEmpty) receiveCommand(cleaned);
      }
    };

    _vosk.onEngineChanged = (active) {
      _wakeWordListening = active;
      // Update MIC dot in UI when wake word engine starts/stops
      _permissions = Map<String, bool>.from(_permissions)
        ..['microphone'] = active || _isListening;
      notifyListeners();
    };

    _vosk.onError = (err) {
      if (kDebugMode) debugPrint('Vosk: $err');
      // If mic permission denied, inform user
      if (err.contains('no_mic_permission') || err.contains('permission')) {
        _state = _state.copyWith(
            lastResponse: 'Mic permission chahiye Sir! Settings mein do.');
        notifyListeners();
      }
    };

    // Agent mode
    _access.setAgentMessageHandler((contact, message) {
      if (!_disposed) handleAgentMessage(contact, message);
    });

    // ✅ FIX: VoskService agentMessage dispatch via VoskService callback
    _vosk.onAgentMessage = (contact, message) {
      _access.dispatchAgentMessage(contact, message);
    };

    // ── Auto-start Vosk — 3s delay for engine + channel handler to settle ─────
    // (was 2s, increased to 3s to ensure setupChannelHandler() is fully effective)
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) startWakeWordEngine();
    });

    _checkAndGuidePermissions();

    if (kDebugMode) {
      debugPrint('╔══ ZARA v16.0 ════════════════════════╗');
      debugPrint('║ Gemini    : ${ApiKeys.geminiReady  ? "✅" : "❌ MISSING"}');
      debugPrint('║ ElevenLabs: ${ApiKeys.elevenReady  ? "✅" : "❌ MISSING — TTS OFF"}');
      debugPrint('║ OpenAI    : ${ApiKeys.openaiReady  ? "✅" : "— optional"}');
      debugPrint('║ LiveKit   : ${ApiKeys.livekitReady ? "✅" : "— optional"}');
      debugPrint('║ Vosk      : ✅ offline');
      debugPrint('║ Channel   : ✅ single handler (conflict fixed)');
      debugPrint('║ Model     : ${ApiKeys.geminiModel}');
      debugPrint('╚══════════════════════════════════════╝');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WAKE WORD ENGINE CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> startWakeWordEngine() async {
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

    // Step 2: OS mic release buffer (OEM-safe: Exynos/Snapdragon ~180ms)
    await Future.delayed(const Duration(milliseconds: 200));

    // ✅ FIX BUG 3: Only sayQuick if ElevenLabs key is configured
    if (_tts.isTtsConfigured) {
      final acks = ['Ji Sir?', 'Hmm?', 'Haan boliye?', 'Ji?', 'Haan Sir?'];
      await _tts.sayQuick(acks[DateTime.now().millisecond % acks.length]);
      // 300ms buffer after TTS — AudioFocus release is async on Android
      await Future.delayed(const Duration(milliseconds: 300));
    } else {
      // No TTS key — skip ack, show text in UI instead
      _state = _state.copyWith(lastResponse: 'Haan Sir, bol do...');
      notifyListeners();
    }

    // Step 4: Whisper can now safely open AudioRecord
    if (!_realtimeActive && !_isListening && !_disposed) {
      _realtimeActive = true;
      await _startRealtimeListen();
      if (!_isListening && _realtimeActive) {
        _realtimeActive = false;
        _vosk.enterWakeWordMode();
        await _vosk.start();
      }
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
      final cleaned = _stripWakeWord(text.trim());
      if (cleaned.isEmpty) {
        await _startRealtimeListen();
        return;
      }
      await receiveCommand(cleaned);
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
  // HANDS-FREE MODE
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
    final cleaned = _stripWakeWord(cmd);
    if (cleaned.isEmpty) return;
    _handsFreeListenTimer?.cancel();
    _tts.resetIdleTimer();

    final userMsg    = ChatMessage.fromUser(cleaned);
    final newHistory = List<String>.from(_state.dialogueHistory)..add(cleaned);
    final newMsgs    = List<ChatMessage>.from(_state.messages)..add(userMsg);

    _state = _state.copyWith(
      lastCommand:     cleaned,
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

      if (_isCodeCommand(cleaned)) {
        _setMood(Mood.coding);
        response = await _ai.generateCode(cleaned);

      } else if (_isChatCommand(cleaned)) {
        _determineMood(cleaned);
        response = await _ai.emotionalChat(cleaned, _state.affectionLevel);

      } else {
        response = await _handleScreenQuery(cleaned);
      }

      final commands = _parseAllGodCommands(response);
      if (commands.isNotEmpty && commands.first.type != GodCommand.unknown) {
        await _executeGodCommandChain(commands, response);
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
  // VISION PIPELINE
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _handleScreenQuery(String cmd) async {
    final results = await Future.wait([
      _access.scanScreen()
          .timeout(const Duration(seconds: 3), onTimeout: () => '{}'),
      _access.getScreenContext()
          .timeout(const Duration(seconds: 2), onTimeout: () => ''),
    ]);

    final scanJson  = results[0];
    final plainText = results[1];

    final userMsg = plainText.isNotEmpty
        ? '$cmd\n\n[VISIBLE TEXT: $plainText]'
        : cmd;

    _setMood(Mood.calm);
    return await _ai.generalQuery(
      userMsg,
      screenLayout: scanJson,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — COMMAND PARSER
  // ══════════════════════════════════════════════════════════════════════════

  List<ParsedCommand> _parseAllGodCommands(String text) {
    final results = <ParsedCommand>[];
    final matches = RegExp(r'\[COMMAND:(\w+)([^\]]*)\]').allMatches(text);
    for (final match in matches) {
      final cmdStr = match.group(1)?.toUpperCase() ?? '';
      final rest   = match.group(2) ?? '';
      final params = <String, String>{};
      for (final kv in RegExp(r',\s*(\w+):([^,\]]+)').allMatches(rest)) {
        params[kv.group(1)!.trim().toUpperCase()] = kv.group(2)!.trim();
      }
      GodCommand type;
      switch (cmdStr) {
        case 'OPEN_APP':       type = GodCommand.openApp;           break;
        case 'SCROLL_REELS':   type = GodCommand.scrollReels;       break;
        case 'LIKE_REEL':      type = GodCommand.likeReel;          break;
        case 'YT_SEARCH':      type = GodCommand.ytSearch;          break;
        case 'IG_COMMENT':     type = GodCommand.instagramComment;  break;
        case 'FLIPKART_BUY':   type = GodCommand.flipkartBuy;       break;
        case 'WHATSAPP_SEND':  type = GodCommand.whatsappSend;      break;
        case 'WHATSAPP_CALL':  type = GodCommand.whatsappVoiceCall; break;
        case 'WHATSAPP_VIDEO': type = GodCommand.whatsappVideoCall; break;
        case 'FACEBOOK_POST':  type = GodCommand.facebookPost;      break;
        case 'CLICK_BY_ID':    type = GodCommand.clickById;         break;
        case 'CLICK_BY_TEXT':  type = GodCommand.clickByText;       break;
        case 'TAP_AT':         type = GodCommand.tapAt;             break;
        case 'TYPE_TEXT':      type = GodCommand.typeText;          break;
        case 'PRESS_BACK':     type = GodCommand.pressBack;         break;
        case 'PRESS_HOME':     type = GodCommand.pressHome;         break;
        default:               type = GodCommand.unknown;
      }
      if (type != GodCommand.unknown) results.add(ParsedCommand(type, params));
    }
    if (results.isEmpty) return [const ParsedCommand(GodCommand.unknown, {})];
    return results;
  }

  ParsedCommand _parseGodCommand(String text) => _parseAllGodCommands(text).first;

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — COMMAND CHAIN EXECUTOR
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _executeGodCommandChain(
      List<ParsedCommand> commands, String fullAiResponse) async {
    final clean = fullAiResponse
        .replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();

    if (clean.isNotEmpty) await _processResponse(clean);

    for (int i = 0; i < commands.length; i++) {
      if (_disposed) break;
      await _executeSingleCommand(commands[i], '');
      if (i < commands.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }
  }

  Future<void> _executeGodCommand(ParsedCommand cmd, String fullAiResponse) =>
      _executeGodCommandChain([cmd], fullAiResponse);

  Future<void> _executeSingleCommand(ParsedCommand cmd, String clean) async {
    switch (cmd.type) {

      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) {
          final ok = await _access.openApp(pkg);
          if (!ok) await _processResponse(
              'Accessibility Service enable karo Sir → Settings → God Mode.');
        }

      case GodCommand.scrollReels:
        final steps = int.tryParse(cmd.params['STEPS'] ?? '3') ?? 3;
        await _access.scrollDown(steps: steps.clamp(1, 20));

      case GodCommand.likeReel:
        await _access.instagramLikeReel();

      case GodCommand.ytSearch:
        final query = cmd.params['QUERY'] ?? '';
        if (query.isNotEmpty) {
          final ok = await _access.youtubeSearch(query);
          if (!ok) await _processResponse(
              'YouTube search mein problem. Accessibility enable hai?');
        }

      case GodCommand.instagramComment:
        final txt = cmd.params['TEXT'] ?? '';
        await _access.instagramPostComment(txt);

      case GodCommand.flipkartBuy:
        final product = cmd.params['PRODUCT'] ?? '';
        final size    = cmd.params['SIZE']    ?? 'M';
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
        await _access.whatsappSendMessage(to, msg);

      case GodCommand.whatsappVoiceCall:
        final to = cmd.params['TO'] ?? '';
        if (to.isNotEmpty) await _access.whatsappVoiceCall(to);

      case GodCommand.whatsappVideoCall:
        final to = cmd.params['TO'] ?? '';
        if (to.isNotEmpty) await _access.whatsappVideoCall(to);

      case GodCommand.facebookPost:
        final text = cmd.params['TEXT'] ?? '';
        if (text.isNotEmpty) await _access.facebookPost(text);

      case GodCommand.clickById:
        final id = cmd.params['ID'] ?? '';
        if (id.isNotEmpty) await _access.clickById(id);

      case GodCommand.clickByText:
        final text = cmd.params['TEXT'] ?? '';
        if (text.isNotEmpty) await _access.clickText(text);

      case GodCommand.tapAt:
        final x = int.tryParse(cmd.params['X'] ?? '0') ?? 0;
        final y = int.tryParse(cmd.params['Y'] ?? '0') ?? 0;
        if (x > 0 && y > 0) await _access.tapAt(x, y);

      case GodCommand.typeText:
        final text = cmd.params['TEXT'] ?? '';
        if (text.isNotEmpty) await _access.typeText(text);

      case GodCommand.pressBack:
        await _access.pressBack();

      case GodCommand.pressHome:
        await _access.pressHome();

      case GodCommand.unknown:
        await _processResponse(clean);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STT — manual mic button
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
      // Check microphone via Vosk engine status
      final micOk = _wakeWordListening || _isListening;
      _permissions = {
        'accessibility':        perms['accessibility']        ?? false,
        'overlay':              perms['overlay']              ?? false,
        'notificationListener': perms['notificationListener'] ?? false,
        'foregroundService':    perms['foregroundService']    ?? false,
        'microphone':           micOk,
      };
      notifyListeners();

      final missing = <String>[];
      if (_permissions['accessibility'] != true) missing.add('Accessibility Service');
      if (_permissions['overlay']       != true) missing.add('Overlay Permission');

      if (missing.isEmpty) {
        if (kDebugMode) debugPrint('✅ All permissions granted');
        return;
      }

      // ✅ Only warn in UI text, don't attempt TTS if key not set
      final msg = 'Sir, permissions missing: ${missing.join(", ")}. '
          'Settings → Z.A.R.A. → Enable karo.';
      _state = _state.copyWith(lastResponse: msg);
      notifyListeners();
      if (_tts.isTtsConfigured) {
        unawaited(_tts.speak(msg));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_checkAndGuidePermissions: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AGENT MODE
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

  Future<void> executeCommandChain(List<Map<String, dynamic>> commands) async {
    await _access.executeChain(commands);
  }

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

  static const _wakeWords = [
    'hii zara', 'hi zara', 'hey zara', 'zara sunna',
    'zara suno', 'suno zara', 'sunna zara',
    'hii', 'hey', 'zara',
  ];

  String _stripWakeWord(String text) {
    var lower = text.toLowerCase().trim();
    final sorted = List<String>.from(_wakeWords)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final w in sorted) {
      if (lower.startsWith(w)) {
        lower = lower.substring(w.length).trim();
        lower = lower.replaceFirst(RegExp(r'^[,\.\-\s]+'), '').trim();
        if (kDebugMode) debugPrint('🧹 WakeStrip: "$text" → "$lower"');
        return lower;
      }
    }
    return text.trim();
  }

  bool _isCodeCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('code')    || l.contains('dart')    ||
           l.contains('flutter') || l.contains('fix')     ||
           l.contains('error')   || l.contains('function');
  }

  bool _isChatCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('pyar')   || l.contains('love')    ||
           l.contains('miss')   || l.contains('kaisi ho') ||
           l.contains('kya kar rahi') || l.contains('tum kahan') ||
           l.contains('boyfriend') || l.contains('girlfriend') ||
           l.contains('shayari') || l.contains('poem')   ||
           l.contains('joke')   || l.contains('hasao');
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
    await _vosk.dispose();
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
