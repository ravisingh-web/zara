// lib/core/constants/api_keys.dart
// Z.A.R.A. — Neural Core v5.0
// ✅ Keys hardcoded — no SharedPreferences dependency for API calls
// ✅ ElevenLabs Simran voice hardcoded
// ✅ Settings se sirf save hota hai, default mein keys kaam karte hain

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiProvider { gemini, none }

class ApiKeys {
  static late SharedPreferences _prefs;

  // ── HARDCODED DEFAULTS — ye hamesha kaam karenge ─────────────────────────
  // Settings mein key daalne par override ho jaayegi, warna ye use hogi
  static String _gemKey   = '';   // User Settings mein daalega
  static String _elKey    = '';   // User Settings mein daalega
  static String _model    = 'gemini-2.5-flash-preview-05-20';
  static String _voice    = 'rdz6GofVsYlLgQl2dBEE';  // Simran — hardcoded
  static String _lang     = 'hi-IN';
  static String _owner    = 'OWNER RAVI';
  static int    _aff      = 85;
  static bool   _elEnabled = true;

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const _kGem      = 'gem_key';
  static const _kElKey    = 'el_key';
  static const _kElEnable = 'el_enabled';
  static const _kModel    = 'model';
  static const _kVoice    = 'voice';
  static const _kLang     = 'lang';
  static const _kOwner    = 'owner';
  static const _kAff      = 'affection';

  // ── Gemini Brain Models ───────────────────────────────────────────────────
  static const List<Map<String, String>> gemModels = [
    {'id': 'gemini-2.5-flash-preview-05-20',      'name': 'Gemini 2.5 Flash',      'desc': 'Best balance'},
    {'id': 'gemini-2.5-flash-lite-preview-06-17', 'name': 'Gemini 2.5 Flash Lite', 'desc': 'Lightest'},
    {'id': 'gemini-2.5-flash-preview-tts',        'name': 'Gemini 2.5 Flash TTS',  'desc': 'TTS quality'},
    {'id': 'gemini-exp-1206',                      'name': 'Gemini 3 Flash',        'desc': 'Latest'},
    {'id': 'gemma-3-27b-it',                       'name': 'Gemma 3 27B',           'desc': 'Open model'},
  ];

  // ── ElevenLabs — Simran voice only ───────────────────────────────────────
  static const String simranVoiceId = 'rdz6GofVsYlLgQl2dBEE';

  static const List<Map<String, String>> elevenLabsVoices = [
    {'id': 'rdz6GofVsYlLgQl2dBEE', 'name': 'Simran (Default)'},
    {'id': 'Z454IZ827TNOaUaaQSzE',  'name': 'Voice 2'},
    {'id': 'qFwAIpwqlpqZbTYpttVi',  'name': 'Voice 3'},
    {'id': 'CpLFIATEbkaZdJr01erZ',  'name': 'Voice 4'},
    {'id': 'OtEfb2LVzIE45wdYe54M',  'name': 'Voice 5'},
  ];

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load saved keys — override defaults if user has set them
    final savedGem = _prefs.getString(_kGem) ?? '';
    final savedEl  = _prefs.getString(_kElKey) ?? '';
    if (savedGem.isNotEmpty) _gemKey = savedGem;
    if (savedEl.isNotEmpty)  _elKey  = savedEl;

    // Model
    final saved    = _prefs.getString(_kModel) ?? '';
    final validIds = gemModels.map((m) => m['id']!).toList();
    if (validIds.contains(saved)) _model = saved;

    // Other prefs
    _lang      = _prefs.getString(_kLang)   ?? _lang;
    _owner     = _prefs.getString(_kOwner)  ?? _owner;
    _aff       = _prefs.getInt(_kAff)       ?? _aff;
    _elEnabled = _prefs.getBool(_kElEnable) ?? true;

    if (kDebugMode) {
      debugPrint('ApiKeys init — gemKey:${_gemKey.isNotEmpty ? "SET" : "EMPTY"} '
          'elKey:${_elKey.isNotEmpty ? "SET" : "EMPTY"} model:$_model');
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  static String      get gemKey    => _gemKey;
  static String      get elKey     => _elKey;
  static String      get key       => _gemKey;
  static bool        get elEnabled => _elEnabled;
  static String      get model     => _model;
  static String      get voice     => simranVoiceId;  // Always Simran
  static String      get lang      => _lang;
  static String      get owner     => _owner;
  static int         get aff       => _aff;
  static String      get orKey     => '';

  static ApiProvider get provider  =>
      _gemKey.isNotEmpty ? ApiProvider.gemini : ApiProvider.none;

  static List<Map<String, String>> get models   => gemModels;
  static List<Map<String, String>> get orModels => [];

  static bool get ready => _gemKey.isNotEmpty;

  // ── Save ──────────────────────────────────────────────────────────────────
  static Future<bool> save({
    String? gemKey, String? elKey, bool? elEnabled,
    String? model,  String? voice, String? lang,
    String? owner,  int?    aff,
    String? orKey, ApiProvider? prov,
  }) async {
    try {
      var ok = true;
      if (gemKey != null && gemKey.isNotEmpty) {
        if (!_validGem(gemKey)) return false;
        _gemKey = gemKey;
        ok = await _prefs.setString(_kGem, gemKey) && ok;
      }
      if (elKey != null) {
        _elKey = elKey;
        ok = await _prefs.setString(_kElKey, elKey) && ok;
      }
      if (elEnabled != null) {
        _elEnabled = elEnabled;
        ok = await _prefs.setBool(_kElEnable, elEnabled) && ok;
      }
      if (model != null && gemModels.any((m) => m['id'] == model)) {
        _model = model;
        ok = await _prefs.setString(_kModel, model) && ok;
      }
      // voice ignored — Simran hardcoded
      if (lang  != null) { _lang  = lang;  ok = await _prefs.setString(_kLang,  lang)  && ok; }
      if (owner != null) { _owner = owner; ok = await _prefs.setString(_kOwner, owner) && ok; }
      if (aff   != null) { _aff   = aff.clamp(0,100); ok = await _prefs.setInt(_kAff, _aff) && ok; }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('ApiKeys.save: $e');
      return false;
    }
  }

  static bool _validGem(String k) =>
      RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);
  static bool validCurrent(String k) => _validGem(k);

  static Map<String, dynamic> get status => {
    'configured': ready, 'model': _model,
    'gemSet': _gemKey.isNotEmpty, 'elSet': _elKey.isNotEmpty,
  };

  // Backward compat stubs
  static String defaultModelFor(ApiProvider p) => _model;
  static bool isValidModel(String id, ApiProvider p) =>
      gemModels.any((m) => m['id'] == id);
  static List<Map<String, String>> modelsFor(ApiProvider p) => gemModels;
  static Map<String, String> get headers => {'Content-Type': 'application/json'};
  static String? parseGem(Map<String, dynamic> r) {
    try { return r['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?; }
    catch (_) { return null; }
  }
  static Future<void> clear() async { await _prefs.clear(); await init(); }

  // Removed: geminiTtsVoices — ElevenLabs only
  static List<Map<String, String>> get geminiTtsVoices => [];
}
