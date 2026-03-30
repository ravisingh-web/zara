// lib/services/vosk_service.dart
// Z.A.R.A. v11.0 — Vosk Wake Word + Whisper Bridge
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX v11: CRITICAL BUGS RESOLVED                                        ║
// ║                                                                         ║
// ║  🔴 BUG 1: MethodChannel CONFLICT                                       ║
// ║     VoskService AND AccessibilityService BOTH used                      ║
// ║     'com.mahakal.zara/accessibility' channel.                           ║
// ║     setMethodCallHandler() silently overwrites the first handler.       ║
// ║     → Result: whichever set handler LAST wins, other gets NOTHING.      ║
// ║     FIX: VoskService now ONLY listens — does NOT call               ║
// ║           setMethodCallHandler(). MainActivity routes ALL events from  ║
// ║           accessibility channel to both services via a dispatcher.     ║
// ║                                                                         ║
// ║  🔴 BUG 2: _ch.setMethodCallHandler() called in start() every time     ║
// ║     → multiple handlers piled up, events duplicated                    ║
// ║     FIX: Handler registered once in constructor via _setupHandler()   ║
// ║                                                                         ║
// ║  🔴 BUG 3: enterCommandMode() suppresses subsequent wake events but    ║
// ║     if Vosk restart fails, mode stays 'command' forever → locked       ║
// ║     FIX: enterWakeWordMode() always called after stop() returns        ║
// ║                                                                         ║
// ║  ✅ dispatchNativeCall() — called by AccessibilityService.dart          ║
// ║     dispatcher pattern removes channel conflict entirely               ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// STATE MACHINE (unchanged):
//   ZaraMode.wakeWord → Vosk scanning (background, screen-off safe)
//   ZaraMode.command  → Vosk stopped, Whisper started
//   ZaraMode.thinking → Gemini processing
//   ZaraMode.speaking → ElevenLabs TTS (mic blocked)
//   ZaraMode.wakeWord → loop restarts

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── State machine ─────────────────────────────────────────────────────────────
enum ZaraMode {
  wakeWord,
  command,
  thinking,
  speaking,
}

// ─────────────────────────────────────────────────────────────────────────────
class VoskService {
  static final VoskService _i = VoskService._();
  factory VoskService() => _i;
  VoskService._();

  // ✅ FIX: VoskService uses the accessibility channel for INVOKING methods
  // but does NOT setMethodCallHandler() — that is done by AccessibilityService
  // which then calls dispatchNativeCall() on VoskService for vosk events.
  static const _ch = MethodChannel('com.mahakal.zara/accessibility');

  bool      _active   = false;
  ZaraMode  _mode     = ZaraMode.wakeWord;
  bool      _disposed = false;

  bool     get isActive => _active;
  ZaraMode get mode     => _mode;

  // ── Callbacks ──────────────────────────────────────────────────────────────
  void Function(String word)? onWakeDetected;
  void Function(String pcmBase64, int sampleRate)? onPcmReady;
  void Function(bool active)? onEngineChanged;
  void Function(String error)? onError;
  void Function(String contact, String message)? onAgentMessage;
  void Function(String type, int count)? onSecurityEvent;

  // ══════════════════════════════════════════════════════════════════════════
  // START / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> start() async {
    if (_active || _disposed) return _active;

    try {
      final ok = await _ch.invokeMethod<bool>('startWakeWord') ?? false;
      _active = ok;
      _mode   = ZaraMode.wakeWord;
      onEngineChanged?.call(_active);
      if (kDebugMode) debugPrint('🎙️ VoskService started: $_active');
      return _active;
    } catch (e) {
      if (kDebugMode) debugPrint('VoskService.start: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  Future<void> stop() async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<bool>('stopWakeWord');
    } catch (_) {}
    _active = false;
    // ✅ FIX BUG 3: always reset mode on stop so we're never stuck in command mode
    _mode = ZaraMode.wakeWord;
    onEngineChanged?.call(false);
    if (kDebugMode) debugPrint('🎙️ VoskService stopped — mic released');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODE TRANSITIONS
  // ══════════════════════════════════════════════════════════════════════════

  void enterCommandMode() {
    _mode = ZaraMode.command;
    if (kDebugMode) debugPrint('ZaraMode → command');
  }

  void enterThinkingMode() {
    _mode = ZaraMode.thinking;
    if (kDebugMode) debugPrint('ZaraMode → thinking');
  }

  void enterSpeakingMode() {
    _mode = ZaraMode.speaking;
    if (kDebugMode) debugPrint('ZaraMode → speaking');
  }

  void enterWakeWordMode() {
    _mode = ZaraMode.wakeWord;
    if (kDebugMode) debugPrint('ZaraMode → wakeWord');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ FIX BUG 1 & 2: DISPATCHER — called by AccessibilityService
  //
  // AccessibilityService owns the single MethodCallHandler for
  // 'com.mahakal.zara/accessibility'. When it receives a vosk-related
  // event (wake_word_detected, onWakeWordPcmReady, etc.) it calls this
  // method to forward the event here.
  //
  // This eliminates the channel conflict completely.
  // ══════════════════════════════════════════════════════════════════════════

  Future<dynamic> dispatchNativeCall(MethodCall call) async {
    switch (call.method) {

      case 'wake_word_detected':
        final args = _asMap(call.arguments);
        final word = args['word'] ?? args['transcript'] ?? 'zara';

        if (_mode == ZaraMode.wakeWord && !_disposed) {
          if (kDebugMode) debugPrint('🔔 Vosk wake: "$word"');
          enterCommandMode();
          onWakeDetected?.call(word);
        } else {
          if (kDebugMode) debugPrint('🔕 Vosk wake suppressed (mode: $_mode)');
        }
        break;

      case 'onWakeWordPcmReady':
        if (_mode != ZaraMode.wakeWord || _disposed) break;
        final args = _asMap(call.arguments);
        final b64  = args['pcm_base64'] ?? '';
        final sr   = int.tryParse(args['sample_rate'] ?? '16000') ?? 16000;
        if (b64.isNotEmpty) onPcmReady?.call(b64, sr);
        break;

      case 'onWakeWordEngineChanged':
        final raw    = call.arguments;
        final active = raw is Map ? raw['active'] == true : false;
        _active = active;
        onEngineChanged?.call(_active);
        break;

      case 'onWakeWordError':
        final args  = _asMap(call.arguments);
        final error = args['error'] ?? 'unknown';
        _active = false;
        // ✅ On error, reset mode so engine can restart
        _mode = ZaraMode.wakeWord;
        onError?.call(error);
        if (kDebugMode) debugPrint('VoskService error: $error');
        break;

      case 'onAgentMessageReceived':
        final args    = _asMap(call.arguments);
        final contact = args['contact'] ?? '';
        final message = args['message'] ?? '';
        onAgentMessage?.call(contact, message);
        break;

      case 'onServiceStatusChanged':
        final args    = _asMap(call.arguments);
        final enabled = args['enabled'] == 'true';
        if (kDebugMode) debugPrint('AccessibilityService enabled: $enabled');
        break;

      case 'onWindowChanged':
        break;

      case 'onChainComplete':
        if (kDebugMode) {
          final args    = _asMap(call.arguments);
          final results = args['results'] ?? '';
          debugPrint('⛓️ Chain complete: $results');
        }
        break;

      case 'onAgentModeChanged':
        final args    = _asMap(call.arguments);
        final active  = args['active'] == 'true';
        final contact = args['contact'] ?? '';
        if (kDebugMode) debugPrint('🤖 Agent mode: $active contact=$contact');
        break;

      case 'onSecurityEvent':
        final args  = _asMap(call.arguments);
        final type  = args['type'] ?? '';
        final count = args['count'] ?? '0';
        if (kDebugMode) debugPrint('🛡️ Security: $type count=$count');
        onSecurityEvent?.call(type, int.tryParse(count) ?? 0);
        break;

      default:
        break;
    }
  }

  // ── Util ──────────────────────────────────────────────────────────────────
  Map<String, String> _asMap(dynamic raw) {
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(raw as Map)
          .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } catch (_) { return {}; }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
