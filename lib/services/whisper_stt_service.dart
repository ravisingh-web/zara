// lib/services/whisper_stt_service.dart
// Z.A.R.A. v18.0 — Clean STT (ElevenLabs REMOVED)
//
// STT Chain:
//   1. Gemini STT  → gemini-2.0-flash audio understanding (FREE)
//   2. HuggingFace → openai/whisper-small (FREE fallback)

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:zara/core/constants/api_keys.dart';

class WhisperSttService {
  static final WhisperSttService _i = WhisperSttService._();
  factory WhisperSttService() => _i;
  WhisperSttService._();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording    = false;
  bool _alwaysOnActive = false;
  bool _disposed       = false;

  bool get isRecording    => _isRecording;
  bool get alwaysOnActive => _alwaysOnActive;

  void Function(String text)? onTranscription;
  void Function(bool active)? onAlwaysOnChange;

  static const _hfBase         = 'https://router.huggingface.co/hf-inference/models';
  static const _hfWhisperModel = 'openai/whisper-small';
  static const _chunkDuration  = Duration(seconds: 5);
  static const _minBytes       = 500;

  // ══════════════════════════════════════════════════════════════════════════
  // MANUAL RECORDING
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> startRecording() async {
    if (_isRecording || _alwaysOnActive) return false;
    try {
      if (!await _recorder.hasPermission()) {
        if (kDebugMode) debugPrint('STT: no mic permission');
        return false;
      }
      final path = await _tmpPath('stt');
      await _recorder.start(
        const RecordConfig(
          encoder:     AudioEncoder.aacLc,
          sampleRate:  16000,
          bitRate:     128000,
          numChannels: 1,
        ),
        path: path,
      );
      _isRecording = true;
      if (kDebugMode) debugPrint('STT ✅ recording started');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('STT startRecording: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<String?> stopAndTranscribe() async {
    if (!_isRecording) return null;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path == null || path.isEmpty) return null;
      return await _transcribe(path);
    } catch (e) {
      if (kDebugMode) debugPrint('STT stopAndTranscribe: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try { await _recorder.cancel(); } catch (_) {}
    _isRecording = false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALWAYS-ON MODE
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> startAlwaysOn() async {
    if (_alwaysOnActive || _disposed) return false;
    if (!await _recorder.hasPermission()) return false;
    _alwaysOnActive = true;
    onAlwaysOnChange?.call(true);
    unawaited(_alwaysOnLoop());
    return true;
  }

  Future<void> stopAlwaysOn() async {
    _alwaysOnActive = false;
    onAlwaysOnChange?.call(false);
    try { await _recorder.cancel(); } catch (_) {}
    _isRecording = false;
  }

  Future<void> _alwaysOnLoop() async {
    while (_alwaysOnActive && !_disposed) {
      try {
        final path = await _tmpPath('aon');
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1),
          path: path,
        );
        _isRecording = true;
        await Future.delayed(_chunkDuration);
        if (!_alwaysOnActive) break;
        final stopped = await _recorder.stop();
        _isRecording  = false;
        if (stopped != null) {
          final file = File(stopped);
          if (await file.exists() && await file.length() > _minBytes) {
            unawaited(_transcribeAndFire(stopped));
          }
        }
      } catch (e) {
        _isRecording = false;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _transcribeAndFire(String path) async {
    try {
      final text = await _transcribe(path);
      if (text != null && text.trim().isNotEmpty) {
        onTranscription?.call(text.trim());
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE TRANSCRIPTION — Gemini first, HF fallback
  // ══════════════════════════════════════════════════════════════════════════
  Future<String?> _transcribe(String filePath) async {
    // 1. Gemini STT — most accurate for Hindi/Hinglish, FREE
    if (ApiKeys.geminiKey.isNotEmpty) {
      final result = await _transcribeGemini(filePath);
      if (result != null && result.trim().isNotEmpty) {
        return _filter(result);
      }
    }

    // 2. HuggingFace Whisper — FREE fallback
    final hfResult = await _transcribeHF(filePath);
    if (hfResult != null && hfResult.trim().isNotEmpty) {
      return _filter(hfResult);
    }

    return null;
  }

  // ── Gemini STT ─────────────────────────────────────────────────────────────
  Future<String?> _transcribeGemini(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length < _minBytes) return null;

      final b64 = base64Encode(bytes);
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models'
        '/gemini-2.0-flash:generateContent?key=${ApiKeys.geminiKey}'
      );

      final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [
              {
                'inline_data': {
                  'mime_type': 'audio/mp4',
                  'data': b64,
                }
              },
              {
                'text': 'Transcribe this audio. Return ONLY the spoken words in original language (Hindi/Hinglish/English). No translation, no explanation, just the words.'
              }
            ]
          }]
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
        if (kDebugMode) debugPrint('Gemini STT ✅: "$text"');
        return text.trim().isEmpty ? null : text.trim();
      }
      if (kDebugMode) debugPrint('Gemini STT ❌ ${resp.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini STT: $e');
      return null;
    }
  }

  // ── HuggingFace Whisper ────────────────────────────────────────────────────
  Future<String?> _transcribeHF(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length < _minBytes) return null;

      final headers = <String, String>{'Content-Type': 'audio/mpeg'};
      if (ApiKeys.hfKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${ApiKeys.hfKey}';
      }

      if (kDebugMode) debugPrint('HF STT → whisper-small (${bytes.length} bytes)');

      final resp = await http.post(
        Uri.parse('$_hfBase/$_hfWhisperModel'),
        headers: headers,
        body: bytes,
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final text = json['text'] as String? ?? '';
        if (kDebugMode) debugPrint('HF STT ✅: "$text"');
        return text.trim().isEmpty ? null : text.trim();
      }
      if (kDebugMode) debugPrint('HF STT ❌ ${resp.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('HF STT: $e');
      return null;
    }
  }

  // ── PCM base64 transcription (Vosk VAD fallback) ──────────────────────────
  Future<String?> transcribePcmBase64(String pcmBase64, int sampleRate) async {
    try {
      final pcm  = base64Decode(pcmBase64);
      final tmp  = await getTemporaryDirectory();
      final path = '${tmp.path}/vosk_pcm_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _writePcmWav(path, pcm, sampleRate);
      return await _transcribe(path);
    } catch (e) {
      if (kDebugMode) debugPrint('transcribePcmBase64: $e');
      return null;
    }
  }

  Future<void> _writePcmWav(String path, Uint8List pcm, int sr) async {
    final buf = ByteData(44 + pcm.length);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) buf.setUint8(o + i, s.codeUnitAt(i));
    }
    str(0, 'RIFF'); buf.setUint32(4, 36 + pcm.length, Endian.little);
    str(8, 'WAVE'); str(12, 'fmt ');
    buf.setUint32(16, 16, Endian.little); buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);  buf.setUint32(24, sr, Endian.little);
    buf.setUint32(28, sr * 2, Endian.little); buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    str(36, 'data'); buf.setUint32(40, pcm.length, Endian.little);
    final out = buf.buffer.asUint8List();
    out.setRange(44, 44 + pcm.length, pcm);
    await File(path).writeAsBytes(out);
  }

  // ── Hallucination filter ───────────────────────────────────────────────────
  String? _filter(String text) {
    final t = text.trim();
    if (t.length < 2) return null;
    const junk = [
      'thank you for watching', 'thanks for watching',
      'subscribe', 'please like', 'you', 'the', 'a', 'i',
      'hmm', '...', 'uh', 'um',
    ];
    if (junk.contains(t.toLowerCase())) return null;
    return t;
  }

  Future<String> _tmpPath(String prefix) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopAlwaysOn();
    try { await _recorder.dispose(); } catch (_) {}
  }
}
