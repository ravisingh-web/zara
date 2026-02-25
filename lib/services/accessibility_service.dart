// lib/services/accessibility_service.dart
// Z.A.R.A. — The Native Accessibility & Automation Bridge (God Mode)
// ✅ True Android MethodChannel • Ghost Touch Logic • System-Wide Controls
// ✅ Native Security Stream (Wrong Password Detection)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // ========== THE SECURE NATIVE TUNNEL ==========
  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');
  
  // Broadcast stream for real-time native alerts (e.g., Lockscreen attempts)
  StreamController<Map<String, dynamic>>? _securityStream;
  Stream<Map<String, dynamic>> get nativeEventStream => _securityStream!.stream;
  
  bool _isGodModeActive = false;
  bool get isEnabled => _isGodModeActive;

  // Android Accessibility Global Action Constants
  static const int actionBack = 1;
  static const int actionHome = 2;
  static const int actionRecents = 3;
  static const int actionNotifications = 4;
  static const int actionQuickSettings = 5;
  static const int actionPowerDialog = 6;
  static const int actionToggleSplitScreen = 7;
  static const int actionLockScreen = 8;
  static const int actionTakeScreenshot = 9;

  // ========== BOOT & SYNC PROTOCOL ==========

  Future<void> initialize() async {
    try {
      _securityStream ??= StreamController<Map<String, dynamic>>.broadcast();
      _channel.setMethodCallHandler(_handleNativeCallback);
      
      _isGodModeActive = await checkServiceEnabled();
      
      if (kDebugMode) {
        debugPrint('🔐 GOD MODE BRIDGE: ${_isGodModeActive ? "ACTIVE (Full Control)" : "STANDBY (Requires Permission)"}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Native Bridge Collapse: $e');
    }
  }

  // ========== 🦾 GHOST TOUCH (UI AUTOMATION) ==========

  /// Finds and clicks a UI element by its Content Description (e.g., "Send", "Share")
  Future<bool> clickOnDescription(String description) async {
    if (!_isGodModeActive) return false;
    try {
      final result = await _channel.invokeMethod<bool>('clickOnDescription', {'description': description});
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ Ghost Touch (Desc) Failed: $e');
      return false;
    }
  }

  /// Finds and clicks on exact visible text (e.g., "Reply", "Confirm")
  Future<bool> clickOnText(String text) async {
    if (!_isGodModeActive) return false;
    try {
      final result = await _channel.invokeMethod<bool>('clickOnText', {'text': text});
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ Ghost Touch (Text) Failed: $e');
      return false;
    }
  }

  /// Injects a global system action (Home, Back, Lock Screen)
  Future<bool> performSystemAction(int actionId) async {
    if (!_isGodModeActive) return false;
    try {
      final result = await _channel.invokeMethod<bool>('performGlobalAction', {'action': actionId});
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ System Action Override Failed: $e');
      return false;
    }
  }

  // ========== ⌨️ INPUT & TYPING SENSORS ==========

  /// Checks if the cursor is currently inside a text field (for auto-reply readiness)
  Future<bool> isTextFieldFocused() async {
    if (!_isGodModeActive) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isTextFieldFocused');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // ========== 🛡️ NATIVE SECURITY LISTENER ==========

  /// Listens to unsolicited events sent from Kotlin/Java (e.g., Intruder attempts)
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onSecurityEvent':
          // Guardian Mode: Native side caught a wrong password or screen tamper
          final data = Map<String, dynamic>.from(call.arguments);
          _securityStream?.add({'source': 'native_guardian', ...data});
          return true;
          
        case 'onAutoTypeComplete':
          // Automation Sequence Finished
          _securityStream?.add({'type': 'auto_type_success'});
          return true;
          
        case 'onServiceStatusChanged':
          // Real-time permission toggle sync
          _isGodModeActive = call.arguments['enabled'] ?? false;
          _securityStream?.add({'type': 'permission_sync', 'active': _isGodModeActive});
          return true;
          
        default:
          return null;
      }
    } catch (e) {
      debugPrint('⚠️ Native Callback Parsing Error: $e');
      return false;
    }
  }

  // ========== PERMISSION GATES ==========

  Future<bool> checkServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAccessibilityEnabled');
      _isGodModeActive = result ?? false;
      return _isGodModeActive;
    } catch (e) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Settings Override Failed: $e');
    }
  }

  // ========== CLEANUP ==========

  void dispose() {
    _securityStream?.close();
  }
}
