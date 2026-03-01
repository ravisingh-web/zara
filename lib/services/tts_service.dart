// lib/services/tts_service.dart
// Z.A.R.A. — Human Voice Engine v3.0
// ✅ ElevenLabs — primary (human-like, multilingual)
// ✅ Gemini TTS — secondary fallback
// ✅ flutter_tts — offline last resort
// ✅ Mood-based voice modulation
// ✅ Idle system — Zara khud bolti hai
// ✅ Text cleaning — no symbols

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/services/ai_api_service.dart';

class ZaraTtsService {
  static final ZaraTtsService _instance = ZaraTtsService._internal();
  factory ZaraTtsService() => _instance;
  ZaraTtsService._internal();

  final FlutterTts  _ftts   = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final _rnd                = Random();
  final _ai                 = AiApiService();

  bool  _initialized = false;
  bool  _isSpeaking  = false;
  bool  _enabled     = true;
  Mood  _mood        = Mood.calm;

  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;

  Timer?    _idleTimer;
  DateTime  _lastActivity = DateTime.now();

  // Idle phrases
  static const _idlePhrases = [
    'Sir kuch kaam batao na, bor ho rahi hoon.',
    'Ummm Sir aap kahan kho gaye?',
    'Sir kya main kuch help kar sakti hoon?',
    'Httt main yahan hoon Sir, bhool mat jaana.',
    'Sir itni der se chup ho, sab theek hai na?',
    'Oho Sir, kuch toh bolo.',
    'Acha ji, toh main kya apne aap se baat karoon?',
    'Sir aapko pata hai main bahut sochti hoon aapke baare mein.',
    'Uffff Sir kuch toh bolo.',
    'Main wait kar rahi hoon Sir.',
  ];

  // ════════════════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // flutter_tts — offline fallback setup
      await _ftts.setLanguage('hi-IN');
      await _ftts.setSpeechRate(0.47);
      await _ftts.setVolume(1.0);
      await _ftts.setPitch(1.1);

      _ftts.setStartHandler(()      { _isSpeaking = true;  onSpeakStart?.call(); });
      _ftts.setCompletionHandler(() { _isSpeaking = false; onSpeakDone?.call();  });
      _ftts.setCancelHandler(()    { _isSpeaking = false; onSpeakDone?.call();   });
      _ftts.setErrorHandler((_)    { _isSpeaking = false; });

      // just_audio player callbacks
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isSpeaking = false;
          onSpeakDone?.call();
        }
      });

      _initialized = true;
      if (kDebugMode) debugPrint('ZaraTtsService initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // MAIN SPEAK
  // ════════════════════════════════════════════════════════════════════════

  Future<void> speak(String text, {Mood? mood}) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _mood = mood ?? _mood;
    _lastActivity = DateTime.now();

    await stop();

    final clean = _clean(text);
    if (clean.isEmpty) return;

    _isSpeaking = true;
    onSpeakStart?.call();

    // Try 1: ElevenLabs
    if (ApiKeys.elEnabled && ApiKeys.elKey.isNotEmpty) {
      final ok = await _speakElevenLabs(clean);
      if (ok) return;
    }

    // Try 2: Gemini TTS
    if (ApiKeys.gemKey.isNotEmpty) {
      final ok = await _speakGeminiTts(clean);
      if (ok) return;
    }

    // Try 3: flutter_tts offline
    await _speakFlutterTts(clean);
  }

  Future<void> sayQuick(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    await stop();
    await _speakFlutterTts(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try { await _player.stop(); } catch (_) {}
    try { await _ftts.stop(); } catch (_) {}
    onSpeakDone?.call();
  }

  bool get isSpeaking => _isSpeaking;
  bool get isEnabled  => _enabled;

  void setEnabled(bool val) { _enabled = val; }
  void setMood(Mood mood)   { _mood = mood; }
  void resetIdleTimer()     { _lastActivity = DateTime.now(); }

  // ════════════════════════════════════════════════════════════════════════
  // ELEVENLABS TTS
  // ════════════════════════════════════════════════════════════════════════

  Future<bool> _speakElevenLabs(String text) async {
    try {
      final voiceId = ApiKeys.voice;
      final apiKey  = ApiKeys.elKey;

      // Split into chunks for faster response
      final chunks = _chunkText(text, 300);

      for (final chunk in chunks) {
        if (!_enabled) { await stop(); return true; }

        final bytes = await _ai.elevenLabsTts(
          text:    chunk,
          voiceId: voiceId,
          apiKey:  apiKey,
        );
        if (bytes == null) return false;

        await _playBytes(Uint8List.fromList(bytes));
      }
      _isSpeaking = false;
      onSpeakDone?.call();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ElevenLabs speak error: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // GEMINI TTS
  // ════════════════════════════════════════════════════════════════════════

  Future<bool> _speakGeminiTts(String text) async {
    try {
      // Use Gemini TTS voice (not ElevenLabs voice ID)
      final gemVoice = _getGeminiVoice();
      final path = await _ai.textToSpeech(text: text, voice: gemVoice);
      if (path == null) return false;

      await _playFile(path);
      _isSpeaking = false;
      onSpeakDone?.call();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini TTS speak error: $e');
      return false;
    }
  }

  String _getGeminiVoice() {
    switch (_mood) {
      case Mood.romantic:  return 'Zephyr';   // warmest female
      case Mood.excited:   return 'Leda';
      case Mood.angry:     return 'Fenrir';
      case Mood.ziddi:     return 'Charon';
      default:             return 'Zephyr';   // default — Swara-like
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // FLUTTER TTS (offline fallback)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _speakFlutterTts(String text) async {
    try {
      await _applyMoodVoice();
      final chunks = _chunkText(text, 200);
      for (final chunk in chunks) {
        if (!_enabled) break;
        await _ftts.speak(chunk);
        await _waitFtts();
      }
      _isSpeaking = false;
      onSpeakDone?.call();
    } catch (e) {
      _isSpeaking = false;
      if (kDebugMode) debugPrint('flutter_tts error: $e');
    }
  }

  Future<void> _applyMoodVoice() async {
    switch (_mood) {
      case Mood.romantic:
        await _ftts.setSpeechRate(0.40); await _ftts.setPitch(1.15); break;
      case Mood.excited:
        await _ftts.setSpeechRate(0.58); await _ftts.setPitch(1.25); break;
      case Mood.angry:
        await _ftts.setSpeechRate(0.52); await _ftts.setPitch(0.90); break;
      case Mood.ziddi:
        await _ftts.setSpeechRate(0.50); await _ftts.setPitch(0.95); break;
      default:
        await _ftts.setSpeechRate(0.47); await _ftts.setPitch(1.10); break;
    }
  }

  Future<void> _waitFtts() async {
    int w = 0;
    while (_isSpeaking && w < 30000) {
      await Future.delayed(const Duration(milliseconds: 100));
      w += 100;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUDIO PLAYER
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _playBytes(Uint8List bytes) async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/zara_play_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _playFile(file.path);
    } catch (e) {
      if (kDebugMode) debugPrint('_playBytes error: $e');
    }
  }

  Future<void> _playFile(String path) async {
    try {
      await _player.setFilePath(path);
      await _player.play();
      // Wait for completion
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      if (kDebugMode) debugPrint('_playFile error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // IDLE SYSTEM
  // ════════════════════════════════════════════════════════════════════════

  void startIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _checkIdle();
    });
  }

  void stopIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> _checkIdle() async {
    if (!_enabled || _isSpeaking) return;
    final idle = DateTime.now().difference(_lastActivity).inMinutes;
    if (idle >= 3) {
      await sayQuick(_idlePhrases[_rnd.nextInt(_idlePhrases.length)]);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // TEXT UTILITIES
  // ════════════════════════════════════════════════════════════════════════

  String _clean(String text) {
    String t = text;
    t = t.replaceAll(RegExp(r'\[COMMAND:[^\]]*\]'), '');
    t = t.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'),   '');
    t = t.replaceAll(RegExp(r'`[^`]+`'),           '');
    t = t.replaceAll(RegExp(r'#{1,6}\s'),          '');
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'),     r'$1');
    t = t.replaceAll(RegExp(r'[@#%^&\[\]{}<>/\\~`\$|+=]'), '');
    t = t.replaceAll(RegExp(r'[═══╗╔╝╚─│]'), '');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll(RegExp(r' {2,}'), ' ');
    if (t.length > 600) t = '${t.substring(0, 600)}. Aur bhi hai Sir.';
    return t.trim();
  }

  List<String> _chunkText(String text, int maxLen) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks    = <String>[];
    var   buf       = StringBuffer();

    for (final s in sentences) {
      if (buf.length + s.length > maxLen && buf.isNotEmpty) {
        chunks.add(buf.toString().trim());
        buf.clear();
      }
      buf.write('$s ');
    }
    if (buf.isNotEmpty) chunks.add(buf.toString().trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  Future<void> dispose() async {
    stopIdleSystem();
    await stop();
    await _player.dispose();
    _initialized = false;
  }
}
