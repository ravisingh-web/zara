// lib/services/whisper_stt_service.dart
// Z.A.R.A. v7.0 — OpenAI Whisper STT
// Real mic recording + Whisper API transcription

import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
  bool  _isRecording = false;
  bool  get isRecording => _isRecording;

  // ── Start Recording ────────────────────────────────────────────────────────
  Future<bool> startRecording() async {
    if (_isRecording) return false;
    try {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) { if (kDebugMode) debugPrint('Whisper: no mic permission'); return false; }

      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/zara_stt_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, bitRate: 128000, numChannels: 1),
        path: path,
      );
      _isRecording = true;
      if (kDebugMode) debugPrint('Whisper ✅ recording started');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Whisper startRecording: $e');
      return false;
    }
  }

  // ── Stop & Transcribe ──────────────────────────────────────────────────────
  Future<String?> stopAndTranscribe() async {
    if (!_isRecording) return null;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path == null || path.isEmpty) return null;
      if (kDebugMode) debugPrint('Whisper: stopped, transcribing...');
      return await _transcribe(path);
    } catch (e) {
      _isRecording = false;
      if (kDebugMode) debugPrint('Whisper stopAndTranscribe: $e');
      return null;
    }
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try { await _recorder.cancel(); } catch (_) {}
    _isRecording = false;
  }

  // ── Whisper API Call ───────────────────────────────────────────────────────
  Future<String?> _transcribe(String filePath) async {
    final key = ApiKeys.openaiKey;
    if (key.isEmpty) {
      if (kDebugMode) debugPrint('Whisper: OpenAI key empty — Settings mein dalo');
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      req.headers['Authorization'] = 'Bearer $key';
      req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: 'audio.m4a'));
      req.fields['model']           = 'whisper-1';
      req.fields['language']        = _lang();
      req.fields['response_format'] = 'json';

      if (kDebugMode) debugPrint('Whisper → OpenAI API...');

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body     = await streamed.stream.bytesToString();

      // Clean temp file
      try { await file.delete(); } catch (_) {}

      if (streamed.statusCode == 200) {
        final j    = jsonDecode(body) as Map<String, dynamic>;
        final text = j['text'] as String? ?? '';
        if (kDebugMode) debugPrint('Whisper ✅ "$text"');
        return text.trim().isEmpty ? null : text.trim();
      }

      if (kDebugMode) debugPrint('Whisper ❌ ${streamed.statusCode}: $body');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Whisper _transcribe error: $e');
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
    if (l.startsWith('ur')) return 'ur';
    return 'hi';
  }

  Future<void> dispose() async {
    await cancelRecording();
    try { await _recorder.dispose(); } catch (_) {}
  }
}

