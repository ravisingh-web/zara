// lib/services/tts_service.dart
// Z.A.R.A. — Voice Engine v4.0
// ✅ ElevenLabs ONLY — Simran voice (rdz6GofVsYlLgQl2dBEE)
// ✅ Gemini TTS + flutter_tts REMOVED completely
// ✅ Mood-based voice params
// ✅ Idle system

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
  static final ZaraTtsService _instance = ZaraTtsService._internal();
  factory ZaraTtsService() => _instance;
  ZaraTtsService._internal();

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

  static const _voiceId = 'rdz6GofVsYlLgQl2dBEE'; // Simran

  static const _idlePhrases = [
    'Sir, kuch baat karo na mere se.',
    'Ummm, Sir kahan kho gaye?',
    'Sir, kya main kuch kar sakti hoon aapke liye?',
    'Arey Sir, itni der se chup kyu ho?',
    'Sir, main yahan hoon.',
    'Sir, aapki yaad aa rahi thi mujhe.',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isSpeaking = false;
          onSpeakDone?.call();
        }
      });
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init: $e');
    }
  }

  Future<void> speak(String text, {Mood? mood}) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _mood = mood ?? _mood;
    _lastActivity = DateTime.now();
    await stop();

    final clean  = _clean(text);
    if (clean.isEmpty) return;

    final apiKey = ApiKeys.elKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('ElevenLabs key nahi hai — Settings mein dalo');
      return;
    }

    _isSpeaking = true;
    onSpeakStart?.call();

    final chunks = _chunk(clean, 250);
    for (final chunk in chunks) {
      if (!_enabled) break;
      final bytes = await _ai.elevenLabsTts(
        text:           chunk,
        voiceId:        _voiceId,
        apiKey:         apiKey,
        stability:      _stability(),
        similarityBoost:0.85,
        style:          _style(),
      );
      if (bytes != null) {
        await _playBytes(Uint8List.fromList(bytes));
      } else {
        if (kDebugMode) debugPrint('ElevenLabs chunk failed');
        break;
      }
    }

    _isSpeaking = false;
    onSpeakDone?.call();
  }

  Future<void> sayQuick(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    final apiKey = ApiKeys.elKey;
    if (apiKey.isEmpty) return;
    await stop();
    _isSpeaking = true;
    onSpeakStart?.call();
    final bytes = await _ai.elevenLabsTts(
      text: _clean(text), voiceId: _voiceId, apiKey: apiKey,
      stability: 0.5, similarityBoost: 0.85, style: 0.3,
    );
    if (bytes != null) await _playBytes(Uint8List.fromList(bytes));
    _isSpeaking = false;
    onSpeakDone?.call();
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try { await _player.stop(); } catch (_) {}
    onSpeakDone?.call();
  }

  bool get isSpeaking => _isSpeaking;
  bool get isEnabled  => _enabled;
  void setEnabled(bool v) { _enabled = v; }
  void setMood(Mood m)    { _mood = m; }
  void resetIdleTimer()   { _lastActivity = DateTime.now(); }

  double _stability() {
    switch (_mood) {
      case Mood.romantic: return 0.35;
      case Mood.excited:  return 0.30;
      case Mood.angry:    return 0.70;
      case Mood.ziddi:    return 0.60;
      default:            return 0.50;
    }
  }

  double _style() {
    switch (_mood) {
      case Mood.romantic: return 0.60;
      case Mood.excited:  return 0.70;
      case Mood.angry:    return 0.20;
      default:            return 0.35;
    }
  }

  Future<void> _playBytes(Uint8List bytes) async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/zara_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _player.setFilePath(file.path);
      await _player.play();
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      if (kDebugMode) debugPrint('playBytes: $e');
    }
  }

  void startIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 4), (_) => _checkIdle());
  }

  void stopIdleSystem() { _idleTimer?.cancel(); _idleTimer = null; }

  Future<void> _checkIdle() async {
    if (!_enabled || _isSpeaking) return;
    if (DateTime.now().difference(_lastActivity).inMinutes >= 4) {
      await sayQuick(_idlePhrases[_rnd.nextInt(_idlePhrases.length)]);
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
    t = t.replaceAll(RegExp(r'[═╗╔╝╚─│■□]'), '');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll('\n', ' ');
    t = t.replaceAll(RegExp(r' {2,}'), ' ');
    if (t.length > 500) t = '${t.substring(0, 500)}.';
    return t.trim();
  }

  List<String> _chunk(String text, int max) {
    final sents = text.split(RegExp(r'(?<=[.!?।])\s+'));
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
