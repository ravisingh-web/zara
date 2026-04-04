// lib/services/tts_service.dart
// Z.A.R.A. v18.0 — Clean TTS (ElevenLabs REMOVED)
//
// TTS Chain:
//   1. Gemini TTS  → gemini-2.5-flash-preview-tts, Aoede voice (FREE)
//   2. HuggingFace → facebook/mms-tts-hin (FREE fallback)
//
// No ElevenLabs. No crashes. No keys needed beyond Gemini.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';

// ── In-memory audio source for just_audio ─────────────────────────────────────
class _BytesAudioSource extends StreamAudioSource {
  final List<int> _bytes;
  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end   ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength:  _bytes.length,
      contentLength: end - start,
      offset:        start,
      stream:        Stream.value(_bytes.sublist(start, end)),
      contentType:   'audio/wav',
    );
  }
}

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

  Timer?   _idleTimer;
  DateTime _lastActivity = DateTime.now();
  final    _rnd = Random();

  // ── Callbacks ──────────────────────────────────────────────────────────────
  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;
  VoidCallback? onAutoListenTrigger;
  void Function(double)? onVolumeLevel;
  void Function(String)? onError;

  // ── HF Constants ──────────────────────────────────────────────────────────
  static const _hfBase     = 'https://router.huggingface.co/hf-inference/models';
  static const _hfTtsHindi = 'facebook/mms-tts-hin';
  static const _hfTtsEng   = 'facebook/mms-tts-eng';

  static const _idlePhrases = [
    'Sir, kuch baat karo na mere se.',
    'Ummm, Sir kahan kho gaye?',
    'Arey, itni der se chup kyu ho?',
    'Sir, kya main kuch kar sakti hoon?',
    'Main yahan hoon, Sir.',
    'Aapki yaad aa rahi thi mujhe.',
  ];

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isSpeaking      => _isSpeaking;
  bool get isEnabled       => _enabled;
  bool get handsFreeMode   => _handsFreeMode;
  bool get isTtsConfigured => true; // always true — Gemini always available

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_disposed) return;
    if (_initialized && _player != null) return;
    try { await _player?.dispose(); } catch (_) {}
    _player      = AudioPlayer();
    _initialized = true;
    if (kDebugMode) debugPrint('ZaraTTS ✅ v18 ready (Gemini + HF)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPEAK
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
      final chunks = _splitChunks(clean, 300);
      for (final chunk in chunks) {
        if (_stopFlag || _disposed) break;
        await _speakChunk(chunk);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak: $e');
    } finally {
      _isSpeaking = false;
      onSpeakDone?.call();
      if (_handsFreeMode && !_stopFlag && _enabled && !_disposed) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!_disposed && _handsFreeMode && !_stopFlag) onAutoListenTrigger?.call();
      }
    }
  }

  Future<void> sayQuick(String text) async {
    if (_disposed || !_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    await _haltPlayer();
    _stopFlag   = false;
    _isSpeaking = true;
    onSpeakStart?.call();
    try {
      await _speakChunk(_cleanText(text));
    } catch (e) {
      if (kDebugMode) debugPrint('TTS sayQuick: $e');
    } finally {
      _isSpeaking = false;
      onSpeakDone?.call();
    }
  }

  // ── Main speak chunk — Gemini first, HF fallback ──────────────────────────
  Future<void> _speakChunk(String text) async {
    if (text.trim().isEmpty || _stopFlag || _disposed) return;

    // 1. Gemini TTS (primary — FREE, human-like)
    if (ApiKeys.geminiKey.isNotEmpty) {
      final ok = await _geminiTts(text);
      if (ok) return;
    }

    // 2. HuggingFace TTS (fallback — FREE)
    await _hfTts(text);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GEMINI TTS — primary voice
  // Model: gemini-2.5-flash-preview-tts
  // Voice: Aoede (warm female, Hindi/Hinglish natural)
  // Returns PCM → we add WAV header → play
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> _geminiTts(String text) async {
    try {
      // Voice prompt based on mood
      final style = _geminiVoicePrompt();
      final prompt = style.isNotEmpty ? '$style: $text' : text;

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models'
        '/gemini-2.5-flash-preview-tts:generateContent'
        '?key=${ApiKeys.geminiKey}'
      );

      final resp = await _http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
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
        final b64  = json['candidates']?[0]?['content']?['parts']?[0]
                         ?['inlineData']?['data'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          final pcm = base64Decode(b64);
          final wav = _pcmToWav(pcm);
          await _playBytes(wav);
          if (kDebugMode) debugPrint('Gemini TTS ✅ ${pcm.length} bytes');
          return true;
        }
      }
      if (kDebugMode) debugPrint('Gemini TTS ❌ ${resp.statusCode}');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini TTS: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HUGGINGFACE TTS — fallback
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _hfTts(String text) async {
    if (text.trim().isEmpty || _stopFlag || _disposed) return;
    try {
      final isHindi = _isHindi(text);
      final model   = isHindi ? _hfTtsHindi : _hfTtsEng;

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (ApiKeys.hfKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${ApiKeys.hfKey}';
      }

      final resp = await _http.post(
        Uri.parse('$_hfBase/$model'),
        headers: headers,
        body: jsonEncode({'inputs': text}),
      ).timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await _playBytes(resp.bodyBytes);
        if (kDebugMode) debugPrint('HF TTS ✅ ${resp.bodyBytes.length} bytes');
      } else if (resp.statusCode == 503) {
        // Model loading — wait and retry
        if (kDebugMode) debugPrint('HF TTS: model loading...');
        await Future.delayed(const Duration(seconds: 8));
        if (!_stopFlag && !_disposed) await _hfTts(text);
      } else {
        if (kDebugMode) debugPrint('HF TTS ❌ ${resp.statusCode}');
        _fireError('TTS kaam nahi kar raha Sir. Internet check karo.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HF TTS: $e');
      _fireError('TTS error. Internet check karo Sir.');
    }
  }

  // ── Play bytes ─────────────────────────────────────────────────────────────
  Future<void> _playBytes(List<int> bytes) async {
    if (_stopFlag || _disposed || _player == null) return;
    try {
      final src = _BytesAudioSource(bytes);
      await _player!.setAudioSource(src);
      await _player!.seek(Duration.zero);
      await _player!.play();

      // Volume animation
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

      // Wait for playback complete
      await _player!.playerStateStream
          .where((s) =>
              s.processingState == ProcessingState.completed ||
              _stopFlag || _disposed)
          .first
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => PlayerState(false, ProcessingState.completed),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('_playBytes: $e');
    }
    onVolumeLevel?.call(0.0);
  }

  // ── PCM → WAV ─────────────────────────────────────────────────────────────
  Uint8List _pcmToWav(List<int> pcm, {int sampleRate = 24000}) {
    const ch = 1, bits = 16;
    final dataLen    = pcm.length;
    final byteRate   = sampleRate * ch * bits ~/ 8;
    final blockAlign = ch * bits ~/ 8;
    final buf        = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) buf.setUint8(o + i, s.codeUnitAt(i));
    }
    str(0, 'RIFF'); buf.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE'); str(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little); buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, ch, Endian.little); buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little); buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bits, Endian.little);
    str(36, 'data'); buf.setUint32(40, dataLen, Endian.little);
    final out = buf.buffer.asUint8List();
    out.setRange(44, 44 + dataLen, pcm);
    return out;
  }

  // ── Hindi detection ────────────────────────────────────────────────────────
  bool _isHindi(String text) {
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return true;
    final words = ['karo', 'hai', 'hoon', 'mein', 'sir', 'aap', 'kya',
                   'nahi', 'haan', 'aur', 'baat', 'bol', 'sun', 'zara',
                   'ji', 'bolo', 'theek', 'achha'];
    final lower = text.toLowerCase();
    return words.where((w) => lower.contains(w)).length >= 2;
  }

  // ── Gemini voice prompt based on mood ─────────────────────────────────────
  String _geminiVoicePrompt() {
    switch (_mood) {
      case Mood.romantic: return 'Say warmly and affectionately';
      case Mood.excited:  return 'Say enthusiastically and energetically';
      case Mood.angry:    return 'Say firmly and seriously';
      case Mood.coding:   return 'Say clearly and professionally';
      default:            return '';
    }
  }

  // ── Playback control ──────────────────────────────────────────────────────
  Future<void> stop() async {
    _stopFlag   = true;
    _isSpeaking = false;
    await _haltPlayer();
  }

  Future<void> _haltPlayer() async {
    try { await _player?.stop(); } catch (_) {}
    onVolumeLevel?.call(0.0);
  }

  void _fireError(String msg) {
    if (_disposed) return;
    if (kDebugMode) debugPrint('TTS ERROR: $msg');
    onError?.call(msg);
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
    _idleTimer = Timer.periodic(const Duration(minutes: 5), (_) => _idle());
  }

  void stopIdleSystem() { _idleTimer?.cancel(); _idleTimer = null; }

  Future<void> _idle() async {
    if (_disposed || !_enabled || _isSpeaking) return;
    if (DateTime.now().difference(_lastActivity).inMinutes >= 5) {
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
    try { await _player?.stop();    } catch (_) {}
    try { await _player?.dispose(); _player = null; } catch (_) {}
    _http.close();
    _initialized = false;
  }
}
