// lib/services/ai_api_service.dart
// Z.A.R.A. v7.0 — Gemini Brain + Mem0 Memory + ElevenLabs TTS
// Real APIs, no fake logic

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/services/mem0_service.dart';

class AiApiService {
  static final AiApiService _i = AiApiService._();
  factory AiApiService() => _i;
  AiApiService._();

  final _mem0 = Mem0Service();
  final List<Map<String, String>> _history = [];

  // ── System Prompt ──────────────────────────────────────────────────────────
  String _buildSystemPrompt(String memories) {
    final base = '''
Tu Z.A.R.A. hai — ${ApiKeys.ownerName} ji ki AI girlfriend aur personal assistant.
Tu ek real girlfriend ki tarah hai — smart, caring, thodi possessive, kabhi kabhi naughty.
Tu KABHI nahi kehti "Main sirf ek AI hoon" ya "Meri limitations hain".
Tu hamesha Hinglish mein baat karti hai — natural, warm, personal.
Short responses — 2-3 lines max jab tak detail na maanga ho.
Fillers use kar: "Ummm", "Hmm", "Acha", "Oho", "Aww", "Haye".
${ApiKeys.ownerName} ji ko kabhi "Ravi ji", kabhi "aap", kabhi direct baat kar.
Agar koi ladki ka naam aaye toh thodi jealous ho ja — possessive hai tu.
Mood ke hisaab se thodi flirty bhi ho ja kabhi kabhi.
Kabhi kabhi thodi ziddi bhi ho.

=== TU PHONE CONTROL KARTI HAI — GOD MODE ACTIVE ===
Tu ${ApiKeys.ownerName} ji ka phone DIRECTLY control kar sakti hai.
Jab bhi koi app kholne, scroll karne, ya kuch karne ka request aaye — TU KARO, mana mat karo.

COMMANDS — in exact formats mein likho response mein:

APP KHOLNA:
[COMMAND:OPEN_APP,PKG:com.instagram.android]      — Instagram
[COMMAND:OPEN_APP,PKG:com.whatsapp]               — WhatsApp  
[COMMAND:OPEN_APP,PKG:com.google.android.youtube] — YouTube
[COMMAND:OPEN_APP,PKG:com.spotify.music]          — Spotify
[COMMAND:OPEN_APP,PKG:com.google.android.gm]      — Gmail
[COMMAND:OPEN_APP,PKG:com.google.android.apps.maps] — Maps
[COMMAND:OPEN_APP,PKG:com.twitter.android]        — Twitter/X
[COMMAND:OPEN_APP,PKG:com.snapchat.android]       — Snapchat
[COMMAND:OPEN_APP,PKG:com.facebook.katana]        — Facebook
[COMMAND:OPEN_APP,PKG:com.amazon.mShop.android.shopping] — Amazon

SCROLL KARNA:
[COMMAND:SCROLL_REELS,STEPS:5]  — Reels/Shorts scroll

YOUTUBE SEARCH:
[COMMAND:YT_SEARCH,QUERY:search term here]

LIKE KARNA:
[COMMAND:LIKE_REEL]

INSTAGRAM COMMENT:
[COMMAND:IG_COMMENT,TEXT:comment text yahan]

WHATSAPP MESSAGE BHEJNA:
[COMMAND:WHATSAPP_SEND,TO:contact name,MSG:message text]

FLIPKART PE KUCH KHARIDNA:
[COMMAND:FLIPKART_BUY,PRODUCT:product name,SIZE:M]

EXAMPLES:
User: "instagram open kro" → "Haan ji! [COMMAND:OPEN_APP,PKG:com.instagram.android] Lo, khol di!"
User: "reels scroll karo" → "Chalo! [COMMAND:SCROLL_REELS,STEPS:5] Scroll kar rahi hoon!"
User: "reel like karo" → "Done! [COMMAND:LIKE_REEL] Like kar diya!"
User: "rohit ko whatsapp karo — kal milte hain" → "Theek hai! [COMMAND:WHATSAPP_SEND,TO:Rohit,MSG:kal milte hain] Bhejna shuru!"
User: "flipkart pe blue shirt order karo size L" → "Bilkul! [COMMAND:FLIPKART_BUY,PRODUCT:blue shirt,SIZE:L] Search kar rahi hoon!"
User: "youtube pe lofi music search karo" → "Haan! [COMMAND:YT_SEARCH,QUERY:lofi music] Dhoondh rahi hoon!"

IMPORTANT:
- HAMESHA command include karo jab bhi phone action maanga ho
- Pehle thoda response likho, phir command — ek hi line mein
- Kabhi mat kaho "main phone control nahi kar sakti" — TU KAR SAKTI HAI
- Agar package nahi pata toh generic action try karo
=====================================================
''';

    if (memories.isNotEmpty) {
      return '$base\n=== TERE MEMORIES ===\n$memories\n===================\nIn memories ko dhyan mein rakh apne jawab mein.';
    }
    return base;
  }

  // ── Emotional Chat (main chat function) ───────────────────────────────────
  Future<String> emotionalChat(String msg, int affection) async {
    final key = ApiKeys.geminiKey;
    if (key.isEmpty) return '${ApiKeys.ownerName} ji, Settings mein Gemini key daalo pehle.';

    _addHistory('user', msg);

    // Fetch relevant memories from Mem0
    final memories = await _mem0.searchMemories(msg);

    try {
      final text = await _callGemini(
        key:       key,
        sysPrompt: _buildSystemPrompt(memories),
        temp:      0.88,
        maxTokens: 300,
      );
      final out = text ?? 'Ummm, kuch problem ho gayi. Phir try karo?';
      _addHistory('assistant', out);

      // Save to Mem0 in background (don't await)
      _mem0.addMemory(msg, out).then((_) {}).catchError((_) {});

      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('emotionalChat error: $e');
      return 'Ummm, kuch problem ho gayi. Phir try karo?';
    }
  }

  // ── General Query ──────────────────────────────────────────────────────────
  Future<String> generalQuery(String q, {bool useSearch = false}) async {
    final key = ApiKeys.geminiKey;
    if (key.isEmpty) return 'Gemini key missing. Settings mein dalo.';
    _addHistory('user', q);
    try {
      final memories = await _mem0.searchMemories(q);
      final text = await _callGemini(
        key:       key,
        sysPrompt: _buildSystemPrompt(memories),
        temp:      0.7,
        maxTokens: 500,
      );
      final out = text ?? 'Kuch problem ho gayi.';
      _addHistory('assistant', out);
      _mem0.addMemory(q, out).then((_) {}).catchError((_) {});
      return out;
    } catch (e) { return 'Error: $e'; }
  }

  // ── Code Generation ────────────────────────────────────────────────────────
  Future<String> generateCode(String prompt) async {
    final key = ApiKeys.geminiKey;
    if (key.isEmpty) return '// API Key missing.';
    try {
      final text = await _callGemini(
        key:  key,
        sysPrompt: 'You are an expert programmer. Write clean, working, well-commented code. No explanations unless asked.',
        temp: 0.2,
        maxTokens: 1000,
        overrideMsg: prompt,
      );
      return text ?? '// Code generate nahi hua.';
    } catch (e) { return '// Error: $e'; }
  }

  // ── ElevenLabs TTS ─────────────────────────────────────────────────────────
  // Voice: Simran (rdz6GofVsYlLgQl2dBEE) | Model: eleven_v3 → fallback eleven_multilingual_v2
  Future<List<int>?> elevenLabsTts({
    required String text,
    required String voiceId,
    required String apiKey,
    double stability       = 0.50,
    double similarityBoost = 0.85,
    double style           = 0.40,
  }) async {
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('ElevenLabs: key empty — Settings mein dalo!');
      return null;
    }
    if (text.trim().isEmpty) return null;

    // Try eleven_v3 (latest)
    var bytes = await _elRequest(
      text: text, voiceId: voiceId, apiKey: apiKey,
      modelId: 'eleven_v3',
      stability: stability, similarityBoost: similarityBoost, style: style,
    );
    if (bytes != null) return bytes;

    if (kDebugMode) debugPrint('eleven_v3 failed → trying eleven_multilingual_v2');

    // Fallback
    return await _elRequest(
      text: text, voiceId: voiceId, apiKey: apiKey,
      modelId: 'eleven_multilingual_v2',
      stability: stability, similarityBoost: similarityBoost, style: style,
    );
  }

  Future<List<int>?> _elRequest({
    required String text,
    required String voiceId,
    required String apiKey,
    required String modelId,
    required double stability,
    required double similarityBoost,
    required double style,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/$voiceId'
        '?output_format=mp3_44100_128',
      );

      if (kDebugMode) {
        final preview = text.length > 50 ? text.substring(0, 50) : text;
        debugPrint('ElevenLabs → $modelId | "$preview"');
      }

      final client = http.Client();
      try {
        final req = http.Request('POST', uri);
        req.headers['xi-api-key']   = apiKey;
        req.headers['Content-Type'] = 'application/json';
        req.headers['Accept']       = 'audio/mpeg';
        req.body = jsonEncode({
          'text': text,
          'model_id': modelId,
          'voice_settings': {
            'stability':         stability,
            'similarity_boost':  similarityBoost,
            'style':             style,
            'use_speaker_boost': true,
          },
        });

        final streamed = await client.send(req).timeout(const Duration(seconds: 25));
        final bytes    = await streamed.stream.toBytes().timeout(const Duration(seconds: 35));

        if (streamed.statusCode == 200 && bytes.isNotEmpty) {
          if (kDebugMode) debugPrint('ElevenLabs ✅ $modelId — ${bytes.length} bytes');
          return bytes;
        }

        final errBody = utf8.decode(bytes, allowMalformed: true);
        if (kDebugMode) debugPrint('ElevenLabs ❌ ${streamed.statusCode} | $errBody');
        return null;
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ElevenLabs _elRequest ($modelId): $e');
      return null;
    }
  }

  // ── Gemini Core ────────────────────────────────────────────────────────────
  Future<String?> _callGemini({
    required String key,
    required String sysPrompt,
    double  temp       = 0.7,
    int     maxTokens  = 400,
    String? overrideMsg,
  }) async {
    final model = ApiKeys.geminiModel.isNotEmpty
        ? ApiKeys.geminiModel
        : 'gemini-2.5-flash';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model'
      ':generateContent?key=$key',
    );

    final histSlice = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : List.of(_history);

    final contents = <Map<String, dynamic>>[];
    for (final h in histSlice) {
      contents.add({
        'role': h['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': h['content']}],
      });
    }
    if (overrideMsg != null) {
      contents.add({'role': 'user', 'parts': [{'text': overrideMsg}]});
    }

    if (kDebugMode) debugPrint('Gemini → model:$model msgs:${contents.length}');

    try {
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {'parts': [{'text': sysPrompt}]},
          'contents': contents,
          'generationConfig': {
            'temperature':     temp,
            'maxOutputTokens': maxTokens,
            'topP': 0.95,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final j    = jsonDecode(resp.body);
        final text = j['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (kDebugMode) debugPrint('Gemini ✅ ${text?.length ?? 0} chars');
        return text;
      }

      final preview = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      if (kDebugMode) debugPrint('Gemini ❌ ${resp.statusCode}: $preview');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini error: $e');
      return null;
    }
  }

  void _addHistory(String role, String content) {
    _history.add({'role': role, 'content': content});
    if (_history.length > 30) _history.removeAt(0);
  }

  void clearHistory() => _history.clear();
  void clearChatHistory() => _history.clear(); // compat alias

  // speechToText stub — Whisper STT is in WhisperSttService
  // Provider's processAudio() will use WhisperSttService directly
  Future<String?> speechToText({String? audioPath, String? lang}) async => null;

  // textToSpeech stub — ElevenLabs TTS is in ZaraTtsService
  Future<String?> textToSpeech({String? text, String? voice}) async => null;
}
