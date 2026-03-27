// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. v9.0 — Realtime Neural Intelligence Controller
//
// ✅ REALTIME VOICE — mic se bolo, Zara turant reply kare, loop chalti rahe
// ✅ ORB — sirf speaking/listening pe animate, warna BILKUL STILL
// ✅ YouTube search — proper auto-type + submit (FIXED)
// ✅ Instagram/WhatsApp/Flipkart all flows working
// ✅ Screen context injection into Gemini
// ✅ Permission guard on startup
// ✅ Hands-free continuous loop

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
import 'package:zara/services/automation_service.dart';
import 'package:zara/services/livekit_service.dart';

// ── God Mode command types ─────────────────────────────────────────────────────
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

  // ── Services ───────────────────────────────────────────────────────────────
  final _ai       = AiApiService();
  final _camera   = CameraService();
  final _location = LocationService();
  final _access   = AccessibilityService();
  final _email    = EmailService();
  final _tts      = ZaraTtsService();
  final _notif    = NotificationService();
  final _whisper  = WhisperSttService();
  final _livekit  = LiveKitService();
  final _auto     = AutomationService(); // PipeDream + Sheets

  // ── State ──────────────────────────────────────────────────────────────────
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  bool _isListening    = false;
  bool get isListening => _isListening;

  bool _isSpeaking    = false;
  bool get isSpeaking => _isSpeaking;

  // ── Realtime / Hands-free ──────────────────────────────────────────────────
  bool _handsFreeMode    = false;
  bool get handsFreeMode => _handsFreeMode;

  bool _realtimeActive   = false;
  bool get realtimeActive => _realtimeActive;

  Timer? _handsFreeListenTimer;
  Timer? _silenceTimer;         // stops listening after N seconds silence

  // ── Permissions ────────────────────────────────────────────────────────────
  Map<String, bool> _permissions = {};
  Map<String, bool> get permissions => _permissions;
  bool get allPermissionsGranted => _permissions.values.every((v) => v);

  bool _disposed = false;

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    await _loadNeuralMemory();

    try { await _email.initialize(); } catch (_) {}

    // TTS init
    try {
      await _tts.initialize();
      _tts.setEnabled(true);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init: $e');
    }

    // TTS callbacks → orb state update
    _tts.onSpeakStart = () {
      if (_disposed) return;
      _isSpeaking = true;
      _state = _state.copyWith(isSpeaking: true);
      _notif.updateOrb('speaking');
      notifyListeners();
    };

    // ── TTS volume → drives orb animation in home screen ────────────────
    _tts.onVolumeLevel = (v) {
      if (_disposed) return;
      onVolumeLevel?.call(v);
    };

    _tts.onSpeakDone = () {
      if (_disposed) return;
      _isSpeaking = false;
      _state = _state.copyWith(isSpeaking: false);
      // Orb goes STILL after speaking — not idle animation, fully calm
      _notif.updateOrb('still');
      notifyListeners();

      // Realtime loop: after Zara speaks → auto-listen again
      if (_realtimeActive && !_disposed) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_realtimeActive && !_disposed && !_isListening) {
            _startRealtimeListen();
          }
        });
      }
    };

    _tts.startIdleSystem();

    // Notification service
    try {
      await _notif.initialize();
      await _notif.startForegroundService();
      _notif.onProactiveAlert = (alert) => _handleProactiveNotification(alert);

    // ForegroundService → Flutter: wake word start request
    _notif.onRequestWakeWordStart = () {
      if (!_disposed && !_wakeWordListening) startWakeWordEngine();
    };
    } catch (e) {
      if (kDebugMode) debugPrint('NotifService init: $e');
    }

    // ── AutomationService — PipeDream + Sheets ────────────────────────────
    _auto.onNewSheetRow = (rowText) {
      if (_disposed) return;
      // Zara reads new Sheets row aloud
      final msg = 'Sir, Google Sheets mein naya row aaya: $rowText';
      _processResponse(msg);
    };
    if (kDebugMode) debugPrint('AutomationService: n8n=${ApiKeys.n8nReady}, sheets=${ApiKeys.sheetsReady}');
    if (ApiKeys.n8nReady && ApiKeys.sheetsReady) {
      _auto.startPolling();
    }
    // Whisper 5s chunks → onTranscription → receiveCommand
    // Runs silently in background without mic button tap
    _whisper.onTranscription = (text) {
      if (_disposed || _isSpeaking || _isListening) return;
      if (kDebugMode) debugPrint('🎙️ AlwaysOn heard: "$text"');
      receiveCommand(text);
    };
    _whisper.onAlwaysOnChange = (active) {
      if (_disposed) return;
      notifyListeners();
    };
    // Start always-on only if OpenAI key is set
    if (ApiKeys.openaiKey.isNotEmpty) {
      _whisper.startAlwaysOn().then((ok) {
        if (kDebugMode) debugPrint('AlwaysOn started: $ok');
      });
    }

    // ── Wake Word + Agent mode callbacks ──────────────────────────────────
    // Single setMethodCallHandler handles: PCM ready, wake word, agent msgs
    _access.setWakeWordHandlers(
      onPcmReady: (pcmBase64, sampleRate) async {
        // PCM chunk from native → transcribe with Whisper
        if (_disposed || _isSpeaking) return;
        final text = await _whisper.transcribePcmBase64(pcmBase64, sampleRate);
        if (text == null || text.trim().isEmpty) return;
        // Check if it's a wake word
        final lower = text.toLowerCase().trim();
        final isWake = ['hii zara', 'hi zara', 'hey zara', 'sunna', 'suno', 'zara sunna']
            .any((w) => lower.contains(w));
        if (isWake) {
          // Fire wake word → Zara responds + starts listening for command
          _onWakeWordDetected(text);
        } else if (realtimeActive) {
          // Not a wake word but realtime is on — treat as command
          receiveCommand(text);
        }
      },
      onDetected: (transcript) {
        if (!_disposed) _onWakeWordDetected(transcript);
      },
    );

    _access.setAgentMessageHandler((contact, message) {
      if (!_disposed) handleAgentMessage(contact, message);
    });

    // ── Wake Word engine — auto start ──────────────────────────────────────
    // Porcupine (preferred) OR VAD+Whisper fallback
    // Both paths use startWakeWord() on native side
    if (ApiKeys.openaiKey.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed) startWakeWordEngine();
      });
    }

    // ── Permission Force-Check — guide user if missing ────────────────────
    _checkAndGuidePermissions();

    if (kDebugMode) {
      debugPrint('=== ZARA v9.0 ===');
      debugPrint('Gemini    : ${ApiKeys.geminiKey.isNotEmpty ? "✅" : "❌ MISSING"}');
      debugPrint('ElevenLabs: ${ApiKeys.elevenKey.isNotEmpty ? "✅" : "❌ MISSING — Zara nahi bolegi"}');
      debugPrint('OpenAI    : ${ApiKeys.openaiKey.isNotEmpty ? "✅" : "❌ MISSING — mic kaam nahi karega"}');
      debugPrint('Model     : ${ApiKeys.geminiModel}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REALTIME MODE — main new feature
  //
  // Flow:
  //   User taps mic → realtime ON
  //   Zara listens (red pulsing orb)
  //   User speaks → Whisper transcribes
  //   Gemini replies → ElevenLabs speaks (purple orb)
  //   After speaking done → auto-listen again (loop)
  //   User taps mic again → realtime OFF
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleRealtime() async {
    if (_realtimeActive) {
      await _stopRealtime();
    } else {
      await _startRealtime();
    }
  }

  Future<void> _startRealtime() async {
    _realtimeActive  = true;
    _handsFreeMode   = false;
    _tts.setHandsFree(false);
    _tts.onAutoListenTrigger = null;
    notifyListeners();

    await _tts.stop();

    // ✅ FIX: Stop AlwaysOn FIRST — Android mic is exclusive resource
    // AlwaysOn + Realtime ek saath = dono fail silently
    if (_whisper.alwaysOnActive) {
      await _whisper.stopAlwaysOn();
      if (kDebugMode) debugPrint('🎙️ AlwaysOn stopped — Realtime starting');
    }
    // Also stop wake word engine — mic conflict with AudioRecord in native
    if (_wakeWordListening) await stopWakeWordEngine();

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

    // ✅ FIX: Restart background listeners after realtime ends
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_disposed) {
      // Restart wake word engine
      if (!_wakeWordListening) startWakeWordEngine();
      // Restart AlwaysOn only if wake word is NOT active (mic conflict)
      if (!_wakeWordListening && ApiKeys.openaiKey.isNotEmpty &&
          !_whisper.alwaysOnActive) {
        _whisper.startAlwaysOn();
      }
    }
  }

  Future<void> _startRealtimeListen() async {
    if (_disposed || !_realtimeActive || _isListening || _isSpeaking) return;

    _isListening = true;
    _state = _state.copyWith(isListening: true, lastResponse: 'Bol Sir, sun rahi hoon...');
    _notif.updateOrb('listening');
    notifyListeners();

    final started = await _whisper.startRecording();
    if (!started) {
      _isListening = false;
      _state = _state.copyWith(isListening: false, lastResponse: 'Mic permission do Sir.');
      notifyListeners();
      return;
    }

    // Auto-stop after 8 seconds of listening (in case user is silent)
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 8), () {
      if (_isListening && _realtimeActive) {
        _stopRealtimeListen();
      }
    });
  }

  Future<void> _stopRealtimeListen() async {
    if (!_isListening) return;
    _silenceTimer?.cancel();
    _isListening = false;
    _notif.updateOrb('thinking');
    _state = _state.copyWith(isListening: false, lastResponse: 'Samajh rahi hoon...');
    notifyListeners();

    final text = await _whisper.stopAndTranscribe();
    if (text != null && text.trim().isNotEmpty) {
      await receiveCommand(text.trim());
    } else {
      // Nothing heard — loop back to listening
      _state = _state.copyWith(lastResponse: 'Hmm, kuch sunai nahi diya Sir.');
      _notif.updateOrb('still');
      notifyListeners();
      if (_realtimeActive && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _startRealtimeListen();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HANDS-FREE MODE (legacy — replaced by realtime but kept for compatibility)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> toggleHandsFree() async {
    // If realtime is active, just toggle it off
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
        response = await _ai.generalQuery(cmd, useSearch: _needsSearch(cmd));
      }

      // Check for God Mode command in response
      final parsed = _parseGodCommand(response);
      if (parsed.type != GodCommand.unknown) {
        await _executeGodCommand(parsed, response);
      } else {
        await _processResponse(response);
      }

      await _saveNeuralMemory();

    } catch (e) {
      await _processResponse(
          'Sir, thodi problem aayi: ${e.toString().substring(0, min(60, e.toString().length))}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN QUERY
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _handleScreenQuery(String cmd) async {
    String screenCtx = '';
    try {
      screenCtx = await _access.getScreenContext()
          .timeout(const Duration(seconds: 3), onTimeout: () => '');
    } catch (_) {}

    final enriched = screenCtx.isNotEmpty
        ? '$cmd\n\n[SCREEN_CONTEXT: $screenCtx]' : cmd;
    _setMood(Mood.calm);
    return await _ai.generalQuery(enriched);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE PARSER + EXECUTOR
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
    final clean = fullAiResponse
        .replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();

    switch (cmd.type) {

      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) {
          await _processResponse('$clean\n\n📱 App khol rahi hoon...');
          final ok = await _access.openApp(pkg);
          if (!ok) await _processResponse(
              'Accessibility Service enable hai? Settings → God Mode.');
        }
        break;

      case GodCommand.scrollReels:
        await _processResponse('$clean\n\nScroll kar rahi hoon...');
        await _access.scrollDown(steps: 3);
        break;

      case GodCommand.likeReel:
        await _processResponse('$clean\n\n❤️ Like kar diya!');
        await _access.instagramLikeReel();
        break;

      case GodCommand.ytSearch:
        // ✅ FIXED: uses dedicated youtubeSearch method
        final query = cmd.params['QUERY'] ?? '';
        if (query.isNotEmpty) {
          await _processResponse('$clean\n\n🔍 YouTube pe search kar rahi hoon: "$query"');
          final ok = await _access.youtubeSearch(query);
          if (!ok) await _processResponse(
              'YouTube search mein problem aayi Sir. Accessibility enable hai?');
        }
        break;

      case GodCommand.instagramComment:
        final txt = cmd.params['TEXT'] ?? '';
        await _processResponse('$clean\n\n💬 Comment kar rahi hoon...');
        await _access.instagramPostComment(txt);
        break;

      case GodCommand.flipkartBuy:
        final product = cmd.params['PRODUCT'] ?? '';
        final size    = cmd.params['SIZE']    ?? 'M';
        await _processResponse('$clean\n\n🛍️ Flipkart pe dhundh rahi hoon: $product');
        await _access.flipkartSearchProduct(product);
        await Future.delayed(const Duration(seconds: 3));
        await _access.flipkartSelectSize(size);
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartAddToCart();
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartGoToPayment();
        break;

      case GodCommand.whatsappSend:
        final to  = cmd.params['TO']  ?? '';
        final msg = cmd.params['MSG'] ?? '';
        await _processResponse('$clean\n\n📤 $to ko WhatsApp bhej rahi hoon...');
        await _access.whatsappSendMessage(to, msg);
        break;

      case GodCommand.unknown:
        await _processResponse(clean);
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STT — manual mic button
  // ══════════════════════════════════════════════════════════════════════════

  void Function(String)? _oneTimeTranscribeCallback;

  Future<void> startListening({void Function(String text)? onTranscribed}) async {
    _oneTimeTranscribeCallback = onTranscribed;
    // If realtime mode — delegate
    if (_realtimeActive) { await _startRealtimeListen(); return; }

    if (_isListening) return;
    await _tts.stop();
    _isListening = true;
    _state = _state.copyWith(
        isListening: true, lastResponse: 'Bol Sir, sun rahi hoon...',
        isActive: true);
    _notif.updateOrb('listening');
    notifyListeners();

    final started = await _whisper.startRecording();
    if (!started) {
      _isListening = false;
      _oneTimeTranscribeCallback = null;
      _state = _state.copyWith(
          isListening: false, lastResponse: 'Mic start nahi hua. Permission check karo.');
      _notif.updateOrb('still');
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    // If realtime — delegate
    if (_realtimeActive) { await _stopRealtimeListen(); return; }

    _handsFreeListenTimer?.cancel();
    _isListening = false;
    _tts.resetIdleTimer();
    _state = _state.copyWith(
        isListening: false, lastResponse: 'Samajh rahi hoon...');
    _notif.updateOrb('thinking');
    notifyListeners();

    final text = await _whisper.stopAndTranscribe();
    if (text != null && text.isNotEmpty) {
      // If there's a one-time callback (e.g. reply approval), use it
      final cb = _oneTimeTranscribeCallback;
      _oneTimeTranscribeCallback = null;
      if (cb != null) {
        cb(text);
      } else {
        await receiveCommand(text);
      }
    } else {
      _oneTimeTranscribeCallback = null;
      _state = _state.copyWith(lastResponse: 'Kuch suna nahi Sir, dobara bolein?');
      _notif.updateOrb('still');
      notifyListeners();
      if (_handsFreeMode && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 800));
        _tts.onAutoListenTrigger?.call();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERMISSION FORCE-CHECK — guides user if any permission missing
  // Called on startup. Zara speaks what to fix, not just silent fail.
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
      if (_permissions['accessibility'] != true)
        missing.add('Accessibility Service');
      if (_permissions['overlay'] != true)
        missing.add('Overlay (Draw over apps)');
      if (_permissions['notificationListener'] != true)
        missing.add('Notification Listener');

      if (missing.isEmpty) {
        if (kDebugMode) debugPrint('✅ All permissions granted');
        return;
      }

      final list = missing.join(', ');
      await _processResponse(
        'Sir, kuch permissions missing hain: $list. '
        'Settings → Z.A.R.A. → Permissions mein jaake enable kar do. '
        'Bina iske God Mode aur voice kaam nahi karega.'
      );
      if (kDebugMode) debugPrint('⚠️ Missing: $missing');
    } catch (e) {
      if (kDebugMode) debugPrint('_checkAndGuidePermissions: $e');
    }
  }
  bool _agentModeActive = false;
  bool get agentModeActive => _agentModeActive;
  String _agentContactName = '';
  String get agentContact => _agentContactName;

  Future<void> startAgentMode(String contact) async {
    _agentModeActive = true;
    _agentContactName = contact;
    notifyListeners();
    final persona = 'Tu Ravi ka AI assistant hai. '
        'Iske WhatsApp pe $contact ke messages ka reply de as Ravi. '
        'Natural, friendly Hinglish mein reply karo. Short rakho.';
    await _access.whatsappStartAgent(contact, persona);
    await _processResponse('Agent Mode ON! Ab main $contact ke '
        'WhatsApp messages ka reply karungi Sir.');
  }

  Future<void> stopAgentMode() async {
    _agentModeActive = false;
    _agentContactName = '';
    notifyListeners();
    await _access.whatsappStopAgent();
    await _processResponse('Agent Mode OFF. Wapas aagaye Sir!');
  }

  // Called from native when agent mode receives a new message
  Future<void> handleAgentMessage(String contact, String message) async {
    if (!_agentModeActive) return;
    final reply = await _ai.emotionalChat(
        'WhatsApp pe $contact ne bheja: "$message"\n'
        'Reply karo as Ravi ka proxy — short, natural Hinglish mein.',
        _state.affectionLevel);
    final clean = reply.replaceAll(RegExp(r'\[COMMAND:[^\]]+\]'), '').trim();
    if (clean.isNotEmpty) {
      await _access.whatsappSendMessage(contact, clean);
    }
  }

  // ── Command Chain executor ─────────────────────────────────────────────────
  Future<void> executeCommandChain(List<Map<String, dynamic>> commands) async {
    await _access.executeChain(commands);
  }

  // Called from home screen speaker icon — re-speaks last response
  // ══════════════════════════════════════════════════════════════════════════
  // WAKE WORD — "Hii Zara" / "Sunna" detection engine
  // ══════════════════════════════════════════════════════════════════════════

  bool _wakeWordListening = false;
  bool get wakeWordListening => _wakeWordListening;

  Future<void> startWakeWordEngine() async {
    // ✅ FIX: AlwaysOn bhi mic use karta hai — pehle band karo
    if (_whisper.alwaysOnActive) {
      await _whisper.stopAlwaysOn();
      if (kDebugMode) debugPrint('🎙️ AlwaysOn stopped for wake word engine');
    }
    final ok = await _access.startWakeWord();
    _wakeWordListening = ok;
    notifyListeners();
    if (kDebugMode) debugPrint('🎙️ Wake word engine: $ok');
  }

  Future<void> stopWakeWordEngine() async {
    await _access.stopWakeWord();
    _wakeWordListening = false;
    notifyListeners();
  }

  Future<void> _onWakeWordDetected(String transcript) async {
    if (_disposed || _isSpeaking) return;
    if (kDebugMode) debugPrint('🔔 Wake word: "$transcript"');

    // ✅ FIX: Stop AlwaysOn — mic free karo for realtime listening
    if (_whisper.alwaysOnActive) await _whisper.stopAlwaysOn();

    _notif.updateOrb('listening');
    final acks = ['Ji Ravi ji?', 'Hmm?', 'Haan boliye?', 'Ji?', 'Haan Sir?'];
    final ack  = acks[DateTime.now().millisecond % acks.length];
    unawaited(_tts.speak(ack, mood: _state.mood));
    if (!_realtimeActive && !_isListening) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!_disposed) await _startRealtimeListen();
    }
  }

  // ── Universal Generic Control ─────────────────────────────────────────────
  Future<bool> performGenericAction(String action, String target, {
    String target2 = '', int steps = 3,
  }) => _access.performGenericAction(action, target, target2: target2, steps: steps);

  // Volume level callback — orb animation
  void Function(double)? onVolumeLevel;

  Future<String?> speakLastResponse() async {
    if (_isSpeaking) return null;
    final text = _state.lastResponse
        .replaceAll(RegExp(r'[*\[\]#>]'), '').trim();
    if (text.isEmpty) return null;
    unawaited(_tts.speak(text, mood: _state.mood));
    return text;
  }

  Future<void> processAudio(String audioPath) async {
    _isListening = false;
    _state = _state.copyWith(lastResponse: 'Sun rahi hoon...');
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
    if (_state.ttsEnabled) {
      unawaited(_tts.speak(aiMessage, mood: _state.mood));
    }

    // Log to n8n/Sheets — non-blocking
    if (ApiKeys.n8nReady) {
      unawaited(_auto.logConversation(_state.lastCommand, aiMessage));
    }
  }

  // ── Pending reply state — shown in overlay for user approval ────────────
  PendingReply? _pendingReply;
  PendingReply? get pendingReply => _pendingReply;

  void _handleProactiveNotification(NotificationAlert alert) {
    if (alert.zaraAlert.isEmpty) return;

    // Store pending reply context so overlay can show approve/dismiss btns
    if (alert.package_.contains('whatsapp') || alert.package_.contains('telegram') ||
        alert.package_.contains('instagram') || alert.package_.contains('messaging')) {
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
      isActive: true, lastActivity: DateTime.now(),
    );
    notifyListeners();
    if (_state.ttsEnabled) unawaited(_tts.speak(alert.zaraAlert));
  }

  // User says "Haan bol do" / approves a reply suggestion
  Future<void> approvePendingReply(String replyText) async {
    final pending = _pendingReply;
    if (pending == null) return;
    _pendingReply = null;
    notifyListeners();

    // Generate reply if not provided
    String reply = replyText.trim();
    if (reply.isEmpty) {
      reply = await _ai.emotionalChat(
        'User ne approve kiya reply "${pending.message}" ko "${pending.contact}" ke liye. '
        'Ek short natural Hinglish reply generate karo.',
        _state.affectionLevel) ?? '';
    }
    if (reply.isEmpty) return;

    // Send via accessibility
    if (pending.pkg.contains('whatsapp')) {
      await _access.whatsappSendMessage(pending.contact, reply);
      await _processResponse('Done Sir! "${pending.contact}" ko reply bhej diya: "$reply"');
    } else {
      await _processResponse('Reply: "$reply" — Sir manually paste kar do, ${{pending.app}} ka direct send abhi set up ho raha hai.');
    }
  }

  void dismissPendingReply() {
    _pendingReply = null;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GUARDIAN MODE
  // ══════════════════════════════════════════════════════════════════════════

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
        await _processResponse('Guardian Mode ACTIVE Sir! Koi phone haath bhi lagaye toh pakad lungi! 😤');
      } else {
        await _processResponse('Camera aur location permission chahiye. Settings mein enable karo.');
      }
    } else {
      await _location.stopTracking();
      await _processResponse('Guardian Mode STANDBY. Aap safe hain Sir.');
    }
  }

  Future<void> reportIntruder(String photoPath) async {
    try {
      _state = _state.copyWith(
          lastIntruderPhoto: photoPath, mood: Mood.angry, lastActivity: DateTime.now());
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
  // CHAT EDIT / DELETE
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

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT ARCHIVE
  // ══════════════════════════════════════════════════════════════════════════

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
    final session = _state.chatArchives
        .firstWhere((s) => s.id == sessionId, orElse: () =>
            ChatSession(id: '', topicName: '', messages: [], timestamp: DateTime.now()));
    if (session.id.isEmpty) return;
    final msgs = session.chatMessages.isNotEmpty
        ? session.chatMessages
        : session.messages.map((t) => ChatMessage.system(t)).toList();
    _state = _state.copyWith(
        messages: msgs, dialogueHistory: session.messages,
        lastCommand: session.topicName, isActive: true);
    notifyListeners();
  }

  void loadSession(ChatSession s)         => loadArchivedChat(s.id);
  void deleteArchivedChat(String id)      {
    _state = _state.copyWith(
        chatArchives: _state.chatArchives.where((s) => s.id != id).toList());
    notifyListeners(); _saveNeuralMemory();
  }
  void clearAllArchives()                 {
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

  bool _isScreenQuery(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('screen')       || l.contains('dikha')      ||
           l.contains('dikh raha')    || l.contains('yahan kya')  ||
           l.contains('kya open')     || l.contains('abhi kya')   ||
           l.contains('is app mein')  || l.contains('kya likha')  ||
           l.contains('page pe');
  }

  // WhatsApp read commands
  bool _isWhatsAppReadCommand(String cmd) {
    final l = cmd.toLowerCase();
    return (l.contains('whatsapp') || l.contains('wa') || l.contains('message')) &&
           (l.contains('padh') || l.contains('read') || l.contains('dekh') ||
            l.contains('kya aaya') || l.contains('check'));
  }

  // Agent mode commands
  bool _isAgentModeCommand(String cmd) {
    final l = cmd.toLowerCase();
    return l.contains('agent') ||
           (l.contains('proxy') && l.contains('whatsapp')) ||
           (l.contains('reply') && l.contains('mere liye'));
  }

  void _determineMood(String cmd) {
    final l = cmd.toLowerCase();
    if (l.contains('pyar') || l.contains('love') || l.contains('thank') || l.contains('miss')) {
      _state = _state.copyWith(
          affectionLevel: (_state.affectionLevel + 5).clamp(0, 100), mood: Mood.romantic);
    } else if (l.contains('gussa') || l.contains('angry') || l.contains('hate')) {
      _state = _state.copyWith(
          affectionLevel: (_state.affectionLevel - 10).clamp(0, 100), mood: Mood.ziddi);
    }
    notifyListeners();
  }

  void _setMood(Mood m) {
    _state = _state.copyWith(mood: m);
  }

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
    _disposed = true;
    _realtimeActive = false;
    _silenceTimer?.cancel();
    _handsFreeListenTimer?.cancel();
    _tts.onAutoListenTrigger = null;
    _auto.stopPolling();
    _auto.dispose();
    await _whisper.stopAlwaysOn();
    await _tts.dispose();
    super.dispose();
  }
}

// ── Pending Reply — shown in overlay for user to approve/modify ─────────────
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
