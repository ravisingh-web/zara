// lib/services/whisper_stt_service.dart
// Z.A.R.A. v17.0 — Multi-Provider STT
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  PROVIDERS:                                                             ║
// ║  1. HuggingFace Whisper large-v3 — FREE (no key needed basic use)      ║
// ║  2. OpenAI Whisper — fallback if HF fails (needs paid key)             ║
// ║                                                                         ║
// ║  HF MODEL: openai/whisper-large-v3                                     ║
// ║  • 99 languages including Hindi                                         ║
// ║  • FREE via HF Inference API                                            ║
// ║  • With HF token → higher rate limits                                   ║
// ╚══════════════════════════════════════════════════════════════════════════╝

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

  // HuggingFace Whisper
  static const _hfWhisperModel = 'openai/whisper-large-v3';
  static const _hfApiBase = 'https://api-inference.huggingface.co/models';

  static const _chunkDuration = Duration(seconds: 5);
  static const _minChunkBytes = 6000;

  // ══════════════════════════════════════════════════════════════════════════
  // MANUAL RECORDING
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> startRecording() async {
    if (_isRecording || _alwaysOnActive) return false;
    try {
      if (!await _recorder.hasPermission()) return false;
      final path = await _tmpPath('stt');
      await _recorder.start(
        const RecordConfig(
          encoder:    AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate:    128000,
          numChannels: 1,
        ),
        path: path,
      );
      _isRecording = true;
      if (kDebugMode) debugPrint('WhisperSTT ✅ recording started');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('WhisperSTT startRecording: $e');
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
          if (await file.exists() && await file.length() > _minChunkBytes) {
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
  // CORE TRANSCRIPTION — HuggingFace first, OpenAI fallback
  // ══════════════════════════════════════════════════════════════════════════
  Future<String?> _transcribe(String filePath) async {
    // Try HuggingFace Whisper first (FREE)
    final hfResult = await _transcribeHuggingFace(filePath);
    if (hfResult != null && hfResult.trim().isNotEmpty) {
      return _filterHallucinations(hfResult);
    }

    // Fallback to OpenAI Whisper
    if (ApiKeys.openaiKey.isNotEmpty) {
      if (kDebugMode) debugPrint('WhisperSTT → OpenAI fallback');
      return await _transcribeOpenAI(filePath);
    }

    return null;
  }

  // ── HuggingFace Whisper ────────────────────────────────────────────────────
  Future<String?> _transcribeHuggingFace(String filePath) async {
    try {
      final file  = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();

      final headers = <String, String>{
        'Content-Type': 'audio/m4a',
      };
      if (ApiKeys.hfKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${ApiKeys.hfKey}';
      }
      // Add Hindi language hint
      final url = Uri.parse(
        '$_hfApiBase/$_hfWhisperModel'
        '?language=hi&task=transcribe',
      );

      if (kDebugMode) debugPrint('WhisperSTT → HuggingFace (${bytes.length} bytes)');

      final resp = await http.post(url, headers: headers, body: bytes)
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final text = json['text'] as String? ?? '';
        if (kDebugMode) debugPrint('WhisperSTT HF ✅: "$text"');
        return text.trim().isEmpty ? null : text.trim();
      } else if (resp.statusCode == 503) {
        // Model loading
        if (kDebugMode) debugPrint('WhisperSTT HF: loading model...');
        await Future.delayed(const Duration(seconds: 5));
        // Retry once
        final retry = await http.post(url, headers: headers, body: bytes)
            .timeout(const Duration(seconds: 30));
        if (retry.statusCode == 200) {
          final json = jsonDecode(retry.body);
          return (json['text'] as String? ?? '').trim();
        }
      } else {
        if (kDebugMode) debugPrint('WhisperSTT HF ❌ ${resp.statusCode}: ${resp.body.substring(0, min(100, resp.body.length))}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('WhisperSTT HF error: $e');
      return null;
    }
  }

  // ── OpenAI Whisper fallback ────────────────────────────────────────────────
  Future<String?> _transcribeOpenAI(String filePath) async {
    try {
      final key  = ApiKeys.openaiKey;
      if (key.isEmpty) return null;
      final file = File(filePath);
      if (!await file.exists()) return null;

      final req = http.MultipartRequest(
        'POST', Uri.parse('https://api.openai.com/v1/audio/transcriptions'));
      req.headers['Authorization'] = 'Bearer $key';
      req.files.add(await http.MultipartFile.fromPath('file', filePath,
          filename: 'audio.m4a'));
      req.fields['model']    = 'whisper-1';
      req.fields['language'] = 'hi';
      req.fields['response_format'] = 'json';

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body     = await streamed.stream.toBytes();
      final json     = jsonDecode(utf8.decode(body));
      return (json['text'] as String? ?? '').trim();
    } catch (e) {
      if (kDebugMode) debugPrint('WhisperSTT OpenAI: $e');
      return null;
    }
  }

  // ── HuggingFace PCM transcription (for Vosk VAD fallback) ─────────────────
  Future<String?> transcribePcmBase64(String pcmBase64, int sampleRate) async {
    try {
      final pcmBytes = base64Decode(pcmBase64);
      // Save as WAV
      final tmp  = await getTemporaryDirectory();
      final path = '${tmp.path}/vosk_fallback_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _writePcmAsWav(path, pcmBytes, sampleRate);
      return await _transcribe(path);
    } catch (e) {
      if (kDebugMode) debugPrint('transcribePcmBase64: $e');
      return null;
    }
  }

  Future<void> _writePcmAsWav(String path, Uint8List pcm, int sr) async {
    final file   = File(path);
    final output = file.openWrite();
    final length = pcm.length;
    // WAV header
    final header = ByteData(44);
    void writeStr(int off, String s) {
      for (var i = 0; i < s.length; i++) header.setUint8(off + i, s.codeUnitAt(i));
    }
    writeStr(0, 'RIFF');
    header.setUint32(4, 36 + length, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sr, Endian.little);
    header.setUint32(28, sr * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    header.setUint32(40, length, Endian.little);
    output.add(header.buffer.asUint8List());
    output.add(pcm);
    await output.close();
  }

  // ── Hallucination filter ───────────────────────────────────────────────────
  String? _filterHallucinations(String text) {
    final t = text.trim().toLowerCase();
    const hallucinations = [
      'thank you for watching', 'thanks for watching',
      'subscribe', 'please like', 'you', 'the', 'i', 'a',
    ];
    if (t.length < 3) return null;
    if (hallucinations.any((h) => t == h)) return null;
    return text.trim();
  }

  // ── Temp file path ─────────────────────────────────────────────────────────
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
