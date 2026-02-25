// lib/services/email_service.dart
// Z.A.R.A. — Autonomous SMTP Security Transmitter
// ✅ Background Delivery (Zero UI Block) • Sci-Fi HTML Template
// ✅ Photo + GPS Payload Sync • Real-Time Trusted Contact Sync

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // ========== Z.A.R.A. Neural Network Credentials ==========
  // Hardcoded for autonomous background execution without user login
  final String _zaraEmail = 'zaraaiassistent@gmail.com';
  final String _appPassword = 'lkrp kaow uftr gtic'.replaceAll(' ', '');

  // ========== Tactical Contacts ==========
  static const List<String> _defaultEmails = ['bgmilover8730@gmail.com', 'rootv9321@gmail.com'];
  static const String _keyTrustedEmails = 'zara_trusted_emails';
  List<String> _trustedEmails = [];
  bool _emailsLoaded = false;

  // ========== Boot Protocol ==========
  Future<void> initialize() async {
    if (_emailsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_keyTrustedEmails);
      
      // Merge defaults with saved without duplicates
      final Set<String> merged = {};
      merged.addAll(_defaultEmails);
      if (saved != null) merged.addAll(saved);
      
      _trustedEmails = merged.toList();
      _emailsLoaded = true;
      if (kDebugMode) debugPrint('📧 SMTP Uplink: Ready with ${_trustedEmails.length} secure contacts.');
    } catch (e) {
      _trustedEmails = List.from(_defaultEmails);
      _emailsLoaded = true;
      debugPrint('⚠️ SMTP Initialization Error: $e');
    }
  }

  // ========== THE CORE TRANSMITTER (Background Safe) ==========

  Future<bool> sendSecurityAlert({
    required String alertType,
    required String message,
    String? photoPath,
    String? locationUrl,
    String? addressText,
  }) async {
    await initialize();

    if (_trustedEmails.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ TRANSMISSION FAILED: No trusted contacts.');
      return false;
    }

    try {
      if (kDebugMode) debugPrint('📧 Compiling Tactical Threat Report...');

      final smtpServer = gmail(_zaraEmail, _appPassword);
      final mail = Message()
        ..from = Address(_zaraEmail, 'Z.A.R.A. GUARDIAN SYSTEM')
        ..recipients.addAll(_trustedEmails)
        ..subject = '🚨 Z.A.R.A. THREAT REPORT: $alertType'
        ..html = _buildSciFiEmailTemplate(alertType, message, locationUrl, addressText);

      // Attach Optical Data (Intruder Photo)
      if (photoPath != null) {
        final file = File(photoPath);
        if (await file.exists()) {
          mail.attachments.add(FileAttachment(file));
        } else {
          debugPrint('⚠️ Attachment missing at: $photoPath');
        }
      }

      // Fire the email in background
      final sendReport = await send(mail, smtpServer);
      if (kDebugMode) debugPrint('✅ REPORT SENT: ${sendReport.toString()}');
      return true;

    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ CRITICAL SMTP FAILURE: $e');
      return false;
    }
  }

  // ========== HTML MATRIX TEMPLATE ==========
  
  String _buildSciFiEmailTemplate(String type, String msg, String? locUrl, String? locText) {
    return '''
    <div style="background-color: #050816; color: #00F5FF; font-family: 'Courier New', monospace; padding: 40px; border: 2px solid #FF003C; border-radius: 12px; max-width: 600px; margin: auto;">
      <h2 style="color: #FF003C; letter-spacing: 2px; text-align: center; border-bottom: 1px solid #FF003C; padding-bottom: 10px;">
        ⚠️ GUARDIAN PROTOCOL TRIGGERED
      </h2>
      <p style="color: #FFFFFF; font-size: 16px;"><strong>INCIDENT:</strong> <span style="color: #FF003C;">$type</span></p>
      <p style="color: #FFFFFF; font-size: 15px;"><strong>DETAILS:</strong> $msg</p>
      
      ${locUrl != null ? '''
      <div style="background-color: #0A1128; padding: 15px; border-left: 4px solid #00F5FF; margin-top: 20px;">
        <p style="margin: 0; color: #00F5FF;"><strong>📍 LIVE SATELLITE TRACKING:</strong></p>
        <p style="color: #FFFFFF; margin-top: 5px;">${locText ?? 'GPS Coordinates Locked'}</p>
        <a href="$locUrl" style="display: inline-block; margin-top: 10px; padding: 10px 20px; background-color: #FF003C; color: #FFFFFF; text-decoration: none; font-weight: bold; border-radius: 5px;">
          OPEN IN GOOGLE MAPS
        </a>
      </div>
      ''' : ''}
      
      <div style="margin-top: 30px; border-top: 1px dashed #00F5FF; padding-top: 20px;">
        <p style="font-size: 12px; color: #888; text-align: center;">
          TIMESTAMP: ${DateTime.now().toIso8601String()}<br>
          TRANSMITTED BY Z.A.R.A. AUTONOMOUS ENGINE
        </p>
      </div>
    </div>
    ''';
  }

  // ========== BRIDGES FOR OTHER SERVICES ==========

  Future<bool> sendIntruderAlert({
    required String photoPath,
    String? locationLink,
    String? address,
    String? customMessage,
  }) async {
    return await sendSecurityAlert(
      alertType: 'UNAUTHORIZED ACCESS (INTRUDER)',
      message: customMessage ?? 'System integrity compromised. Unknown biological entity detected interacting with the device.',
      photoPath: photoPath,
      locationUrl: locationLink,
      addressText: address,
    );
  }

  // ========== CONTACTS MANAGEMENT ==========

  List<String> get trustedEmails => List.unmodifiable(_trustedEmails);

  bool _isValidEmail(String email) => RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);

  Future<bool> addTrustedEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail) || _trustedEmails.contains(cleanEmail)) return false;
    
    _trustedEmails.add(cleanEmail);
    await _saveTrustedEmails();
    return true;
  }

  Future<bool> removeTrustedEmail(String email) async {
    final removed = _trustedEmails.remove(email.trim().toLowerCase());
    if (removed) await _saveTrustedEmails();
    return removed;
  }

  Future<void> _saveTrustedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyTrustedEmails, _trustedEmails);
  }
}
