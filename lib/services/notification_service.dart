// lib/services/notification_service.dart
// Z.A.R.A. v7.0 — Flutter side Notification Listener
// Kotlin ZaraNotificationService se events receive karta hai
// Zara proactively bolti hai: "Sir, Rohit ka WhatsApp aaya!"

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  static const _notifCh = MethodChannel('com.mahakal.zara/notifications');
  static const _mainCh  = MethodChannel('com.mahakal.zara/main');

  // Callback — ZaraController yahan subscribe karega
  void Function(NotificationAlert)? onProactiveAlert;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _notifCh.setMethodCallHandler(_onNativeCall);
    _initialized = true;
    if (kDebugMode) debugPrint('NotificationService ✅ initialized');
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onProactiveNotification') {
      final args  = Map<String, dynamic>.from(call.arguments as Map);
      final alert = NotificationAlert.fromMap(args);
      if (kDebugMode) debugPrint('📱 Proactive: ${alert.zaraAlert}');
      onProactiveAlert?.call(alert);
    }
  }

  // Permissions
  Future<bool> isEnabled() async {
    try { return await _mainCh.invokeMethod<bool>('checkNotificationListenerEnabled') ?? false; }
    catch (_) { return false; }
  }

  Future<void> openSettings() async {
    try { await _mainCh.invokeMethod('openNotificationListenerSettings'); } catch (_) {}
  }

  // Orb control
  Future<void> showOrb(String state) async {
    try { await _mainCh.invokeMethod('showOrb', {'state': state}); } catch (_) {}
  }
  Future<void> hideOrb() async {
    try { await _mainCh.invokeMethod('hideOrb'); } catch (_) {}
  }
  Future<void> updateOrb(String state) async {
    try { await _mainCh.invokeMethod('updateOrb', {'state': state}); } catch (_) {}
  }

  // Overlay permission
  Future<bool> hasOverlayPermission() async {
    try { return await _mainCh.invokeMethod<bool>('checkOverlayPermission') ?? false; }
    catch (_) { return false; }
  }
  Future<void> openOverlaySettings() async {
    try { await _mainCh.invokeMethod('openOverlaySettings'); } catch (_) {}
  }

  // Foreground service
  Future<void> startForegroundService() async {
    try { await _mainCh.invokeMethod('startForegroundService'); } catch (_) {}
  }
}

class NotificationAlert {
  final String app;
  final String package_;
  final String title;
  final String text;
  final String zaraAlert;
  final int    timestamp;

  const NotificationAlert({
    required this.app, required this.package_,
    required this.title, required this.text,
    required this.zaraAlert, required this.timestamp,
  });

  factory NotificationAlert.fromMap(Map<String, dynamic> m) => NotificationAlert(
    app:       m['app']?.toString()       ?? '',
    package_:  m['package']?.toString()   ?? '',
    title:     m['title']?.toString()     ?? '',
    text:      m['text']?.toString()      ?? '',
    zaraAlert: m['zaraAlert']?.toString() ?? '',
    timestamp: (m['timestamp'] as int?)   ?? 0,
  );
}
