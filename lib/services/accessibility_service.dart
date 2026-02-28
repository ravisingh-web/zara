import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');
  StreamController<Map<String, dynamic>>? _stream;
  bool _active = false;

  Stream<Map<String, dynamic>>? get events => _stream?.stream;
  bool get active => _active;

  Future<void> initialize() async {
    try {
      _stream ??= StreamController<Map<String, dynamic>>.broadcast();
      _channel.setMethodCallHandler(_handle);
      await Future.delayed(const Duration(milliseconds: 500));
      _active = await _channel.invokeMethod<bool>('checkAccessibilityEnabled') ?? false;
      if (kDebugMode) debugPrint('🔐 Accessibility: ${_active ? "ON" : "OFF"}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Init error: $e');
      _active = false;
    }
  }

  Future<dynamic> _handle(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onServiceStatusChanged':
          _active = call.arguments['enabled'] as bool? ?? false;
          _stream?.add({'type': 'status', 'data': {'enabled': _active}});
          break;
        case 'onSecurityEvent':
          final data = call.arguments as Map<dynamic, dynamic>? ?? {};
          final sanitized = <String, dynamic>{};
          for (final e in data.entries) {
            if (e.key is String) sanitized[e.key as String] = e.value;
          }
          _stream?.add(sanitized);
          if (sanitized['type'] == 'intruder_detected') {
            await _triggerIntruderAlert(sanitized);          }
          break;
        case 'onAutoTypeProgress':
        case 'onAutoTypeComplete':
        case 'onAutoTypeError':
          _stream?.add({'type': call.method, 'data': call.arguments});
          break;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Handle error: $e');
      return null;
    }
  }

  Future<void> _triggerIntruderAlert(Map<String, dynamic> data) async {
    final path = data['path'] as String?;
    final loc = data['location'] as String?;
    if (kDebugMode) debugPrint('🚨 INTRUDER: path=$path, loc=$loc');
  }

  Future<bool> checkEnabled() async {
    try {
      _active = await _channel.invokeMethod<bool>('checkAccessibilityEnabled') ?? false;
      return _active;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check error: $e');
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Settings error: $e');
    }
  }

  Future<void> resetWrongCount() async {
    try {
      await _channel.invokeMethod('resetWrongPasswordCount');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Reset error: $e');
    }
  }

  Future<int> getWrongCount() async {
    try {
      final count = await _channel.invokeMethod<int>('getWrongPasswordCount');      return count ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ GetCount error: $e');
      return 0;
    }
  }

  Future<bool> queueAutoType(String text, {int delay = 10}) async {
    try {
      final result = await _channel.invokeMethod<bool>('queueAutoType', {'text': text, 'delayMs': delay});
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Queue error: $e');
      return false;
    }
  }

  Future<void> cancelAutoType() async {
    try {
      await _channel.invokeMethod('cancelAutoType');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cancel error: $e');
    }
  }

  Future<bool> isFieldFocused() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTextFieldFocused');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Focus error: $e');
      return false;
    }
  }

  Future<bool> clickText(String text) async {
    try {
      final result = await _channel.invokeMethod<bool>('clickOnText', {'text': text});
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Click error: $e');
      return false;
    }
  }

  Future<bool> openApp(String pkg) async {
    try {
      final result = await _channel.invokeMethod<bool>('openApp', {'package': pkg});
      return result ?? false;
    } catch (e) {      if (kDebugMode) debugPrint('⚠️ OpenApp error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> status() async {
    try {
      final s = await _channel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      final result = <String, dynamic>{'active': _active, 'focused': await isFieldFocused()};
      if (s != null) {
        for (final entry in s.entries) {
          if (entry.key is String) {
            result[entry.key as String] = entry.value;
          }
        }
      }
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Status error: $e');
      return {'active': _active};
    }
  }

  Future<void> refresh() async {
    _active = await checkEnabled();
  }

  void dispose() {
    _stream?.close();
    _stream = null;
    _active = false;
  }

  static Future<bool> ready() async {
    return await AccessibilityService().checkEnabled();
  }
}
