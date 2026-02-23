// lib/services/accessibility_service.dart
// Z.A.R.A. — Accessibility Service Bridge (Flutter ↔ Native)
// ✅ Guardian Mode Events • Auto-Type Bridge • Security Monitoring
// ✅ Platform Channel • Stream Events • Production-Ready

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Accessibility Service Bridge for Z.A.R.A. Guardian Mode
/// 
/// This service acts as a bridge between Flutter and native Android
/// Accessibility Service for:
/// - Guardian Mode: Wrong password detection, intruder alerts
/// - Auto-Type: Programmatically typing code into text editors
/// - Security Monitoring: Lock screen detection, suspicious activity
/// 
/// ⚠️ Requires Android Accessibility Service permission
/// User must enable manually: Settings → Accessibility → Z.A.R.A. Guardian
class AccessibilityService {
  // ========== Singleton Pattern ==========
  
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  // ========== Platform Channel ==========
  
  /// Method channel for Flutter ↔ Native communication
  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');

  // ========== Event Streaming ==========
  
  /// Stream controller for security events from native side
  StreamController<Map<String, dynamic>>? _eventController;
  
  /// Public stream for listening to security events
  Stream<Map<String, dynamic>>? get securityEventStream => _eventController?.stream;

  // ========== Service State ==========
  
  /// Whether Accessibility Service is currently enabled by user
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;
  
  /// Whether auto-type feature is currently active
  bool _isTyping = false;
  bool get isTyping => _isTyping;

  // ========== Initialization ==========
  
  /// Initialize the accessibility service bridge
  /// 
  /// Sets up:
  /// - Event stream listener for security events
  /// - Method channel handler for native callbacks
  /// - Initial service enabled check
  /// 
  /// Call this once at app startup after Provider setup
  Future<void> initialize() async {
    try {
      // Initialize event stream
      _eventController = StreamController<Map<String, dynamic>>.broadcast();

      // Set up method channel handler for native → Flutter events
      _channel.setMethodCallHandler(_handleNativeCall);

      // Check initial service status
      _isEnabled = await checkServiceEnabled();
      
      if (kDebugMode) {
        debugPrint('🔐 Accessibility Service: ${_isEnabled ? "ENABLED ✓" : "DISABLED ✗"}');
        if (!_isEnabled) {
          debugPrint('💡 User must enable: Settings → Accessibility → Z.A.R.A. Guardian');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Accessibility Service init error: $e');
      }
      _isEnabled = false;
    }
  }

  /// Handle method calls from native Android side
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSecurityEvent':
        // Security event from Guardian Mode
        final data = call.arguments as Map<dynamic, dynamic>;
        final typedData = _sanitizeEventData(data);
        
        if (kDebugMode) {
          debugPrint('🔐 Security Event: ${typedData['type']}');
        }
        
        _eventController?.add(typedData);
        await _handleSecurityEvent(typedData);
        return true;
        
      case 'onAutoTypeComplete':
        // Auto-type operation completed
        final success = call.arguments['success'] as bool? ?? false;
        _isTyping = false;
        
        if (kDebugMode) {
          debugPrint('⌨️ Auto-Type: ${success ? "Success ✓" : "Failed ✗"}');
        }
        return true;
        
      case 'onAutoTypeError':
        // Auto-type operation failed
        final error = call.arguments['error'] as String? ?? 'Unknown error';
        _isTyping = false;
        
        if (kDebugMode) {
          debugPrint('⚠️ Auto-Type Error: $error');
        }
        return true;
        
      default:
        if (kDebugMode) {
          debugPrint('❓ Unknown native method: ${call.method}');
        }
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

  // ========== Security Event Handling ==========
  
  /// Process incoming security events from native Accessibility Service
  Future<void> _handleSecurityEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    final eventData = event['data'] as Map<String, dynamic>? ?? {};
    
    switch (type) {
      case 'wrong_password':
        // Wrong password attempt detected
        final count = eventData['count'] as int? ?? 0;
        final timestamp = eventData['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        
        if (kDebugMode) {
          debugPrint('🚨 Wrong Password Detected! Attempt #$count at ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
        }
        
        // TODO: Trigger Z.A.R.A. response via Provider
        // context.read<ZaraController>().triggerSecurityAlert('Wrong password attempt #$count');
        break;
        
      case 'intruder_detected':
        // Intruder detected — trigger photo capture
        final action = eventData['action'] as String? ?? 'capture_photo';
        final wrongAttempts = eventData['wrongAttempts'] as int? ?? 0;
        
        if (kDebugMode) {
          debugPrint('🚨 INTRUDER DETECTED! Action: $action, Attempts: $wrongAttempts');
        }
        
        // TODO: Trigger camera service via Provider
        // context.read<ZaraController>().captureIntruderPhoto();
        break;
        
      case 'lock_screen':
        // Lock screen visibility changed
        final visible = eventData['visible'] as bool? ?? false;
        final packageName = eventData['package'] as String? ?? '';
        
        if (kDebugMode) {
          debugPrint('🔒 Lock Screen: ${visible ? "Visible" : "Hidden"} ($packageName)');
        }
        break;
        
      case 'password_field_focused':
        // Text input field focused (for auto-type)
        final packageName = eventData['package'] as String? ?? '';
        final hint = eventData['hint'] as String? ?? '';
        final canEdit = eventData['canEdit'] as bool? ?? true;
        
        if (kDebugMode) {
          debugPrint('📝 Text Field Focused: $packageName, hint: "$hint", editable: $canEdit');
        }
        
        // If auto-type is queued, trigger it now
        // TODO: Integrate with auto_type_service
        break;
        
      case 'suspicious_activity':
        // Unusual app behavior detected
        final activity = eventData['activity'] as String? ?? 'unknown';
        final severity = eventData['severity'] as String? ?? 'low';
        
        if (kDebugMode) {
          debugPrint('⚠️ Suspicious Activity: $activity (severity: $severity)');
        }
        break;
        
      default:
        if (kDebugMode) {
          debugPrint('🔐 Unknown Security Event: $type');
        }
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
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Check service enabled error: $e');
      }
      return false;
    }
  }

  /// Open Android Accessibility Settings for user to enable service
  /// 
  /// Note: User must manually enable "Z.A.R.A. Guardian Service"
  /// This method cannot auto-enable due to Android security restrictions
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      
      if (kDebugMode) {
        debugPrint('🔓 Opened Accessibility Settings — User must enable Z.A.R.A. Guardian');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Open settings error: $e');
      }
      // Fallback: Try to open general settings
      try {
        await _channel.invokeMethod('openGeneralSettings');
      } catch (_) {
        // Last resort: Let caller handle with url_launcher
        rethrow;
      }
    }
  }

  /// Check if service has required permissions
  Future<Map<String, bool>> checkPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
      return result?.map((key, value) => MapEntry(key.toString(), value as bool)) ?? {};
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check permissions error: $e');
      return {};
    }
  }

  // ========== Guardian Mode Controls ==========
  
  /// Reset wrong password count (call after successful unlock)
  /// 
  /// Prevents false intruder alerts when Sir unlocks device legitimately
  Future<void> resetWrongPasswordCount() async {
    try {
      await _channel.invokeMethod('resetWrongPasswordCount');
      
      if (kDebugMode) {
        debugPrint('🔄 Wrong password count reset');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Reset count error: $e');
    }
  }

  /// Get current wrong password attempt count
  Future<int> getWrongPasswordCount() async {
    try {
      final count = await _channel.invokeMethod<int>('getWrongPasswordCount');
      return count ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get count error: $e');
      return 0;
    }
  }

  /// Enable Guardian Mode monitoring (theatrical — actual monitoring is always on when service enabled)
  Future<void> enableGuardianMode() async {
    try {
      await _channel.invokeMethod('enableGuardianMode');
      if (kDebugMode) debugPrint('🛡️ Guardian Mode enabled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Enable guardian error: $e');
    }
  }

  /// Disable Guardian Mode monitoring
  Future<void> disableGuardianMode() async {
    try {
      await _channel.invokeMethod('disableGuardianMode');
      if (kDebugMode) debugPrint('🛡️ Guardian Mode disabled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Disable guardian error: $e');
    }
  }

  // ========== Auto-Type Bridge Methods ==========
  
  /// Queue text for auto-typing into active text field
  /// 
  /// [text]: The text to type
  /// [packageName]: Optional target app package name (null = any app)
  /// [fieldName]: Optional target field identifier (null = any editable field)
  /// 
  /// Returns true if text was queued successfully
  Future<bool> queueAutoType({
    required String text,
    String? packageName,
    String? fieldName,
  }) async {
    try {
      if (_isTyping) {
        if (kDebugMode) debugPrint('⌨️ Auto-type already in progress');
        return false;
      }
      
      _isTyping = true;
      
      final result = await _channel.invokeMethod<bool>('queueAutoType', {
        'text': text,
        'packageName': packageName,
        'fieldName': fieldName,
      });
      
      if (kDebugMode) {
        debugPrint('⌨️ Auto-Type Queued: ${text.length} chars, result: $result');
      }
      
      return result ?? false;
    } catch (e) {
      _isTyping = false;
      if (kDebugMode) debugPrint('⚠️ Queue auto-type error: $e');
      return false;
    }
  }

  /// Cancel any pending auto-type operation
  Future<void> cancelAutoType() async {
    try {
      await _channel.invokeMethod('cancelAutoType');
      _isTyping = false;
      if (kDebugMode) debugPrint('⌨️ Auto-Type cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cancel auto-type error: $e');
    }
  }

  /// Check if a text input field is currently focused (ready for auto-type)
  Future<bool> isTextFieldFocused() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTextFieldFocused');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check text field error: $e');
      return false;
    }
  }

  /// Click on UI element by text content (for navigation)
  Future<bool> clickOnText(String text) async {
    try {
      final result = await _channel.invokeMethod<bool>('clickOnText', {'text': text});
      if (kDebugMode) debugPrint('👆 Click on "$text": ${result ?? false}');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Click on text error: $e');
      return false;
    }
  }

  /// Open app by package name
  Future<bool> openApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('openApp', {'package': packageName});
      if (kDebugMode) debugPrint('📱 Open app "$packageName": ${result ?? false}');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open app error: $e');
      return false;
    }
  }

  // ========== Utility Methods ==========
  
  /// Get detailed service status for debugging
  Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final status = await _channel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      return status?.map((key, value) => MapEntry(key.toString(), value)) ?? {};
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get service status error: $e');
      return {};
    }
  }

  /// Refresh service status (re-check enabled state)
  Future<void> refreshStatus() async {
    _isEnabled = await checkServiceEnabled();
    if (kDebugMode) {
      debugPrint('🔄 Accessibility Service status refreshed: ${_isEnabled ? "ENABLED" : "DISABLED"}');
    }
  }

  // ========== Lifecycle ==========
  
  /// Dispose service and clean up resources
  /// Call when service is no longer needed (app close)
  void dispose() {
    _eventController?.close();
    _eventController = null;
    _isTyping = false;
    
    if (kDebugMode) {
      debugPrint('🔐 Accessibility Service disposed');
    }
  }

  // ========== Static Helpers ==========
  
  /// Quick check: Is service ready for Guardian Mode?
  static Future<bool> isGuardianReady() async {
    final service = AccessibilityService();
    return await service.checkServiceEnabled();
  }
  
  /// Quick check: Is auto-type ready?
  static Future<bool> isAutoTypeReady() async {
    final service = AccessibilityService();
    final enabled = await service.checkServiceEnabled();
    final fieldFocused = await service.isTextFieldFocused();
    return enabled && fieldFocused;
  }
}

// ========== Extension: Convenience Methods ==========

/// Extension to add convenience methods for AccessibilityService
extension AccessibilityServiceHelpers on AccessibilityService {
  /// Stream only specific event types
  Stream<Map<String, dynamic>> filterEvents(List<String> eventTypes) {
    return securityEventStream?.where((event) {
      final type = event['type'] as String?;
      return type != null && eventTypes.contains(type);
    }) ?? const Stream.empty();
  }
  
  /// Stream only wrong password events
  Stream<Map<String, dynamic>> get wrongPasswordStream {
    return filterEvents(['wrong_password']);
  }
  
  /// Stream only intruder detected events
  Stream<Map<String, dynamic>> get intruderStream {
    return filterEvents(['intruder_detected']);
  }
  
  /// Stream only lock screen events
  Stream<Map<String, dynamic>> get lockScreenStream {
    return filterEvents(['lock_screen']);
  }
  
  /// Wait for service to be enabled (with timeout)
  Future<bool> waitForEnabled({Duration timeout = const Duration(seconds: 30)}) async {
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < timeout) {
      if (await checkServiceEnabled()) {
        return true;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }
}

// ========== Event Type Constants ==========

/// Constants for security event types (for type-safe filtering)
abstract final class SecurityEventType {
  static const String wrongPassword = 'wrong_password';
  static const String intruderDetected = 'intruder_detected';
  static const String lockScreen = 'lock_screen';
  static const String passwordFieldFocused = 'password_field_focused';
  static const String suspiciousActivity = 'suspicious_activity';
  static const String autoTypeComplete = 'auto_type_complete';
  static const String autoTypeError = 'auto_type_error';
}
