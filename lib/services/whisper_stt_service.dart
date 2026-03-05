// lib/services/whisper_stt_service.dart
// Z.A.R.A. v8.0 — OpenAI Whisper STT + Always-On Background Listening
//
// ✅ Manual mode  : startRecording / stopAndTranscribe
// ✅ Always-On    : continuous 5s chunk recording → Whisper → callback
// ✅ Noise filter : skips silence / hallucinated text
// ✅ Background   : runs while Zara is minimized via ForegroundService

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

  // Callbacks
  void Function(String text)? onTranscription;   // always-on: speech detected
  void Function(bool active)? onAlwaysOnChange;  // mode changed

  static const _chunkDuration = Duration(seconds: 5);
  static const _minChunkBytes = 6000; // skip silence chunks

  // ══════════════════════════════════════════════════════════════════════════
  // MANUAL MODE
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> startRecording() async {
    if (_isRecording || _alwaysOnActive) return false;
    try {
      if (!await _recorder.hasPermission()) return false;
      final path = await _tmpPath('stt');
      await _recorder.start(
        const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            bitRate: 128000,
            numChannels: 1),
        path: path,
      );
      _isRecording = true;
      if (kDebugMode) debugPrint('Whisper ✅ recording');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Whisper startRecording: $e');
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
  // ALWAYS-ON MODE — background continuous listening
  //
  // Usage in zara_provider.initialize():
  //   _whisper.onTranscription = (text) => receiveCommand(text);
  //   await _whisper.startAlwaysOn();
  //
  // Flow:
  //   record 5s → send to Whisper → if real speech → fire onTranscription
  //   → immediately record next 5s → loop
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> startAlwaysOn() async {
    if (_alwaysOnActive || _disposed) return false;
    if (!await _recorder.hasPermission()) {
      if (kDebugMode) debugPrint('AlwaysOn: no mic permission');
      return false;
    }
    _alwaysOnActive = true;
    onAlwaysOnChange?.call(true);
    if (kDebugMode) debugPrint('🎙️ Always-On: ACTIVE');
    unawaited(_alwaysOnLoop());
    return true;
  }

  Future<void> stopAlwaysOn() async {
    _alwaysOnActive = false;
    if (_isRecording) {
      try { await _recorder.cancel(); } catch (_) {}
      _isRecording = false;
    }
    onAlwaysOnChange?.call(false);
    if (kDebugMode) debugPrint('🎙️ Always-On: STOPPED');
  }

  Future<void> _alwaysOnLoop() async {
    while (_alwaysOnActive && !_disposed) {
      try {
        final path = await _recordChunk();
        if (path == null || !_alwaysOnActive) break;
        // Transcribe in parallel — don't block next chunk
        unawaited(_transcribeAndFire(path));
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        if (kDebugMode) debugPrint('AlwaysOn loop: $e');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<String?> _recordChunk() async {
    if (_disposed || !_alwaysOnActive) return null;
    try {
      final path = await _tmpPath('ao');
      await _recorder.start(
        const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            bitRate: 64000,
            numChannels: 1),
        path: path,
      );
      _isRecording = true;
      await Future.delayed(_chunkDuration);
      if (!_alwaysOnActive) {
        try { await _recorder.cancel(); } catch (_) {}
        _isRecording = false;
        return null;
      }
      final stopped = await _recorder.stop();
      _isRecording  = false;
      return stopped;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<void> _transcribeAndFire(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      if (await file.length() < _minChunkBytes) { await file.delete(); return; }

      final text = await _transcribe(path);
      if (text == null || text.trim().isEmpty) return;
      if (_isNoise(text.trim().toLowerCase())) return;

      if (kDebugMode) debugPrint('🎙️ AlwaysOn: "$text"');
      onTranscription?.call(text.trim());
    } catch (e) {
      if (kDebugMode) debugPrint('_transcribeAndFire: $e');
    }
  }

  // Whisper hallucinates these patterns on silence — filter them
  bool _isNoise(String t) {
    if (t.length < 3) return true;
    const noise = ['thank you','thanks','bye','you','the','.','music',
      'applause','silence','hmm','uh','um','uhh','oh','ah','okay okay',
      'dhanyavaad','shukriya','ahem'];
    return noise.any((n) => t == n || t == '$n.');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WHISPER API
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> _transcribe(String filePath) async {
    final key = ApiKeys.openaiKey;
    if (key.isEmpty) {
      if (kDebugMode) debugPrint('Whisper: OpenAI key missing');
      return null;
    }
    final file = File(filePath);
    if (!await file.exists()) return null;
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('https://api.openai.com/v1/audio/transcriptions'));
      req.headers['Authorization'] = 'Bearer $key';
      req.files.add(await http.MultipartFile.fromPath(
          'file', filePath, filename: 'audio.m4a'));
      req.fields['model']           = 'whisper-1';
      req.fields['language']        = _lang();
      req.fields['response_format'] = 'json';

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final body     = await streamed.stream.bytesToString();
      try { await file.delete(); } catch (_) {}

      if (streamed.statusCode == 200) {
        final text = (jsonDecode(body) as Map)['text'] as String? ?? '';
        return text.trim().isEmpty ? null : text.trim();
      }
      if (kDebugMode) debugPrint('Whisper ❌ ${streamed.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Whisper _transcribe: $e');
      return null;
    }
  }

  String _lang() {
    final l = ApiKeys.lang;
    if (l.startsWith('hi')) return 'hi';
    if (l.startsWith('en')) return 'en';
    if (l.startsWith('mr')) return 'mr';
    if (l.startsWith('gu')) return 'gu';
    if (l.startsWith('ta')) return 'ta';
    return 'hi';
  }

  Future<String> _tmpPath(String tag) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/zara_${tag}_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  // ── Transcribe raw PCM from native wake word engine ──────────────────────
  // Native sends 16-bit PCM as base64, we convert to WAV and send to Whisper
  Future<String?> transcribePcmBase64(String pcmBase64, int sampleRate) async {
    final key = ApiKeys.openaiKey;
    if (key.isEmpty) return null;
    try {
      final pcmBytes = base64Decode(pcmBase64);
      // Build WAV header
      final wavBytes = _pcmToWav(pcmBytes, sampleRate);
      final dir      = await getTemporaryDirectory();
      final path     = '${dir.path}/zara_ww_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(path).writeAsBytes(wavBytes);
      return await _transcribe(path);
    } catch (e) {
      if (kDebugMode) debugPrint('transcribePcmBase64: $e');
      return null;
    }
  }

  Uint8List _pcmToWav(Uint8List pcm, int sampleRate) {
    final dataSize   = pcm.length;
    final totalSize  = 44 + dataSize;
    final buffer     = Uint8List(totalSize);
    final data       = ByteData.view(buffer.buffer);
    // RIFF header
    buffer.setRange(0, 4, [82,73,70,70]); // 'RIFF'
    data.setUint32(4, totalSize - 8, Endian.little);
    buffer.setRange(8, 12, [87,65,86,69]); // 'WAVE'
    buffer.setRange(12, 16, [102,109,116,32]); // 'fmt '
    data.setUint32(16, 16, Endian.little); // chunk size
    data.setUint16(20, 1, Endian.little);  // PCM format
    data.setUint16(22, 1, Endian.little);  // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little);  // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    buffer.setRange(36, 40, [100,97,116,97]); // 'data'
    data.setUint32(40, dataSize, Endian.little);
    buffer.setRange(44, 44 + dataSize, pcm);
    return buffer;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopAlwaysOn();
    try { await _recorder.dispose(); } catch (_) {}
  }
}
