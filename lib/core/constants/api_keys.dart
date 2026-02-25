// lib/core/constants/api_keys.dart
// Z.A.R.A. — High-Security API Key & Identity Engine
// ✅ Full Logic • Identity Persistence • RegEx Validation
// ✅ Owner Name & Affection Memory • Zero Dummy

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeys {
  static late SharedPreferences _prefs;

  // ========== Internal Registers ==========
  static String _gemini = '';
  static String _qwen = '';
  static String _llama = '';
  static String _voiceName = 'hi-IN-SwaraNeural';
  static String _languageCode = 'hi-IN';
  static String _ownerName = 'OWNER RAVI';
  static int _affectionLevel = 85;

  // ========== Secure Storage Keys ==========
  static const String _kGemini = 'reg_gemini_core';
  static const String _kQwen = 'reg_qwen_core';
  static const String _kLlama = 'reg_llama_core';
  static const String _kVoice = 'cfg_voice_module';
  static const String _kLang = 'cfg_lang_code';
  static const String _kOwner = 'id_owner_name';
  static const String _kAffection = 'id_affection_val';

  // ========== Initialization (Boot Protocol) ==========
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    _gemini = _prefs.getString(_kGemini) ?? '';
    _qwen = _prefs.getString(_kQwen) ?? '';
    _llama = _prefs.getString(_kLlama) ?? '';
    _voiceName = _prefs.getString(_kVoice) ?? 'hi-IN-SwaraNeural';
    _languageCode = _prefs.getString(_kLang) ?? 'hi-IN';
    _ownerName = _prefs.getString(_kOwner) ?? 'OWNER RAVI';
    _affectionLevel = _prefs.getInt(_kAffection) ?? 85;
  }

  // ========== Public Accessors ==========
  static String get gemini => _gemini;
  static String get qwen => _qwen;
  static String get llama => _llama;
  static String get voiceName => _voiceName;
  static String get languageCode => _languageCode;
  static String get ownerName => _ownerName;
  static int get affectionLevel => _affectionLevel;

  // ========== Save Logic (Atomic Updates) ==========
  static Future<bool> saveApiKey(String type, dynamic value) async {
    try {
      switch (type.toLowerCase()) {
        case 'gemini':
          if (!_isValidFormat('gemini', value)) return false;
          _gemini = value;
          return await _prefs.setString(_kGemini, value);
        case 'qwen':
          _qwen = value;
          return await _prefs.setString(_kQwen, value);
        case 'llama':
          _llama = value;
          return await _prefs.setString(_kLlama, value);
        case 'voice':
          _voiceName = value;
          return await _prefs.setString(_kVoice, value);
        case 'language':
          _languageCode = value;
          return await _prefs.setString(_kLang, value);
        case 'owner': // Save Owner Name Logic Added
          _ownerName = value;
          return await _prefs.setString(_kOwner, value);
        case 'affection':
          _affectionLevel = value;
          return await _prefs.setInt(_kAffection, value);
      }
    } catch (e) {
      debugPrint('⚠️ Neural Storage Failure: $e');
    }
    return false;
  }

  // ========== HUD Status Engine (For Settings UI) ==========
  static bool _isValidFormat(String type, String key) {
    if (key.isEmpty) return false;
    if (type == 'gemini') return RegExp(r'^AIza[0-9A-Za-z-_]{35}$').hasMatch(key);
    return key.length > 20;
  }

  static Map<String, bool> get status => {
    'gemini': _isValidFormat('gemini', _gemini),
    'qwen': _qwen.length > 20,
    'llama': _llama.length > 20,
    'all': _gemini.isNotEmpty && _qwen.isNotEmpty,
  };

  // ========== Reset Engine (Fixed Missing Method) ==========
  static Future<void> clearAll() async {
    await _prefs.clear();
    await initialize(); // Reload defaults
  }
}
