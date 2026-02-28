// lib/core/constants/api_keys.dart
// Z.A.R.A. — API Key Manager (Clean + Real Models)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiProvider { openRouter, gemini, none }

class ApiKeys {
  static late SharedPreferences _prefs;
  
  // Separate keys for each provider
  static String _orKey = '';
  static String _gemKey = '';
  static ApiProvider _prov = ApiProvider.none;
  static String _model = '';
  static String _voice = 'hi-IN-SwaraNeural';
  static String _lang = 'hi-IN';
  static String _owner = 'OWNER RAVI';
  static int _aff = 85;

  // Storage keys
  static const _kOR = 'or_key';
  static const _kGem = 'gem_key';
  static const _kProv = 'provider';
  static const _kModel = 'model';
  static const _kVoice = 'voice';
  static const _kLang = 'lang';
  static const _kOwner = 'owner';
  static const _kAff = 'affection';

  // OpenRouter Free Models (YOUR REAL LIST)
  static const List<Map<String, String>> orModels = [
    {'id': 'google/gemma-3-4b-it:free', 'name': 'Gemma 3 4B IT', 'desc': 'Google latest free'},
    {'id': 'nousresearch/hermes-3-llama-3.1-405b:free', 'name': 'Hermes 3 Llama 405B', 'desc': 'High reasoning'},
    {'id': 'meta-llama/llama-3.2-3b-instruct:free', 'name': 'Llama 3.2 3B', 'desc': 'Lightweight'},
    {'id': 'meta-llama/llama-3.3-70b-instruct:free', 'name': 'Llama 3.3 70B', 'desc': 'Powerful'},
    {'id': 'qwen/qwen3-4b:free', 'name': 'Qwen3 4B', 'desc': 'Alibaba efficient'},
    {'id': 'cognitivecomputations/dolphin-mistral-24b-venice-edition:free', 'name': 'Dolphin Mistral 24B', 'desc': 'Uncensored'},
    {'id': 'qwen/qwen3-coder:free', 'name': 'Qwen3 Coder', 'desc': 'Code specialist'},
    {'id': 'qwen/qwen3-235b-a22b-thinking-2507', 'name': 'Qwen3 235B Thinking', 'desc': 'Deep reasoning'},
    {'id': 'z-ai/glm-4.5-air:free', 'name': 'GLM-4.5 Air', 'desc': 'Zhipu AI'},
    {'id': 'openai/gpt-oss-20b:free', 'name': 'GPT-OSS 20B', 'desc': 'Open source'},
    {'id': 'openai/gpt-oss-120b:free', 'name': 'GPT-OSS 120B', 'desc': 'Large model'},
    {'id': 'nvidia/nemotron-nano-9b-v2:free', 'name': 'Nemotron Nano 9B v2', 'desc': 'NVIDIA optimized'},
    {'id': 'qwen/qwen3-next-80b-a3b-instruct:free', 'name': 'Qwen3 Next 80B', 'desc': 'Next-gen'},
    {'id': 'qwen/qwen3-vl-235b-a22b-thinking', 'name': 'Qwen3 VL 235B', 'desc': 'Vision + reasoning'},
    {'id': 'qwen/qwen3-vl-30b-a3b-thinking', 'name': 'Qwen3 VL 30B', 'desc': 'Light vision'},
    {'id': 'nvidia/nemotron-nano-12b-v2-vl:free', 'name': 'Nemotron Nano 12B VL', 'desc': 'Vision capable'},
    {'id': 'black-forest-labs/flux.2-pro', 'name': 'Flux.2 Pro', 'desc': 'Image generation'},    {'id': 'upstage/solar-pro-3:free', 'name': 'Solar Pro 3', 'desc': 'Upstage efficient'},
    {'id': 'nvidia/llama-nemotron-embed-vl-1b-v2:free', 'name': 'Nemotron Embed VL 1B', 'desc': 'Embedding'},
  ];

  // Gemini Models (YOUR REAL LIST)
  static const List<Map<String, String>> gemModels = [
    {'id': 'gemini-3-flash-preview', 'name': 'Gemini 3 Flash Preview', 'desc': 'Next-gen fast'},
    {'id': 'gemini-2.5-pro', 'name': 'Gemini 2.5 Pro', 'desc': 'Google flagship'},
    {'id': 'gemini-flash-latest', 'name': 'Gemini Flash Latest', 'desc': 'Auto-updating'},
    {'id': 'gemini-flash-lite-latest', 'name': 'Gemini Flash Lite Latest', 'desc': 'Lightweight auto'},
    {'id': 'gemini-2.5-flash', 'name': 'Gemini 2.5 Flash', 'desc': 'Balanced speed'},
    {'id': 'gemini-2.5-flash-lite', 'name': 'Gemini 2.5 Flash Lite', 'desc': 'Efficient'},
    {'id': 'gemini-2.0-flash', 'name': 'Gemini 2.0 Flash', 'desc': 'Previous stable'},
    {'id': 'gemini-2.0-flash-lite', 'name': 'Gemini 2.0 Flash Lite', 'desc': 'Light 2.0'},
    {'id': 'gemini-robotics-er-1.5-preview', 'name': 'Gemini Robotics ER 1.5', 'desc': 'Robotics'},
    {'id': 'gemini-2.5-pro-preview-tts', 'name': 'Gemini 2.5 Pro TTS', 'desc': 'With TTS'},
    {'id': 'gemini-2.5-flash-preview-tts', 'name': 'Gemini 2.5 Flash TTS', 'desc': 'Flash with TTS'},
  ];

  // Defaults
  static const _defOR = 'google/gemma-3-4b-it:free';
  static const _defGem = 'gemini-2.0-flash-lite';

  // Endpoints
  static String get orEp => 'https://openrouter.ai/api/v1/chat/completions';
  static String get gemEp => 'https://generativelanguage.googleapis.com/v1beta/models';
  static String gemUrl(String m) => '$gemEp/$m:generateContent?key=$_gemKey';

  // Init
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _orKey = _prefs.getString(_kOR) ?? '';
    _gemKey = _prefs.getString(_kGem) ?? '';
    final p = _prefs.getString(_kProv) ?? 'none';
    _prov = ApiProvider.values.firstWhere(
      (x) => x.toString().split('.').last == p,
      orElse: () => ApiProvider.none,
    );
    _model = _prefs.getString(_kModel) ?? (_prov == ApiProvider.openRouter ? _defOR : _defGem);
    _voice = _prefs.getString(_kVoice) ?? _voice;
    _lang = _prefs.getString(_kLang) ?? _lang;
    _owner = _prefs.getString(_kOwner) ?? _owner;
    _aff = _prefs.getInt(_kAff) ?? _aff;
  }

  // Getters
  static String get key => _prov == ApiProvider.openRouter ? _orKey : _gemKey;
  static ApiProvider get provider => _prov;
  static String get model => _model;
  static String get voice => _voice;  static String get lang => _lang;
  static String get owner => _owner;
  static int get aff => _aff;
  static List<Map<String, String>> get models => _prov == ApiProvider.openRouter ? orModels : gemModels;

  // Headers
  static Map<String, String> get headers {
    if (_prov == ApiProvider.openRouter) {
      return {
        'Authorization': 'Bearer $_orKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://zara-ai.example.com',
        'X-Title': 'Z.A.R.A. AI',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  // Request body
  static Map<String, dynamic> body({
    required List<Map<String, String>> msgs,
    double temp = 0.7,
    int maxTok = 2048,
  }) {
    if (_prov == ApiProvider.openRouter) {
      return {
        'model': _model,
        'messages': msgs,
        'temperature': temp,
        'max_tokens': maxTok,
        'stream': false,
      };
    }
    return {
      'contents': msgs.map((m) => {
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': m['content'] ?? ''}],
      }).toList(),
      'generationConfig': {
        'temperature': temp,
        'maxOutputTokens': maxTok,
      },
    };
  }

  // Save config
  static Future<bool> save({
    String? orKey,
    String? gemKey,
    ApiProvider? prov,    String? model,
    String? voice,
    String? lang,
    String? owner,
    int? aff,
  }) async {
    try {
      var ok = true;
      if (orKey != null) {
        if (orKey.isNotEmpty && !_validOR(orKey)) return false;
        _orKey = orKey;
        ok = await _prefs.setString(_kOR, orKey) && ok;
      }
      if (gemKey != null) {
        if (gemKey.isNotEmpty && !_validGem(gemKey)) return false;
        _gemKey = gemKey;
        ok = await _prefs.setString(_kGem, gemKey) && ok;
      }
      if (prov != null) {
        _prov = prov;
        ok = await _prefs.setString(_kProv, prov.toString().split('.').last) && ok;
        _model = prov == ApiProvider.openRouter ? _defOR : _defGem;
        await _prefs.setString(_kModel, _model);
      }
      if (model != null && model.isNotEmpty) {
        _model = model;
        ok = await _prefs.setString(_kModel, model) && ok;
      }
      if (voice != null) { _voice = voice; ok = await _prefs.setString(_kVoice, voice) && ok; }
      if (lang != null) { _lang = lang; ok = await _prefs.setString(_kLang, lang) && ok; }
      if (owner != null) { _owner = owner; ok = await _prefs.setString(_kOwner, owner) && ok; }
      if (aff != null) { _aff = aff.clamp(0, 100); ok = await _prefs.setInt(_kAff, _aff) && ok; }
      return ok;
    } catch (e) {
      if (kDebugMode) print('Save error: $e');
      return false;
    }
  }

  // Validation
  static bool _validOR(String k) => k.length >= 32 && RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(k);
  static bool _validGem(String k) => RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);
  static bool validCurrent(String k) => _prov == ApiProvider.openRouter ? _validOR(k) : _validGem(k);

  // Status
  static Map<String, dynamic> get status => {
    'configured': key.isNotEmpty && _prov != ApiProvider.none,
    'provider': _prov.toString().split('.').last,
    'model': _model,
    'orSet': _orKey.isNotEmpty,    'gemSet': _gemKey.isNotEmpty,
  };

  static bool get ready => key.isNotEmpty && _model.isNotEmpty && _prov != ApiProvider.none;

  // Clear
  static Future<void> clear() async {
    await _prefs.clear();
    await init();
  }

  // Parse responses
  static String? parseOR(Map<String, dynamic> r) {
    try { return r['choices']?[0]?['message']?['content'] as String?; } catch (_) { return null; }
  }

  static String? parseGem(Map<String, dynamic> r) {
    try { return r['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?; } catch (_) { return null; }
  }
}
