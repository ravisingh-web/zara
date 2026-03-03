// lib/services/livekit_service.dart
// Z.A.R.A. v7.0 — LiveKit Real-Time Voice Room
// Real-time low-latency voice: mic → LiveKit room → Zara listens
// LiveKit SDK: livekit_client

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:zara/core/constants/api_keys.dart';

class LiveKitService {
  static final LiveKitService _i = LiveKitService._();
  factory LiveKitService() => _i;
  LiveKitService._();

  Room? _room;
  LocalAudioTrack? _micTrack;

  bool _connected  = false;
  bool _micActive  = false;
  bool get isConnected => _connected;
  bool get isMicActive => _micActive;

  // Callbacks
  void Function(String participantId, String text)? onTranscription;
  void Function(bool connected)? onConnectionChange;
  void Function(String error)? onError;

  // ── Connect to LiveKit Room ────────────────────────────────────────────────
  Future<bool> connect() async {
    final url   = ApiKeys.livekitUrl;
    final token = ApiKeys.livekitToken;

    if (url.isEmpty || token.isEmpty) {
      if (kDebugMode) debugPrint('LiveKit: URL or Token empty — Settings mein dalo');
      onError?.call('LiveKit URL/Token missing');
      return false;
    }

    try {
      if (kDebugMode) debugPrint('LiveKit: connecting to $url...');

      _room = Room();

      await _room!.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'zara_mic',
            audioBitrate: 32000,
          ),
        ),
      );

      _room!.addListener(_onRoomEvent);
      _connected = true;
      onConnectionChange?.call(true);
      if (kDebugMode) debugPrint('LiveKit ✅ connected');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('LiveKit connect error: $e');
      onError?.call('LiveKit connect failed: $e');
      _connected = false;
      return false;
    }
  }

  // ── Start Mic Publishing ───────────────────────────────────────────────────
  Future<bool> startMic() async {
    if (!_connected || _room == null) return false;
    if (_micActive) return true;

    try {
      _micTrack = await LocalAudioTrack.create(
        AudioCaptureOptions(
          noiseSuppression: true,
          echoCancellation: true,
          autoGainControl: true,
        ),
      );

      await _room!.localParticipant?.publishAudioTrack(_micTrack!);
      _micActive = true;
      if (kDebugMode) debugPrint('LiveKit ✅ mic started');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('LiveKit startMic error: $e');
      return false;
    }
  }

  // ── Stop Mic ───────────────────────────────────────────────────────────────
  Future<void> stopMic() async {
    if (!_micActive) return;
    try {
      await _micTrack?.stop();
      _micTrack = null;
      _micActive = false;
      if (kDebugMode) debugPrint('LiveKit mic stopped');
    } catch (e) {
      if (kDebugMode) debugPrint('LiveKit stopMic error: $e');
    }
  }

  // ── Toggle Mic ─────────────────────────────────────────────────────────────
  Future<bool> toggleMic() async {
    if (_micActive) { await stopMic(); return false; }
    else { return await startMic(); }
  }

  // ── Room Events ────────────────────────────────────────────────────────────
  void _onRoomEvent() {
    final room = _room;
    if (room == null) return;

    switch (room.connectionState) {
      case ConnectionState.disconnected:
        _connected  = false;
        _micActive  = false;
        onConnectionChange?.call(false);
        if (kDebugMode) debugPrint('LiveKit disconnected');
        break;
      case ConnectionState.reconnecting:
        if (kDebugMode) debugPrint('LiveKit reconnecting...');
        break;
      case ConnectionState.connected:
        _connected = true;
        onConnectionChange?.call(true);
        if (kDebugMode) debugPrint('LiveKit reconnected');
        break;
      default:
        break;
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    try {
      await stopMic();
      _room?.removeListener(_onRoomEvent);
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
      _connected = false;
      onConnectionChange?.call(false);
      if (kDebugMode) debugPrint('LiveKit disconnected');
    } catch (e) {
      if (kDebugMode) debugPrint('LiveKit disconnect error: $e');
    }
  }

  // ── Room Info ──────────────────────────────────────────────────────────────
  String? get roomName => _room?.name;
  int get participantCount => _room?.remoteParticipants.length ?? 0;

  Future<void> dispose() async => await disconnect();
}
	

