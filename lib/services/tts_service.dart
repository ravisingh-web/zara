// lib/services/tts_service.dart
// Z.A.R.A. v15.0 — ElevenLabs Official Streaming TTS
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  OFFICIAL STREAMING — NO TEMP FILE, NO SILENCE GAP                     ║
// ║                                                                         ║
// ║  Endpoint: POST /v1/text-to-speech/{voice_id}/stream                   ║
// ║  Model   : eleven_turbo_v2_5  (lowest latency, free tier)              ║
// ║  Format  : mp3_22050_32       (free tier compatible)                   ║
// ║  Latency : optimize_streaming_latency=4  (max — text normalizer off)   ║
// ║                                                                         ║
// ║  HOW IT WORKS:                                                          ║
// ║  ┌─────────────────────────────────────────────────────────────────┐   ║
// ║  │  http.Client().send()  →  StreamedResponse                      │   ║
// ║  │  bytes arrive progressively (chunked transfer encoding)         │   ║
// ║  │  _ZaraStreamAudioSource.feed() accumulates bytes in buffer      │   ║
// ║  │  just_audio calls getByteRange() as it needs data               │   ║
// ║  │  Audio starts playing ~200-400ms after first request byte       │   ║
// ║  │  No file write → no disk I/O → no latency from storage          │   ║
// ║  └─────────────────────────────────────────────────────────────────┘   ║
// ║                                                                         ║
// ║  StreamAudioSource is just_audio's official in-memory streaming API.   ║
// ║  We subclass it, accumulate ElevenLabs bytes as they arrive, then      ║
// ║  serve them to just_audio's internal player buffer on demand.          ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';

// ══════════════════════════════════════════════════════════════════════════════
// _ZaraStreamAudioSource
//
// Feeds ElevenLabs streaming bytes into just_audio without any file I/O.
//
// just_audio calls getByteRange(start, end) whenever it needs audio data.
// We block (await) until the requested bytes have arrived from ElevenLabs,
// then return them immediately. This is the official "push" pattern from
// the just_audio documentation.
// ══════════════════════════════════════════════════════════════════════════════

class _ZaraStreamAudioSource extends StreamAudioSource {
  final _buffer    = BytesBuilder(copy: false);
  bool  _done      = false;
  int?  _totalSize;
  final _waiters   = <Completer<void>>[];

  // Called by _TtsEngine as bytes arrive from ElevenLabs
  void feed(List<int> bytes) {
    _buffer.add(Uint8List.fromList(bytes));
    // Wake any waiting getByteRange() calls
    for (final c in _waiters) { if (!c.isCompleted) c.complete(); }
    _waiters.clear();
  }

  // Called by _TtsEngine when ElevenLabs stream is fully received
  void finalize(int totalBytes) {
    _done      = true;
    _totalSize = totalBytes;
    for (final c in _waiters) { if (!c.isCompleted) c.complete(); }
    _waiters.clear();
  }

  // Signal error / cancellation
  void cancel() {
    _done = true;
    for (final c in _waiters) { if (!c.isCompleted) c.complete(); }
    _waiters.clear();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;

    // Wait until we have at least 'start' bytes (or stream is done)
    while (_buffer.length < start + 1 && !_done) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }

    final all    = _buffer.toBytes();
    final length = all.length;
    final slice  = all.sublist(start, end != null ? min(end, length) : length);

    return StreamAudioResponse(
      sourceLength: _totalSize,       // null until finalize() is called
      contentLength: slice.length,
      offset: start,
      stream: Stream.value(slice),
      contentType: 'audio/mpeg',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ZaraTtsService
// ══════════════════════════════════════════════════════════════════════════════

class ZaraTtsService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ZaraTtsService _i = ZaraTtsService._();
  factory ZaraTtsService() => _i;
  ZaraTtsService._();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _initialized   = false;
  bool _isSpeaking    = false;
  bool _enabled       = true;
  bool _stopFlag      = false;
  bool _handsFreeMode = false;
  bool _disposed      = false;
  Mood _mood          = Mood.calm;

  // ── Single persistent AudioPlayer — created once, reused forever ───────────
  AudioPlayer? _player;

  // ── Persistent HTTP client — reuses TCP connection to ElevenLabs ───────────
  final _http = http.Client();

  // ── Active StreamAudioSource ──────────────────────────────────────────────
  _ZaraStreamAudioSource? _src;

  // ── Idle system ────────────────────────────────────────────────────────────
  Timer?   _idleTimer;
  DateTime _lastActivity = DateTime.now();
  final    _rnd = Random();

  // ── Callbacks ──────────────────────────────────────────────────────────────
  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;
  VoidCallback? onAutoListenTrigger;
  void Function(double level)? onVolumeLevel;

  // ── Constants ──────────────────────────────────────────────────────────────

  // ElevenLabs voice — Anjura
  static const _voiceId = 'rdz6GofVsYlLgQl2dBEE';

  // eleven_turbo_v2_5: ~75ms inference, free tier, supports 32 languages
  // Fallback to eleven_multilingual_v2 if turbo fails (rare)
  static const _models = [
    'eleven_turbo_v2_5',
    'eleven_multilingual_v2',
  ];

  // mp3_22050_32 = free tier. mp3_44100_128 = Creator+ only (paid).
  static const _outputFormat = 'mp3_22050_32';

  // optimize_streaming_latency:
  //   0 = no optimization
  //   4 = max speed (text normalizer off — numbers may be pronounced oddly)
  // Use 3 if numbers/dates matter more than latency.
  static const _latencyOpt = 4;

  // Minimum bytes to buffer before AudioPlayer.play() is called.
  // ~6KB ≈ first ~0.4s of audio at 22050Hz/32kbps.
  // Lower = faster start, but higher risk of stutter on slow connections.
  static const _minPlayBytes = 6144;

  static const _idlePhrases = [
    'Sir, kuch baat karo na mere se.',
    'Ummm, Sir kahan kho gaye?',
    'Arey, itni der se chup kyu ho?',
    'Sir, kya main kuch kar sakti hoon?',
    'Main yahan hoon, Sir.',
    'Aapki yaad aa rahi thi mujhe.',
    'Sir, bore ho rahi hoon main.',
    'Kuch toh bolo ji.',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _player = AudioPlayer();
    _initialized = true;
    if (kDebugMode) debugPrint('ZaraTTS ✅ v15 streaming engine ready');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPEAK — main entry point
  //
  // Splits text into natural chunks (≤ 200 chars), streams each one.
  // First chunk starts playing as soon as _minPlayBytes are buffered.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> speak(String text, {Mood? mood}) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _mood = mood ?? _mood;
    _lastActivity = DateTime.now();
    _stopFlag = false;

    await _haltPlayer();

    final clean = _cleanText(text);
    if (clean.isEmpty) return;

    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('ZaraTTS ❌ ElevenLabs key missing — Settings mein dalo');
      return;
    }

    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      final chunks = _splitChunks(clean, 200);
      for (final chunk in chunks) {
        if (_stopFlag || _disposed) break;
        final ok = await _streamSpeak(chunk, apiKey);
        if (!ok) break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS speak: $e');
    } finally {
      _isSpeaking = false;
      _cancelSrc();
      onSpeakDone?.call();

      if (_handsFreeMode && !_stopFlag && _enabled && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!_disposed && _handsFreeMode && !_stopFlag) onAutoListenTrigger?.call();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAY QUICK — single short phrase (wake ack, idle)
  // Bypasses the chunk splitter for lowest latency.
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> sayQuick(String text) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) return;

    await _haltPlayer();
    _stopFlag   = false;
    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      await _streamSpeak(_cleanText(text), apiKey);
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS sayQuick: $e');
    } finally {
      _isSpeaking = false;
      _cancelSrc();
      onSpeakDone?.call();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _streamSpeak — core streaming logic
  //
  // 1. Build POST /v1/text-to-speech/{voice_id}/stream request
  // 2. http.Client().send() → StreamedResponse (bytes arrive progressively)
  // 3. Create _ZaraStreamAudioSource, feed bytes as they arrive
  // 4. After _minPlayBytes buffered → AudioPlayer.setAudioSource() + play()
  // 5. Continue feeding bytes while player plays
  // 6. On stream done → finalize() → player reads to end → return
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _streamSpeak(String text, String apiKey) async {
    if (text.trim().isEmpty) return false;

    for (final model in _models) {
      if (_stopFlag || _disposed) return false;
      final ok = await _tryStream(text, apiKey, model);
      if (ok) return true;
      if (kDebugMode) debugPrint('ZaraTTS: $model failed → trying next');
    }
    return false;
  }

  Future<bool> _tryStream(String text, String apiKey, String model) async {
    try {
      final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$_voiceId/stream'
        '?output_format=$_outputFormat'
        '&optimize_streaming_latency=$_latencyOpt',
      );

      final req = http.Request('POST', uri)
        ..headers['xi-api-key']   = apiKey
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept']       = 'audio/mpeg'
        ..body = jsonEncode({
            'text'     : text,
            'model_id' : model,
            'voice_settings': {
              'stability'       : _stability(),
              'similarity_boost': 0.85,
              'style'           : _style(),
              'use_speaker_boost': true,
            },
          });

      if (kDebugMode) {
        final p = text.length > 55 ? '${text.substring(0, 55)}…' : text;
        debugPrint('ZaraTTS → $model | "$p"');
      }

      // ── Send request — do NOT await entire response (that defeats streaming) ─
      final resp = await _http.send(req).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        final body = await resp.stream.toBytes();
        final err  = utf8.decode(body, allowMalformed: true);
        if (kDebugMode) {
          debugPrint('ZaraTTS ❌ HTTP ${resp.statusCode} [$model]');
          final short = err.length > 180 ? err.substring(0, 180) : err;
          debugPrint('  $short');
          if (resp.statusCode == 401) debugPrint('  → Invalid API key');
          if (resp.statusCode == 422) debugPrint('  → Model/voice not on your plan');
          if (resp.statusCode == 429) debugPrint('  → Rate limit / quota exceeded');
        }
        return false;
      }

      // ── Create fresh StreamAudioSource for this request ────────────────────
      final src = _ZaraStreamAudioSource();
      _src = src;

      bool  playerStarted = false;
      int   totalBytes    = 0;
      final done          = Completer<bool>();

      // ── Consume stream ─────────────────────────────────────────────────────
      late StreamSubscription<List<int>> sub;
      sub = resp.stream.listen(
        (chunk) async {
          if (_stopFlag || _disposed) {
            src.cancel();
            sub.cancel();
            if (!done.isCompleted) done.complete(false);
            return;
          }

          src.feed(chunk);
          totalBytes += chunk.length;

          // Start player once we have enough data buffered
          if (!playerStarted && totalBytes >= _minPlayBytes) {
            playerStarted = true;
            unawaited(_beginPlayback(src));
          }
        },
        onDone: () async {
          src.finalize(totalBytes);

          // Handle case: short text that finished before _minPlayBytes
          if (!playerStarted && totalBytes > 0 && !_stopFlag && !_disposed) {
            playerStarted = true;
            unawaited(_beginPlayback(src));
          }

          if (kDebugMode) debugPrint('ZaraTTS ✅ $model — $totalBytes bytes');
          await _waitForPlayback();
          if (!done.isCompleted) done.complete(true);
        },
        onError: (dynamic e) {
          if (kDebugMode) debugPrint('ZaraTTS stream error: $e');
          src.cancel();
          if (!done.isCompleted) done.complete(false);
        },
        cancelOnError: true,
      );

      return await done.future;

    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS _tryStream ($model): $e');
      _src?.cancel();
      _src = null;
      return false;
    }
  }

  Future<void> _beginPlayback(_ZaraStreamAudioSource src) async {
    if (_stopFlag || _disposed) return;
    final player = _player;
    if (player == null) return;
    try {
      // setAudioSource() opens the StreamAudioSource immediately
      // It calls src.request() which blocks until data is available
      await player.setAudioSource(src);
      await player.seek(Duration.zero);
      await player.play();

      // Orb animation — pulsing volume level while speaking
      player.positionStream.listen((pos) {
        try {
          final dur = player.duration?.inMilliseconds ?? 0;
          if (dur > 0) {
            final p   = pos.inMilliseconds / dur;
            final vol = (0.4 + 0.6 * sin(p * pi * 8).abs()).clamp(0.0, 1.0);
            onVolumeLevel?.call(vol);
          }
        } catch (_) {}
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS _beginPlayback: $e');
    }
  }

  Future<void> _waitForPlayback() async {
    final player = _player;
    if (player == null || _stopFlag || _disposed) return;
    try {
      // Wait until player actually starts (or immediately if already completed)
      await player.playerStateStream
          .where((s) =>
              s.playing ||
              s.processingState == ProcessingState.completed)
          .first
          .timeout(const Duration(seconds: 8));

      // Wait for completion (or stop flag)
      await player.playerStateStream
          .where((s) =>
              s.processingState == ProcessingState.completed ||
              _stopFlag || _disposed)
          .first
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () => PlayerState(false, ProcessingState.completed),
          );
    } catch (_) {}
    onVolumeLevel?.call(0.0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> stop() async {
    _stopFlag   = true;
    _isSpeaking = false;
    await _haltPlayer();
    _cancelSrc();
  }

  Future<void> _haltPlayer() async {
    try { await _player?.stop(); } catch (_) {}
    onVolumeLevel?.call(0.0);
  }

  void _cancelSrc() {
    _src?.cancel();
    _src = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOOD → ElevenLabs voice_settings params
  //
  // stability:        0.0 = very expressive, 1.0 = very consistent
  // style:            0.0 = neutral, 1.0 = exaggerated
  // ══════════════════════════════════════════════════════════════════════════

  double _stability() {
    switch (_mood) {
      case Mood.romantic: return 0.28;
      case Mood.excited:  return 0.22;
      case Mood.angry:    return 0.72;
      case Mood.ziddi:    return 0.55;
      case Mood.coding:   return 0.68;
      default:            return 0.45;
    }
  }

  double _style() {
    switch (_mood) {
      case Mood.romantic: return 0.75;
      case Mood.excited:  return 0.82;
      case Mood.angry:    return 0.12;
      case Mood.ziddi:    return 0.42;
      default:            return 0.32;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT CLEANER
  // Removes markdown, code blocks, emojis, control chars before TTS
  // ══════════════════════════════════════════════════════════════════════════

  String _cleanText(String t) {
    t = t.replaceAll(RegExp(r'\[COMMAND:[^\]]*\]'), '');
    t = t.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');   // **bold**
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '');        // code blocks
    t = t.replaceAll(RegExp(r'`[^`]+`'), '');               // inline code
    t = t.replaceAll(RegExp(r'#{1,6}\s'), '');              // headers
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');      // *italic*
    t = t.replaceAll(RegExp(r'[@#%^&\[\]{}<>/\\~`\$|+=]'), '');
    t = t.replaceAll(RegExp(r'[═╗╔╝╚─│■□]'), '');
    t = t.replaceAll(RegExp(
        r'[\u{1F300}-\u{1F9FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}]',
        unicode: true), '');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll(RegExp(r' {2,}'), ' ');
    if (t.length > 500) t = '${t.substring(0, 497)}...';
    return t.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHUNK SPLITTER — splits on sentence boundaries
  // ══════════════════════════════════════════════════════════════════════════

  List<String> _splitChunks(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final sentences = text.split(RegExp(r'(?<=[.!?।,;])\s+'));
    final out       = <String>[];
    var   buf       = StringBuffer();

    for (final s in sentences) {
      if (s.trim().isEmpty) continue;
      if (buf.length + s.length + 1 > maxLen && buf.isNotEmpty) {
        out.add(buf.toString().trim()); buf.clear();
      }
      if (s.length > maxLen) {
        for (final w in s.split(' ')) {
          if (buf.length + w.length + 1 > maxLen && buf.isNotEmpty) {
            out.add(buf.toString().trim()); buf.clear();
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

  void stopIdleSystem() { _idleTimer?.cancel(); _idleTimer = null; }

  Future<void> _idle() async {
    if (_disposed || !_enabled || _isSpeaking) return;
    if (DateTime.now().difference(_lastActivity).inMinutes >= 4) {
      await sayQuick(_idlePhrases[_rnd.nextInt(_idlePhrases.length)]);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS / SETTERS
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
    _disposed   = true;
    _stopFlag   = true;
    _isSpeaking = false;
    stopIdleSystem();
    _cancelSrc();
    try { await _player?.stop();    } catch (_) {}
    try { await _player?.dispose(); _player = null; } catch (_) {}
    _http.close();
    _initialized = false;
  }
}
