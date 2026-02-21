// lib/services/email_service.dart
// Z.A.R.A. — REAL Email Service for Security Alerts
// Send Intruder Photos via Email • No Fake Stuff

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // Default trusted emails (Sir can customize)
  List<String> _trustedEmails = [
    'bgmilover8730@gmail.com',
    'rootv9321@gmail.com',
  ];

  /// Add trusted email
  Future<void> addTrustedEmail(String email) async {
    if (!_trustedEmails.contains(email)) {
      _trustedEmails.add(email);
      await _saveTrustedEmails();
      debugPrint('📧 Trusted email added: $email');
    }
  }

  /// Remove trusted email
  Future<void> removeTrustedEmail(String email) async {
    _trustedEmails.remove(email);
    await _saveTrustedEmails();
    debugPrint('📧 Trusted email removed: $email');
  }

  /// Get all trusted emails
  List<String> get trustedEmails => List.unmodifiable(_trustedEmails);

  /// Save trusted emails to SharedPreferences
  Future<void> _saveTrustedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trusted_emails', _trustedEmails);
  }

  /// Load trusted emails from SharedPreferences
  Future<void> loadTrustedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('trusted_emails');
    if (saved != null && saved.isNotEmpty) {
      _trustedEmails = saved;
    }
  }

  /// Send intruder alert email (opens default email app)
  Future<bool> sendIntruderAlert({
    required String photoPath,
    String? customMessage,
    List<String>? additionalEmails,
  }) async {
    try {
      // Combine trusted + additional emails
      final recipients = [..._trustedEmails, ...?additionalEmails];
      
      if (recipients.isEmpty) {
        debugPrint('⚠️ No recipients for email alert');
        return false;
      }

      // Create email content
      final timestamp = DateTime.now();
      final subject = '🚨 Z.A.R.A. Intruder Alert - ${timestamp.toString()}';
      final body = customMessage ?? '''
🚨 SECURITY ALERT 🚨

Z.A.R.A. Guardian Mode detected unauthorized access.

📸 Intruder Photo: Attached
📍 Time: ${timestamp.toString()}
📱 Device: ${Platform.isAndroid ? 'Android' : 'iOS'}

This is an automated alert from Z.A.R.A. (Zenith Autonomous Reasoning Array).

Please check your device immediately.

---
Z.A.R.A. Security System
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
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        debugPrint('📧 Email app opened with intruder alert');
        return true;
      } else {
        debugPrint('⚠️ Cannot launch email app');
        return false;
      }

    } catch (e) {
      debugPrint('⚠️ Email send error: $e');
      return false;
    }
  }

  /// Send location alert email
  Future<bool> sendLocationAlert({
    required String locationLink,
    String? address,
  }) async {
    try {
      final recipients = _trustedEmails;
      final timestamp = DateTime.now();
      
      final subject = '📍 Z.A.R.A. Location Alert - ${timestamp.toString()}';
      final body = '''
📍 LOCATION ALERT 📍

Z.A.R.A. Guardian Mode - Device Location Update

🗺️ Google Maps: $locationLink
🏠 Address: ${address ?? 'Unavailable'}
📱 Time: ${timestamp.toString()}

---
Z.A.R.A. Security System
''';

      final emailUri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        debugPrint('📧 Location alert email sent');
        return true;
      }
      
      return false;

    } catch (e) {
      debugPrint('⚠️ Location email error: $e');
      return false;
    }
  }

  /// Send general security alert
  Future<bool> sendSecurityAlert({
    required String alertType,
    required String message,
  }) async {
    try {
      final recipients = _trustedEmails;
      final timestamp = DateTime.now();
      
      final subject = '⚠️ Z.A.R.A. Security Alert: $alertType';
      final body = '''
⚠️ SECURITY ALERT: $alertType

$message

📱 Time: ${timestamp.toString()}
🤖 Z.A.R.A. Guardian Mode

---
Z.A.R.A. Security System
''';

      final emailUri = Uri(
        scheme: 'mailto',
        path: recipients.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        return true;
      }
      
      return false;

    } catch (e) {
      debugPrint('⚠️ Security email error: $e');
      return false;
    }
  }
}
