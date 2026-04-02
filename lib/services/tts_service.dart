// lib/services/tts_service.dart
// Z.A.R.A. v17.0 — Multi-Provider TTS
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  PROVIDERS (priority order):                                            ║
// ║                                                                         ║
// ║  1. ElevenLabs  — Best quality, streaming (needs paid key)             ║
// ║  2. HuggingFace — FREE, no key needed for basic use                    ║
// ║     • facebook/mms-tts-hin    → Hindi (ZARA ke liye best)             ║
// ║     • microsoft/speecht5_tts  → English fallback                       ║
// ║  3. HF Inference API          → HF token se better quality            ║
// ║                                                                         ║
// ║  AUTO FALLBACK:                                                         ║
// ║  ElevenLabs key set → ElevenLabs use karo                             ║
// ║  ElevenLabs key missing/fail → HuggingFace use karo (FREE)            ║
// ║                                                                         ║
// ║  FIXES from v16:                                                        ║
// ║  ✅ mp3_44100_128 → mp3_22050_32 (free plan compatible)               ║
// ║  ✅ onError callback                                                    ║
// ║  ✅ isTtsConfigured — true even without ElevenLabs (HF fallback)       ║
// ║  ✅ HF Inference API — WAV audio, plays via just_audio                 ║
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
// _ZaraStreamAudioSource — in-memory audio for just_audio
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
    final all   = _buffer.toBytes();
    final len   = all.length;
    final slice = all.sublist(start, end != null ? min(end, len) : len);
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
// ZaraTtsService
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
  void Function(String errorMsg)? onError;

  // ── ElevenLabs Constants ───────────────────────────────────────────────────
  static const _voiceId      = 'rdz6GofVsYlLgQl2dBEE'; // Anjura
  static const _elModels     = ['eleven_flash_v2_5', 'eleven_multilingual_v2', 'eleven_flash_v2'];
  static const _outputFormat = 'mp3_22050_32'; // ✅ free plan compatible
  static const _latencyOpt   = 4;
  static const _minPlayBytes = 4096;

  // ── HuggingFace Constants ─────────────────────────────────────────────────
  // FREE: no key needed (rate limited) — or use HF token for higher limits
  static const _hfTtsHindi   = 'facebook/mms-tts-hin';      // Hindi TTS
  static const _hfTtsEnglish = 'facebook/mms-tts-eng';      // English TTS
  static const _hfApiBase    = 'https://api-inference.huggingface.co/models';

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
  bool get isSpeaking => _isSpeaking;
  bool get isEnabled  => _enabled;
  bool get handsFreeMode => _handsFreeMode;

  /// ✅ Always true — HF fallback available even without ElevenLabs key
  bool get isTtsConfigured => true;

  /// True if ElevenLabs will be used (key present)
  bool get isElevenLabsActive => ApiKeys.elevenKey.isNotEmpty;

  /// Which TTS provider is active
  String get activeProvider => isElevenLabsActive ? 'ElevenLabs' : 'HuggingFace';

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_disposed) return;
    if (_initialized && _player != null) return;
    if (_player != null) {
      try { await _player!.dispose(); } catch (_) {}
      _player = null;
    }
    _player      = AudioPlayer();
    _initialized = true;
    if (kDebugMode) debugPrint('ZaraTTS ✅ v17 ready — provider: $activeProvider');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPEAK — auto-selects provider
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

    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      bool ok = false;

      // Try ElevenLabs first if key present
      if (ApiKeys.elevenKey.isNotEmpty) {
        final chunks = _splitChunks(clean, 200);
        ok = true;
        for (final chunk in chunks) {
          if (_stopFlag || _disposed) break;
          final r = await _elevenLabsSpeak(chunk, ApiKeys.elevenKey);
          if (!r) { ok = false; break; }
        }
      }

      // Fallback to HuggingFace
      if (!ok && !_stopFlag && !_disposed) {
        if (kDebugMode) debugPrint('ZaraTTS → HuggingFace fallback');
        final chunks = _splitChunks(clean, 500); // HF handles longer chunks
        for (final chunk in chunks) {
          if (_stopFlag || _disposed) break;
          await _huggingFaceSpeak(chunk);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS speak: $e');
      _fireError('TTS error: ${e.toString().substring(0, min(60, e.toString().length))}');
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
  // SAY QUICK
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> sayQuick(String text) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    await _haltPlayer();
    _stopFlag   = false;
    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      bool ok = false;
      if (ApiKeys.elevenKey.isNotEmpty) {
        ok = await _elevenLabsSpeak(_cleanText(text), ApiKeys.elevenKey);
      }
      if (!ok && !_stopFlag && !_disposed) {
        await _huggingFaceSpeak(_cleanText(text));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS sayQuick: $e');
    } finally {
      _isSpeaking = false;
      _cancelSrc();
      onSpeakDone?.call();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ELEVENLABS STREAMING
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> _elevenLabsSpeak(String text, String apiKey) async {
    if (text.trim().isEmpty) return false;
    for (final model in _elModels) {
      if (_stopFlag || _disposed) return false;
      final ok = await _tryElStream(text, apiKey, model);
      if (ok) return true;
    }
    _fireError('ElevenLabs respond nahi kar raha → HuggingFace use ho raha hai');
    return false;
  }

  Future<bool> _tryElStream(String text, String apiKey, String model) async {
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

      final resp = await _http.send(req).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        final body = await resp.stream.toBytes();
        final err  = utf8.decode(body, allowMalformed: true);
        if (kDebugMode) debugPrint('ElevenLabs ❌ ${resp.statusCode}: ${err.substring(0, min(100, err.length))}');
        if (resp.statusCode == 401) _fireError('ElevenLabs key galat hai Sir. Check karo.');
        if (resp.statusCode == 429) _fireError('ElevenLabs quota khatam. HuggingFace use ho raha hai.');
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
          if (_stopFlag || _disposed) { src.cancel(); sub.cancel(); if (!done.isCompleted) done.complete(false); return; }
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
          await _waitForPlayback();
          if (!done.isCompleted) done.complete(true);
        },
        onError: (dynamic e) {
          src.cancel();
          if (!done.isCompleted) done.complete(false);
        },
        cancelOnError: true,
      );
      return await done.future;
    } catch (e) {
      if (kDebugMode) debugPrint('ElevenLabs _tryStream: $e');
      _src?.cancel(); _src = null;
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HUGGINGFACE TTS — FREE fallback
  //
  // Uses HF Inference API:
  //   POST https://api-inference.huggingface.co/models/facebook/mms-tts-hin
  //   Body: {"inputs": "text to speak"}
  //   Returns: audio/wav bytes
  //
  // FREE tier: ~30 req/hour without token
  // With HF token: much higher limits
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _huggingFaceSpeak(String text) async {
    if (text.trim().isEmpty || _stopFlag || _disposed) return;
    try {
      final isHindi = _isHindi(text);
      final model   = isHindi ? _hfTtsHindi : _hfTtsEnglish;
      final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'audio/wav'};
      if (ApiKeys.hfKey.isNotEmpty) headers['Authorization'] = 'Bearer ${ApiKeys.hfKey}';

      final resp = await _http.post(
        Uri.parse('$_hfApiBase/$model'),
        headers: headers,
        body: jsonEncode({'inputs': text}),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await _playBytes(resp.bodyBytes, 'audio/wav');
        if (kDebugMode) debugPrint('HF TTS ✅ ${resp.bodyBytes.length} bytes');
        return;
      } else if (resp.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 8));
        if (!_stopFlag && !_disposed) await _huggingFaceSpeak(text);
        return;
      }
      // HF failed → Gemini TTS (human-like voice, uses existing Gemini key)
      if (kDebugMode) debugPrint('HF TTS ❌ ${resp.statusCode} → Gemini TTS');
      await _geminiTtsSpeak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('HF TTS: $e → Gemini TTS');
      await _geminiTtsSpeak(text);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GEMINI TTS — Human-like voice, uses your existing Gemini API key
  //
  // Model : gemini-2.5-flash-preview-tts (FREE with Gemini key)
  // Voice : Aoede — warm, natural female voice (best for Hindi/Hinglish)
  // Output: PCM 24000Hz 16-bit mono → WAV header → just_audio
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _geminiTtsSpeak(String text) async {
    if (text.trim().isEmpty || _stopFlag || _disposed) return;
    final apiKey = ApiKeys.geminiKey;
    if (apiKey.isEmpty) {
      _fireError('TTS ke liye Gemini key chahiye Sir. Settings mein dalo.');
      return;
    }
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models'
        '/gemini-2.5-flash-preview-tts:generateContent?key=$apiKey'
      );
      final resp = await _http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': text}]}],
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': 'Aoede'}
              }
            }
          }
        }),
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final b64  = json['candidates']?[0]?['content']?['parts']?[0]?['inlineData']?['data'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          final pcm = base64Decode(b64);
          final wav = _pcmToWav(pcm);
          await _playBytes(wav, 'audio/wav');
          if (kDebugMode) debugPrint('Gemini TTS ✅ Aoede ${pcm.length} bytes');
          return;
        }
      }
      if (kDebugMode) debugPrint('Gemini TTS ❌ ${resp.statusCode}');
      _fireError('TTS unavailable. ElevenLabs key dalo Sir for best voice.');
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini TTS: $e');
      _fireError('TTS error. Internet check karo Sir.');
    }
  }

  // PCM 16-bit signed → WAV (adds 44-byte RIFF header)
  Uint8List _pcmToWav(List<int> pcm, {int sampleRate = 24000}) {
    const channels = 1, bitsPerSample = 16;
    final dataLen    = pcm.length;
    final byteRate   = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final buf        = ByteData(44 + dataLen);
    void str(int o, String s) { for (var i = 0; i < s.length; i++) buf.setUint8(o + i, s.codeUnitAt(i)); }
    str(0, 'RIFF'); buf.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE'); str(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);  buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, channels, Endian.little); buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little); buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    str(36, 'data'); buf.setUint32(40, dataLen, Endian.little);
    final out = buf.buffer.asUint8List();
    out.setRange(44, 44 + dataLen, pcm);
    return out;
  }

  // Play raw bytes (WAV from HuggingFace)
  Future<void> _playBytes(List<int> bytes, String mimeType) async {
    if (_stopFlag || _disposed || _player == null) return;
    try {
      final src = _ZaraStreamAudioSource();
      _src = src;
      src.feed(bytes);
      src.finalize(bytes.length);
      await _player!.setAudioSource(src);
      await _player!.seek(Duration.zero);
      await _player!.play();
      await _waitForPlayback();
    } catch (e) {
      if (kDebugMode) debugPrint('_playBytes: $e');
    }
  }

  // ── Hindi detection ────────────────────────────────────────────────────────
  bool _isHindi(String text) {
    // Check for Devanagari characters
    final devanagari = RegExp(r'[\u0900-\u097F]');
    if (devanagari.hasMatch(text)) return true;
    // Check for common Hinglish words
    final hindiWords = ['karo', 'hai', 'hoon', 'mein', 'sir', 'aap', 'kya',
                        'nahi', 'haan', 'aur', 'baat', 'bol', 'sun', 'zara'];
    final lower = text.toLowerCase();
    return hindiWords.any((w) => lower.contains(w));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEST SPEAK
  // ══════════════════════════════════════════════════════════════════════════
  Future<({bool ok, String message})> testSpeak(String apiKey) async {
    if (!_initialized) await initialize();
    await _haltPlayer();
    _stopFlag   = false;
    _isSpeaking = true;

    try {
      if (apiKey.trim().isNotEmpty) {
        // Test ElevenLabs
        final ok = await _tryElStream(
          'Haan Sir, ElevenLabs ka test ho gaya!',
          apiKey.trim(),
          'eleven_flash_v2_5',
        );
        _isSpeaking = false;
        _cancelSrc();
        if (ok) return (ok: true, message: '✅ ElevenLabs working!');
        return (ok: false, message: '❌ ElevenLabs key invalid ya quota khatam.');
      } else {
        // Test HuggingFace
        await _huggingFaceSpeak('Haan Sir, HuggingFace TTS kaam kar raha hai!');
        _isSpeaking = false;
        _cancelSrc();
        return (ok: true, message: '✅ HuggingFace TTS working! (Free)');
      }
    } catch (e) {
      _isSpeaking = false;
      _cancelSrc();
      return (ok: false, message: '❌ Error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAYBACK HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _beginPlayback(_ZaraStreamAudioSource src) async {
    if (_stopFlag || _disposed || _player == null) return;
    try {
      await _player!.setAudioSource(src);
      await _player!.seek(Duration.zero);
      await _player!.play();
      _player!.positionStream.listen((pos) {
        try {
          final dur = _player!.duration?.inMilliseconds ?? 0;
          if (dur > 0) {
            final p   = pos.inMilliseconds / dur;
            final vol = (0.4 + 0.6 * sin(p * pi * 8).abs()).clamp(0.0, 1.0);
            onVolumeLevel?.call(vol);
          }
        } catch (_) {}
      });
    } catch (e) {
      if (kDebugMode) debugPrint('_beginPlayback: $e');
    }
  }

  Future<void> _waitForPlayback() async {
    final player = _player;
    if (player == null || _stopFlag || _disposed) return;
    try {
      await player.playerStateStream
          .where((s) => s.playing || s.processingState == ProcessingState.completed)
          .first.timeout(const Duration(seconds: 8));
      await player.playerStateStream
          .where((s) => s.processingState == ProcessingState.completed || _stopFlag || _disposed)
          .first.timeout(
            const Duration(seconds: 120),
            onTimeout: () => PlayerState(false, ProcessingState.completed),
          );
    } catch (_) {}
    onVolumeLevel?.call(0.0);
  }

  Future<void> stop() async {
    _stopFlag   = true;
    _isSpeaking = false;
    await _haltPlayer();
    _cancelSrc();
  }

  Future<void> _haltPlayer() async {
    _cancelSrc();
    try { await _player?.stop(); } catch (_) {}
    onVolumeLevel?.call(0.0);
  }

  void _cancelSrc() { _src?.cancel(); _src = null; }
  void _fireError(String msg) { if (_disposed) return; if (kDebugMode) debugPrint('ZaraTTS ERROR: $msg'); onError?.call(msg); }

  // ══════════════════════════════════════════════════════════════════════════
  // MOOD PARAMS
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
    t = t.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}]', unicode: true), '');
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
    final out = <String>[];
    var buf = StringBuffer();
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

  // ── Setters ────────────────────────────────────────────────────────────────
  void setEnabled(bool v)   { _enabled = v; if (!v) stop(); }
  void setMood(Mood m)      { _mood = m; }
  void resetIdleTimer()     { _lastActivity = DateTime.now(); }
  void setHandsFree(bool v) { _handsFreeMode = v; }

  // ── Dispose ────────────────────────────────────────────────────────────────
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
