// lib/services/vosk_service.dart
// Z.A.R.A. v10.0 — Vosk Wake Word Service
//
// ══════════════════════════════════════════════════════════════════════════════
// ARCHITECTURE
//
//   ZaraAccessibilityService.kt (Native)
//     │  AudioRecord 16kHz → Vosk (grammar restricted, IO thread)
//     │  WakeLock → alive even when screen is off
//     │
//     ▼  MethodChannel "com.mahakal.zara/accessibility"
//
//   VoskService (this file) — Flutter bridge
//     │  Handles: wake_word_detected, onWakeWordPcmReady,
//     │           onWakeWordEngineChanged, onWakeWordError
//     │
//     ▼  Callbacks → ZaraController (zara_provider.dart)
//
// STATE MACHINE (managed by ZaraController):
//
//   ZaraMode.wakeWord  ──► "Hii Zara" heard ──► ZaraMode.command
//   ZaraMode.command   ──► Whisper STT       ──► ZaraMode.thinking
//   ZaraMode.thinking  ──► Gemini reply      ──► ZaraMode.speaking
//   ZaraMode.speaking  ──► TTS done + 800ms  ──► ZaraMode.wakeWord
//
// USAGE in zara_provider.dart:
//   _vosk.onWakeDetected  = (word) => _onWakeWordDetected(word);
//   _vosk.onPcmReady      = (b64, sr) => _handleVadPcm(b64, sr);
//   _vosk.onEngineChanged = (active) { _wakeWordListening = active; };
//   await _vosk.start();
//   // In dispose():
//   await _vosk.dispose();
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── State machine enum ─────────────────────────────────────────────────────────
enum ZaraMode {
  /// Vosk silently scanning for "Hii Zara" — low CPU, always-on
  wakeWord,

  /// Wake word heard — Whisper mic open, waiting for full command
  command,

  /// Gemini is processing the command
  thinking,

  /// ElevenLabs TTS is speaking — mic closed
  speaking,
}

// ─────────────────────────────────────────────────────────────────────────────
class VoskService {

  // Singleton
  static final VoskService _i = VoskService._();
  factory VoskService() => _i;
  VoskService._();

  static const _ch = MethodChannel('com.mahakal.zara/accessibility');

  // ── Internal state ─────────────────────────────────────────────────────────
  bool      _active   = false;
  ZaraMode  _mode     = ZaraMode.wakeWord;
  bool      _disposed = false;

  bool     get isActive => _active;
  ZaraMode get mode     => _mode;

  // ── Public callbacks — wire in ZaraController.initialize() ─────────────────

  /// Vosk heard "Hii Zara" (or grammar match)
  /// word = exact wake word, e.g. "hii zara"
  void Function(String word)? onWakeDetected;

  /// VAD fallback path (no model in assets/) — raw PCM for Whisper
  void Function(String pcmBase64, int sampleRate)? onPcmReady;

  /// Engine status changed (started/stopped)
  void Function(bool active)? onEngineChanged;

  /// Error (no mic permission, AudioRecord fail)
  void Function(String error)? onError;

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<bool> start() async {
    if (_active || _disposed) return _active;

    // Register BEFORE calling native start
    // (some devices fire events synchronously inside invokeMethod)
    _ch.setMethodCallHandler(_onNativeCall);

    try {
      final ok = await _ch.invokeMethod<bool>('startWakeWord') ?? false;
      _active = ok;
      _mode   = ZaraMode.wakeWord;
      onEngineChanged?.call(_active);
      if (kDebugMode) debugPrint('VoskService started: $_active');
      return _active;
    } catch (e) {
      if (kDebugMode) debugPrint('VoskService.start: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  // ── Stop ───────────────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (!_active) return;
    try {
      await _ch.invokeMethod<bool>('stopWakeWord');
    } catch (_) {}
    _active = false;
    _mode   = ZaraMode.wakeWord;
    onEngineChanged?.call(false);
    if (kDebugMode) debugPrint('VoskService stopped');
  }

  // ── Mode transitions — called by ZaraController ────────────────────────────

  /// Call immediately after wake word detected — suppresses further events
  /// until enterWakeWordMode() is called (prevents double-fire)
  void enterCommandMode() {
    _mode = ZaraMode.command;
    if (kDebugMode) debugPrint('Vosk → command mode');
  }

  /// Call after TTS finishes + 800ms silence buffer
  /// Returns Vosk to scanning state
  void enterWakeWordMode() {
    _mode = ZaraMode.wakeWord;
    if (kDebugMode) debugPrint('Vosk → wake word mode');
  }

  void enterThinkingMode() => _mode = ZaraMode.thinking;
  void enterSpeakingMode() => _mode = ZaraMode.speaking;

  // ── Native → Flutter handler ───────────────────────────────────────────────

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {

      // ── Vosk: wake word matched ──────────────────────────────────────────
      case 'wake_word_detected':
        final args = _map(call.arguments);
        final word = args['word'] ?? args['transcript'] ?? 'zara';

        // Only fire in wakeWord mode — ignore during command / speaking
        if (_mode == ZaraMode.wakeWord && !_disposed) {
          if (kDebugMode) debugPrint('🔔 Vosk: "$word"');
          enterCommandMode();          // suppress further events immediately
          onWakeDetected?.call(word);
        }
        break;

      // ── VAD fallback: PCM chunk → send to Whisper ────────────────────────
      case 'onWakeWordPcmReady':
        if (_mode != ZaraMode.wakeWord || _disposed) break;
        final args      = _map(call.arguments);
        final b64       = args['pcm_base64'] ?? '';
        final sampleRate = int.tryParse(args['sample_rate'] ?? '16000') ?? 16000;
        if (b64.isNotEmpty) onPcmReady?.call(b64, sampleRate);
        break;

      // ── Engine status (started / stopped from native side) ───────────────
      case 'onWakeWordEngineChanged':
        final args = _map(call.arguments);
        final raw  = call.arguments;
        _active = args['active'] == 'true' ||
                  (raw is Map && raw['active'] == true);
        onEngineChanged?.call(_active);
        break;

      // ── Error ────────────────────────────────────────────────────────────
      case 'onWakeWordError':
        final args  = _map(call.arguments);
        final error = args['error'] ?? 'unknown';
        if (kDebugMode) debugPrint('VoskService error: $error');
        _active = false;
        onError?.call(error);
        break;

      // ── Agent messages — handled separately in AccessibilityService ───────
      case 'onAgentMessageReceived':
        break;
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  Map<String, String> _map(dynamic raw) {
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
