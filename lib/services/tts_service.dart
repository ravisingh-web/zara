// lib/services/tts_service.dart
// Z.A.R.A. v8.0 — ElevenLabs Voice Engine (Anjura)
// Voice ID : rdz6GofVsYlLgQl2dBEE
// Model    : eleven_multilingual_v2 → fallback eleven_v1
//
// ✅ FIX: Persistent AudioPlayer — no per-chunk init gap (silence bug FIXED)
// ✅ FIX: Pre-fetch pipeline — chunk N+1 fetched while chunk N plays
// ✅ Hands-Free Mode — auto-listen after speaking
// ✅ Mood-based voice params
// ✅ Idle phrase system
// ✅ Thread-safe stop/dispose

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/services/ai_api_service.dart';

class ZaraTtsService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ZaraTtsService _i = ZaraTtsService._internal();
  factory ZaraTtsService() => _i;
  ZaraTtsService._internal();

  // ── Dependencies ───────────────────────────────────────────────────────────
  final _ai  = AiApiService();
  final _rnd = Random();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _initialized   = false;
  bool _isSpeaking    = false;
  bool _enabled       = true;
  bool _stopFlag      = false;
  bool _handsFreeMode = false;
  bool _disposed      = false;
  Mood _mood          = Mood.calm;

  // ── Persistent player — created ONCE, reused per chunk ────────────────────
  // OLD: new AudioPlayer() per chunk = 200-400ms init gap = SILENCE BUG
  // NEW: single player reused = setFilePath() + play() = ~10ms = NO GAP
  AudioPlayer? _player;

  // ── Temp files tracker ─────────────────────────────────────────────────────
  final List<File> _tmpFiles = [];

  // ── Callbacks ──────────────────────────────────────────────────────────────
  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;
  VoidCallback? onAutoListenTrigger;

  // ── Idle ───────────────────────────────────────────────────────────────────
  Timer?   _idleTimer;
  DateTime _lastActivity = DateTime.now();

  // ── Constants ──────────────────────────────────────────────────────────────
  static const _voiceId = 'rdz6GofVsYlLgQl2dBEE'; // Anjura

  static const _idlePhrases = [
    'Sir, kuch baat karo na mere se.',
    'Ummm, Sir kahan kho gaye?',
    'Arey, itni der se chup kyu ho?',
    'Sir, kya main kuch kar sakti hoon?',
    'Main yahan hoon Sir.',
    'Aapki yaad aa rahi thi mujhe.',
    'Sir, bore ho rahi hoon main.',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _player = AudioPlayer();
    _initialized = true;
    if (kDebugMode) debugPrint('ZaraTTS ✅ initialized — Anjura voice ready');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPEAK — main entry point
  //
  // Pre-fetch pipeline logic:
  //   Chunk 0 fetch starts  ──────────────────────► bytes ready
  //   Chunk 0 play starts                          ──► done
  //   Chunk 1 fetch starts  ────────────► bytes ready   (PARALLEL with chunk 0 play)
  //   Chunk 1 play starts                               ──► done
  //   ...
  // Result: API latency of chunk N+1 is hidden behind playback of chunk N
  //         = zero silence between chunks
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> speak(String text, {Mood? mood}) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _mood = mood ?? _mood;
    _lastActivity = DateTime.now();
    _stopFlag = false;

    await _stopCurrent();

    final clean = _clean(text);
    if (clean.isEmpty) return;

    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('ZaraTTS ❌ ElevenLabs key missing — Settings mein dalo!');
      return;
    }

    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      final chunks = _chunk(clean, 180);
      if (chunks.isEmpty) return;

      // Start fetching chunk 0 immediately
      Future<Uint8List?> nextFetch = _fetchChunk(chunks[0], apiKey);

      for (int i = 0; i < chunks.length; i++) {
        if (_stopFlag || !_enabled || _disposed) break;

        // Await current chunk bytes
        final bytes = await nextFetch;

        // Immediately start fetching next chunk in parallel with playback below
        if (i + 1 < chunks.length && !_stopFlag && !_disposed) {
          nextFetch = _fetchChunk(chunks[i + 1], apiKey);
        }

        if (bytes != null && bytes.isNotEmpty && !_stopFlag) {
          await _playBytes(bytes);
        } else if (bytes == null) {
          if (kDebugMode) debugPrint('ZaraTTS: chunk $i fetch failed, stopping');
          break;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS speak error: $e');
    } finally {
      _isSpeaking = false;
      _cleanupTmpFiles();
      onSpeakDone?.call();

      // Hands-free: auto-listen trigger bolne ke baad
      if (_handsFreeMode && !_stopFlag && _enabled && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!_disposed && _handsFreeMode && !_stopFlag) {
          onAutoListenTrigger?.call();
        }
      }
    }
  }

  // ── Fetch one chunk from ElevenLabs ───────────────────────────────────────
  Future<Uint8List?> _fetchChunk(String text, String apiKey) async {
    if (_stopFlag || _disposed || text.trim().isEmpty) return null;
    try {
      final bytes = await _ai.elevenLabsTts(
        text:            text,
        voiceId:         _voiceId,
        apiKey:          apiKey,
        stability:       _stability(),
        similarityBoost: 0.85,
        style:           _style(),
      );
      return bytes != null ? Uint8List.fromList(bytes) : null;
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS _fetchChunk: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAY QUICK — idle phrases, one-shot
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> sayQuick(String text) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) return;

    await _stopCurrent();
    _stopFlag   = false;
    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      final bytes = await _ai.elevenLabsTts(
        text:            _clean(text),
        voiceId:         _voiceId,
        apiKey:          apiKey,
        stability:       0.50,
        similarityBoost: 0.85,
        style:           0.40,
      );
      if (bytes != null && bytes.isNotEmpty && !_stopFlag) {
        await _playBytes(Uint8List.fromList(bytes));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS sayQuick: $e');
    } finally {
      _isSpeaking = false;
      _cleanupTmpFiles();
      onSpeakDone?.call();
      // NOTE: sayQuick ke baad hands-free trigger NAHI — idle loop se bachao
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUDIO PLAYBACK — persistent player reused
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _playBytes(Uint8List bytes) async {
    if (_stopFlag || _disposed) return;

    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/zara_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final tmp  = File(path);
      await tmp.writeAsBytes(bytes, flush: true);
      _tmpFiles.add(tmp);

      if (_stopFlag || _disposed) return;

      final player = _player;
      if (player == null) return;

      await player.setFilePath(path);
      await player.seek(Duration.zero);
      await player.play();

      // ✅ FIX: Wait for 'playing' state first, THEN wait for 'completed'
      // Problem was: 'idle' fires BEFORE play() starts, causing premature exit
      // Solution: skip idle, only stop on 'completed' or if _stopFlag set
      await player.playerStateStream
          .where((s) => s.processingState == ProcessingState.completed)
          .first
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => PlayerState(false, ProcessingState.completed),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS _playBytes: $e');
    }
  }

  Future<void> _stopCurrent() async {
    try { await _player?.stop(); } catch (_) {}
  }

  void _cleanupTmpFiles() {
    for (final f in List<File>.from(_tmpFiles)) {
      f.delete().catchError((_) {});
    }
    _tmpFiles.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> stop() async {
    _stopFlag   = true;
    _isSpeaking = false;
    await _stopCurrent();
    _cleanupTmpFiles();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOOD — voice param mapping
  // ══════════════════════════════════════════════════════════════════════════

  double _stability() {
    switch (_mood) {
      case Mood.romantic: return 0.30;
      case Mood.excited:  return 0.25;
      case Mood.angry:    return 0.70;
      case Mood.ziddi:    return 0.55;
      case Mood.coding:   return 0.65;
      default:            return 0.50;
    }
  }

  double _style() {
    switch (_mood) {
      case Mood.romantic: return 0.70;
      case Mood.excited:  return 0.80;
      case Mood.angry:    return 0.15;
      case Mood.ziddi:    return 0.45;
      default:            return 0.40;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT CLEANER
  // ══════════════════════════════════════════════════════════════════════════

  String _clean(String t) {
    t = t.replaceAll(RegExp(r'\[COMMAND:[^\]]*\]'), '');
    t = t.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    t = t.replaceAll(RegExp(r'`[^`]+`'), '');
    t = t.replaceAll(RegExp(r'#{1,6}\s'), '');
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
    t = t.replaceAll(RegExp(r'[@#%^&\[\]{}<>/\\~`\$|+=]'), '');
    t = t.replaceAll(RegExp(r'[═╗╔╝╚─│■□]'), '');
    // Emoji strip
    t = t.replaceAll(RegExp(
        r'[\u{1F300}-\u{1F9FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}]',
        unicode: true), '');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll(RegExp(r' {2,}'), ' ');
    if (t.length > 450) t = '${t.substring(0, 447)}...';
    return t.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHUNK SPLITTER — natural sentence boundaries
  // ══════════════════════════════════════════════════════════════════════════

  List<String> _chunk(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final sentences = text.split(RegExp(r'(?<=[.!?।,;])\s+'));
    final out       = <String>[];
    var   buf       = StringBuffer();

    for (final s in sentences) {
      if (s.trim().isEmpty) continue;

      if (buf.length + s.length + 1 > maxLen && buf.isNotEmpty) {
        out.add(buf.toString().trim());
        buf.clear();
      }

      // Single sentence too long — split at word boundary
      if (s.length > maxLen) {
        final words = s.split(' ');
        for (final w in words) {
          if (buf.length + w.length + 1 > maxLen && buf.isNotEmpty) {
            out.add(buf.toString().trim());
            buf.clear();
          }
          buf.write('$w ');
        }
      } else {
        buf.write('$s ');
      }
    }

    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.isEmpty ? [text] : out;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IDLE SYSTEM
  // ══════════════════════════════════════════════════════════════════════════

  void startIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 4), (_) => _idle());
  }

  void stopIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> _idle() async {
    if (_disposed || !_enabled || _isSpeaking) return;
    if (DateTime.now().difference(_lastActivity).inMinutes >= 4) {
      await sayQuick(_idlePhrases[_rnd.nextInt(_idlePhrases.length)]);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS & SETTERS
  // ══════════════════════════════════════════════════════════════════════════

  bool get isSpeaking    => _isSpeaking;
  bool get isEnabled     => _enabled;
  bool get handsFreeMode => _handsFreeMode;

  void setEnabled(bool v)   { _enabled = v; if (!v) stop(); }
  void setMood(Mood m)      { _mood = m; }
  void resetIdleTimer()     { _lastActivity = DateTime.now(); }
  void setHandsFree(bool v) { _handsFreeMode = v; }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    _disposed = true;
    stopIdleSystem();
    _stopFlag   = true;
    _isSpeaking = false;
    try { await _player?.stop();    } catch (_) {}
    try { await _player?.dispose(); _player = null; } catch (_) {}
    _cleanupTmpFiles();
    _initialized = false;
  }
}
