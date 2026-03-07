// lib/services/vosk_service.dart
// Z.A.R.A. v10.0 — Vosk Wake Word + Whisper Bridge
//
// ══════════════════════════════════════════════════════════════════════════════
// STATE MACHINE:
//
//   ZaraMode.wakeWord  ──► Vosk scanning (background, low CPU, screen-off safe)
//        │                  WakeLock keeps AudioRecord alive
//        │  "Hii Zara" detected
//        ▼
//   ZaraMode.command   ──► Vosk STOPS (releases mic) → Whisper STARTS
//        │                  Seamless mic handover: Vosk frees → Whisper claims
//        │  command captured
//        ▼
//   ZaraMode.thinking  ──► Gemini processing
//        │
//        ▼
//   ZaraMode.speaking  ──► ElevenLabs streaming TTS
//        │
//        │  TTS done + 800ms buffer (no self-hearing)
//        ▼
//   ZaraMode.wakeWord  ──► Vosk restarts
//
// MIC HANDOVER SEQUENCE:
//   1. Vosk detects "Hii Zara"
//   2. enterCommandMode() called → sets mode = command
//   3. VoskService fires onWakeDetected callback
//   4. ZaraController:
//      a. Calls stopWakeWordEngine() → native stopWakeWord → AudioRecord released
//      b. Waits 150ms (OS mic release buffer)
//      c. Calls _whisper.startRecording() → Whisper claims mic
//   5. After TTS done + 800ms:
//      a. _vosk.enterWakeWordMode()
//      b. startWakeWordEngine() → Vosk claims mic again
//
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── State machine ─────────────────────────────────────────────────────────────
enum ZaraMode {
  /// Vosk actively scanning — low CPU, screen-off safe via WakeLock
  wakeWord,

  /// Wake word heard — Vosk stopped, Whisper listening for command
  command,

  /// Gemini processing command
  thinking,

  /// ElevenLabs TTS speaking — all mic blocked
  speaking,
}

// ─────────────────────────────────────────────────────────────────────────────
class VoskService {
  // Singleton
  static final VoskService _i = VoskService._();
  factory VoskService() => _i;
  VoskService._();

  static const _ch = MethodChannel('com.mahakal.zara/accessibility');

  // ── State ──────────────────────────────────────────────────────────────────
  bool      _active   = false;
  ZaraMode  _mode     = ZaraMode.wakeWord;
  bool      _disposed = false;

  bool     get isActive => _active;
  ZaraMode get mode     => _mode;

  // ── Callbacks — wire in ZaraController.initialize() ───────────────────────

  /// Vosk detected wake word — string is the matched phrase
  /// ZaraController should: stop Vosk → wait 150ms → start Whisper
  void Function(String word)? onWakeDetected;

  /// VAD fallback path — raw PCM for Whisper transcription
  void Function(String pcmBase64, int sampleRate)? onPcmReady;

  /// Engine started/stopped
  void Function(bool active)? onEngineChanged;

  /// Error (no mic permission, etc.)
  void Function(String error)? onError;

  /// Agent message received (dispatched from native)
  void Function(String contact, String message)? onAgentMessage;

  // ── Start Vosk ─────────────────────────────────────────────────────────────

  Future<bool> start() async {
    if (_active || _disposed) return _active;

    _ch.setMethodCallHandler(_onNativeCall);

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

  // ── Stop Vosk — releases mic so Whisper can claim it ──────────────────────

  Future<void> stop() async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<bool>('stopWakeWord');
    } catch (_) {}
    _active = false;
    onEngineChanged?.call(false);
    if (kDebugMode) debugPrint('🎙️ VoskService stopped — mic released');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODE TRANSITIONS — called by ZaraController
  // ══════════════════════════════════════════════════════════════════════════

  /// Step 1: Called right after wake word detected
  /// Marks mode = command so further Vosk events are suppressed
  /// ZaraController MUST then: await stop() → await Future.delayed(150ms) → start Whisper
  void enterCommandMode() {
    _mode = ZaraMode.command;
    if (kDebugMode) debugPrint('ZaraMode → command (Vosk stopping, Whisper starting)');
  }

  /// Step 2: Called when Gemini starts thinking
  void enterThinkingMode() {
    _mode = ZaraMode.thinking;
    if (kDebugMode) debugPrint('ZaraMode → thinking');
  }

  /// Step 3: Called when ElevenLabs TTS starts
  void enterSpeakingMode() {
    _mode = ZaraMode.speaking;
    if (kDebugMode) debugPrint('ZaraMode → speaking (mic blocked)');
  }

  /// Step 4: Called 800ms after TTS done
  /// ZaraController MUST then: call startWakeWordEngine() to restart Vosk
  void enterWakeWordMode() {
    _mode = ZaraMode.wakeWord;
    if (kDebugMode) debugPrint('ZaraMode → wakeWord (Vosk restarting)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NATIVE → FLUTTER EVENT HANDLER
  // ══════════════════════════════════════════════════════════════════════════

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {

      // ── Vosk: wake word matched ──────────────────────────────────────────
      case 'wake_word_detected':
        final args = _asMap(call.arguments);
        final word = args['word'] ?? args['transcript'] ?? 'zara';

        // Only fire if we're in wakeWord mode — ignore during command/speaking
        if (_mode == ZaraMode.wakeWord && !_disposed) {
          if (kDebugMode) debugPrint('🔔 Vosk wake: "$word"');
          enterCommandMode(); // suppress immediately — before async callback
          onWakeDetected?.call(word);
        } else {
          if (kDebugMode) debugPrint('🔕 Vosk wake suppressed (mode: $_mode)');
        }
        break;

      // ── VAD fallback: PCM chunk → send to Whisper ────────────────────────
      case 'onWakeWordPcmReady':
        if (_mode != ZaraMode.wakeWord || _disposed) break;
        final args  = _asMap(call.arguments);
        final b64   = args['pcm_base64'] ?? '';
        final sr    = int.tryParse(args['sample_rate'] ?? '16000') ?? 16000;
        if (b64.isNotEmpty) onPcmReady?.call(b64, sr);
        break;

      // ── Engine status changed ─────────────────────────────────────────────
      case 'onWakeWordEngineChanged':
        final raw    = call.arguments;
        final active = raw is Map ? raw['active'] == true : false;
        _active = active;
        onEngineChanged?.call(_active);
        break;

      // ── Error ─────────────────────────────────────────────────────────────
      case 'onWakeWordError':
        final args  = _asMap(call.arguments);
        final error = args['error'] ?? 'unknown';
        _active = false;
        onError?.call(error);
        if (kDebugMode) debugPrint('VoskService error: $error');
        break;

      // ── Agent messages ────────────────────────────────────────────────────
      case 'onAgentMessageReceived':
        final args    = _asMap(call.arguments);
        final contact = args['contact'] ?? '';
        final message = args['message'] ?? '';
        onAgentMessage?.call(contact, message);
        break;

      // ── Service status ────────────────────────────────────────────────────
      case 'onServiceStatusChanged':
        final args    = _asMap(call.arguments);
        final enabled = args['enabled'] == 'true';
        if (kDebugMode) debugPrint('AccessibilityService enabled: $enabled');
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
