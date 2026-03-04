// lib/services/accessibility_service.dart
// Z.A.R.A. — God Mode Bridge v2.0
// ✅ openApp, clickText, typeText, scroll, swipe, tap
// ✅ pressBack/Home, screenshot, notifications
// ✅ getForegroundApp, findTextOnScreen
// ✅ Proper error handling — never crashes Flutter

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static const _ch = MethodChannel('com.mahakal.zara/accessibility');

  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns true if accessibility service is running
  Future<bool> checkEnabled() async {
    try {
      final result = await _ch.invokeMethod<bool>('isEnabled');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ checkEnabled: $e');
      return false;
    }
  }

  /// Opens Android Accessibility Settings page
  Future<bool> openSettings() async {
    try {
      final result = await _ch.invokeMethod<bool>('openSettings');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ openSettings: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — APP CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  /// Open any installed app by package name
  /// Example: openApp('com.instagram.android')
  Future<bool> openApp(String packageName) async {
    try {
      final result = await _ch.invokeMethod<bool>('openApp', {
        'package': packageName,
      });
      if (kDebugMode) debugPrint('📱 openApp($packageName): $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ openApp: $e');
      return false;
    }
  }

  /// Click any visible text/button on screen
  /// Example: clickText('Like') — clicks Like button on Instagram
  Future<bool> clickText(String text) async {
    try {
      final result = await _ch.invokeMethod<bool>('clickText', {
        'text': text,
      });
      if (kDebugMode) debugPrint('👆 clickText($text): $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ clickText: $e');
      return false;
    }
  }

  /// Click element by Android resource ID
  /// Example: clickById('com.instagram.android:id/like_button')
  Future<bool> clickById(String resourceId) async {
    try {
      final result = await _ch.invokeMethod<bool>('clickById', {
        'id': resourceId,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ clickById: $e');
      return false;
    }
  }

  /// Type text into currently focused input field
  /// Example: typeText('Hello World')
  Future<bool> typeText(String text) async {
    try {
      final result = await _ch.invokeMethod<bool>('typeText', {
        'text': text,
      });
      if (kDebugMode) debugPrint('⌨️ typeText: $result');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ typeText: $e');
      return false;
    }
  }

  // Legacy alias — used in zara_provider.dart
  Future<bool> queueAutoType(String text) => typeText(text);

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — GESTURES
  // ══════════════════════════════════════════════════════════════════════════

  /// Scroll down N times (for reels, feed, etc.)
  Future<bool> scrollDown({int steps = 1}) async {
    try {
      final result = await _ch.invokeMethod<bool>('scrollDown', {
        'steps': steps,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ scrollDown: $e');
      return false;
    }
  }

  /// Scroll up N times
  Future<bool> scrollUp({int steps = 1}) async {
    try {
      final result = await _ch.invokeMethod<bool>('scrollUp', {
        'steps': steps,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ scrollUp: $e');
      return false;
    }
  }

  /// Custom swipe from (x1,y1) to (x2,y2)
  Future<bool> swipe({
    required int x1, required int y1,
    required int x2, required int y2,
    int durationMs = 300,
  }) async {
    try {
      final result = await _ch.invokeMethod<bool>('swipe', {
        'x1': x1, 'y1': y1,
        'x2': x2, 'y2': y2,
        'durationMs': durationMs,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ swipe: $e');
      return false;
    }
  }

  /// Tap at exact screen coordinates
  Future<bool> tapAt(int x, int y) async {
    try {
      final result = await _ch.invokeMethod<bool>('tapAt', {
        'x': x, 'y': y,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ tapAt: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOD MODE — SYSTEM BUTTONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> pressBack()           => _invoke('pressBack');
  Future<bool> pressHome()           => _invoke('pressHome');
  Future<bool> pressRecents()        => _invoke('pressRecents');
  Future<bool> takeScreenshot()      => _invoke('takeScreenshot');
  Future<bool> openNotifications()   => _invoke('openNotifications');
  Future<bool> openQuickSettings()   => _invoke('openQuickSettings');

  // ══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns package name of app currently on screen
  Future<String> getForegroundApp() async {
    try {
      final result = await _ch.invokeMethod<String>('getForegroundApp');
      return result ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Returns true if given text is visible on current screen
  Future<bool> findTextOnScreen(String text) async {
    try {
      final result = await _ch.invokeMethod<bool>('findTextOnScreen', {
        'text': text,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMON GOD MODE SHORTCUTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Instagram kholo
  Future<bool> openInstagram() => openApp('com.instagram.android');

  /// WhatsApp kholo
  Future<bool> openWhatsApp() => openApp('com.whatsapp');

  /// YouTube kholo
  Future<bool> openYouTube()   => openApp('com.google.android.youtube');
  Future<bool> openFlipkart()  => openApp('com.flipkart.android');
  Future<bool> openSpotify()   => openApp('com.spotify.music');
  Future<bool> openGmail()     => openApp('com.google.android.gm');
  Future<bool> openMaps()      => openApp('com.google.android.apps.maps');

  // ── Instagram God Mode ─────────────────────────────────────────────────────
  Future<bool> instagramOpenReels()           => _callBool('instagramOpenReels');
  Future<bool> instagramScrollReels(int n)    => _callBool('instagramScrollReels', {'count': n});
  Future<bool> instagramLikeReel()            => _callBool('instagramLikeReel');
  Future<bool> instagramPostComment(String t) => _callBool('instagramPostComment', {'text': t});
  Future<bool> instagramSearchUser(String u)  => _callBool('instagramSearchUser',  {'username': u});

  // ── Flipkart Shopping Flow ─────────────────────────────────────────────────
  Future<bool> flipkartSearchProduct(String q) => _callBool('flipkartSearchProduct', {'query': q});
  Future<bool> flipkartSelectSize(String s)    => _callBool('flipkartSelectSize',    {'size': s});
  Future<bool> flipkartAddToCart()             => _callBool('flipkartAddToCart');
  Future<bool> flipkartGoToPayment()           => _callBool('flipkartGoToPayment');

  // ── WhatsApp ───────────────────────────────────────────────────────────────
  Future<bool> whatsappSendMessage(String contact, String message) =>
      _callBool('whatsappSendMessage', {'contact': contact, 'message': message});

  // ── YouTube ────────────────────────────────────────────────────────────────
  Future<bool> youtubeSearch(String q) => _callBool('youtubeSearch', {'query': q});
  Future<bool> youtubePlayFirst()      => _callBool('youtubePlayFirst');

  Future<bool> _callBool(String method, [Map<String, dynamic>? args]) async {
    try {
      final r = await _ch.invokeMethod<bool>(method, args);
      return r ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('Accessibility._callBool $method: $e');
      return false;
    }
  }

  /// Facebook kholo
  Future<bool> openFacebook() => openApp('com.facebook.katana');

  /// Settings kholo
  Future<bool> openSettings2() => openApp('com.android.settings');

  /// Camera kholo
  Future<bool> openCamera() => openApp('com.android.camera2');

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _invoke(String method) async {
    try {
      final result = await _ch.invokeMethod<bool>(method);
      return result ?? true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ $method: $e');
      return false;
    }
  }

  /// Status map — for settings screen
  Future<Map<String, dynamic>> status() async {
    final enabled = await checkEnabled();
    final pkg     = enabled ? await getForegroundApp() : '';
    return {
      'enabled':        enabled,
      'foregroundApp':  pkg,
    };
  }
}
