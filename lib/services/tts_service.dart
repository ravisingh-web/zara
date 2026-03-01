// lib/services/tts_service.dart
// Z.A.R.A. — Voice Engine v3.0
// ElevenLabs → Gemini TTS → flutter_tts

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

  Timer?   _idleTimer;
  DateTime _lastActivity = DateTime.now();

  static const _idle = [
    'Sir kuch kaam batao na, bor ho rahi hoon.',
    'Ummm Sir aap kahan kho gaye?',
    'Sir kya main kuch help kar sakti hoon?',
    'Httt main yahan hoon Sir, bhool mat jaana.',
    'Sir itni der se chup ho, sab theek hai na?',
    'Oho Sir, kuch toh bolo.',
    'Main wait kar rahi hoon Sir.',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _ftts.setLanguage('hi-IN');
      await _ftts.setSpeechRate(0.47);
      await _ftts.setVolume(1.0);
      await _ftts.setPitch(1.1);
      _ftts.setStartHandler(()      { _isSpeaking = true;  onSpeakStart?.call(); });
      _ftts.setCompletionHandler(() { _isSpeaking = false; onSpeakDone?.call();  });
      _ftts.setCancelHandler(()    { _isSpeaking = false; onSpeakDone?.call();   });
      _ftts.setErrorHandler((_)    { _isSpeaking = false; });
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _isSpeaking = false; onSpeakDone?.call();
        }
      });
      _initialized = true;
    } catch (e) { if (kDebugMode) debugPrint('TTS init: $e'); }
  }

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

    // 1. ElevenLabs
    if (ApiKeys.elEnabled && ApiKeys.elKey.isNotEmpty) {
      if (await _speakEl(clean)) return;
    }
    // 2. Gemini TTS
    if (ApiKeys.gemKey.isNotEmpty) {
      if (await _speakGem(clean)) return;
    }
    // 3. flutter_tts offline
    await _speakFtts(clean);
  }

  Future<void> sayQuick(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    await stop();
    await _speakFtts(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try { await _player.stop(); } catch (_) {}
    try { await _ftts.stop(); } catch (_) {}
    onSpeakDone?.call();
  }

  bool get isSpeaking => _isSpeaking;
  bool get isEnabled  => _enabled;
  void setEnabled(bool v)  { _enabled = v; }
  void setMood(Mood m)     { _mood = m; }
  void resetIdleTimer()    { _lastActivity = DateTime.now(); }

  Future<bool> _speakEl(String text) async {
    try {
      final chunks = _chunk(text, 300);
      for (final c in chunks) {
        if (!_enabled) { await stop(); return true; }
        final bytes = await _ai.elevenLabsTts(
          text: c, voiceId: ApiKeys.voice, apiKey: ApiKeys.elKey);
        if (bytes == null) return false;
        await _playBytes(Uint8List.fromList(bytes));
      }
      _isSpeaking = false; onSpeakDone?.call();
      return true;
    } catch (e) { if (kDebugMode) debugPrint('EL speak: $e'); return false; }
  }

  Future<bool> _speakGem(String text) async {
    try {
      final voice = _gemVoice();
      final path  = await _ai.textToSpeech(text: text, voice: voice);
      if (path == null) return false;
      await _playFile(path);
      _isSpeaking = false; onSpeakDone?.call();
      return true;
    } catch (e) { if (kDebugMode) debugPrint('Gem TTS: $e'); return false; }
  }

  Future<void> _speakFtts(String text) async {
    try {
      await _applyMood();
      for (final c in _chunk(text, 200)) {
        if (!_enabled) break;
        await _ftts.speak(c);
        await _waitFtts();
      }
      _isSpeaking = false; onSpeakDone?.call();
    } catch (e) { _isSpeaking = false; }
  }

  String _gemVoice() {
    switch (_mood) {
      case Mood.romantic: return 'Zephyr';
      case Mood.excited:  return 'Leda';
      case Mood.angry:    return 'Fenrir';
      case Mood.ziddi:    return 'Charon';
      default:            return 'Zephyr';
    }
  }

  Future<void> _applyMood() async {
    switch (_mood) {
      case Mood.romantic: await _ftts.setSpeechRate(0.40); await _ftts.setPitch(1.15); break;
      case Mood.excited:  await _ftts.setSpeechRate(0.58); await _ftts.setPitch(1.25); break;
      case Mood.angry:    await _ftts.setSpeechRate(0.52); await _ftts.setPitch(0.90); break;
      case Mood.ziddi:    await _ftts.setSpeechRate(0.50); await _ftts.setPitch(0.95); break;
      default:            await _ftts.setSpeechRate(0.47); await _ftts.setPitch(1.10); break;
    }
  }

  Future<void> _waitFtts() async {
    int w = 0;
    while (_isSpeaking && w < 30000) { await Future.delayed(const Duration(milliseconds: 100)); w += 100; }
  }

  Future<void> _playBytes(Uint8List bytes) async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/zara_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _playFile(file.path);
    } catch (e) { if (kDebugMode) debugPrint('playBytes: $e'); }
  }

  Future<void> _playFile(String path) async {
    try {
      await _player.setFilePath(path);
      await _player.play();
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 60));
    } catch (e) { if (kDebugMode) debugPrint('playFile: $e'); }
  }

  void startIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 3), (_) => _checkIdle());
  }

  void stopIdleSystem() { _idleTimer?.cancel(); _idleTimer = null; }

  Future<void> _checkIdle() async {
    if (!_enabled || _isSpeaking) return;
    if (DateTime.now().difference(_lastActivity).inMinutes >= 3) {
      await sayQuick(_idle[_rnd.nextInt(_idle.length)]);
    }
  }

  String _clean(String t) {
    t = t.replaceAll(RegExp(r'\[COMMAND:[^\]]*\]'), '');
    t = t.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    t = t.replaceAll(RegExp(r'`[^`]+`'), '');
    t = t.replaceAll(RegExp(r'#{1,6}\s'), '');
    t = t.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
    t = t.replaceAll(RegExp(r'[@#%^&\[\]{}<>/\\~`\$|+=]'), '');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll(RegExp(r' {2,}'), ' ');
    if (t.length > 600) t = '${t.substring(0, 600)}. Aur bhi hai Sir.';
    return t.trim();
  }

  List<String> _chunk(String text, int max) {
    final sents = text.split(RegExp(r'(?<=[.!?])\s+'));
    final out   = <String>[];
    var   buf   = StringBuffer();
    for (final s in sents) {
      if (buf.length + s.length > max && buf.isNotEmpty) {
        out.add(buf.toString().trim()); buf.clear();
      }
      buf.write('$s ');
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.isEmpty ? [text] : out;
  }

  Future<void> dispose() async {
    stopIdleSystem(); await stop(); await _player.dispose(); _initialized = false;
  }
}
