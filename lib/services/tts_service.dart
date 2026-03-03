// lib/services/tts_service.dart
// Z.A.R.A. v7.0 — Voice Engine
// ElevenLabs Simran (rdz6GofVsYlLgQl2dBEE) + eleven_v3
// Fixed audio playback — fresh AudioPlayer per chunk

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
  static final ZaraTtsService _i = ZaraTtsService._internal();
  factory ZaraTtsService() => _i;
  ZaraTtsService._internal();

  final _ai  = AiApiService();
  final _rnd = Random();

  bool  _initialized = false;
  bool  _isSpeaking  = false;
  bool  _enabled     = true;
  bool  _stopFlag    = false;
  Mood  _mood        = Mood.calm;

  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;

  Timer?   _idleTimer;
  DateTime _lastActivity = DateTime.now();

  static const _voiceId = 'rdz6GofVsYlLgQl2dBEE'; // Simran — HARDCODED

  static const _idlePhrases = [
    'Sir, kuch baat karo na mere se.',
    'Ummm, Sir kahan kho gaye?',
    'Arey, itni der se chup kyu ho?',
    'Sir, kya main kuch kar sakti hoon?',
    'Main yahan hoon Sir.',
    'Aapki yaad aa rahi thi mujhe.',
    'Sir, bore ho rahi hoon main.',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kDebugMode) debugPrint('ZaraTTS ✅ initialized (ElevenLabs Simran)');
  }

  // ── Speak ──────────────────────────────────────────────────────────────────
  Future<void> speak(String text, {Mood? mood}) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _mood = mood ?? _mood;
    _lastActivity = DateTime.now();
    _stopFlag = false;
    await _stopPlayer();

    final clean = _clean(text);
    if (clean.isEmpty) return;

    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('ZaraTTS: ElevenLabs key nahi — Settings mein dalo!');
      return;
    }

    if (kDebugMode) debugPrint('ZaraTTS: speaking "${clean.substring(0, min(60, clean.length))}"');

    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      final chunks = _chunk(clean, 200);
      for (final chunk in chunks) {
        if (_stopFlag || !_enabled) break;
        if (chunk.trim().isEmpty) continue;

        final bytes = await _ai.elevenLabsTts(
          text:            chunk,
          voiceId:         _voiceId,
          apiKey:          apiKey,
          stability:       _stability(),
          similarityBoost: 0.85,
          style:           _style(),
        );

        if (bytes != null && bytes.isNotEmpty) {
          await _playBytes(Uint8List.fromList(bytes));
        } else {
          if (kDebugMode) debugPrint('ZaraTTS: chunk failed, stopping');
          break;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS speak error: $e');
    } finally {
      _isSpeaking = false;
      onSpeakDone?.call();
    }
  }

  Future<void> sayQuick(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    final apiKey = ApiKeys.elevenKey;
    if (apiKey.isEmpty) return;

    await _stopPlayer();
    _stopFlag   = false;
    _isSpeaking = true;
    onSpeakStart?.call();

    try {
      final bytes = await _ai.elevenLabsTts(
        text: _clean(text), voiceId: _voiceId, apiKey: apiKey,
        stability: 0.50, similarityBoost: 0.85, style: 0.40,
      );
      if (bytes != null && bytes.isNotEmpty) {
        await _playBytes(Uint8List.fromList(bytes));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS sayQuick: $e');
    } finally {
      _isSpeaking = false;
      onSpeakDone?.call();
    }
  }

  Future<void> stop() async {
    _stopFlag   = true;
    _isSpeaking = false;
    await _stopPlayer();
  }

  Future<void> _stopPlayer() async {
    // No persistent player — each chunk gets fresh player
  }

  // ── Audio Playback — fresh AudioPlayer per chunk ──────────────────────────
  Future<void> _playBytes(Uint8List bytes) async {
    if (_stopFlag) return;
    File? tmp;
    AudioPlayer? player;
    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/zara_${DateTime.now().millisecondsSinceEpoch}.mp3';
      tmp = File(path);
      await tmp.writeAsBytes(bytes);

      if (_stopFlag) return;

      player = AudioPlayer();
      await player.setFilePath(path);
      await player.play();

      // Wait until done or timeout
      await player.playerStateStream
          .where((s) =>
              s.processingState == ProcessingState.completed ||
              s.processingState == ProcessingState.idle)
          .first
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      if (kDebugMode) debugPrint('ZaraTTS _playBytes: $e');
    } finally {
      try { await player?.dispose(); } catch (_) {}
      try { await tmp?.delete(); } catch (_) {}
    }
  }

  // ── Mood params ────────────────────────────────────────────────────────────
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

  // ── Text clean ─────────────────────────────────────────────────────────────
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
    if (t.length > 450) t = '${t.substring(0, 450)}.';
    return t.trim();
  }

  List<String> _chunk(String text, int max) {
    if (text.length <= max) return [text];
    final parts = text.split(RegExp(r'(?<=[.!?।,])\s+'));
    final out   = <String>[];
    var   buf   = StringBuffer();
    for (final p in parts) {
      if (buf.length + p.length > max && buf.isNotEmpty) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      buf.write('$p ');
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.isEmpty ? [text] : out;
  }

  // ── Idle system ────────────────────────────────────────────────────────────
  void startIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 4), (_) => _idle());
  }

  void stopIdleSystem() { _idleTimer?.cancel(); _idleTimer = null; }

  Future<void> _idle() async {
    if (!_enabled || _isSpeaking) return;
    if (DateTime.now().difference(_lastActivity).inMinutes >= 4) {
      await sayQuick(_idlePhrases[_rnd.nextInt(_idlePhrases.length)]);
    }
  }

  bool get isSpeaking => _isSpeaking;
  bool get isEnabled  => _enabled;
  void setEnabled(bool v) { _enabled = v; if (!v) stop(); }
  void setMood(Mood m)    { _mood = m; }
  void resetIdleTimer()   { _lastActivity = DateTime.now(); }

  Future<void> dispose() async {
    stopIdleSystem();
    await stop();
    _initialized = false;
  }
}
