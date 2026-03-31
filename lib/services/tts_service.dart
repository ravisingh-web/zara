// lib/services/tts_service.dart
// Z.A.R.A. v16.0 — ElevenLabs Official Streaming TTS
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX v16: KEY BUGS RESOLVED                                             ║
// ║                                                                         ║
// ║  🔴 BUG 1: Silent failure when ElevenLabs key missing/invalid          ║
// ║     FIX:  onError callback added → UI shows real error message         ║
// ║                                                                         ║
// ║  🔴 BUG 2: HTTP 401/422/429 silently swallowed, no user feedback       ║
// ║     FIX:  onError fires with human-readable Hindi error message        ║
// ║                                                                         ║
// ║  🔴 BUG 3: AudioPlayer not disposed between chunks → memory leak       ║
// ║     FIX:  _haltPlayer() properly awaited, _src cancelled first         ║
// ║                                                                         ║
// ║  🔴 BUG 4: initialize() called multiple times → duplicate players      ║
// ║     FIX:  Guard check + old player disposed before new created         ║
// ║                                                                         ║
// ║  🔴 BUG 5: onSpeakDone not firing if exception thrown mid-stream       ║
// ║     FIX:  try/finally guarantees onSpeakDone always fires             ║
// ║                                                                         ║
// ║  ✅ onError callback → ZaraProvider shows error in UI + speaks it      ║
// ║  ✅ isTtsConfigured getter → Settings/UI can show warning              ║
// ║  ✅ Test mode: testSpeak() to verify key before saving                 ║
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
// _ZaraStreamAudioSource — feeds ElevenLabs bytes into just_audio
// ══════════════════════════════════════════════════════════════════════════════

class _ZaraStreamAudioSource extends StreamAudioSource {
  final _buffer  = BytesBuilder(copy: false);
  bool  _done    = false;
  int?  _total;
  final _waiters = <Completer<void>>[];

  void feed(List<int> bytes) {
    _buffer.add(Uint8List.fromList(bytes));
    for (final c in _waiters) { if (!c.isCompleted) c.complete(); }
    _waiters.clear();
  }

  void finalize(int total) {
    _done  = true;
    _total = total;
    for (final c in _waiters) { if (!c.isCompleted) c.complete(); }
    _waiters.clear();
  }

  void cancel() {
    _done = true;
    for (final c in _waiters) { if (!c.isCompleted) c.complete(); }
    _waiters.clear();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    while (_buffer.length < start + 1 && !_done) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    final all    = _buffer.toBytes();
    final length = all.length;
    final slice  = all.sublist(start, end != null ? min(end, length) : length);
    return StreamAudioResponse(
      sourceLength:  _total,
      contentLength: slice.length,
      offset:        start,
      stream:        Stream.value(slice),
      contentType:   'audio/mpeg',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ZaraTtsService — Singleton
// ══════════════════════════════════════════════════════════════════════════════

class ZaraTtsService {
  static final ZaraTtsService _i = ZaraTtsService._();
  factory ZaraTtsService() => _i;
  ZaraTtsService._();

  bool _initialized   = false;
  bool _isSpeaking    = false;
  bool _enabled       = true;
  bool _stopFlag      = false;
  bool _handsFreeMode = false;
  bool _disposed      = false;
  Mood _mood          = Mood.calm;

  AudioPlayer? _player;
  final _http = http.Client();
  _ZaraStreamAudioSource? _src;

  Timer?   _idleTimer;
  DateTime _lastActivity = DateTime.now();
  final    _rnd = Random();

  // ── Callbacks ──────────────────────────────────────────────────────────────
  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;
  VoidCallback? onAutoListenTrigger;
  void Function(double level)? onVolumeLevel;

  /// ✅ NEW: fires when TTS fails (key missing, quota, network error)
  /// ZaraProvider wires this to show error in UI
  void Function(String errorMsg)? onError;

  // ── Constants ──────────────────────────────────────────────────────────────
  static const _voiceId      = 'rdz6GofVsYlLgQl2dBEE'; // Anjura
  static const _models = ['eleven_flash_v2_5', 'eleven_multilingual_v2', 'eleven_flash_v2'];
  static const _outputFormat = 'mp3_44100_128';
  static const _latencyOpt   = 4;
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

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isSpeaking        => _isSpeaking;
  bool get isEnabled         => _enabled;
  bool get handsFreeMode     => _handsFreeMode;

  /// ✅ NEW: true only when ElevenLabs key is present and non-empty
  bool get isTtsConfigured   => ApiKeys.elevenKey.isNotEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE — FIX: idempotent, disposes old player before creating new
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_disposed) return;
    if (_initialized && _player != null) return; // already up

    // Dispose old player if somehow called twice
    if (_player != null) {
      try { await _player!.dispose(); } catch (_) {}
      _player = null;
    }

    _player      = AudioPlayer();
    _initialized = true;
    if (kDebugMode) debugPrint('ZaraTTS ✅ v16 streaming engine ready');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPEAK — main entry point
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> speak(String text, {Mood? mood}) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _mood         = mood ?? _mood;
    _lastActivity = DateTime.now();
    _stopFlag     = false;

    await _haltPlayer();

    final clean = _cleanText(text);
    if (clean.isEmpty) return;

    // ✅ FIX BUG 1: Check key BEFORE speaking, fire onError with message
    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('ZaraTTS ❌ ElevenLabs key missing');
      _fireError('ElevenLabs key set nahi hai. Settings mein dalo Sir.');
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
      _fireError('TTS error: ${e.toString().substring(0, min(60, e.toString().length))}');
    } finally {
      // ✅ FIX BUG 5: finally block guarantees callbacks always fire
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
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> sayQuick(String text) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) {
      _fireError('ElevenLabs key missing — Settings mein dalo Sir.');
      return;
    }

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
  // TEST SPEAK — verify key before saving in settings
  // ✅ NEW: returns success bool + error message
  // ══════════════════════════════════════════════════════════════════════════

  Future<({bool ok, String message})> testSpeak(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      return (ok: false, message: 'Key empty hai Sir!');
    }

    if (!_initialized) await initialize();
    await _haltPlayer();
    _stopFlag   = false;
    _isSpeaking = true;

    try {
      final ok = await _tryStream(
        'Haan Sir, ElevenLabs ka test ho gaya. Main bilkul sahi kaam kar rahi hoon!',
        apiKey.trim(),
        'eleven_flash_v2_5',
      );

      _isSpeaking = false;
      _cancelSrc();

      if (ok) {
        return (ok: true, message: '✅ ElevenLabs working! Key valid hai.');
      } else {
        return (ok: false, message: '❌ Key invalid hai ya quota khatam. Check karo.');
      }
    } catch (e) {
      _isSpeaking = false;
      _cancelSrc();
      return (ok: false, message: '❌ Error: ${e.toString().substring(0, min(80, e.toString().length))}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE STREAMING
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _streamSpeak(String text, String apiKey) async {
    if (text.trim().isEmpty) return false;
    for (final model in _models) {
      if (_stopFlag || _disposed) return false;
      final ok = await _tryStream(text, apiKey, model);
      if (ok) return true;
      if (kDebugMode) debugPrint('ZaraTTS: $model failed → trying next');
    }
    _fireError('ElevenLabs respond nahi kar raha. Internet check karo Sir.');
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

      final resp = await _http.send(req).timeout(const Duration(seconds: 15));

      // ✅ FIX BUG 2: Proper error handling for each HTTP error code
      if (resp.statusCode != 200) {
        final body = await resp.stream.toBytes();
        final err  = utf8.decode(body, allowMalformed: true);
        if (kDebugMode) {
          debugPrint('ZaraTTS ❌ HTTP ${resp.statusCode} [$model]');
          debugPrint('  ${err.length > 180 ? err.substring(0, 180) : err}');
        }

        String userMsg;
        switch (resp.statusCode) {
          case 401:
            userMsg = 'ElevenLabs key galat hai Sir. Settings mein sahi key dalo.';
            break;
          case 422:
            userMsg = 'ElevenLabs voice ya model plan mein nahi hai Sir.';
            break;
          case 429:
            userMsg = 'ElevenLabs ka quota khatam ho gaya Sir. Thodi der baad try karo.';
            break;
          case 500:
          case 503:
            userMsg = 'ElevenLabs server down hai Sir. Baad mein try karo.';
            break;
          default:
            userMsg = 'ElevenLabs error ${resp.statusCode} [$model].';
        }
        _fireError(userMsg);
        return false;
      }

      final src = _ZaraStreamAudioSource();
      _src = src;

      bool  playerStarted = false;
      int   totalBytes    = 0;
      final done          = Completer<bool>();

      late StreamSubscription<List<int>> sub;
      sub = resp.stream.listen(
        (chunk) async {
          if (_stopFlag || _disposed) {
            src.cancel(); sub.cancel();
            if (!done.isCompleted) done.complete(false);
            return;
          }
          src.feed(chunk);
          totalBytes += chunk.length;
          if (!playerStarted && totalBytes >= _minPlayBytes) {
            playerStarted = true;
            unawaited(_beginPlayback(src));
          }
        },
        onDone: () async {
          src.finalize(totalBytes);
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
          _fireError('Network error. Internet stable hai Sir?');
          if (!done.isCompleted) done.complete(false);
        },
        cancelOnError: true,
      );

      return await done.future;

    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS _tryStream ($model): $e');
      _src?.cancel(); _src = null;
      return false;
    }
  }

  Future<void> _beginPlayback(_ZaraStreamAudioSource src) async {
    if (_stopFlag || _disposed) return;
    final player = _player;
    if (player == null) return;
    try {
      await player.setAudioSource(src);
      await player.seek(Duration.zero);
      await player.play();

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
      await player.playerStateStream
          .where((s) => s.playing || s.processingState == ProcessingState.completed)
          .first
          .timeout(const Duration(seconds: 8));

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

  // ✅ FIX BUG 3: Proper halt order — cancel source THEN stop player
  Future<void> _haltPlayer() async {
    _cancelSrc();
    try { await _player?.stop(); } catch (_) {}
    onVolumeLevel?.call(0.0);
  }

  void _cancelSrc() {
    _src?.cancel();
    _src = null;
  }

  // ✅ NEW: internal helper — fires onError callback safely
  void _fireError(String msg) {
    if (_disposed) return;
    if (kDebugMode) debugPrint('ZaraTTS ERROR: $msg');
    onError?.call(msg);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOOD → ElevenLabs voice_settings
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
  // ══════════════════════════════════════════════════════════════════════════

  String _cleanText(String t) {
    t = t.replaceAll(RegExp(r'\[COMMAND:[^\]]*\]'), '');
    t = t.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    t = t.replaceAll(RegExp(r'`[^`]+`'), '');
    t = t.replaceAll(RegExp(r'#{1,6}\s'), '');
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
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
  // CHUNK SPLITTER
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
    if (!isTtsConfigured) return; // ✅ Don't idle-speak if key not 
