// lib/core/constants/api_keys.dart
// Z.A.R.A. v19.0 — Clean: Gemini only
// Vosk: REMOVED | ElevenLabs: REMOVED | OpenAI: REMOVED

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiKeys {
  ApiKeys._();
  static late SharedPreferences _p;

  static String _geminiKey    = '';
  static String _hfKey        = '';
  static String _mem0Key      = '';
  static String _mem0UserId   = 'zara_ravi';
  static String _geminiModel  = 'gemini-2.5-flash';
  static String _liveModel    = 'gemini-3.1-flash-live-preview';
  static String _ownerName    = 'Ravi';
  static int    _affection    = 85;
  static String _lang         = 'hi-IN';
  static String _livekitUrl   = '';
  static String _livekitToken = '';

  static const _kGemini    = 'gemini_key';
  static const _kHF        = 'hf_key';
  static const _kMem0      = 'mem0_key';
  static const _kMem0User  = 'mem0_user_id';
  static const _kModel     = 'gemini_model';
  static const _kLiveModel = 'live_model';
  static const _kOwner     = 'owner_name';
  static const _kAff       = 'affection';
  static const _kLang      = 'lang';
  static const _kLkUrl     = 'livekit_url';
  static const _kLkToken   = 'livekit_token';

  static const geminiModels = [
    {'id': 'gemini-2.5-flash',      'name': 'Gemini 2.5 Flash', 'desc': '⭐ Best'},
    {'id': 'gemini-2.0-flash',      'name': 'Gemini 2.0 Flash', 'desc': 'Stable'},
  ];

  static const liveModels = [
    {'id': 'gemini-3.1-flash-live-preview', 'name': '3.1 Flash Live', 'desc': '⭐ Latest'},
    {'id': 'gemini-2.5-flash-live-preview', 'name': '2.5 Flash Live', 'desc': 'Stable'},
  ];

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _geminiKey    = _p.getString(_kGemini)    ?? '';
    _hfKey        = _p.getString(_kHF)        ?? '';
    _mem0Key      = _p.getString(_kMem0)      ?? '';
    _mem0UserId   = _p.getString(_kMem0User)  ?? 'zara_ravi';
    _ownerName    = _p.getString(_kOwner)     ?? 'Ravi';
    _affection    = _p.getInt(_kAff)          ?? 85;
    _lang         = _p.getString(_kLang)      ?? 'hi-IN';
    _livekitUrl   = _p.getString(_kLkUrl)     ?? '';
    _livekitToken = _p.getString(_kLkToken)   ?? '';
    final saved   = _p.getString(_kModel)     ?? '';
    final valids  = geminiModels.map((m) => m['id']!).toList();
    _geminiModel  = valids.contains(saved) ? saved : 'gemini-2.5-flash';
    final lSaved  = _p.getString(_kLiveModel) ?? '';
    final lValids = liveModels.map((m) => m['id']!).toList();
    _liveModel    = lValids.contains(lSaved) ? lSaved : 'gemini-3.1-flash-live-preview';

    if (kDebugMode) {
      debugPrint('┌─ Z.A.R.A. v19 ───────────────────────');
      debugPrint('│  Gemini    : ${_geminiKey.isNotEmpty ? "✅" : "❌ MISSING"}');
      debugPrint('│  LiveModel : $_liveModel');
      debugPrint('│  HuggFace  : ${_hfKey.isNotEmpty ? "✅" : "✅ free tier"}');
      debugPrint('│  LiveKit   : ${_livekitUrl.isNotEmpty ? "✅" : "❌ not set"}');
      debugPrint('│  Vosk      : ❌ REMOVED');
      debugPrint('│  ElevenLabs: ❌ REMOVED');
      debugPrint('└───────────────────────────────────────');
    }
  }

  static String get geminiKey    => _geminiKey;
  static String get hfKey        => _hfKey;
  static String get mem0Key      => _mem0Key;
  static String get mem0UserId   => _mem0UserId;
  static String get geminiModel  => _geminiModel;
  static String get liveModel    => _liveModel;
  static String get ownerName    => _ownerName;
  static int    get affection    => _affection;
  static String get lang         => _lang;
  static String get key          => _geminiKey;
  static String get model        => _geminiModel;
  static String get owner        => _ownerName;
  static int    get aff          => _affection;
  static String get livekitUrl   => _livekitUrl;
  static String get livekitToken => _livekitToken;

  // Compat stubs
  static String get elevenKey  => '';
  static String get openaiKey  => '';
  static bool get elevenReady  => false;
  static bool get openaiReady  => false;
  static bool get geminiReady  => _geminiKey.isNotEmpty;
  static bool get hfReady      => true;
  static bool get ready        => _geminiKey.isNotEmpty;
  static bool get mem0Ready    => _mem0Key.isNotEmpty;
  static bool get livekitReady => _livekitUrl.isNotEmpty && _livekitToken.isNotEmpty;

  static Future<bool> save({
    String? geminiKey,
    String? hfKey,
    String? mem0Key,
    String? mem0UserId,
    String? geminiModel,
    String? liveModel,
    String? ownerName,
    int?    affection,
    String? lang,
    String? gemKey,
    String? model,
    String? owner,
    int?    aff,
    String? elevenKey,
    String? openaiKey,
    String? livekitUrl,
    String? livekitToken,
  }) async {
    try {
      var ok = true;
      final gk = geminiKey ?? gemKey ?? '';
      if (gk.isNotEmpty && _validGeminiKey(gk)) {
        _geminiKey = gk;
        ok = await _p.setString(_kGemini, gk) && ok;
      }
      if (hfKey?.isNotEmpty == true) {
        _hfKey = hfKey!;
        ok = await _p.setString(_kHF, hfKey) && ok;
      }
      if (mem0Key?.isNotEmpty == true) {
        _mem0Key = mem0Key!;
        ok = await _p.setString(_kMem0, mem0Key) && ok;
      }
      if (mem0UserId?.isNotEmpty == true) {
        _mem0UserId = mem0UserId!;
        ok = await _p.setString(_kMem0User, mem0UserId) && ok;
      }
      final gm = geminiModel ?? model ?? '';
      if (gm.isNotEmpty) {
        _geminiModel = gm;
        ok = await _p.setString(_kModel, gm) && ok;
      }
      if (liveModel?.isNotEmpty == true) {
        _liveModel = liveModel!;
        ok = await _p.setString(_kLiveModel, liveModel) && ok;
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
      if (lang?.isNotEmpty == true) {
        _lang = lang!;
        ok = await _p.setString(_kLang, lang) && ok;
      }
      if (livekitUrl != null) {
        _livekitUrl = livekitUrl;
        ok = await _p.setString(_kLkUrl, livekitUrl) && ok;
      }
      if (livekitToken != null) {
        _livekitToken = livekitToken;
        ok = await _p.setString(_kLkToken, livekitToken) && ok;
      }
      return ok;
    } catch (e) { return false; }
  }

  static bool _validGeminiKey(String k) =>
      RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k);
  static bool validCurrent(String k) => _validGeminiKey(k);
  static Future<void> clear() async { await _p.clear(); await init(); }
}
