// lib/core/constants/api_keys.dart
// Z.A.R.A. — API Keys Configuration with SharedPreferences
// ✅ NO HARDCODED KEYS • All via Settings Screen • Persists After Restart
// ✅ API Routing: Qwen=Code, Gemini=Voice/Search/Files, Llama=Emotional Chat

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API key management for Z.A.R.A.
/// All keys stored securely in SharedPreferences — never in code!
class ApiKeys {
  // ========== Internal Storage (Loaded from SharedPreferences) ==========
  
  /// Google Gemini API Key — Voice TTS/STT, Search, Image/PDF/Video Analysis
  static String _gemini = '';
  
  /// Qwen API Key — Code Generation (Primary)
  static String _qwen = '';
  
  /// LLAMA API Key — Emotional Conversations (Love, Angry, Ziddi, etc.)
  static String _llama = '';
  
  /// Voice Name for TTS (Google Neural Voices)
  /// Options: hi-IN-SwaraNeural, hi-IN-MadhurNeural, en-US-JennyNeural, etc.
  static String _voiceName = 'hi-IN-SwaraNeural';
  
  /// Language Code for Voice/STT
  static String _languageCode = 'hi-IN';

  // ========== SharedPreferences Keys (Internal Use Only) ==========
  
  static const String _keyGemini = 'zara_gemini_key';
  static const String _keyQwen = 'zara_qwen_key';
  static const String _keyLlama = 'zara_llama_key';
  static const String _keyVoice = 'zara_voice';
  static const String _keyLanguage = 'zara_language';
  static const String _keyInit = 'zara_init';

  // ========== Public Getters (Read-Only — Use saveApiKey() to change) ==========
  
  /// Get Gemini API key (for Voice, Search, File Analysis)
  static String get gemini => _gemini;
  
  /// Get Qwen API key (for Code Generation)
  static String get qwen => _qwen;
  
  /// Get LLAMA API key (for Emotional Conversations)
  static String get llama => _llama;
  
  /// Get selected voice name for TTS
  static String get voiceName => _voiceName;
  
  /// Get selected language code
  static String get languageCode => _languageCode;

  // ========== Initialize (Call in main.dart on app startup) ==========
  
  /// Load all API keys from SharedPreferences
  /// Returns true if at least one key was previously saved
  static Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load API keys
      _gemini = prefs.getString(_keyGemini) ?? '';
      _qwen = prefs.getString(_keyQwen) ?? '';
      _llama = prefs.getString(_keyLlama) ?? '';
      
      // Load voice/language settings
      _voiceName = prefs.getString(_keyVoice) ?? 'hi-IN-SwaraNeural';
      _languageCode = prefs.getString(_keyLanguage) ?? 'hi-IN';
      
      // Debug logging (removed in production builds)
      if (kDebugMode) {
        debugPrint('🔐 Z.A.R.A. API Keys Loaded:');
        debugPrint('  Gemini: ${_isValid(_gemini) ? "✓ Configured" : "✗ Missing"}');
        debugPrint('  Qwen: ${_isValid(_qwen) ? "✓ Configured" : "✗ Missing"}');
        debugPrint('  Llama: ${_isValid(_llama) ? "✓ Configured" : "✗ Missing"}');
        debugPrint('  Voice: $_voiceName ($_languageCode)');
      }
      
      return prefs.getBool(_keyInit) ?? false;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ API Init Error: $e');
      return false;
    }
  }

  // ========== Save API Key (Called from Settings Screen) ==========
  
  /// Save a single API key or setting to SharedPreferences
  /// [type]: 'gemini', 'qwen', 'llama', 'voice', or 'language'
  /// [value]: The new value to save
  static Future<bool> saveApiKey(String type, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      switch (type.toLowerCase()) {
        case 'gemini':
          _gemini = value;
          await prefs.setString(_keyGemini, value);
          break;
        case 'qwen':
          _qwen = value;
          await prefs.setString(_keyQwen, value);
          break;
        case 'llama':
          _llama = value;
          await prefs.setString(_keyLlama, value);
          break;
        case 'voice':
          _voiceName = value;
          await prefs.setString(_keyVoice, value);
          break;
        case 'language':
          _languageCode = value;
          await prefs.setString(_keyLanguage, value);
          break;
        default:
          if (kDebugMode) debugPrint('⚠️ Unknown key type: $type');
          return false;
      }
      
      // Mark as initialized
      await prefs.setBool(_keyInit, true);
      
      if (kDebugMode) debugPrint('💾 API Key Saved: $type');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Save Error [$type]: $e');
      return false;
    }
  }

  // ========== Save All Keys at Once (Bulk Update) ==========
  
  /// Save all API keys and settings in one operation
  static Future<bool> saveAll({
    required String gemini,
    required String qwen,
    required String llama,
    required String voice,
    required String language,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Update internal state
      _gemini = gemini;
      _qwen = qwen;
      _llama = llama;
      _voiceName = voice;
      _languageCode = language;
      
      // Save to SharedPreferences
      await prefs.setString(_keyGemini, gemini);
      await prefs.setString(_keyQwen, qwen);
      await prefs.setString(_keyLlama, llama);
      await prefs.setString(_keyVoice, voice);
      await prefs.setString(_keyLanguage, language);
      await prefs.setBool(_keyInit, true);
      
      if (kDebugMode) debugPrint('💾 All API Keys Saved');
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Save All Error: $e');
      return false;
    }
  }

  // ========== Validation Helpers ==========
  
  /// Check if an API key looks valid (basic heuristic)
  static bool _isValid(String key) {
    return key.isNotEmpty && 
           key.length > 20 && 
           !key.contains('your_') &&
           !key.contains('paste_') &&
           !key.contains('xxxxx');
  }

  /// Check if all three AI APIs are configured
  static bool get isConfigured {
    return _isValid(_gemini) && 
           _isValid(_qwen) && 
           _isValid(_llama);
  }

  /// Get status map for each API key
  static Map<String, bool> get status {
    return {
      'gemini': _isValid(_gemini),
      'qwen': _isValid(_qwen),
      'llama': _isValid(_llama),
      'all': isConfigured,
    };
  }

  /// Get list of missing/unconfigured API keys
  static List<String> get missing {
    final list = <String>[];
    if (!_isValid(_gemini)) list.add('Gemini');
    if (!_isValid(_qwen)) list.add('Qwen');
    if (!_isValid(_llama)) list.add('Llama');
    return list;
  }

  // ========== Clear/Reset Functionality ==========
  
  /// Clear all stored API keys and reset to defaults
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove from SharedPreferences
      await prefs.remove(_keyGemini);
      await prefs.remove(_keyQwen);
      await prefs.remove(_keyLlama);
      await prefs.remove(_keyVoice);
      await prefs.remove(_keyLanguage);
      
      // Reset internal state to defaults
      _gemini = '';
      _qwen = '';
      _llama = '';
      _voiceName = 'hi-IN-SwaraNeural';
      _languageCode = 'hi-IN';
      
      if (kDebugMode) debugPrint('🗑️ All API Keys Cleared — Reset to defaults');
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Clear All Error: $e');
    }
  }

  // ========== API Routing Configuration (For Other Services) ==========
  
  /// Which API to use for Code Generation
  static String get codeGenerationApi => 'qwen';
  
  /// Which API to use for Natural/Emotional Conversations
  static String get conversationApi => 'llama';
  
  /// Which API to use for Voice (TTS/STT)
  static String get voiceApi => 'gemini';
  
  /// Which API to use for File Analysis (Image, PDF, Video)
  static String get fileAnalysisApi => 'gemini';
  
  /// Which API to use for Realtime Search
  static String get searchApi => 'gemini';

  // ========== Export/Import for Backup (Advanced) ==========
  
  /// Export all keys to a map (for backup — use securely!)
  static Map<String, String> exportKeys() {
    return {
      'gemini': _gemini,
      'qwen': _qwen,
      'llama': _llama,
      'voice': _voiceName,
      'language': _languageCode,
    };
  }

  /// Import keys from a map (for restore — validate first!)
  static Future<bool> importKeys(Map<String, String> keys) async {
    if (keys.containsKey('gemini')) await saveApiKey('gemini', keys['gemini']!);
    if (keys.containsKey('qwen')) await saveApiKey('qwen', keys['qwen']!);
    if (keys.containsKey('llama')) await saveApiKey('llama', keys['llama']!);
    if (keys.containsKey('voice')) await saveApiKey('voice', keys['voice']!);
    if (keys.containsKey('language')) await saveApiKey('language', keys['language']!);
    return true;
  }
}
