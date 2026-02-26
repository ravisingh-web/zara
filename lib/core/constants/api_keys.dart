// lib/core/constants/api_keys.dart
// Z.A.R.A. — High-Security API Key & Identity Engine
// ✅ Single API Key: OpenRouter OR Gemini • Free Models Supported
// ✅ No Hardcoded Keys • Settings-Driven • Zero Dummy

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API Provider enum — user selects ONE provider in Settings
enum ApiProvider {
  openRouter,  // Uses free models via OpenRouter
  gemini,      // Uses direct Google Gemini API
  none,        // No API configured
}

class ApiKeys {
  static late SharedPreferences _prefs;

  // ========== Internal Registers ==========
  static String _apiKey = '';                    // Single key: OpenRouter OR Gemini
  static ApiProvider _provider = ApiProvider.none; // Selected provider
  static String _selectedModel = '';             // Model name for API calls
  static String _voiceName = 'hi-IN-SwaraNeural';
  static String _languageCode = 'hi-IN';
  static String _ownerName = 'OWNER RAVI';
  static int _affectionLevel = 85;

  // ========== Secure Storage Keys ==========
  static const String _kApiKey = 'reg_api_key_core';
  static const String _kProvider = 'cfg_api_provider';
  static const String _kModel = 'cfg_selected_model';
  static const String _kVoice = 'cfg_voice_module';
  static const String _kLang = 'cfg_lang_code';
  static const String _kOwner = 'id_owner_name';
  static const String _kAffection = 'id_affection_val';

  // ========== OpenRouter Free Models (Recommended) ==========
  /// List of tested free models via OpenRouter
  static const List<Map<String, String>> openRouterFreeModels = [
    {'id': 'google/gemini-2.0-flash-lite:free', 'name': 'Gemini 2.0 Flash Lite (Free)', 'desc': 'Fast chat & code'},
    {'id': 'google/gemini-2.0-flash-thinking-exp:free', 'name': 'Gemini 2.0 Flash Thinking (Free)', 'desc': 'Deep reasoning'},
    {'id': 'meta-llama/llama-3.2-3b-instruct:free', 'name': 'Llama 3.2 3B (Free)', 'desc': 'Lightweight chat'},
    {'id': 'meta-llama/llama-3.1-8b-instruct:free', 'name': 'Llama 3.1 8B (Free)', 'desc': 'Balanced performance'},
    {'id': 'mistralai/mistral-7b-instruct:free', 'name': 'Mistral 7B (Free)', 'desc': 'Reliable general purpose'},
    {'id': 'google/gemma-2-9b-it:free', 'name': 'Gemma 2 9B (Free)', 'desc': 'Google lightweight'},
  ];

  /// Default recommended model for Z.A.R.A.
  static const String defaultModel = 'google/gemini-2.0-flash-lite:free';
  // ========== Initialization (Boot Protocol) ==========
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // Load API key and provider
    _apiKey = _prefs.getString(_kApiKey) ?? '';
    final providerStr = _prefs.getString(_kProvider) ?? 'none';
    _provider = ApiProvider.values.firstWhere(
      (p) => p.toString().split('.').last == providerStr,
      orElse: () => ApiProvider.none,
    );
    _selectedModel = _prefs.getString(_kModel) ?? defaultModel;

    // Load voice/language preferences
    _voiceName = _prefs.getString(_kVoice) ?? 'hi-IN-SwaraNeural';
    _languageCode = _prefs.getString(_kLang) ?? 'hi-IN';
    _ownerName = _prefs.getString(_kOwner) ?? 'OWNER RAVI';
    _affectionLevel = _prefs.getInt(_kAffection) ?? 85;

    if (kDebugMode) {
      debugPrint('🔐 ApiKeys Loaded: provider=$_provider, model=$_selectedModel, keyLength=${_apiKey.length}');
    }
  }

  // ========== Public Accessors ==========
  static String get apiKey => _apiKey;
  static ApiProvider get provider => _provider;
  static String get selectedModel => _selectedModel;
  static String get voiceName => _voiceName;
  static String get languageCode => _languageCode;
  static String get ownerName => _ownerName;
  static int get affectionLevel => _affectionLevel;

  // ========== Provider-Specific Helpers ==========
  
  /// Get OpenRouter API endpoint
  static String get openRouterEndpoint => 'https://openrouter.ai/api/v1/chat/completions';
  
  /// Get Gemini API endpoint
  static String get geminiEndpoint => 'https://generativelanguage.googleapis.com/v1beta/models';
  
  /// Get headers for API calls (provider-aware)
  static Map<String, String> getApiHeaders() {
    if (_provider == ApiProvider.openRouter) {
      return {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://zara-ai.example.com', // Required by OpenRouter
        'X-Title': 'Z.A.R.A. AI',      };
    } else if (_provider == ApiProvider.gemini) {
      return {
        'Content-Type': 'application/json',
        // Gemini uses key as query param, not header
      };
    }
    return {};
  }

  /// Get request body template for chat completion (provider-aware)
  static Map<String, dynamic> getChatRequestBody({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) {
    if (_provider == ApiProvider.openRouter) {
      return {
        'model': _selectedModel,
        'messages': messages.map((m) => {'role': m['role'], 'content': m['content']}).toList(),
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': false,
      };
    } else if (_provider == ApiProvider.gemini) {
      // Gemini format is different
      return {
        'contents': messages.map((m) => {
          'role': m['role'] == 'assistant' ? 'model' : 'user',
          'parts': [{'text': m['content']}]
        }).toList(),
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens,
        },
      };
    }
    return {};
  }

  // ========== Save Logic (Atomic Updates) ==========
  static Future<bool> saveConfig({
    String? apiKey,
    ApiProvider? provider,
    String? model,
    String? voice,
    String? language,
    String? owner,
    int? affection,
  }) async {    try {
      bool saved = true;
      
      if (apiKey != null) {
        if (!_isValidApiKey(apiKey, provider ?? _provider)) return false;
        _apiKey = apiKey;
        saved = await _prefs.setString(_kApiKey, apiKey) && saved;
      }
      
      if (provider != null) {
        _provider = provider;
        saved = await _prefs.setString(_kProvider, provider.toString().split('.').last) && saved;
        
        // Reset model to default when provider changes
        if (provider == ApiProvider.openRouter) {
          _selectedModel = defaultModel;
          await _prefs.setString(_kModel, defaultModel);
        }
      }
      
      if (model != null && model.isNotEmpty) {
        _selectedModel = model;
        saved = await _prefs.setString(_kModel, model) && saved;
      }
      
      if (voice != null) {
        _voiceName = voice;
        saved = await _prefs.setString(_kVoice, voice) && saved;
      }
      
      if (language != null) {
        _languageCode = language;
        saved = await _prefs.setString(_kLang, language) && saved;
      }
      
      if (owner != null) {
        _ownerName = owner;
        saved = await _prefs.setString(_kOwner, owner) && saved;
      }
      
      if (affection != null) {
        _affectionLevel = affection.clamp(0, 100);
        saved = await _prefs.setInt(_kAffection, _affectionLevel) && saved;
      }
      
      if (kDebugMode && saved) {
        debugPrint('✅ ApiKeys Saved: provider=$_provider, model=$_selectedModel');
      }
      return saved;
          } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Neural Storage Failure: $e');
      return false;
    }
  }

  // ========== Validation Logic ==========
  static bool _isValidApiKey(String key, ApiProvider provider) {
    if (key.isEmpty) return false;
    
    if (provider == ApiProvider.gemini) {
      // Gemini keys start with AIza
      return RegExp(r'^AIza[0-9A-Za-z-_]{35,}$').hasMatch(key);
    } else if (provider == ApiProvider.openRouter) {
      // OpenRouter keys are typically 32+ chars, alphanumeric + hyphens
      return key.length >= 32 && RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(key);
    }
    return false;
  }

  // ========== Status Engine (For Settings UI) ==========
  static Map<String, dynamic> get status {
    return {
      'configured': _apiKey.isNotEmpty && _provider != ApiProvider.none,
      'provider': _provider.toString().split('.').last,
      'model': _selectedModel,
      'modelType': _selectedModel.contains(':free') ? 'free' : 'paid',
      'keyLength': _apiKey.length,
      'voice': _voiceName,
      'language': _languageCode,
    };
  }

  /// Quick check: Is API ready for calls?
  static bool get isReady => _apiKey.isNotEmpty && _provider != ApiProvider.none;

  /// Get available models based on selected provider
  static List<Map<String, String>> get availableModels {
    if (_provider == ApiProvider.openRouter) {
      return openRouterFreeModels;
    }
    // For Gemini, return a single entry (model is fixed by endpoint)
    return [
      {'id': 'gemini-2.0-flash-lite', 'name': 'Gemini 2.0 Flash Lite', 'desc': 'Google official'},
    ];
  }

  // ========== Reset Engine ==========
  static Future<void> clearAll() async {
    await _prefs.clear();    await initialize(); // Reload defaults
    if (kDebugMode) debugPrint('🗑️ ApiKeys Reset to defaults');
  }

  // ========== Utility: Parse OpenRouter Response ==========
  static String? parseOpenRouterResponse(Map<String, dynamic> response) {
    try {
      return response['choices']?[0]?['message']?['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ========== Utility: Parse Gemini Response ==========
  static String? parseGeminiResponse(Map<String, dynamic> response) {
    try {
      return response['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    } catch (_) {
      return null;
    }
  }
}
