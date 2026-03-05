// lib/services/accessibility_service.dart
// Z.A.R.A. — God Mode Bridge v3.0
//
// ✅ All v2.0 methods preserved
// ✅ NEW: getScreenContext() — real-time screen text for Gemini
// ✅ NEW: checkAllPermissions() — unified startup permission check
// ✅ Consistent null-safe error handling throughout

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const _ch  = MethodChannel('com.mahakal.zara/accessibility');
  static const _main = MethodChannel('com.mahakal.zara/main');

  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> checkEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('isEnabled') ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc checkEnabled: $e');
      return false;
    }
  }

  Future<bool> openSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openSettings') ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc openSettings: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NEW: SCREEN CONTEXT — real-time screen perception
  //
  // Returns all visible text on the current screen as a single string.
  // ZaraProvider passes this to Gemini so Zara can answer contextually:
  //   "Sir, screen pe dikha raha hai: [product name] — 20% off..."
  //
  // Called via main channel so it works even without accessibility sub-channel
  // being fully set up (uses MainActivity's direct handler).
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> getScreenContext() async {
    try {
      final result = await _main.invokeMethod<String>('getScreenContext');
      final ctx    = result ?? '';
      if (kDebugMode && ctx.isNotEmpty) {
        debugPrint('ScreenCtx (${ctx.length} chars): ${ctx.substring(0, ctx.length.clamp(0, 80))}...');
      }
      return ctx;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc getScreenContext: $e');
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NEW: UNIFIED PERMISSION CHECK
  //
  // Returns all critical permission states in one native call.
  // PermissionGuard widget reads this on app startup.
  //
  // Returns map with keys:
  //   accessibility, overlay, notificationListener, foregroundService
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, bool>> checkAllPermissions() async {
    try {
      final raw = await _main.invokeMethod<Map>('checkAllPermissions');
      if (raw == null) return _defaultPerms();
      return {
        'accessibility':        raw['accessibility']        == true,
        'overlay':              raw['overlay']              == true,
        'notificationListener': raw['notificationListener'] == true,
        'foregroundService':    raw['foregroundService']    == true,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc checkAllPermissions: $e');
      return _defaultPerms();
    }
  }

  Map<String, bool> _defaultPerms() => {
    'accessibility':        false,
    'overlay':              false,
    'notificationListener': false,
    'foregroundService':    false,
  };

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — APP CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> openApp(String packageName) async {
    try {
      final result = await _ch.invokeMethod<bool>('openApp', {'package': packageName});
      if (kDebugMode) debugPrint('📱 openApp($packageName): $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc openApp: $e');
      return false;
    }
  }

  Future<bool> clickText(String text) async {
    try {
      final result = await _ch.invokeMethod<bool>('clickText', {'text': text});
      if (kDebugMode) debugPrint('👆 clickText($text): $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc clickText: $e');
      return false;
    }
  }

  Future<bool> clickById(String resourceId) async {
    try {
      return await _ch.invokeMethod<bool>('clickById', {'id': resourceId}) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc clickById: $e');
      return false;
    }
  }

  Future<bool> typeText(String text) async {
    try {
      final result = await _ch.invokeMethod<bool>('typeText', {'text': text});
      if (kDebugMode) debugPrint('⌨️ typeText: $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc typeText: $e');
      return false;
    }
  }

  // Legacy alias
  Future<bool> queueAutoType(String text) => typeText(text);

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — GESTURES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> scrollDown({int steps = 1}) async {
    try {
      return await _ch.invokeMethod<bool>('scrollDown', {'steps': steps}) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc scrollDown: $e');
      return false;
    }
  }

  Future<bool> scrollUp({int steps = 1}) async {
    try {
      return await _ch.invokeMethod<bool>('scrollUp', {'steps': steps}) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc scrollUp: $e');
      return false;
    }
  }

  Future<bool> swipe({
    required int x1, required int y1,
    required int x2, required int y2,
    int durationMs = 300,
  }) async {
    try {
      return await _ch.invokeMethod<bool>('swipe', {
        'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'durationMs': durationMs,
      }) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc swipe: $e');
      return false;
    }
  }

  Future<bool> tapAt(int x, int y) async {
    try {
      return await _ch.invokeMethod<bool>('tapAt', {'x': x, 'y': y}) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc tapAt: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — SYSTEM BUTTONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> pressBack()         => _invoke('pressBack');
  Future<bool> pressHome()         => _invoke('pressHome');
  Future<bool> pressRecents()      => _invoke('pressRecents');
  Future<bool> takeScreenshot()    => _invoke('takeScreenshot');
  Future<bool> openNotifications() => _invoke('openNotifications');
  Future<bool> openQuickSettings() => _invoke('openQuickSettings');

  // ══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> getForegroundApp() async {
    try {
      return await _ch.invokeMethod<String>('getForegroundApp') ?? '';
    } catch (e) {
      return '';
    }
  }

  Future<bool> findTextOnScreen(String text) async {
    try {
      return await _ch.invokeMethod<bool>('findTextOnScreen', {'text': text}) ?? false;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMON GOD MODE SHORTCUTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> openInstagram() => openApp('com.instagram.android');
  Future<bool> openWhatsApp()  => openApp('com.whatsapp');
  Future<bool> openYouTube()   => openApp('com.google.android.youtube');
  Future<bool> openFlipkart()  => openApp('com.flipkart.android');
  Future<bool> openSpotify()   => openApp('com.spotify.music');
  Future<bool> openGmail()     => openApp('com.google.android.gm');
  Future<bool> openMaps()      => openApp('com.google.android.apps.maps');
  Future<bool> openFacebook()  => openApp('com.facebook.katana');
  Future<bool> openSettings2() => openApp('com.android.settings');
  Future<bool> openCamera()    => openApp('com.android.camera2');

  // ── YouTube ────────────────────────────────────────────────────────────────
  Future<bool> youtubeSearch(String q)  => _callBool('youtubeSearch',  {'query': q});
  Future<bool> youtubePlayFirst()        => _callBool('youtubePlayFirst');

  // ── Instagram ──────────────────────────────────────────────────────────────
  Future<bool> instagramOpenReels()           => _callBool('instagramOpenReels');
  Future<bool> instagramScrollReels(int n)    => _callBool('instagramScrollReels', {'count': n});
  Future<bool> instagramLikeReel()            => _callBool('instagramLikeReel');
  Future<bool> instagramPostComment(String t) => _callBool('instagramPostComment', {'text': t});
  Future<bool> instagramSearchUser(String u)  => _callBool('instagramSearchUser',  {'username': u});

  // ── Flipkart ───────────────────────────────────────────────────────────────
  Future<bool> flipkartSearchProduct(String q) => _callBool('flipkartSearchProduct', {'query': q});
  Future<bool> flipkartSelectSize(String s)    => _callBool('flipkartSelectSize',    {'size': s});
  Future<bool> flipkartAddToCart()             => _callBool('flipkartAddToCart');
  Future<bool> flipkartGoToPayment()           => _callBool('flipkartGoToPayment');

  // ── WhatsApp ───────────────────────────────────────────────────────────────
  Future<bool> whatsappSendMessage(String contact, String message) =>
      _callBool('whatsappSendMessage', {'contact': contact, 'message': message});

  // ── YouTube ────────────────────────────────────────────────────────────────
  // ── WhatsApp Reader ────────────────────────────────────────────────────────
  Future<String> whatsappReadMessages(String contact) async {
    try {
      final r = await _ch.invokeMethod<String>('whatsappReadMessages', {'contact': contact});
      return r ?? 'Kuch nahi mila Sir';
    } catch (e) { return 'Error: $e'; }
  }

  // ── WhatsApp Agent Mode ────────────────────────────────────────────────────
  Future<bool> whatsappStartAgent(String contact, String persona) async {
    try {
      return await _ch.invokeMethod<bool>('whatsappStartAgent',
          {'contact': contact, 'persona': persona}) ?? false;
    } catch (_) { return false; }
  }

  Future<bool> whatsappStopAgent() async {
    try { return await _ch.invokeMethod<bool>('whatsappStopAgent') ?? false; }
    catch (_) { return false; }
  }

  // ── Command Chain ──────────────────────────────────────────────────────────
  // commands: [ {'method': 'youtubeSearch', 'args': {'query': 'arijit'}, 'required': true} ]
  Future<bool> executeChain(List<Map<String, dynamic>> commands) async {
    try {
      return await _ch.invokeMethod<bool>('executeChain', {'commands': commands}) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('executeChain: $e');
      return false;
    }
  }

  // ── Wake Word Engine ──────────────────────────────────────────────────────
  Future<bool> startWakeWord() async {
    try { return await _ch.invokeMethod<bool>('startWakeWord') ?? false; }
    catch (_) { return false; }
  }

  Future<bool> stopWakeWord() async {
    try { return await _ch.invokeMethod<bool>('stopWakeWord') ?? false; }
    catch (_) { return false; }
  }

  // Called from provider after Whisper transcribes wake PCM
  Future<void> notifyWakeWordTranscript(String transcript) async {
    try { await _ch.invokeMethod('onWakeWordTranscript', {'transcript': transcript}); }
    catch (_) {}
  }

  // ── Universal Generic Control — ANY app ───────────────────────────────────
  // action: CLICK_BY_TEXT | CLICK_BY_ID | CLICK_BY_DESC | TYPE_AND_SUBMIT
  //         SCROLL_DOWN | SCROLL_UP | LONG_CLICK | WAIT_FOR_TEXT | OPEN_APP
  //         TAP_AT | SWIPE_CUSTOM | PRESS_BACK | PRESS_HOME | SCREENSHOT
  Future<bool> performGenericAction(String action, String target, {
    String target2 = '',
    int    steps   = 3,
  }) async {
    try {
      return await _ch.invokeMethod<bool>('performGenericAction', {
        'action':  action,
        'target':  target,
        'target2': target2,
        'steps':   steps,
      }) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('performGenericAction $action: $e');
      return false;
    }
  }

  void Function(String transcript)? _wakeWordPcmHandler;
  void Function(String transcript)? _wakeWordDetectedHandler;

  void setWakeWordHandlers({
    required void Function(String pcmBase64, int sampleRate) onPcmReady,
    required void Function(String transcript) onDetected,
  }) {
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWakeWordPcmReady':
          final args       = Map<String, dynamic>.from(call.arguments as Map);
          final pcmBase64  = args['pcm_base64']?.toString() ?? '';
          final sampleRate = (args['sample_rate'] as int?) ?? 16000;
          onPcmReady(pcmBase64, sampleRate);
          break;
        case 'wake_word_detected':
          final args       = Map<String, dynamic>.from(call.arguments as Map);
          final transcript = args['transcript']?.toString() ?? '';
          onDetected(transcript);
          break;
        case 'onAgentMessageReceived':
          final args    = Map<String, dynamic>.from(call.arguments as Map);
          final contact = args['contact']?.toString() ?? '';
          final message = args['message']?.toString() ?? '';
          _agentHandler?.call(contact, message);
          break;
      }
    });
  }

  void Function(String, String)? _agentHandler;

  // Call this to register agent message handler AFTER setWakeWordHandlers
  void setAgentMessageHandler(void Function(String, String) handler) {
    _agentHandler = handler;
    // _agentHandler is already called inside setWakeWordHandlers switch-case
    // No new setMethodCallHandler needed — would overwrite wake word handler
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS MAP
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> status() async {
    final enabled = await checkEnabled();
    final pkg     = enabled ? await getForegroundApp() : '';
    return {'enabled': enabled, 'foregroundApp': pkg};
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _callBool(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _ch.invokeMethod<bool>(method, args) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc.$method: $e');
      return false;
    }
  }

  Future<bool> _invoke(String method) async {
    try {
      return await _ch.invokeMethod<bool>(method) ?? true;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc._invoke $method: $e');
      return false;
    }
  }
}
