// lib/core/constants/api_keys.dart
// Z.A.R.A. — Neural Core v3.0
// ✅ Gemini Only — 4 Brain Models
// ✅ ElevenLabs — 5 Voice IDs
// ✅ Gemini TTS fallback
// ✅ Dropdown crash-proof

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiProvider { gemini, none }

class ApiKeys {
  static late SharedPreferences _prefs;

  static String      _gemKey    = '';
  static ApiProvider _prov      = ApiProvider.none;
  static String      _model     = '';
  static String      _voice     = 'rdz6GofVsYlLgQl2dBEE';
  static String      _lang      = 'hi-IN';
  static String      _owner     = 'OWNER RAVI';
  static int         _aff       = 85;
  static bool        _elEnabled = true;
  static String      _elKey     = '';

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const _kGem      = 'gem_key';
  static const _kElKey    = 'el_key';
  static const _kElEnable = 'el_enabled';
  static const _kModel    = 'model';
  static const _kVoice    = 'voice';
  static const _kLang     = 'lang';
  static const _kOwner    = 'owner';
  static const _kAff      = 'affection';

  // ── Gemini Brain Models — 5 sahi models ──────────────────────────────────
  static const List<Map<String, String>> gemModels = [
    {'id': 'gemini-2.5-flash-preview-05-20', 'name': 'Gemini 2.5 Flash',      'desc': 'Best balance — fast + smart'},
    {'id': 'gemini-2.5-flash-lite-preview-06-17', 'name': 'Gemini 2.5 Flash Lite', 'desc': 'Lightest — battery saver'},
    {'id': 'gemini-2.5-flash-preview-tts',   'name': 'Gemini 2.5 Flash TTS',  'desc': 'Best TTS voice quality'},
    {'id': 'gemini-exp-1206',                 'name': 'Gemini 3 Flash',        'desc': 'Latest experimental'},
    {'id': 'gemma-3-27b-it',                  'name': 'Gemma 3 27B',           'desc': 'Open model — powerful'},
  ];

  // ── ElevenLabs Voices — 5 IDs ─────────────────────────────────────────────
  static const List<Map<String, String>> elevenLabsVoices = [
    {'id': 'rdz6GofVsYlLgQl2dBEE', 'name': 'Zara Voice 1 (Default)'},
    {'id': 'Z454IZ827TNOaUaaQSzE',  'name': 'Zara Voice 2'},
    {'id': 'qFwAIpwqlpqZbTYpttVi',  'name': 'Zara Voice 3'},
    {'id': 'CpLFIATEbkaZdJr01erZ',  'name': 'Zara Voice 4'},
    {'id': 'OtEfb2LVzIE45wdYe54M',  'name': 'Zara Voice 5'},
  ];

  // ElevenLabs ONLY — Simran is default voice, hardcoded in tts_service
  // geminiTtsVoices removed — not needed anymore

  static const _defGem   = 'gemini-2.5-flash-preview-tts';  // Default — TTS quality best
  static const _defVoice = 'rdz6GofVsYlLgQl2dBEE';          // Default ElevenLabs voice

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    _prefs    = await SharedPreferences.getInstance();
    _gemKey   = _prefs.getString(_kGem)   ?? '';
    _elKey    = _prefs.getString(_kElKey) ?? '';
    _prov     = _gemKey.isNotEmpty ? ApiProvider.gemini : ApiProvider.none;

    final saved    = _prefs.getString(_kModel) ?? '';
    final validIds = gemModels.map((m) => m['id']!).toList();
    _model = validIds.contains(saved) ? saved : _defGem;
    if (!validIds.contains(saved)) await _prefs.setString(_kModel, _model);

    _voice     = _prefs.getString(_kVoice)   ?? _defVoice;
    _lang      = _prefs.getString(_kLang)    ?? _lang;
    _owner     = _prefs.getString(_kOwner)   ?? _owner;
    _aff       = _prefs.getInt(_kAff)        ?? _aff;
    _elEnabled = _prefs.getBool(_kElEnable)  ?? true;

    if (kDebugMode) debugPrint('✅ ApiKeys — model:$_model EL:$_elEnabled');
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  static String       get key        => _gemKey;
  static String       get gemKey     => _gemKey;
  static String       get elKey      => _elKey;
  static bool         get elEnabled  => _elEnabled;
  static ApiProvider  get provider   => _prov;
  static String       get model      => _model;
  static String       get voice      => _voice;
  static String       get lang       => _lang;
  static String       get owner      => _owner;
  static int          get aff        => _aff;
  static String       get orKey      => '';   // backward compat — always empty

  static List<Map<String, String>> get models    => gemModels;
  static List<Map<String, String>> get orModels  => [];

  static bool get ready => _gemKey.isNotEmpty && _model.isNotEmpty;

  // ── Save ──────────────────────────────────────────────────────────────────
  static Future<bool> save({
    String?      gemKey,
    String?      elKey,
    bool?        elEnabled,
    String?      model,
    String?      voice,
    String?      lang,
    String?      owner,
    int?         aff,
    // Kept for backward compat — ignored
    String?      orKey,
    ApiProvider? prov,
  }) async {
    try {
      var ok = true;
      if (gemKey != null && gemKey.isNotEmpty) {
        if (!_validGem(gemKey)) return false;
        _gemKey = gemKey;
        _prov   = ApiProvider.gemini;
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
      if (voice  != null) { _voice = voice;  ok = await _prefs.setString(_kVoice, voice) && ok; }
      if (lang   != null) { _lang  = lang;   ok = await _prefs.setString(_kLang,  lang)  && ok; }
      if (owner  != null) { _owner = owner;  ok = await _prefs.setString(_kOwner, owner) && ok; }
      if (aff    != null) {
        _aff = aff.clamp(0, 100);
        ok = await _prefs.setInt(_kAff, _aff) && ok;
      }
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ApiKeys.save: $e');
      return false;
    }
  }

  static bool _validGem(String k) =>
      RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);
  static bool validCurrent(String k) => _validGem(k);

  static Map<String, dynamic> get status => {
    'configured': ready,
    'provider':   'gemini',
    'model':      _model,
    'gemSet':     _gemKey.isNotEmpty,
    'elEnabled':  _elEnabled,
    'elSet':      _elKey.isNotEmpty,
  };

  // Backward compat stubs
  static String defaultModelFor(ApiProvider p) => _defGem;
  static bool isValidModel(String id, ApiProvider p) =>
      gemModels.any((m) => m['id'] == id);
  static List<Map<String, String>> modelsFor(ApiProvider p) => gemModels;
  static Map<String, String> get headers => {'Content-Type': 'application/json'};
  static String? parseGem(Map<String, dynamic> r) {
    try { return r['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?; }
    catch (_) { return null; }
  }
  static Future<void> clear() async { await _prefs.clear(); await init(); }
}
