// lib/core/constants/api_keys.dart
// Z.A.R.A. v9.0 — Free Architecture
// 1. Gemini        — Brain (AI reasoning)
// 2. ElevenLabs    — Anjura Voice (TTS)
// 3. OpenAI        — Whisper STT
// 4. Mem0          — Long-term memory
// 5. LiveKit       — Real-time voice room
// 6. n8n           — Automation webhook (FREE, replaces Pipedream)
// 7. Google Sheets — Neural log sheet
//
// Removed: Picovoice Porcupine (replaced by Vosk — fully offline, no key needed)
// Removed: Pipedream (replaced by n8n — free self-hosted or cloud.n8n.io)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeys {
  static late SharedPreferences _prefs;

  // ── Runtime values ─────────────────────────────────────────────────────────
  static String _geminiKey    = '';
  static String _elevenKey    = '';
  static String _openaiKey    = '';
  static String _mem0Key      = '';
  static String _mem0UserId   = 'zara_ravi';
  static String _livekitUrl   = '';
  static String _livekitToken = '';
  static String _n8nUrl       = '';  // n8n webhook URL
  static String _n8nToken     = '';  // n8n auth token (optional)
  static String _sheetsId     = '';  // Google Spreadsheet ID
  static String _sheetsJson   = '';  // Service Account JSON
  static String _geminiModel  = 'gemini-2.5-flash';
  static String _lang         = 'hi-IN';
  static String _ownerName    = 'Ravi';
  static int    _affection    = 85;

  // ── SharedPrefs keys ───────────────────────────────────────────────────────
  static const _kGemini    = 'gemini_key';
  static const _kEleven    = 'eleven_key';
  static const _kOpenAI    = 'openai_key';
  static const _kMem0      = 'mem0_key';
  static const _kMem0User  = 'mem0_user_id';
  static const _kLKUrl     = 'livekit_url';
  static const _kLKToken   = 'livekit_token';
  static const _kN8nUrl    = 'n8n_webhook_url';
  static const _kN8nToken  = 'n8n_auth_token';
  static const _kSheetsId  = 'sheets_id';
  static const _kSheetsJson= 'sheets_json';
  static const _kModel     = 'gemini_model';
  static const _kLang      = 'lang';
  static const _kOwner     = 'owner_name';
  static const _kAff       = 'affection';

  // ── Anjura voice ID (hardcoded — ElevenLabs) ───────────────────────────────
  static const String anjuraVoiceId = 'rdz6GofVsYlLgQl2dBEE';
  static const String simranVoiceId = 'rdz6GofVsYlLgQl2dBEE';

  // ── Gemini Models ──────────────────────────────────────────────────────────
  static const List<Map<String, String>> geminiModels = [
    {'id': 'gemini-2.5-flash',             'name': 'Gemini 2.5 Flash',  'desc': '⭐ Best'},
    {'id': 'gemini-2.5-flash-lite',        'name': 'Gemini 2.5 Lite',   'desc': 'Fastest'},
    {'id': 'gemini-2.0-flash',             'name': 'Gemini 2.0 Flash',  'desc': 'Stable'},
    {'id': 'gemini-2.5-flash-preview-tts', 'name': 'Gemini 2.5 TTS',    'desc': 'TTS'},
    {'id': 'gemini-3-flash-preview',       'name': 'Gemini 3 Flash',    'desc': 'Latest'},
  ];

  // ── Init — load all keys from SharedPrefs ─────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _geminiKey    = _prefs.getString(_kGemini)    ?? '';
    _elevenKey    = _prefs.getString(_kEleven)    ?? '';
    _openaiKey    = _prefs.getString(_kOpenAI)    ?? '';
    _mem0Key      = _prefs.getString(_kMem0)      ?? '';
    _mem0UserId   = _prefs.getString(_kMem0User)  ?? 'zara_ravi';
    _livekitUrl   = _prefs.getString(_kLKUrl)     ?? '';
    _livekitToken = _prefs.getString(_kLKToken)   ?? '';
    _n8nUrl       = _prefs.getString(_kN8nUrl)    ?? '';
    _n8nToken     = _prefs.getString(_kN8nToken)  ?? '';
    _sheetsId     = _prefs.getString(_kSheetsId)  ?? '';
    _sheetsJson   = _prefs.getString(_kSheetsJson)?? '';
    _ownerName    = _prefs.getString(_kOwner)     ?? 'Ravi';
    _lang         = _prefs.getString(_kLang)      ?? 'hi-IN';
    _affection    = _prefs.getInt(_kAff)          ?? 85;

    final saved  = _prefs.getString(_kModel) ?? '';
    final valids = geminiModels.map((m) => m['id']!).toList();
    _geminiModel = valids.contains(saved) ? saved : 'gemini-2.5-flash';

    if (kDebugMode) {
      debugPrint('ApiKeys.init ───────────────────');
      debugPrint('  Gemini    : ${_geminiKey.isNotEmpty    ? "✅" : "❌"}');
      debugPrint('  ElevenLabs: ${_elevenKey.isNotEmpty    ? "✅" : "❌"}');
      debugPrint('  OpenAI    : ${_openaiKey.isNotEmpty    ? "✅" : "❌"}');
      debugPrint('  Mem0      : ${_mem0Key.isNotEmpty      ? "✅" : "❌"}');
      debugPrint('  LiveKit   : ${_livekitUrl.isNotEmpty   ? "✅" : "❌"}');
      debugPrint('  n8n       : ${_n8nUrl.isNotEmpty       ? "✅" : "❌"}');
      debugPrint('  Sheets    : ${_sheetsId.isNotEmpty     ? "✅" : "❌"}');
      debugPrint('  Model     : $_geminiModel');
      debugPrint('  Vosk      : offline (no key needed)');
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  static String get geminiKey      => _geminiKey;
  static String get elevenKey      => _elevenKey;
  static String get openaiKey      => _openaiKey;
  static String get mem0Key        => _mem0Key;
  static String get mem0UserId     => _mem0UserId;
  static String get livekitUrl     => _livekitUrl;
  static String get livekitToken   => _livekitToken;
  static String get n8nWebhookUrl  => _n8nUrl;
  static String get n8nAuthToken   => _n8nToken;
  static String get sheetsId       => _sheetsId;
  static String get sheetsJson     => _sheetsJson;
  static String get geminiModel    => _geminiModel;
  static String get lang           => _lang;
  static String get ownerName      => _ownerName;
  static int    get affection      => _affection;

  // Backward compat aliases (used across existing codebase — DO NOT REMOVE)
  static String get gemKey  => _geminiKey;
  static String get key     => _geminiKey;
  static String get elKey   => _elevenKey;
  static String get model   => _geminiModel;
  static String get voice   => anjuraVoiceId;
  static String get owner   => _ownerName;
  static int    get aff     => _affection;

  // Ready flags
  static bool get geminiReady   => _geminiKey.isNotEmpty;
  static bool get elevenReady   => _elevenKey.isNotEmpty;
  static bool get openaiReady   => _openaiKey.isNotEmpty;
  static bool get mem0Ready     => _mem0Key.isNotEmpty;
  static bool get livekitReady  => _livekitUrl.isNotEmpty && _livekitToken.isNotEmpty;
  static bool get n8nReady      => _n8nUrl.isNotEmpty;
  static bool get sheetsReady   => _sheetsId.isNotEmpty && _sheetsJson.isNotEmpty;
  static bool get ready         => _geminiKey.isNotEmpty;

  static List<Map<String, String>> get gemModels       => geminiModels;
  static List<Map<String, String>> get geminiTtsVoices => [];

  // ── Save ───────────────────────────────────────────────────────────────────
  static Future<bool> save({
    String? geminiKey,
    String? elevenKey,
    String? openaiKey,
    String? mem0Key,
    String? mem0UserId,
    String? livekitUrl,
    String? livekitToken,
    String? n8nWebhookUrl,
    String? n8nAuthToken,
    String? sheetsId,
    String? sheetsJson,
    String? geminiModel,
    String? lang,
    String? ownerName,
    int?    affection,
    // Backward compat params — accepted but ignored for removed services
    String? pipedreamUrl,
    String? pipedreamApiKey,
    String? porcupineKey,
    // Other backward compat aliases
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
        if (!_validGem(gk)) { debugPrint('Invalid Gemini key'); return false; }
        _geminiKey = gk;
        ok = await _prefs.setString(_kGemini, gk) && ok;
      }

      final ek = elevenKey ?? elKey ?? '';
      if (ek.isNotEmpty) {
        _elevenKey = ek;
        ok = await _prefs.setString(_kEleven, ek) && ok;
      }

      if (openaiKey != null && openaiKey.isNotEmpty) {
        _openaiKey = openaiKey;
        ok = await _prefs.setString(_kOpenAI, openaiKey) && ok;
      }

      if (mem0Key != null && mem0Key.isNotEmpty) {
        _mem0Key = mem0Key;
        ok = await _prefs.setString(_kMem0, mem0Key) && ok;
      }

      if (mem0UserId != null && mem0UserId.isNotEmpty) {
        _mem0UserId = mem0UserId;
        ok = await _prefs.setString(_kMem0User, mem0UserId) && ok;
      }

      if (livekitUrl != null && livekitUrl.isNotEmpty) {
        _livekitUrl = livekitUrl;
        ok = await _prefs.setString(_kLKUrl, livekitUrl) && ok;
      }

      if (livekitToken != null && livekitToken.isNotEmpty) {
        _livekitToken = livekitToken;
        ok = await _prefs.setString(_kLKToken, livekitToken) && ok;
      }

      // ── n8n Webhook (replaces Pipedream) ──────────────────────────────────
      if (n8nWebhookUrl != null && n8nWebhookUrl.isNotEmpty) {
        _n8nUrl = n8nWebhookUrl;
        ok = await _prefs.setString(_kN8nUrl, n8nWebhookUrl) && ok;
      }

      if (n8nAuthToken != null && n8nAuthToken.isNotEmpty) {
        _n8nToken = n8nAuthToken;
        ok = await _prefs.setString(_kN8nToken, n8nAuthToken) && ok;
      }

      // ── Google Sheets ─────────────────────────────────────────────────────
      if (sheetsId != null && sheetsId.isNotEmpty) {
        _sheetsId = sheetsId;
        ok = await _prefs.setString(_kSheetsId, sheetsId) && ok;
      }

      if (sheetsJson != null && sheetsJson.isNotEmpty) {
        _sheetsJson = sheetsJson;
        ok = await _prefs.setString(_kSheetsJson, sheetsJson) && ok;
      }

      // ── Misc ──────────────────────────────────────────────────────────────
      final gm = geminiModel ?? model ?? '';
      if (gm.isNotEmpty && geminiModels.any((m) => m['id'] == gm)) {
        _geminiModel = gm;
        ok = await _prefs.setString(_kModel, gm) && ok;
      }

      if (lang != null && lang.isNotEmpty) {
        _lang = lang;
        ok = await _prefs.setString(_kLang, lang) && ok;
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

      if (kDebugMode) debugPrint('ApiKeys.save ✅ ok=$ok');
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('ApiKeys.save: $e');
      return false;
    }
  }

  static bool _validGem(String k) =>
      RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);
  static bool validCurrent(String k) => _validGem(k);
  static Future<void> clear() async { await _prefs.clear(); await init(); }
  static Map<String, String> get headers => {'Content-Type': 'application/json'};
}
