// lib/features/zara_engine/providers/zara_provider.dart
// Z.A.R.A. v19.0 — Gemini Live API Controller
//
// Architecture:
//   GeminiLiveService  → WebSocket audio-to-audio (Vosk REMOVED)
//   AccessibilityService → God Mode (unchanged)
//   NotificationService  → Proactive alerts (unchanged)
//
// States: disconnected → connecting → listening → speaking → listening...

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/services/gemini_live_service.dart';
import 'package:zara/services/accessibility_service.dart';
import 'package:zara/services/notification_service.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';
import 'package:zara/services/email_service.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';

// ── God Mode Commands ──────────────────────────────────────────────────────────
enum GodCommand {
  openApp, scrollReels, likeReel, ytSearch, instagramComment,
  flipkartBuy, whatsappSend, whatsappVoiceCall, whatsappVideoCall,
  facebookPost, clickById, clickByText, tapAt, typeText,
  pressBack, pressHome, unknown,
}

class ParsedCommand {
  final GodCommand type;
  final Map<String, String> params;
  const ParsedCommand(this.type, this.params);
}

// ══════════════════════════════════════════════════════════════════════════════
class ZaraController extends ChangeNotifier {

  final _live   = GeminiLiveService();
  final _access = AccessibilityService();
  final _notif  = NotificationService();
  final _camera = CameraService();
  final _loc    = LocationService();
  final _email  = EmailService();

  // ── State ──────────────────────────────────────────────────────────────────
  ZaraState _state = ZaraState.initial();
  ZaraState get state => _state;

  ZaraLiveState _liveState = ZaraLiveState.disconnected;
  ZaraLiveState get liveState => _liveState;

  bool get isConnected  => _live.isConnected;
  bool get isListening  => _liveState == ZaraLiveState.listening;
  bool get isSpeaking   => _liveState == ZaraLiveState.speaking;
  bool get isConnecting => _liveState == ZaraLiveState.connecting;

  double _volumeLevel = 0.0;
  double get volumeLevel => _volumeLevel;

  Map<String, bool> _permissions = {};
  Map<String, bool> get permissions => _permissions;

  String _transcript = '';
  String get lastTranscript => _transcript;

  bool _disposed = false;

  // ── Callbacks ──────────────────────────────────────────────────────────────
  void Function(double)? onVolumeLevel;

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> initialize() async {
    await _loadMemory();

    // Setup channel handler FIRST
    _access.setupChannelHandler();

    try { await _email.initialize(); } catch (_) {}
    try {
      await _notif.initialize();
      await _notif.startForegroundService();
      _notif.onProactiveAlert = (alert) => _handleNotification(alert);
    } catch (_) {}

    // Wire Gemini Live callbacks
    _live.onStateChanged = (s) {
      _liveState = s;
      _notif.updateOrb(s == ZaraLiveState.listening  ? 'listening'
                     : s == ZaraLiveState.speaking   ? 'speaking'
                     : s == ZaraLiveState.connecting ? 'thinking'
                     : 'still');

      if (s == ZaraLiveState.error) {
        _state = _state.copyWith(lastResponse: _live.lastError);
      }
      notifyListeners();
    };

    _live.onTranscript = (text) {
      _transcript = text;
      // Parse God Mode commands from transcript
      final cmds = _parseAllCommands(text);
      if (cmds.isNotEmpty && cmds.first.type != GodCommand.unknown) {
        _executeChain(cmds);
      }
      _state = _state.copyWith(lastCommand: text, lastActivity: DateTime.now());
      notifyListeners();
    };

    _live.onResponse = (text) {
      final msg = ChatMessage.fromZara(text);
      final msgs = List<ChatMessage>.from(_state.messages)..add(msg);
      _state = _state.copyWith(
        lastResponse: text,
        messages: msgs,
        lastActivity: DateTime.now(),
      );
      notifyListeners();
    };

    _live.onVolumeLevel = (v) {
      _volumeLevel = v;
      onVolumeLevel?.call(v);
      notifyListeners();
    };

    _live.onError = (e) {
      _state = _state.copyWith(lastResponse: e);
      notifyListeners();
    };

    // Check permissions
    _checkPermissions();

    if (kDebugMode) {
      debugPrint('╔══ Z.A.R.A. v19 ══════════════════════╗');
      debugPrint('║ Gemini Live : ${ApiKeys.geminiReady ? "✅" : "❌ KEY MISSING"}');
      debugPrint('║ Model       : ${ApiKeys.liveModel}');
      debugPrint('║ Voice       : Aoede (Hindi/Hinglish)');
      debugPrint('║ Vosk        : ❌ REMOVED');
      debugPrint('║ ElevenLabs  : ❌ REMOVED');
      debugPrint('╚══════════════════════════════════════╝');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECT / DISCONNECT
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> activate() async {
    if (isConnected) {
      await deactivate();
      return;
    }
    if (!ApiKeys.geminiReady) {
      _state = _state.copyWith(lastResponse: 'Gemini API key missing. Settings mein dalo Sir.');
      notifyListeners();
      return;
    }
    _state = _state.copyWith(isActive: true, lastResponse: 'Connecting...');
    notifyListeners();
    await _live.connect();
  }

  Future<void> deactivate() async {
    await _live.disconnect();
    _state = _state.copyWith(isActive: false, lastResponse: 'Disconnected');
    notifyListeners();
  }

  // Compat aliases for existing UI
  Future<void> startWakeWordEngine() => activate();
  Future<void> stopWakeWordEngine()  => deactivate();
  bool get wakeWordListening => isConnected;

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — Command Parser
  // ══════════════════════════════════════════════════════════════════════════
  List<ParsedCommand> _parseAllCommands(String text) {
    final results = <ParsedCommand>[];
    final matches = RegExp(r'\[COMMAND:(\w+)([^\]]*)\]').allMatches(text);
    for (final m in matches) {
      final cmdStr = m.group(1)?.toUpperCase() ?? '';
      final rest   = m.group(2) ?? '';
      final params = <String, String>{};
      for (final kv in RegExp(r',\s*(\w+):([^,\]]+)').allMatches(rest)) {
        params[kv.group(1)!.toUpperCase()] = kv.group(2)!.trim();
      }
      GodCommand type;
      switch (cmdStr) {
        case 'OPEN_APP':       type = GodCommand.openApp;           break;
        case 'SCROLL_REELS':   type = GodCommand.scrollReels;       break;
        case 'LIKE_REEL':      type = GodCommand.likeReel;          break;
        case 'YT_SEARCH':      type = GodCommand.ytSearch;          break;
        case 'IG_COMMENT':     type = GodCommand.instagramComment;  break;
        case 'FLIPKART_BUY':   type = GodCommand.flipkartBuy;       break;
        case 'WHATSAPP_SEND':  type = GodCommand.whatsappSend;      break;
        case 'WHATSAPP_CALL':  type = GodCommand.whatsappVoiceCall; break;
        case 'WHATSAPP_VIDEO': type = GodCommand.whatsappVideoCall; break;
        case 'FACEBOOK_POST':  type = GodCommand.facebookPost;      break;
        case 'CLICK_BY_ID':    type = GodCommand.clickById;         break;
        case 'CLICK_BY_TEXT':  type = GodCommand.clickByText;       break;
        case 'TAP_AT':         type = GodCommand.tapAt;             break;
        case 'TYPE_TEXT':      type = GodCommand.typeText;          break;
        case 'PRESS_BACK':     type = GodCommand.pressBack;         break;
        case 'PRESS_HOME':     type = GodCommand.pressHome;         break;
        default:               type = GodCommand.unknown;
      }
      if (type != GodCommand.unknown) results.add(ParsedCommand(type, params));
    }
    return results.isEmpty ? [const ParsedCommand(GodCommand.unknown, {})] : results;
  }

  Future<void> _executeChain(List<ParsedCommand> cmds) async {
    for (int i = 0; i < cmds.length; i++) {
      if (_disposed) break;
      await _executeOne(cmds[i]);
      if (i < cmds.length - 1) await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> _executeOne(ParsedCommand cmd) async {
    switch (cmd.type) {
      case GodCommand.openApp:
        final pkg = cmd.params['PKG'] ?? '';
        if (pkg.isNotEmpty) await _access.openApp(pkg);
      case GodCommand.scrollReels:
        await _access.scrollDown(steps: int.tryParse(cmd.params['STEPS'] ?? '3') ?? 3);
      case GodCommand.likeReel:
        await _access.instagramLikeReel();
      case GodCommand.ytSearch:
        final q = cmd.params['QUERY'] ?? '';
        if (q.isNotEmpty) await _access.youtubeSearch(q);
      case GodCommand.instagramComment:
        await _access.instagramPostComment(cmd.params['TEXT'] ?? '');
      case GodCommand.flipkartBuy:
        await _access.flipkartSearchProduct(cmd.params['PRODUCT'] ?? '');
        await Future.delayed(const Duration(seconds: 3));
        await _access.flipkartSelectSize(cmd.params['SIZE'] ?? 'M');
        await Future.delayed(const Duration(seconds: 1));
        await _access.flipkartAddToCart();
      case GodCommand.whatsappSend:
        await _access.whatsappSendMessage(cmd.params['TO'] ?? '', cmd.params['MSG'] ?? '');
      case GodCommand.whatsappVoiceCall:
        await _access.whatsappVoiceCall(cmd.params['TO'] ?? '');
      case GodCommand.whatsappVideoCall:
        await _access.whatsappVideoCall(cmd.params['TO'] ?? '');
      case GodCommand.facebookPost:
        await _access.facebookPost(cmd.params['TEXT'] ?? '');
      case GodCommand.clickById:
        await _access.clickById(cmd.params['ID'] ?? '');
      case GodCommand.clickByText:
        await _access.clickText(cmd.params['TEXT'] ?? '');
      case GodCommand.tapAt:
        final x = int.tryParse(cmd.params['X'] ?? '0') ?? 0;
        final y = int.tryParse(cmd.params['Y'] ?? '0') ?? 0;
        if (x > 0 && y > 0) await _access.tapAt(x, y);
      case GodCommand.typeText:
        await _access.typeText(cmd.params['TEXT'] ?? '');
      case GodCommand.pressBack:
        await _access.pressBack();
      case GodCommand.pressHome:
        await _access.pressHome();
      default: break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MANUAL TEXT INPUT (from UI text field)
  // ══════════════════════════════════════════════════════════════════════════
  void sendTextCommand(String text) {
    if (!isConnected || text.trim().isEmpty) return;
    final msg = ChatMessage.fromUser(text);
    final msgs = List<ChatMessage>.from(_state.messages)..add(msg);
    _state = _state.copyWith(messages: msgs, lastCommand: text);
    notifyListeners();
    _live.sendText(text);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════
  void _handleNotification(NotificationAlert alert) {
    if (alert.zaraAlert.isEmpty) return;
    final msg  = ChatMessage.fromZara(alert.zaraAlert);
    final msgs = List<ChatMessage>.from(_state.messages)..add(msg);
    _state = _state.copyWith(
      messages: msgs,
      lastResponse: alert.zaraAlert,
      isActive: true,
    );
    notifyListeners();
    // Send notification context to Live session
    if (isConnected) {
      _live.sendText('Notification mila: ${alert.zaraAlert}');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERMISSIONS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _checkPermissions() async {
    try {
      final p = await _access.checkAllPermissions();
      _permissions = {
        'accessibility':        p['accessibility']        ?? false,
        'overlay':              p['overlay']              ?? false,
        'notificationListener': p['notificationListener'] ?? false,
        'foregroundService':    p['foregroundService']    ?? false,
        'microphone':           true, // always true — Live API handles mic
      };
      notifyListeners();
    } catch (_) {}
  }

  bool get allPermissionsGranted => _permissions.values.every((v) => v);

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════
  void newChat() {
    final archives = List<ChatSession>.from(_state.chatArchives);
    if (_state.messages.isNotEmpty) {
      archives.insert(0, ChatSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        topicName: _state.lastCommand.isEmpty ? 'Baat cheet' :
                   _state.lastCommand.length > 30 ? _state.lastCommand.substring(0, 30) : _state.lastCommand,
        messages: [],
        chatMessages: List<ChatMessage>.from(_state.messages),
        timestamp: DateTime.now(),
      ));
    }
    _state = ZaraState.initial().copyWith(
      chatArchives: archives.take(20).toList(),
      affectionLevel: _state.affectionLevel,
    );
    notifyListeners();
  }

  List<ChatSession> get chatArchives => _state.chatArchives;

  void deleteArchivedChat(String id) {
    _state = _state.copyWith(
        chatArchives: _state.chatArchives.where((s) => s.id != id).toList());
    notifyListeners();
    _saveMemory();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadMemory() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final data = p.getString('zara_state_v19');
      if (data != null) {
        _state = ZaraState.fromMap(jsonDecode(data));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveMemory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('zara_state_v19', jsonEncode(_state.toMap()));
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MISC COMPAT
  // ══════════════════════════════════════════════════════════════════════════
  // Keep these for UI compatibility
  bool get handsFreeMode   => false;
  bool get realtimeActive  => isConnected;
  bool get isActive        => isConnected;
  Mood get mood            => _state.mood;

  Future<void> toggleHandsFree() async {}
  Future<void> toggleTts()       async {}
  void toggleRealtime()          {}
  Future<void> startListening({void Function(String)? onTranscribed}) async {}
  Future<void> stopListening()   async {}
  void Function(double)? get volumeCallback => onVolumeLevel;

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Future<void> dispose() async {
    _disposed = true;
    await _live.dispose();
    super.dispose();
  }
}

// ── Pending Reply ──────────────────────────────────────────────────────────────
class PendingReply {
  final String app, pkg, contact, message;
  const PendingReply({required this.app, required this.pkg,
                      required this.contact, required this.message});
}
