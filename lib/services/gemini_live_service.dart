// lib/services/gemini_live_service.dart
// Z.A.R.A. v19.0 — Gemini Live API (Audio-to-Audio)
//
// Architecture:
//   WebSocket → wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent
//
// Flow:
//   1. connect()    → WebSocket open + setup message
//   2. startAudio() → record PCM 16bit 16kHz mono → send chunks every 100ms
//   3. onAudio()    → receive PCM 24kHz from Gemini → play immediately
//   4. disconnect() → clean up
//
// States: disconnected → connecting → listening → speaking → listening...

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:zara/core/constants/api_keys.dart';

// ── Session States ─────────────────────────────────────────────────────────────
enum ZaraLiveState {
  disconnected,
  connecting,
  listening,   // mic open, sending audio to Gemini
  speaking,    // receiving audio from Gemini, playing
  error,
}

// ── In-memory audio source ─────────────────────────────────────────────────────
class _PcmAudioSource extends StreamAudioSource {
  final Uint8List _wav;
  _PcmAudioSource(this._wav);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end   ??= _wav.length;
    return StreamAudioResponse(
      sourceLength:  _wav.length,
      contentLength: end - start,
      offset:        start,
      stream:        Stream.value(_wav.sublist(start, end)),
      contentType:   'audio/wav',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
class GeminiLiveService {
  static final GeminiLiveService _i = GeminiLiveService._();
  factory GeminiLiveService() => _i;
  GeminiLiveService._();

  // ── State ──────────────────────────────────────────────────────────────────
  ZaraLiveState _state   = ZaraLiveState.disconnected;
  bool          _disposed = false;
  String        _lastError = '';

  ZaraLiveState get state     => _state;
  String        get lastError => _lastError;
  bool get isConnected => _state != ZaraLiveState.disconnected &&
                          _state != ZaraLiveState.error;

  // ── WebSocket ──────────────────────────────────────────────────────────────
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();
  Timer? _sendTimer;

  // Buffer incoming PCM chunks from Gemini
  final List<int> _rxBuffer = [];
  bool _isPlaying = false;

  // ── System prompt ──────────────────────────────────────────────────────────
  static String _buildSystemPrompt() {
    final owner = ApiKeys.ownerName;
    return '''Tu Z.A.R.A. hai — Zenith Autonomous Reasoning Array.
Tu ${owner} ki personal AI companion aur assistant hai.
Hindi aur Hinglish mein baat kar — natural aur warm tone.
Commands ko execute karne ka pura access hai.
Short, direct replies do. Zyada formal mat bano.
Jab koi app open karna ho ya koi kaam karna ho, seedha karo.''';
  }

  // ── Callbacks ──────────────────────────────────────────────────────────────
  void Function(ZaraLiveState state)? onStateChanged;
  void Function(String text)? onTranscript;      // user speech text
  void Function(String text)? onResponse;         // ZARA response text
  void Function(String error)? onError;
  void Function(double level)? onVolumeLevel;

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECT
  // ══════════════════════════════════════════════════════════════════════════
  Future<bool> connect() async {
    if (_disposed) return false;
    if (isConnected) await disconnect();

    final apiKey = ApiKeys.geminiKey;
    if (apiKey.isEmpty) {
      _setError('Gemini API key missing. Settings mein dalo Sir.');
      return false;
    }

    _setState(ZaraLiveState.connecting);

    try {
      final model = ApiKeys.liveModel;
      final wsUrl = 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey';

      if (kDebugMode) debugPrint('🔗 Gemini Live connecting → $model');

      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));

      // ── Setup message — first thing to send ──────────────────────────────
      final setupMsg = jsonEncode({
        'setup': {
          'model': 'models/$model',
          'generation_config': {
            'response_modalities': ['AUDIO'],
            'speech_config': {
              'voice_config': {
                'prebuilt_voice_config': {
                  'voice_name': 'Aoede', // warm female Hindi voice
                }
              }
            }
          },
          'system_instruction': {
            'parts': [{'text': _buildSystemPrompt()}]
          },
          'realtime_input_config': {
            'automatic_activity_detection': {
              'disabled': false,
              'start_of_speech_sensitivity': 'START_SENSITIVITY_HIGH',
              'end_of_speech_sensitivity':   'END_SENSITIVITY_LOW',
              'prefix_padding_ms':    200,
              'silence_duration_ms':  800,
            },
            'activity_handling': 'START_OF_ACTIVITY_INTERRUPTS',
          },
          'input_audio_transcription':  {},
          'output_audio_transcription': {},
        }
      });

      _ws!.sink.add(setupMsg);

      // ── Listen for messages ───────────────────────────────────────────────
      _wsSub = _ws!.stream.listen(
        _onMessage,
        onError: (e) {
          if (kDebugMode) debugPrint('WS error: $e');
          _setError('Connection error: $e');
        },
        onDone: () {
          if (kDebugMode) debugPrint('WS closed');
          if (_state != ZaraLiveState.disconnected) {
            _setState(ZaraLiveState.disconnected);
          }
        },
      );

      // Wait for setup_complete
      final completer = Completer<bool>();
      late StreamSubscription sub;
      sub = _ws!.stream.listen(null);
      // Actually handled in _onMessage — we set state there

      // Start recording after short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_disposed && isConnected) {
        await _startMic();
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('connect: $e');
      _setError('Connection failed: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGE HANDLER
  // ══════════════════════════════════════════════════════════════════════════
  void _onMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = raw is String
          ? jsonDecode(raw)
          : jsonDecode(utf8.decode(raw as List<int>));

      // ── Setup complete ─────────────────────────────────────────────────
      if (msg.containsKey('setupComplete')) {
        if (kDebugMode) debugPrint('✅ Gemini Live setup complete');
        _setState(ZaraLiveState.listening);
        return;
      }

      // ── Server content (audio response) ──────────────────────────────
      final serverContent = msg['serverContent'];
      if (serverContent != null) {
        final modelTurn = serverContent['modelTurn'];

        if (modelTurn != null) {
          final parts = modelTurn['parts'] as List? ?? [];
          for (final part in parts) {
            // Audio data
            final inlineData = part['inlineData'];
            if (inlineData != null) {
              final mimeType = inlineData['mimeType'] as String? ?? '';
              final data     = inlineData['data']     as String? ?? '';
              if (mimeType.contains('audio') && data.isNotEmpty) {
                _setState(ZaraLiveState.speaking);
                final pcmBytes = base64Decode(data);
                _rxBuffer.addAll(pcmBytes);
                _schedulePlay();
              }
            }
            // Text transcript
            final text = part['text'] as String?;
            if (text != null && text.isNotEmpty) {
              onResponse?.call(text);
            }
          }
        }

        // Turn complete
        final turnComplete = serverContent['turnComplete'] as bool? ?? false;
        if (turnComplete) {
          if (kDebugMode) debugPrint('Turn complete');
          _flushAndPlay();
        }

        // Input transcription
        final inputTranscription = serverContent['inputTranscription'];
        if (inputTranscription != null) {
          final text = inputTranscription['text'] as String? ?? '';
          if (text.isNotEmpty) {
            if (kDebugMode) debugPrint('User said: $text');
            onTranscript?.call(text);
          }
        }
      }

      // ── Go away (server wants to close) ───────────────────────────────
      if (msg.containsKey('goAway')) {
        if (kDebugMode) debugPrint('GoAway received — reconnecting');
        Future.delayed(const Duration(seconds: 1), () => connect());
      }

    } catch (e) {
      if (kDebugMode) debugPrint('_onMessage parse error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MIC — record PCM and send to Gemini
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _startMic() async {
    try {
      if (!await _recorder.hasPermission()) {
        _setError('Mic permission nahi hai Sir.');
        return;
      }

      final tmpDir = await _tmpDir();
      final path   = '$tmpDir/live_chunk_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder:     AudioEncoder.pcm16bits,
          sampleRate:  16000,
          numChannels: 1,
        ),
        path: path,
      );

      if (kDebugMode) debugPrint('🎙️ Mic started — streaming to Gemini Live');

      // Send audio chunks every 100ms
      _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        if (!isConnected || _disposed) return;
        try {
          final stream = await _recorder.getStream();
          // We use stream listener — handled in _onRecorderStream
        } catch (_) {}
      });

      // Use stream approach for real-time audio
      await _startStreamRecording();

    } catch (e) {
      if (kDebugMode) debugPrint('_startMic: $e');
      _setError('Mic error: $e');
    }
  }

  Future<void> _startStreamRecording() async {
    try {
      // Record continuously and send PCM chunks
      final stream = await _recorder.getStream();
      stream?.listen((data) {
        if (!isConnected || _disposed) return;
        _sendAudioChunk(data);
        // Volume level for UI
        if (data.isNotEmpty) {
          double sum = 0;
          for (int i = 0; i < data.length - 1; i += 2) {
            final sample = data[i] | (data[i + 1] << 8);
            final signed = sample > 32767 ? sample - 65536 : sample;
            sum += signed * signed;
          }
          final rms = (sum / (data.length / 2));
          final level = (rms / (32768 * 32768)).clamp(0.0, 1.0);
          onVolumeLevel?.call(level);
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('_startStreamRecording: $e');
    }
  }

  void _sendAudioChunk(List<int> pcmBytes) {
    if (_ws == null || pcmBytes.isEmpty) return;
    try {
      final b64 = base64Encode(pcmBytes);
      final msg = jsonEncode({
        'realtimeInput': {
          'mediaChunks': [{
            'mimeType': 'audio/pcm;rate=16000',
            'data': b64,
          }]
        }
      });
      _ws!.sink.add(msg);
    } catch (e) {
      if (kDebugMode) debugPrint('_sendAudioChunk: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUDIO PLAYBACK — PCM 24kHz from Gemini
  // ══════════════════════════════════════════════════════════════════════════
  Timer? _playTimer;

  void _schedulePlay() {
    _playTimer?.cancel();
    _playTimer = Timer(const Duration(milliseconds: 200), _flushAndPlay);
  }

  void _flushAndPlay() {
    if (_rxBuffer.isEmpty || _isPlaying) return;
    _isPlaying = true;
    final pcm = Uint8List.fromList(List.from(_rxBuffer));
    _rxBuffer.clear();
    _playPcm(pcm);
  }

  Future<void> _playPcm(Uint8List pcm) async {
    try {
      final wav = _pcmToWav(pcm, sampleRate: 24000);
      final src = _PcmAudioSource(wav);
      await _player.setAudioSource(src);
      await _player.seek(Duration.zero);
      await _player.play();

      // Volume animation
      _player.positionStream.listen((pos) {
        final dur = _player.duration?.inMilliseconds ?? 0;
        if (dur > 0) {
          final p = pos.inMilliseconds / dur;
          onVolumeLevel?.call((0.3 + 0.7 * (p * (1 - p) * 4)).clamp(0, 1));
        }
      });

      await _player.playerStateStream
          .where((s) => s.processingState == ProcessingState.completed || _disposed)
          .first
          .timeout(const Duration(seconds: 60), onTimeout: () => PlayerState(false, ProcessingState.completed));

      _isPlaying = false;
      onVolumeLevel?.call(0.0);

      // If more data arrived while playing
      if (_rxBuffer.isNotEmpty) _flushAndPlay();
      else if (isConnected) _setState(ZaraLiveState.listening);

    } catch (e) {
      _isPlaying = false;
      if (kDebugMode) debugPrint('_playPcm: $e');
      if (isConnected) _setState(ZaraLiveState.listening);
    }
  }

  // ── PCM → WAV ──────────────────────────────────────────────────────────────
  Uint8List _pcmToWav(Uint8List pcm, {int sampleRate = 24000}) {
    const ch = 1, bits = 16;
    final dataLen    = pcm.length;
    final byteRate   = sampleRate * ch * bits ~/ 8;
    final blockAlign = ch * bits ~/ 8;
    final buf        = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (int i = 0; i < s.length; i++) buf.setUint8(o + i, s.codeUnitAt(i));
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

  // ══════════════════════════════════════════════════════════════════════════
  // DISCONNECT
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> disconnect() async {
    _sendTimer?.cancel();
    _playTimer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    try { await _player.stop();   } catch (_) {}
    try { await _wsSub?.cancel(); } catch (_) {}
    try { await _ws?.sink.close(); } catch (_) {}
    _ws        = null;
    _rxBuffer.clear();
    _isPlaying = false;
    _setState(ZaraLiveState.disconnected);
    if (kDebugMode) debugPrint('🔌 Gemini Live disconnected');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEND TEXT (for God Mode commands result etc.)
  // ══════════════════════════════════════════════════════════════════════════
  void sendText(String text) {
    if (!isConnected || text.trim().isEmpty) return;
    try {
      final msg = jsonEncode({
        'clientContent': {
          'turns': [{'role': 'user', 'parts': [{'text': text}]}],
          'turnComplete': true,
        }
      });
      _ws?.sink.add(msg);
    } catch (e) {
      if (kDebugMode) debugPrint('sendText: $e');
    }
  }

  // ── State helper ───────────────────────────────────────────────────────────
  void _setState(ZaraLiveState s) {
    if (_state == s) return;
    _state = s;
    onStateChanged?.call(s);
    if (kDebugMode) debugPrint('ZaraLive → ${s.name}');
  }

  void _setError(String msg) {
    _lastError = msg;
    _setState(ZaraLiveState.error);
    onError?.call(msg);
    if (kDebugMode) debugPrint('ZaraLive ERROR: $msg');
  }

  Future<String> _tmpDir() async {
    final dir = await pathProvider();
    return dir;
  }

  Future<String> pathProvider() async {
    try {
      final d = await import_path_provider();
      return d;
    } catch (_) { return '/data/user/0/com.mahakal.zara/cache'; }
  }

  Future<String> import_path_provider() async {
    // Use path_provider
    try {
      final tmp = await _getTmpPath();
      return tmp;
    } catch (_) { return '/tmp'; }
  }

  Future<String> _getTmpPath() async {
    // Will be injected via path_provider in actual build
    return '/data/user/0/com.mahakal.zara/cache';
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    try { await _recorder.dispose(); } catch (_) {}
    try { await _player.dispose();   } catch (_) {}
  }
}
