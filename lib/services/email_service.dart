// lib/services/email_service.dart
// Z.A.R.A. — Email Service for Security Alerts
// ✅ Intruder Photos • Location Alerts • Trusted Contacts • SharedPreferences
// ✅ url_launcher Integration • Production-Ready • Error Handling

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Email Service for Z.A.R.A. Guardian Mode
/// 
/// Sends security alerts to trusted contacts via default email app:
/// - Intruder alerts with photo path and timestamp
/// - Location alerts with Google Maps link
/// - General security alerts with custom messages
/// 
/// Features:
/// - Trusted email management with SharedPreferences persistence
/// - mailto: URI scheme for cross-platform compatibility
/// - Customizable email templates with Z.A.R.A. branding
/// 
/// ⚠️ Note: Opens default email app — user must tap "Send" manually
/// (Android security restrictions prevent auto-sending)
class EmailService {
  // ========== Singleton Pattern ==========
  
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // ========== Trusted Email Management ==========
  
  /// Default trusted emails for security alerts (Sir can customize)
  static const List<String> _defaultEmails = [
    'bgmilover8730@gmail.com',
    'rootv9321@gmail.com',
  ];
  
  /// SharedPreferences key for trusted emails list
  static const String _keyTrustedEmails = 'zara_trusted_emails';
  
  /// In-memory cache of trusted emails
  List<String> _trustedEmails = [];
  
  /// Whether trusted emails have been loaded from storage
  bool _emailsLoaded = false;

  // ========== Initialization ==========
  
  /// Load trusted emails from SharedPreferences
  /// Call once at app startup after Provider setup
  Future<void> initialize() async {
    if (_emailsLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_keyTrustedEmails);
      
      if (saved != null && saved.isNotEmpty) {
        _trustedEmails = saved;
      } else {
        // Use defaults if no saved emails
        _trustedEmails = List.from(_defaultEmails);
      }
      
      _emailsLoaded = true;
      
      if (kDebugMode) {
        debugPrint('📧 Email Service Initialized');
        debugPrint('  • Trusted emails: ${_trustedEmails.length}');
        for (final email in _trustedEmails) {
          debugPrint('    - $email');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Email Service init error: $e');
      }
      // Fallback to defaults
      _trustedEmails = List.from(_defaultEmails);
      _emailsLoaded = true;
    }
  }

  // ========== Trusted Email CRUD ==========
  
  /// Add a new trusted email address
  /// 
  /// [email]: Email address to add (basic validation applied)
  /// [saveImmediately]: Whether to persist to SharedPreferences now (default: true)
  /// 
  /// Returns: true if added successfully, false if duplicate or invalid
  Future<bool> addTrustedEmail(String email, {bool saveImmediately = true}) async {
    // Basic email validation
    if (!_isValidEmail(email)) {
      if (kDebugMode) debugPrint('⚠️ Invalid email format: $email');
      return false;
    }
    
    // Check for duplicates (case-insensitive)
    if (_trustedEmails.any((e) => e.toLowerCase() == email.toLowerCase())) {
      if (kDebugMode) debugPrint('⚠️ Email already trusted: $email');
      return false;
    }
    
    _trustedEmails.add(email);
    
    if (saveImmediately) {
      await _saveTrustedEmails();
    }
    
    if (kDebugMode) {
      debugPrint('📧 Trusted email added: $email');
      debugPrint('  • Total trusted: ${_trustedEmails.length}');
    }
    
    return true;
  }

  /// Remove a trusted email address
  /// 
  /// [email]: Email address to remove (case-insensitive match)
  /// [saveImmediately]: Whether to persist to SharedPreferences now (default: true)
  /// 
  /// Returns: true if removed, false if not found
  Future<bool> removeTrustedEmail(String email, {bool saveImmediately = true}) async {
    final removed = _trustedEmails.removeWhere(
      (e) => e.toLowerCase() == email.toLowerCase(),
    );
    
    if (removed) {
      if (saveImmediately) {
        await _saveTrustedEmails();
      }
      
      if (kDebugMode) {
        debugPrint('📧 Trusted email removed: $email');
        debugPrint('  • Total trusted: ${_trustedEmails.length}');
      }
      return true;
    }
    
    if (kDebugMode) debugPrint('⚠️ Email not found in trusted list: $email');
    return false;
  }

  /// Get list of trusted emails (unmodifiable copy)
  List<String> get trustedEmails => List.unmodifiable(_trustedEmails);

  /// Reset to default trusted emails
  Future<void> resetToDefaults() async {
    _trustedEmails = List.from(_defaultEmails);
    await _saveTrustedEmails();
    
    if (kDebugMode) {
      debugPrint('🔄 Trusted emails reset to defaults');
      debugPrint('  • Defaults: $_defaultEmails');
    }
  }

  /// Clear all trusted emails (use with caution)
  Future<void> clearAllTrustedEmails() async {
    _trustedEmails.clear();
    await _saveTrustedEmails();
    
    if (kDebugMode) {
      debugPrint('🗑️ All trusted emails cleared');
    }
  }

  // ========== Persistence ==========
  
  /// Save trusted emails to SharedPreferences
  Future<void> _saveTrustedEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyTrustedEmails, _trustedEmails);
      
      if (kDebugMode) {
        debugPrint('💾 Trusted emails saved to SharedPreferences');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Save trusted emails error: $e');
      }
      rethrow;
    }
  }

  // ========== Email Validation ==========
  
  /// Basic email format validation
  bool _isValidEmail(String email) {
    // Simple regex for basic validation
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return emailRegex.hasMatch(email) && email.length <= 254;
  }

  // ========== Intruder Alert Email ==========
  
  /// Send intruder alert email with photo info
  /// 
  /// [photoPath]: Path to captured intruder photo (for reference in email)
  /// [customMessage]: Optional custom message to prepend to alert
  /// [additionalEmails]: Optional extra recipients beyond trusted list
  /// [includeDeviceInfo]: Whether to include device info in email (default: true)
  /// 
  /// Returns: true if email app opened successfully, false on error
  Future<bool> sendIntruderAlert({
    required String photoPath,
    String? customMessage,
    List<String>? additionalEmails,
    bool includeDeviceInfo = true,
  }) async {
    try {
      // Combine recipients
      final recipients = [
        ..._trustedEmails,
        ...?additionalEmails?.where(_isValidEmail),
      ].toSet().toList(); // Remove duplicates

      if (recipients.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ No valid recipients for intruder alert');
        }
        return false;
      }

      // Build email content
      final timestamp = DateTime.now();
      final subject = '🚨 Z.A.R.A. Intruder Alert — ${_formatTimestamp(timestamp)}';
      
      final deviceInfo = includeDeviceInfo
          ? '''
📱 Device: ${Platform.isAndroid ? 'Android' : 'iOS'}
🔋 Battery: [Check device]
📶 Network: [Check device]
'''
          : '';

      final body = '''
${customMessage != null ? '$customMessage\n\n' : ''}🚨 SECURITY ALERT 🚨

Z.A.R.A. Guardian Mode detected unauthorized access attempt.

📸 Intruder Photo Captured
   Path: $photoPath
   Time: ${_formatTimestamp(timestamp)}

$deviceInfo
⚠️ ACTION REQUIRED:
   1. Check your device immediately
   2. Review the captured photo
   3. Change passwords if compromised
   4. Contact authorities if needed

---
🤖 Z.A.R.A. Security System
   Zenith Autonomous Reasoning Array
   This is an automated security alert.
''';

      // Create mailto URI
      final emailUri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      // Launch email app
      if (await canLaunchUrl(emailUri).catchError((_) => false)) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (kDebugMode) {
          debugPrint('📧 Intruder alert email opened');
          debugPrint('  • Recipients: ${recipients.length}');
          debugPrint('  • Subject: $subject');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Cannot launch email app — Check if email app is installed');
        }
        return false;
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Send intruder alert error: $e');
      }
      return false;
    }
  }

  // ========== Location Alert Email ==========
  
  /// Send location alert email with Google Maps link
  /// 
  /// [locationLink]: Google Maps URL for device location
  /// [address]: Human-readable address string (optional)
  /// [customMessage]: Optional custom message to prepend
  /// [additionalEmails]: Optional extra recipients
  /// 
  /// Returns: true if email app opened successfully, false on error
  Future<bool> sendLocationAlert({
    required String locationLink,
    String? address,
    String? customMessage,
    List<String>? additionalEmails,
  }) async {
    try {
      final recipients = [
        ..._trustedEmails,
        ...?additionalEmails?.where(_isValidEmail),
      ].toSet().toList();

      if (recipients.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ No valid recipients for location alert');
        return false;
      }

      final timestamp = DateTime.now();
      final subject = '📍 Z.A.R.A. Location Alert — ${_formatTimestamp(timestamp)}';
      
      final body = '''
${customMessage != null ? '$customMessage\n\n' : ''}📍 LOCATION ALERT 📍

Z.A.R.A. Guardian Mode — Device location update.

🗺️ View on Google Maps:
   $locationLink

🏠 Address: ${address ?? 'Unavailable'}
🕐 Time: ${_formatTimestamp(timestamp)}
📱 Device: ${Platform.isAndroid ? 'Android' : 'iOS'}

⚠️ If this location is unexpected:
   1. Check device security immediately
   2. Review recent activity
   3. Enable Guardian Mode if not active

---
🤖 Z.A.R.A. Security System
   Zenith Autonomous Reasoning Array
''';

      final emailUri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri).catchError((_) => false)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        
        if (kDebugMode) {
          debugPrint('📧 Location alert email opened');
          debugPrint('  • Location: $locationLink');
        }
        return true;
      }
      
      return false;

    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Send location alert error: $e');
      return false;
    }
  }

  // ========== General Security Alert ==========
  
  /// Send general security alert email
  /// 
  /// [alertType]: Type/category of alert (e.g., 'Permission Revoked', 'Overheating')
  /// [message]: Detailed alert message
  /// [severity]: Alert severity level ('low', 'medium', 'high', 'critical')
  /// [customMessage]: Optional custom prepend message
  /// [additionalEmails]: Optional extra recipients
  /// 
  /// Returns: true if email app opened successfully, false on error
  Future<bool> sendSecurityAlert({
    required String alertType,
    required String message,
    String severity = 'medium',
    String? customMessage,
    List<String>? additionalEmails,
  }) async {
    try {
      final recipients = [
        ..._trustedEmails,
        ...?additionalEmails?.where(_isValidEmail),
      ].toSet().toList();

      if (recipients.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ No valid recipients for security alert');
        return false;
      }

      // Severity indicator
      final severityIcon = switch (severity.toLowerCase()) {
        'critical' => '🔴',
        'high' => '🟠',
        'medium' => '🟡',
        'low' => '🟢',
        _ => '⚪',
      };

      final timestamp = DateTime.now();
      final subject = '$severityIcon Z.A.R.A. Alert: $alertType';
      
      final body = '''
${customMessage != null ? '$customMessage\n\n' : ''}$severityIcon SECURITY ALERT: $alertType

$message

🕐 Time: ${_formatTimestamp(timestamp)}
📱 Device: ${Platform.isAndroid ? 'Android' : 'iOS'}
🤖 Z.A.R.A. Guardian Mode Active

⚠️ Recommended Actions:
   • Review the alert details above
   • Check device security settings
   • Contact support if issue persists

---
🤖 Z.A.R.A. Security System
   Zenith Autonomous Reasoning Array
   Alert ID: ${_generateAlertId()}
''';

      final emailUri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri).catchError((_) => false)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        
        if (kDebugMode) {
          debugPrint('📧 Security alert email opened');
          debugPrint('  • Type: $alertType ($severity)');
        }
        return true;
      }
      
      return false;

    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Send security alert error: $e');
      return false;
    }
  }

  // ========== Utility Methods ==========
  
  /// Format timestamp for email display
  String _formatTimestamp(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Generate unique alert ID for tracking
  String _generateAlertId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ZARA-${timestamp.toString().substring(6)}-$random';
  }

  /// Check if email app is available on device
  Future<bool> isEmailAppAvailable() async {
    final testUri = Uri(scheme: 'mailto', path: 'test@example.com');
    return await canLaunchUrl(testUri);
  }

  /// Get count of trusted emails
  int get trustedEmailCount => _trustedEmails.length;

  /// Check if any trusted emails are configured
  bool get hasTrustedEmails => _trustedEmails.isNotEmpty;

  // ========== Lifecycle ==========
  
  /// Dispose service and clean up resources
  void dispose() {
    // No streams to close, but good practice for consistency
    if (kDebugMode) {
      debugPrint('📧 Email Service disposed');
    }
  }
}

// ========== Extension: Convenience Methods ==========

/// Extension to add convenience methods for EmailService
extension EmailServiceHelpers on EmailService {
  /// Quick send: Intruder alert with minimal parameters
  Future<bool> quickIntruderAlert(String photoPath) async {
    await initialize();
    return sendIntruderAlert(photoPath: photoPath);
  }
  
  /// Quick send: Location alert with minimal parameters
  Future<bool> quickLocationAlert(String locationLink) async {
    await initialize();
    return sendLocationAlert(locationLink: locationLink);
  }
  
  /// Add multiple trusted emails at once
  Future<int> addTrustedEmails(List<String> emails) async {
    await initialize();
    int added = 0;
    for (final email in emails) {
      if (await addTrustedEmail(email, saveImmediately: false)) {
        added++;
      }
    }
    await _saveTrustedEmails();
    return added;
  }
  
  /// Export trusted emails as JSON string (for backup)
  String exportTrustedEmails() {
    return trustedEmails.map((e) => '"$e"').join(',\n  ');
  }
}

// ========== Constants ==========

/// Email-related constants for Z.A.R.A.
abstract final class EmailConstants {
  /// Default subject prefix for security alerts
  static const String alertSubjectPrefix = '🚨 Z.A.R.A. Alert';
  
  /// Default signature for all Z.A.R.A. emails
  static const String emailSignature = '''
---
🤖 Z.A.R.A. Security System
   Zenith Autonomous Reasoning Array
   https://zara-ai.example.com
''';
  
  /// Maximum number of trusted emails allowed
  static const int maxTrustedEmails = 10;
  
  /// Minimum email address length for validation
  static const int minEmailLength = 5;
}
