// lib/core/constants/api_keys.dart
// Z.A.R.A. v7.0 — All 5 API Keys Config
// 1. Gemini   — Brain (chat, reasoning, vision)
// 2. Mem0     — Long-term memory (Ravi ji ko yaad rakhna)
// 3. LiveKit  — Real-time voice room (low-latency)
// 4. OpenAI   — Whisper STT (speech-to-text)
// 5. ElevenLabs — Voice output (Simran)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeys {
  static late SharedPreferences _prefs;

  // ── Runtime values ─────────────────────────────────────────────────────────
  static String _geminiKey    = '';
  static String _mem0Key      = '';
  static String _livekitUrl   = '';
  static String _livekitToken = '';
  static String _openaiKey    = '';
  static String _elevenKey    = '';
  static String _mem0UserId   = 'zara_ravi';

  static String _geminiModel  = 'gemini-2.5-flash';
  static String _lang         = 'hi-IN';
  static String _ownerName    = 'Ravi';
  static int    _affection    = 85;

  // ── SharedPrefs keys ───────────────────────────────────────────────────────
  static const _kGemini    = 'gemini_key';
  static const _kMem0      = 'mem0_key';
  static const _kLKUrl     = 'livekit_url';
  static const _kLKToken   = 'livekit_token';
  static const _kOpenAI    = 'openai_key';
  static const _kEleven    = 'eleven_key';
  static const _kMem0User  = 'mem0_user_id';
  static const _kModel     = 'gemini_model';
  static const _kLang      = 'lang';
  static const _kOwner     = 'owner_name';
  static const _kAff       = 'affection';

  // ── ElevenLabs — Simran voice hardcoded ───────────────────────────────────
  static const String simranVoiceId = 'rdz6GofVsYlLgQl2dBEE';

  // ── Gemini Models (Sir-verified) ───────────────────────────────────────────
  static const List<Map<String, String>> geminiModels = [
    {'id': 'gemini-2.5-flash',              'name': 'Gemini 2.5 Flash',     'desc': '⭐ Best'},
    {'id': 'gemini-2.5-flash-lite',         'name': 'Gemini 2.5 Lite',      'desc': 'Fastest'},
    {'id': 'gemini-2.0-flash',              'name': 'Gemini 2.0 Flash',     'desc': 'Stable'},
    {'id': 'gemini-2.5-flash-preview-tts',  'name': 'Gemini 2.5 TTS',       'desc': 'TTS optimized'},
    {'id': 'gemini-2.5-pro-preview-tts',    'name': 'Gemini 2.5 Pro TTS',   'desc': 'Pro TTS'},
    {'id': 'gemini-3-flash-preview',        'name': 'Gemini 3 Flash',       'desc': 'Latest'},
    {'id': 'gemini-flash-latest',           'name': 'Gemini Flash Latest',  'desc': 'Auto-latest'},
    {'id': 'gemini-flash-lite-latest',      'name': 'Gemini Lite Latest',   'desc': 'Auto-lite'},
    {'id': 'gemini-2.5-flash-native-audio-preview-12-2025',
                                            'name': 'Gemini Native Audio',  'desc': 'Audio preview'},
  ];

  // ── Init ───────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _geminiKey    = _prefs.getString(_kGemini)   ?? '';
    _mem0Key      = _prefs.getString(_kMem0)     ?? '';
    _livekitUrl   = _prefs.getString(_kLKUrl)    ?? '';
    _livekitToken = _prefs.getString(_kLKToken)  ?? '';
    _openaiKey    = _prefs.getString(_kOpenAI)   ?? '';
    _elevenKey    = _prefs.getString(_kEleven)   ?? '';
    _mem0UserId   = _prefs.getString(_kMem0User) ?? 'zara_ravi';
    _ownerName    = _prefs.getString(_kOwner)    ?? 'Ravi';
    _lang         = _prefs.getString(_kLang)     ?? 'hi-IN';
    _affection    = _prefs.getInt(_kAff)         ?? 85;

    final savedModel = _prefs.getString(_kModel) ?? '';
    final validIds   = geminiModels.map((m) => m['id']!).toList();
    _geminiModel = validIds.contains(savedModel) ? savedModel : 'gemini-2.5-flash';

    if (kDebugMode) {
      debugPrint('ApiKeys.init ─────────────────────');
      debugPrint('  Gemini  : ${_geminiKey.isNotEmpty  ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('  Mem0    : ${_mem0Key.isNotEmpty    ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('  LiveKit : ${_livekitUrl.isNotEmpty ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('  OpenAI  : ${_openaiKey.isNotEmpty  ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('  Eleven  : ${_elevenKey.isNotEmpty  ? "✅ SET" : "❌ EMPTY"}');
      debugPrint('  Model   : $_geminiModel');
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  static String get geminiKey    => _geminiKey;
  static String get mem0Key      => _mem0Key;
  static String get livekitUrl   => _livekitUrl;
  static String get livekitToken => _livekitToken;
  static String get openaiKey    => _openaiKey;
  static String get elevenKey    => _elevenKey;
  static String get mem0UserId   => _mem0UserId;
  static String get geminiModel  => _geminiModel;
  static String get lang         => _lang;
  static String get ownerName    => _ownerName;
  static int    get affection    => _affection;

  // Backward compat
  static String get gemKey  => _geminiKey;
  static String get key     => _geminiKey;
  static String get elKey   => _elevenKey;
  static String get model   => _geminiModel;
  static String get voice   => simranVoiceId;
  static String get owner   => _ownerName;
  static int    get aff     => _affection;

  static bool get geminiReady => _geminiKey.isNotEmpty;
  static bool get mem0Ready   => _mem0Key.isNotEmpty;
  static bool get livekitReady => _livekitUrl.isNotEmpty && _livekitToken.isNotEmpty;
  static bool get openaiReady => _openaiKey.isNotEmpty;
  static bool get elevenReady => _elevenKey.isNotEmpty;

  static List<Map<String, String>> get gemModels => geminiModels;
  static List<Map<String, String>> get geminiTtsVoices => []; // removed

  // ── Save ───────────────────────────────────────────────────────────────────
  static Future<bool> save({
    String? geminiKey,
    String? mem0Key,
    String? livekitUrl,
    String? livekitToken,
    String? openaiKey,
    String? elevenKey,
    String? mem0UserId,
    String? geminiModel,
    String? lang,
    String? ownerName,
    int?    affection,
    // backward compat params
    String? gemKey,
    String? elKey,
    String? model,
    String? owner,
    int?    aff,
    String? voice,
    String? orKey,
    dynamic prov,
    bool?   elEnabled,
  }) async {
    try {
      bool ok = true;

      final gk = geminiKey ?? gemKey ?? '';
      if (gk.isNotEmpty) {
        if (!_isValidGemKey(gk)) return false;
        _geminiKey = gk;
        ok = await _prefs.setString(_kGemini, gk) && ok;
      }

      final ek = elevenKey ?? elKey ?? '';
      if (ek.isNotEmpty) {
        _elevenKey = ek;
        ok = await _prefs.setString(_kEleven, ek) && ok;
      }

      if (mem0Key != null && mem0Key.isNotEmpty) {
        _mem0Key = mem0Key;
        ok = await _prefs.setString(_kMem0, mem0Key) && ok;
      }

      if (livekitUrl != null && livekitUrl.isNotEmpty) {
        _livekitUrl = livekitUrl;
        ok = await _prefs.setString(_kLKUrl, livekitUrl) && ok;
      }

      if (livekitToken != null && livekitToken.isNotEmpty) {
        _livekitToken = livekitToken;
        ok = await _prefs.setString(_kLKToken, livekitToken) && ok;
      }

      if (openaiKey != null && openaiKey.isNotEmpty) {
        _openaiKey = openaiKey;
        ok = await _prefs.setString(_kOpenAI, openaiKey) && ok;
      }

      if (mem0UserId != null && mem0UserId.isNotEmpty) {
        _mem0UserId = mem0UserId;
        ok = await _prefs.setString(_kMem0User, mem0UserId) && ok;
      }

      final gm = geminiModel ?? model ?? '';
      if (gm.isNotEmpty) {
        final validIds = geminiModels.map((m) => m['id']!).toList();
        if (validIds.contains(gm)) {
          _geminiModel = gm;
          ok = await _prefs.setString(_kModel, gm) && ok;
        }
      }

      final lg = lang;
      if (lg != null && lg.isNotEmpty) {
        _lang = lg;
        ok = await _prefs.setString(_kLang, lg) && ok;
      }

      final on = ownerName ?? owner ?? '';
      if (on.isNotEmpty) {
        _ownerName = on;
        ok = await _prefs.setString(_kOwner, on) && ok;
      }

      final af = affection ?? aff;
      if (af != null) {
        _affection = af.clamp(0, 100);
        ok = await _prefs.setInt(_kAff, _affection) && ok;
      }

      if (kDebugMode) debugPrint('ApiKeys.save ✅ ok:$ok');
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('ApiKeys.save error: $e');
      return false;
    }
  }

  static bool _isValidGemKey(String k) =>
      RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);
  static bool validCurrent(String k) => _isValidGemKey(k);
  static bool get ready => _geminiKey.isNotEmpty;
  static Future<void> clear() async { await _prefs.clear(); await init(); }
  static Map<String, String> get headers => {'Content-Type': 'application/json'};
}
