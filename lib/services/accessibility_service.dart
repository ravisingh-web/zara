// lib/services/accessibility_service.dart
// Z.A.R.A. — The Native Accessibility Bridge
// ✅ Crash-Free • Null-Safe • Full Guardian Mode Support • Real Working

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Accessibility Service Bridge for Z.A.R.A. Guardian Mode
/// 
/// This service connects Flutter to the native Android Accessibility Service
/// for security monitoring, intruder detection, and auto-type functionality.
/// 
/// ⚠️ Requires: Android Accessibility Service enabled by user
/// Path: Settings → Accessibility → Z.A.R.A. Guardian → Toggle ON
class AccessibilityService {
  // ========== Singleton Pattern ==========
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // ========== Platform Channel ==========
  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');

  // ========== Event Streaming ==========
  StreamController<Map<String, dynamic>>? _securityStream;
  
  /// Public stream for listening to security events from native side
  /// Events: wrong_password, intruder_detected, lock_screen, text_field_focused
  Stream<Map<String, dynamic>>? get securityEventStream => _securityStream?.stream;

  // ========== Service State ==========
  bool _isGodModeActive = false;
  
  /// Whether Accessibility Service is currently enabled by user
  bool get isEnabled => _isGodModeActive;

  // ========== Initialization ==========
  
  /// Initialize the accessibility service bridge
  /// 
  /// Sets up:
  /// - Event stream for security events
  /// - Method channel handler for native callbacks
  /// - Initial service enabled check
  /// 
  /// Call once at app startup (already done in main.dart)
  Future<void> initialize() async {
    try {      // Initialize event stream (broadcast for multiple listeners)
      _securityStream ??= StreamController<Map<String, dynamic>>.broadcast();
      
      // Set up method channel handler for native → Flutter events
      _channel.setMethodCallHandler(_handleNativeCallback);

      // 🚨 CRITICAL: Small delay to ensure native service is ready
      // Prevents "Keep Stopping" crash on first launch
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check initial service status
      _isGodModeActive = await checkServiceEnabled();

      if (kDebugMode) {
        debugPrint('🔐 Native Bridge: ${_isGodModeActive ? "LINKED ✓" : "UNLINKED ✗"}');
        if (!_isGodModeActive) {
          debugPrint('💡 User must enable: Settings → Accessibility → Z.A.R.A. Guardian');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Bridge Initialization Error: $e');
      _isGodModeActive = false;
    }
  }

  // ========== Native Callback Handler ==========
  
  /// Handle method calls from native Android Accessibility Service
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onServiceStatusChanged':
          // Service enabled/disabled by user in system settings
          final enabled = call.arguments['enabled'] as bool? ?? false;
          _isGodModeActive = enabled;
          _securityStream?.add({'type': 'service_status', 'data': {'enabled': enabled}});
          if (kDebugMode) debugPrint('🔐 Service Status: ${enabled ? "ENABLED" : "DISABLED"}');
          break;
          
        case 'onSecurityEvent':
          // Security event from Guardian Mode monitoring
          final eventData = call.arguments as Map<dynamic, dynamic>? ?? {};
          final sanitized = _sanitizeEventData(eventData);
          final type = sanitized['type'] as String?;
          
          if (kDebugMode && type != null) {
            debugPrint('🚨 Security Event: $type');
          }
          
          // Forward to stream for UI/Provider to handle          _securityStream?.add(sanitized);
          
          // Handle specific events locally if needed
          await _processSecurityEvent(sanitized);
          break;
          
        case 'onAutoTypeProgress':
          // Auto-type progress update (for UI feedback)
          final progress = call.arguments['progress'] as double? ?? 0.0;
          _securityStream?.add({'type': 'auto_type_progress', 'data': {'progress': progress}});
          break;
          
        case 'onAutoTypeComplete':
          // Auto-type completed successfully
          final chars = call.arguments['characters'] as int? ?? 0;
          _securityStream?.add({'type': 'auto_type_complete', 'data': {'characters': chars}});
          if (kDebugMode) debugPrint('✅ Auto-Type Complete: $chars characters');
          break;
          
        case 'onAutoTypeError':
          // Auto-type failed
          final error = call.arguments['error'] as String? ?? 'Unknown error';
          _securityStream?.add({'type': 'auto_type_error', 'data': {'error': error}});
          if (kDebugMode) debugPrint('⚠️ Auto-Type Error: $error');
          break;
          
        default:
          if (kDebugMode) debugPrint('❓ Unknown native method: ${call.method}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Callback Handler Error: $e');
      return null;
    }
  }

  /// Sanitize event data from native (ensure type safety)
  Map<String, dynamic> _sanitizeEventData(Map<dynamic, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key is String) {
        sanitized[entry.key as String] = entry.value;
      }
    }
    return sanitized;
  }

  /// Process security events locally (optional local handling)
  Future<void> _processSecurityEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;    final data = event['data'] as Map<String, dynamic>? ?? {};
    
    switch (type) {
      case 'wrong_password':
        // Wrong password attempt detected
        final count = data['count'] as int? ?? 0;
        if (kDebugMode) debugPrint('🚨 Wrong Password Attempt #$count');
        // TODO: Trigger ZaraController to show alert
        break;
        
      case 'intruder_detected':
        // Intruder detected — photo captured
        final action = data['action'] as String? ?? 'capture_photo';
        if (kDebugMode) debugPrint('🚨 INTRUDER DETECTED! Action: $action');
        // TODO: Trigger camera/email alert via ZaraController
        break;
        
      case 'lock_screen':
        // Lock screen visibility changed
        final visible = data['visible'] as bool? ?? false;
        if (kDebugMode) debugPrint('🔒 Lock Screen: ${visible ? "Visible" : "Hidden"}');
        break;
        
      case 'text_field_focused':
        // Text field focused (for auto-type readiness)
        final packageName = data['package'] as String? ?? '';
        if (kDebugMode) debugPrint('📝 Text Field Focused: $packageName');
        break;
    }
  }

  // ========== Service Status Methods ==========
  
  /// Check if Accessibility Service is enabled by user
  /// 
  /// Returns true if user has enabled Z.A.R.A. Guardian in:
  /// Settings → Accessibility → Z.A.R.A. Guardian → Toggle ON
  Future<bool> checkServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAccessibilityEnabled');
      _isGodModeActive = result ?? false;
      return _isGodModeActive;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check Service Error: $e');
      return false;
    }
  }

  /// Open Android Accessibility Settings for user to enable service
  ///   /// Note: User must manually enable "Z.A.R.A. Guardian Service"
  /// This method cannot auto-enable due to Android security restrictions
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      if (kDebugMode) debugPrint('🔓 Opened Accessibility Settings');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open Settings Error: $e');
    }
  }

  // ========== Guardian Mode Controls ==========
  
  /// Enable Guardian Mode monitoring (theatrical — actual monitoring is always on when service enabled)
  Future<void> enableGuardianMode() async {
    try {
      await _channel.invokeMethod('enableGuardianMode');
      _isGodModeActive = true;
      if (kDebugMode) debugPrint('🛡️ Guardian Mode Enabled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Enable Guardian Error: $e');
    }
  }

  /// Disable Guardian Mode monitoring
  Future<void> disableGuardianMode() async {
    try {
      await _channel.invokeMethod('disableGuardianMode');
      _isGodModeActive = false;
      if (kDebugMode) debugPrint('🛡️ Guardian Mode Disabled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Disable Guardian Error: $e');
    }
  }

  /// Reset wrong password count (call after successful unlock)
  /// 
  /// Prevents false intruder alerts when user unlocks device legitimately
  Future<void> resetWrongPasswordCount() async {
    try {
      await _channel.invokeMethod('resetWrongPasswordCount');
      if (kDebugMode) debugPrint('🔄 Wrong Password Count Reset');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Reset Count Error: $e');
    }
  }

  /// Get current wrong password attempt count
  Future<int> getWrongPasswordCount() async {
    try {      final count = await _channel.invokeMethod<int>('getWrongPasswordCount');
      return count ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get Count Error: $e');
      return 0;
    }
  }

  // ========== Auto-Type Bridge Methods ==========
  
  /// Queue text for auto-typing into active text field
  /// 
  /// [text]: The text to type
  /// [delayMs]: Delay between keystrokes in milliseconds (default: 10ms)
  /// 
  /// Returns: true if text was queued successfully
  Future<bool> queueAutoType(String text, {int delayMs = 10}) async {
    try {
      final result = await _channel.invokeMethod<bool>('queueAutoType', {
        'text': text,
        'delayMs': delayMs,
      });
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Queue Auto-Type Error: $e');
      return false;
    }
  }

  /// Cancel any pending auto-type operation
  Future<void> cancelAutoType() async {
    try {
      await _channel.invokeMethod('cancelAutoType');
      if (kDebugMode) debugPrint('⌨️ Auto-Type Cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cancel Auto-Type Error: $e');
    }
  }

  /// Check if a text input field is currently focused (ready for auto-type)
  Future<bool> isTextFieldFocused() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTextFieldFocused');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check Text Field Error: $e');
      return false;
    }
  }
  /// Click on UI element by visible text (for navigation)
  Future<bool> clickOnText(String text) async {
    try {
      final result = await _channel.invokeMethod<bool>('clickOnText', {'text': text});
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Click On Text Error: $e');
      return false;
    }
  }

  /// Open app by package name
  Future<bool> openApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('openApp', {'package': packageName});
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open App Error: $e');
      return false;
    }
  }

  // ========== Utility Methods ==========
  
  /// Get detailed service status for debugging
  Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final status = await _channel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      return {
        'enabled': _isGodModeActive,
        'textFieldFocused': await isTextFieldFocused(),
        ...?status?.map((key, value) => MapEntry(key.toString(), value)),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get Service Status Error: $e');
      return {'enabled': _isGodModeActive};
    }
  }

  /// Refresh service status (re-check enabled state)
  Future<void> refreshStatus() async {
    _isGodModeActive = await checkServiceEnabled();
    if (kDebugMode) {
      debugPrint('🔄 Accessibility Service Status Refreshed: ${_isGodModeActive ? "ENABLED" : "DISABLED"}');
    }
  }

  // ========== Lifecycle ==========
  
  /// Dispose service and clean up resources  /// Call when service is no longer needed (app close)
  void dispose() {
    _securityStream?.close();
    _securityStream = null;
    _isGodModeActive = false;
    if (kDebugMode) debugPrint('🔐 Accessibility Service Disposed');
  }

  // ========== Static Helpers ==========
  
  /// Quick check: Is service ready for Guardian Mode?
  static Future<bool> isGuardianReady() async {
    final service = AccessibilityService();
    return await service.checkServiceEnabled();
  }
}

// ========== Event Type Constants ==========

/// Constants for security event types (for type-safe filtering)
abstract final class AccessibilityEventType {
  static const String serviceStatus = 'service_status';
  static const String wrongPassword = 'wrong_password';
  static const String intruderDetected = 'intruder_detected';
  static const String lockScreen = 'lock_screen';
  static const String textFieldFocused = 'text_field_focused';
  static const String autoTypeProgress = 'auto_type_progress';
  static const String autoTypeComplete = 'auto_type_complete';
  static const String autoTypeError = 'auto_type_error';
}
