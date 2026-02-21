// lib/services/accessibility_service.dart
// Z.A.R.A. — Flutter ↔ Native Accessibility Bridge
// Platform Channel Communication

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');
  
  StreamController<Map<dynamic, dynamic>>? _eventController;
  Stream<Map<dynamic, dynamic>>? get securityEventStream => _eventController?.stream;
  
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;
  
  /// Initialize platform channel listener
  Future<void> initialize() async {
    _eventController = StreamController<Map<dynamic, dynamic>>.broadcast();
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSecurityEvent') {
        final data = call.arguments as Map<dynamic, dynamic>;
        debugPrint('🔐 Security Event: ${data['type']}');
        _eventController?.add(data);
        
        // Handle specific events
        await _handleSecurityEvent(data);
      }
    });
    
    // Check if service is enabled
    _isEnabled = await checkServiceEnabled();
    debugPrint('🔐 Accessibility Service: ${_isEnabled ? "ENABLED" : "DISABLED"}');
  }
  
  /// Check if Accessibility Service is enabled
  Future<bool> checkServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ Check service error: $e');
      return false;
    }
  }
  
  /// Open Accessibility Settings (user must enable manually)
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('⚠️ Open settings error: $e');
      // Fallback: Open general accessibility settings
      // This requires url_launcher package
    }
  }
  
  /// Reset wrong password count (after successful unlock)
  Future<void> resetWrongPasswordCount() async {
    try {
      await _channel.invokeMethod('resetWrongPasswordCount');
    } catch (e) {
      debugPrint('⚠️ Reset count error: $e');
    }
  }
  
  /// Handle incoming security events
  Future<void> _handleSecurityEvent(Map<dynamic, dynamic> event) async {
    final type = event['type'] as String?;
    
    switch (type) {
      case 'wrong_password':
        debugPrint('🚨 Wrong Password Detected! Count: ${event['data']['count']}');
        break;
        
      case 'intruder_detected':
        debugPrint('🚨 INTRUDER DETECTED! Action: ${event['data']['action']}');
        break;
        
      case 'lock_screen':
        debugPrint('🔒 Lock Screen: ${event['data']['visible']}');
        break;
        
      default:
        debugPrint('🔐 Security Event: $type');
    }
  }
  
  /// Get wrong password count from native
  Future<int> getWrongPasswordCount() async {
    try {
      final count = await _channel.invokeMethod<int>('getWrongPasswordCount');
      return count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Get count error: $e');
      return 0;
    }
  }
  
  @override
  void dispose() {
    _eventController?.close();
  }
}
