// lib/core/constants/api_keys.dart
// Z.A.R.A. v15.0 — API Keys (Clean)
//
// ╔══════════════════════════════════════════════════════════════════╗
// ║  Active Services                                                 ║
// ║  1. Gemini        → AI Brain (chat + vision + God Mode)         ║
// ║  2. ElevenLabs    → Anjura TTS voice (streaming)                ║
// ║  3. OpenAI        → Whisper STT (command recognition)           ║
// ║  4. Mem0          → Long-term neural memory (optional)          ║
// ║  5. LiveKit       → Real-time voice room (optional)             ║
// ║  6. Vosk          → Wake word OFFLINE — zero API key needed     ║
// ╚══════════════════════════════════════════════════════════════════╝
// ❌ n8n webhooks  — PERMANENTLY REMOVED
// ❌ Google Sheets — PERMANENTLY REMOVED

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeys {
  ApiKeys._(); // no instances

  static late SharedPreferences _p;

  // ── In-memory values ───────────────────────────────────────────────────────
  static String _geminiKey    = '';
  static String _elevenKey    = '';
  static String _openaiKey    = '';
  static String _mem0Key      = '';
  static String _mem0UserId   = 'zara_ravi';
  static String _livekitUrl   = '';
  static String _livekitToken = '';
  static String _geminiModel  = 'gemini-2.5-flash';
  static String _lang         = 'hi-IN';
  static String _ownerName    = 'Ravi';
  static int    _affection    = 85;

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const _kGemini   = 'gemini_key';
  static const _kEleven   = 'eleven_key';
  static const _kOpenAI   = 'openai_key';
  static const _kMem0     = 'mem0_key';
  static const _kMem0User = 'mem0_user_id';
  static const _kLKUrl    = 'livekit_url';
  static const _kLKToken  = 'livekit_token';
  static const _kModel    = 'gemini_model';
  static const _kLang     = 'lang';
  static const _kOwner    = 'owner_name';
  static const _kAff      = 'affection';

  // ── Voice constants ────────────────────────────────────────────────────────
  static const String anjuraVoiceId = 'rdz6GofVsYlLgQl2dBEE';
  static const String voice         = anjuraVoiceId; // alias

  // ── Gemini model list ──────────────────────────────────────────────────────
  static const List<Map<String, String>> geminiModels = [
    {'id': 'gemini-2.5-flash',      'name': 'Gemini 2.5 Flash', 'desc': '⭐ Best'},
    {'id': 'gemini-2.5-flash-lite', 'name': 'Gemini 2.5 Lite',  'desc': 'Fastest'},
    {'id': 'gemini-2.0-flash',      'name': 'Gemini 2.0 Flash', 'desc': 'Stable'},
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // INIT — call once from main() before runApp()
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();

    _geminiKey    = _p.getString(_kGemini)   ?? '';
    _elevenKey    = _p.getString(_kEleven)   ?? '';
    _openaiKey    = _p.getString(_kOpenAI)   ?? '';
    _mem0Key      = _p.getString(_kMem0)     ?? '';
    _mem0UserId   = _p.getString(_kMem0User) ?? 'zara_ravi';
    _livekitUrl   = _p.getString(_kLKUrl)    ?? '';
    _livekitToken = _p.getString(_kLKToken)  ?? '';
    _lang         = _p.getString(_kLang)     ?? 'hi-IN';
    _ownerName    = _p.getString(_kOwner)    ?? 'Ravi';
    _affection    = _p.getInt(_kAff)         ?? 85;

    final saved  = _p.getString(_kModel) ?? '';
    final valids = geminiModels.map((m) => m['id']!).toList();
    _geminiModel = valids.contains(saved) ? saved : 'gemini-2.5-flash';

    if (kDebugMode) {
      debugPrint('┌─ ApiKeys ─────────────────────────────');
      debugPrint('│  Gemini     : ${_geminiKey.isNotEmpty  ? "✅ set" : "❌ MISSING"}');
      debugPrint('│  ElevenLabs : ${_elevenKey.isNotEmpty  ? "✅ set" : "❌ MISSING"}');
      debugPrint('│  OpenAI     : ${_openaiKey.isNotEmpty  ? "✅ set" : "— optional"}');
      debugPrint('│  LiveKit    : ${_livekitUrl.isNotEmpty ? "✅ set" : "— optional"}');
      debugPrint('│  Mem0       : ${_mem0Key.isNotEmpty    ? "✅ set" : "— optional"}');
      debugPrint('│  Vosk       : ✅ offline (no key)');
      debugPrint('│  Model      : $_geminiModel');
      debugPrint('└───────────────────────────────────────');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  static String get geminiKey    => _geminiKey;
  static String get elevenKey    => _elevenKey;
  static String get openaiKey    => _openaiKey;
  static String get mem0Key      => _mem0Key;
  static String get mem0UserId   => _mem0UserId;
  static String get livekitUrl   => _livekitUrl;
  static String get livekitToken => _livekitToken;
  static String get geminiModel  => _geminiModel;
  static String get lang         => _lang;
  static String get ownerName    => _ownerName;
  static int    get affection    => _affection;

  // Short aliases (used throughout codebase)
  static String get gemKey => _geminiKey;
  static String get elKey  => _elevenKey;
  static String get key    => _geminiKey;
  static String get model  => _geminiModel;
  static String get owner  => _ownerName;
  static int    get aff    => _affection;

  // Convenience list alias
  static List<Map<String, String>> get gemModels => geminiModels;

  // ── Ready flags ────────────────────────────────────────────────────────────
  static bool get geminiReady  => _geminiKey.isNotEmpty;
  static bool get elevenReady  => _elevenKey.isNotEmpty;
  static bool get openaiReady  => _openaiKey.isNotEmpty;
  static bool get mem0Ready    => _mem0Key.isNotEmpty;
  static bool get livekitReady => _livekitUrl.isNotEmpty && _livekitToken.isNotEmpty;
  static bool get ready        => _geminiKey.isNotEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE
  // ══════════════════════════════════════════════════════════════════════════

  static Future<bool> save({
    String? geminiKey,
    String? elevenKey,
    String? openaiKey,
    String? mem0Key,
    String? mem0UserId,
    String? livekitUrl,
    String? livekitToken,
    String? geminiModel,
    String? lang,
    String? ownerName,
    int?    affection,
    // Short-name aliases
    String? gemKey,
    String? elKey,
    String? model,
    String? owner,
    int?    aff,
  }) async {
    try {
      var ok = true;

      final gk = geminiKey ?? gemKey ?? '';
      if (gk.isNotEmpty) {
        if (!_validGeminiKey(gk)) {
          if (kDebugMode) debugPrint('ApiKeys.save: invalid Gemini key format');
          return false;
        }
        _geminiKey = gk;
        ok = await _p.setString(_kGemini, gk) && ok;
      }

      final ek = elevenKey ?? elKey ?? '';
      if (ek.isNotEmpty) {
        _elevenKey = ek;
        ok = await _p.setString(_kEleven, ek) && ok;
      }

      if (openaiKey?.isNotEmpty == true) {
        _openaiKey = openaiKey!;
        ok = await _p.setString(_kOpenAI, openaiKey) && ok;
      }

      if (mem0Key?.isNotEmpty == true) {
        _mem0Key = mem0Key!;
        ok = await _p.setString(_kMem0, mem0Key) && ok;
      }

      if (mem0UserId?.isNotEmpty == true) {
        _mem0UserId = mem0UserId!;
        ok = await _p.setString(_kMem0User, mem0UserId) && ok;
      }

      if (livekitUrl?.isNotEmpty == true) {
        _livekitUrl = livekitUrl!;
        ok = await _p.setString(_kLKUrl, livekitUrl) && ok;
      }

      if (livekitToken?.isNotEmpty == true) {
        _livekitToken = livekitToken!;
        ok = await _p.setString(_kLKToken, livekitToken) && ok;
      }

      final gm = geminiModel ?? model ?? '';
      if (gm.isNotEmpty && geminiModels.any((m) => m['id'] == gm)) {
        _geminiModel = gm;
        ok = await _p.setString(_kModel, gm) && ok;
      }

      if (lang?.isNotEmpty == true) {
        _lang = lang!;
        ok = await _p.setString(_kLang, lang) && ok;
      }

      final on = ownerName ?? owner ?? '';
      if (on.isNotEmpty) {
        _ownerName = on;
        ok = await _p.setString(_kOwner, on) && ok;
      }

      final af = affection ?? aff;
      if (af != null) {
        _affection = af.clamp(0, 100);
        ok = await _p.setInt(_kAff, _affection) && ok;
      }

      if (kDebugMode) debugPrint('ApiKeys.save ✅ ok=$ok');
      return ok;
    } catch (e) {
      if (kDebugMode) debugPrint('ApiKeys.save ❌ $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILS
  // ══════════════════════════════════════════════════════════════════════════

  static bool _validGeminiKey(String k) =>
      RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);

  static bool validCurrent(String k) => _validGeminiKey(k);

  static Future<void> clear() async {
    await _p.clear();
    await init();
  }

  static Map<String, String> get headers =>
      {'Content-Type': 'application/json'};
}
