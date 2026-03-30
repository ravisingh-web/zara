// lib/services/accessibility_service.dart
// Z.A.R.A. v11.0 — God Mode Flutter Bridge
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX v11: CHANNEL CONFLICT RESOLVED                                     ║
// ║                                                                         ║
// ║  🔴 ROOT CAUSE:                                                         ║
// ║     VoskService called _ch.setMethodCallHandler() in start()            ║
// ║     AccessibilityService was also using the same channel                ║
// ║     → Two handlers on same channel = second one silently wins          ║
// ║     → Either vosk events OR accessibility events lost                  ║
// ║                                                                         ║
// ║  ✅ FIX:                                                                ║
// ║     AccessibilityService owns the SINGLE handler for                   ║
// ║     'com.mahakal.zara/accessibility'.                                   ║
// ║     It calls VoskService.dispatchNativeCall() for vosk events.         ║
// ║     VoskService ONLY invokes methods, never sets handler.              ║
// ║                                                                         ║
// ║  ✅ setupChannelHandler() — call once from ZaraController.initialize() ║
// ║     Sets the single handler. Safe to call multiple times (idempotent) ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zara/services/vosk_service.dart';

class AccessibilityService {
  static const _ch   = MethodChannel('com.mahakal.zara/accessibility');
  static const _main = MethodChannel('com.mahakal.zara/main');

  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  bool _handlerSetup = false;

  // ══════════════════════════════════════════════════════════════════════════
  // ✅ FIX: SINGLE CHANNEL HANDLER
  //
  // Call this ONCE from ZaraController.initialize() BEFORE VoskService.start()
  // This handler receives ALL events from native side and dispatches to
  // the appropriate service (VoskService or AccessibilityService).
  // ══════════════════════════════════════════════════════════════════════════

  void setupChannelHandler() {
    if (_handlerSetup) return; // idempotent
    _handlerSetup = true;

    _ch.setMethodCallHandler((call) async {
      // Vosk + agent + security events → forward to VoskService dispatcher
      const voskEvents = {
        'wake_word_detected',
        'onWakeWordPcmReady',
        'onWakeWordEngineChanged',
        'onWakeWordError',
        'onAgentMessageReceived',
        'onChainComplete',
        'onAgentModeChanged',
        'onSecurityEvent',
        'onServiceStatusChanged',
        'onWindowChanged',
      };

      if (voskEvents.contains(call.method)) {
        await VoskService().dispatchNativeCall(call);
        return;
      }

      // Accessibility-specific events can be handled here if needed
      if (kDebugMode) debugPrint('AccessSvc unhandled: ${call.method}');
    });

    if (kDebugMode) debugPrint('AccessibilityService ✅ channel handler set');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> checkEnabled() async {
    try { return await _ch.invokeMethod<bool>('isEnabled') ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc checkEnabled: $e'); return false; }
  }

  Future<bool> openSettings() async {
    try { return await _ch.invokeMethod<bool>('openSettings') ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc openSettings: $e'); return false; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCREEN CONTEXT
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> getScreenContext() async {
    try {
      final result = await _main.invokeMethod<String>('getScreenContext');
      final ctx    = result ?? '';
      if (kDebugMode && ctx.isNotEmpty)
        debugPrint('ScreenCtx (${ctx.length}): ${ctx.substring(0, ctx.length.clamp(0, 80))}…');
      return ctx;
    } catch (e) { if (kDebugMode) debugPrint('AccessSvc getScreenContext: $e'); return ''; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERMISSIONS
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
  // APP CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> openApp(String packageName) async {
    try {
      final result = await _ch.invokeMethod<bool>('openApp', {'package': packageName});
      if (kDebugMode) debugPrint('📱 openApp($packageName): $result');
      return result ?? false;
    } catch (e) { if (kDebugMode) debugPrint('AccessSvc openApp: $e'); return false; }
  }

  Future<bool> clickText(String text) async {
    try { return await _ch.invokeMethod<bool>('clickText', {'text': text}) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc clickText: $e'); return false; }
  }

  Future<bool> clickById(String id) async {
    try { return await _ch.invokeMethod<bool>('clickById', {'id': id}) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc clickById: $e'); return false; }
  }

  Future<bool> typeText(String text) async {
    try { return await _ch.invokeMethod<bool>('typeText', {'text': text}) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc typeText: $e'); return false; }
  }

  Future<bool> queueAutoType(String text) => typeText(text);

  // ══════════════════════════════════════════════════════════════════════════
  // GESTURES
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> scrollDown({int steps = 1}) async {
    try { return await _ch.invokeMethod<bool>('scrollDown', {'steps': steps}) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc scrollDown: $e'); return false; }
  }

  Future<bool> scrollUp({int steps = 1}) async {
    try { return await _ch.invokeMethod<bool>('scrollUp', {'steps': steps}) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc scrollUp: $e'); return false; }
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
    } catch (e) { if (kDebugMode) debugPrint('AccessSvc swipe: $e'); return false; }
  }

  Future<bool> tapAt(int x, int y) async {
    try { return await _ch.invokeMethod<bool>('tapAt', {'x': x, 'y': y}) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc tapAt: $e'); return false; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYSTEM BUTTONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> pressBack()         => _invoke('pressBack');
  Future<bool> pressHome()         => _invoke('pressHome');
  Future<bool> pressRecents()      => _invoke('pressRecents');
  Future<bool> takeScreenshot()    => _invoke('takeScreenshot');
  Future<bool> openNotifications() => _invoke('openNotifications');
  Future<bool> openQuickSettings() => _invoke('openQuickSettings');

  // ══════════════════════════════════════════════════════════════════════════
  // VISION — SCREEN SCANNER
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> scanScreen() async {
    try {
      final result = await _ch.invokeMethod<String>('scanScreen');
      final json   = result ?? '{}';
      if (kDebugMode && json.length > 2) {
        debugPrint('👁️ scanScreen: ${json.length} chars');
      }
      return json;
    } catch (e) {
      if (kDebugMode) debugPrint('AccessSvc scanScreen: $e');
      return '{}';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> getForegroundApp() async {
    try { return await _ch.invokeMethod<String>('getForegroundApp') ?? ''; }
    catch (_) { return ''; }
  }

  Future<bool> findTextOnScreen(String text) async {
    try { return await _ch.invokeMethod<bool>('findTextOnScreen', {'text': text}) ?? false; }
    catch (_) { return false; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP SHORTCUTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> openInstagram() => openApp('com.instagram.android');
  Future<bool> openWhatsApp()  => openApp('com.whatsapp');
  Future<bool> openYouTube()   => openApp('com.google.android.youtube');
  Future<bool> openFlipkart()  => openApp('com.flipkart.android');
  Future<bool> openSpotify()   => openApp('com.spotify.music');
  Future<bool> openGmail()     => openApp('com.google.android.gm');
  Future<bool> openMaps()      => openApp('com.google.android.apps.maps');
  Future<bool> openFacebook()  => openApp('com.facebook.katana');
  Future<bool> facebookPost(String text) => _callBool('facebookPost', {'text': text});
  Future<bool> openCamera()    => openApp('com.android.camera2');

  // ══════════════════════════════════════════════════════════════════════════
  // YOUTUBE
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> youtubeSearch(String q) => _callBool('youtubeSearch', {'query': q});
  Future<bool> youtubePlayFirst()       => _callBool('youtubePlayFirst');

  // ══════════════════════════════════════════════════════════════════════════
  // INSTAGRAM
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> instagramOpenReels()           => _callBool('instagramOpenReels');
  Future<bool> instagramScrollReels(int n)    => _callBool('instagramScrollReels', {'count': n});
  Future<bool> instagramLikeReel()            => _callBool('instagramLikeReel');
  Future<bool> instagramPostComment(String t) => _callBool('instagramPostComment', {'text': t});
  Future<bool> instagramSearchUser(String u)  => _callBool('instagramSearchUser',  {'username': u});

  // ══════════════════════════════════════════════════════════════════════════
  // FLIPKART
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> flipkartSearchProduct(String q) => _callBool('flipkartSearchProduct', {'query': q});
  Future<bool> flipkartSelectSize(String s)    => _callBool('flipkartSelectSize',    {'size': s});
  Future<bool> flipkartAddToCart()             => _callBool('flipkartAddToCart');
  Future<bool> flipkartGoToPayment()           => _callBool('flipkartGoToPayment');

  // ══════════════════════════════════════════════════════════════════════════
  // WHATSAPP
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> whatsappSendMessage(String contact, String message) =>
      _callBool('whatsappSendMessage', {'contact': contact, 'message': message});

  Future<bool> whatsappVoiceCall(String contact) =>
      _callBool('whatsappVoiceCall', {'contact': contact});

  Future<bool> whatsappVideoCall(String contact) =>
      _callBool('whatsappVideoCall', {'contact': contact});

  Future<String> whatsappReadMessages(String contact) async {
    try {
      final r = await _ch.invokeMethod<String>('whatsappReadMessages', {'contact': contact});
      return r ?? 'Kuch nahi mila Sir';
    } catch (e) { return 'Error: $e'; }
  }

  Future<bool> whatsappStartAgent(String contact, String persona) =>
      _callBool('whatsappStartAgent', {'contact': contact, 'persona': persona});

  Future<bool> whatsappStopAgent() => _callBool('whatsappStopAgent');

  // ══════════════════════════════════════════════════════════════════════════
  // COMMAND CHAIN
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> executeChain(List<Map<String, dynamic>> commands) async {
    try {
      return await _ch.invokeMethod<bool>('executeChain', {'commands': commands}) ?? false;
    } catch (e) { if (kDebugMode) debugPrint('executeChain: $e'); return false; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WAKE WORD — invoke only (handler is now owned by setupChannelHandler)
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> startWakeWord() async {
    try { return await _ch.invokeMethod<bool>('startWakeWord') ?? false; }
    catch (_) { return false; }
  }

  Future<bool> stopWakeWord() async {
    try { return await _ch.invokeMethod<bool>('stopWakeWord') ?? false; }
    catch (_) { return false; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AGENT MODE
  // ══════════════════════════════════════════════════════════════════════════

  void Function(String contact, String message)? _agentHandler;

  void setAgentMessageHandler(void Function(String, String) handler) {
    _agentHandler = handler;
  }

  void dispatchAgentMessage(String contact, String message) {
    _agentHandler?.call(contact, message);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UNIVERSAL GENERIC CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> performGenericAction(
    String action,
    String target, {
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

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS MAP
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> status() async {
    final enabled = await checkEnabled();
    final pkg     = enabled ? await getForegroundApp() : '';
    return {'enabled': enabled, 'foregroundApp': pkg};
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _callBool(String method, [Map<String, dynamic>? args]) async {
    try { return await _ch.invokeMethod<bool>(method, args) ?? false; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc.$method: $e'); return false; }
  }

  Future<bool> _invoke(String method) async {
    try { return await _ch.invokeMethod<bool>(method) ?? true; }
    catch (e) { if (kDebugMode) debugPrint('AccessSvc._invoke $method: $e'); return false; }
  }
}
