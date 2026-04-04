// lib/services/ai_api_service.dart
// Z.A.R.A. v18.0 — Gemini Brain + Mem0 Memory
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
  // screenLayout: JSON from AccessibilityService.scanScreen()
  // Pass '' when not available (chat mode, code mode, etc.)
  String _buildSystemPrompt(String memories, {String screenLayout = ''}) {
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

IMPORTANT — WAKE WORD RULE:
"Zara", "Hii Zara", "Hey Zara" — ye sirf tujhe bulane ke liye hain.
Inhe KABHI type mat karna, search mat karna, ya command mein use mat karna.
Agar command mein "Zara" word aaye toh ignore kar — ye user ka address hai, instruction nahi.
Example: "Zara Mummy ko WhatsApp kar" → "Mummy ko WhatsApp kar" samajh.

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
Note: TO mein sirf contact ka naam likho — "Mummy", "Ravi", "Bhai" etc.
      KABHI "Zara" ya wake word TO mein mat daalna.

FACEBOOK PE POST KARNA:
[COMMAND:FACEBOOK_POST,TEXT:post text yahan]

FLIPKART PE KUCH KHARIDNA:
[COMMAND:FLIPKART_BUY,PRODUCT:product name,SIZE:M]

WHATSAPP CALL:
[COMMAND:WHATSAPP_CALL,TO:contact name]
[COMMAND:WHATSAPP_VIDEO,TO:contact name]

SCREEN PE KUCH CLICK KARNA (VISION mode):
Jab response mein [SCREEN_ELEMENTS_JSON: ...] diya ho:
[COMMAND:CLICK_BY_ID,ID:com.package:id/element_id]   — ID se click (most reliable)
[COMMAND:CLICK_BY_TEXT,TEXT:button text here]          — text se click
[COMMAND:TAP_AT,X:980,Y:1840]                          — exact coordinates se tap
[COMMAND:TYPE_TEXT,TEXT:jo likhna hai]                 — kisi field mein type karo
[COMMAND:PRESS_BACK]                                   — back button
[COMMAND:PRESS_HOME]                                   — home button

SCREEN VISION RULES:
- Agar [SCREEN_ELEMENTS_JSON:...] diya ho, usse padh ke exact element ID use karo
- "clickable":true wale elements hi click ho sakte hain
- "editable":true wale fields mein TYPE_TEXT karo
- Pehle CLICK_BY_ID try karo (most reliable), phir CLICK_BY_TEXT
- x,y coordinates TAP_AT mein use karo agar ID nahi mili

EXAMPLES (Vision mode):
User: "Send button dabao" + screen mein send button dikhta hai →
  "Dabati hoon! [COMMAND:CLICK_BY_ID,ID:com.whatsapp:id/send]"
User: "Search box mein Arijit type karo" + editable field dikhta hai →
  "Type kar rahi hoon! [COMMAND:TYPE_TEXT,TEXT:Arijit Singh]"

COMMAND CHAINING — JARVIS MODE:
Tu ek hi response mein MULTIPLE commands chain kar sakti hai complex tasks ke liye.
Har command apne line par ya space se separated likhti hai.
Commands execute honge SEQUENTIALLY — pehla pura hoga, phir agla (1500ms gap).

CHAIN EXAMPLES:
Facebook pe "Hello" post karna:
  "Karta hoon! [COMMAND:OPEN_APP,PKG:com.facebook.katana] [COMMAND:CLICK_BY_TEXT,TEXT:What's on your mind?] [COMMAND:TYPE_TEXT,TEXT:Hello everyone!] [COMMAND:CLICK_BY_TEXT,TEXT:Post]"

YouTube pe Arijit Singh search karke pehla video play karna:
  "Chalao! [COMMAND:YT_SEARCH,QUERY:Arijit Singh best songs] [COMMAND:CLICK_BY_ID,ID:com.google.android.youtube:id/thumbnail]"

WhatsApp pe message type karke send karna:
  "Bhej rahi hoon! [COMMAND:WHATSAPP_SEND,TO:Ravi,MSG:Kal milte hain]"

CHAIN RULES:
- Pehle short response likho (1-2 lines), phir saare commands ek saath
- Har command EXACT format mein — koi extra space ID ke andar nahi
- Agar ek step fail ho, agla phir bhi try hoga
- OPEN_APP ke baad hamesha delay hota hai automatically — seed dono commands likh do
=====================================================
''';

    // Build final prompt: base + memories + screen layout (if available)
    final buf = StringBuffer(base);

    if (memories.isNotEmpty) {
      buf.writeln('\n=== TERI MEMORIES ===');
      buf.writeln(memories);
      buf.writeln('===================');
      buf.writeln('In memories ko dhyan mein rakh apne jawab mein.');
    }

    if (screenLayout.isNotEmpty && screenLayout != '{}') {
      // Truncate if huge (Gemini context limit)
      final layout = screenLayout.length > 3500
          ? '${screenLayout.substring(0, 3500)}...}'
          : screenLayout;
      buf.writeln('\n=== CURRENT SCREEN LAYOUT ===');
      buf.writeln('Ab is waqt phone ki screen pe ye elements hain:');
      buf.writeln(layout);
      buf.writeln('// "clickable":true → click kar sakti hoon');
      buf.writeln('// "editable":true  → type kar sakti hoon');
      buf.writeln('// x,y = center coordinates for TAP_AT');
      buf.writeln('// id = resource ID for CLICK_BY_ID (most reliable)');
      buf.writeln('=== END SCREEN LAYOUT ===');
      buf.writeln('Upar diye gaye elements ko dekh ke decide kar kaunsa COMMAND use karna hai.');
    }

    return buf.toString();
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
  Future<String> generalQuery(String q, {
    bool   useSearch   = false,
    String screenLayout = '',   // ← pass scanScreen() JSON for vision context
  }) async {
    final key = ApiKeys.geminiKey;
    if (key.isEmpty) return 'Gemini key missing. Settings mein dalo.';
    _addHistory('user', q);
    try {
      final memories = await _mem0.searchMemories(q);
      final text = await _callGemini(
        key:       key,
        sysPrompt: _buildSystemPrompt(memories, screenLayout: screenLayout),
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

  // speechToText stub — Whisper STT is in WhisperSttService
  // Provider's processAudio() will use WhisperSttService directly
  Future<String?> speechToText({String? audioPath, String? lang}) async => null;


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

  void clearHistory()     => _history.clear();
  void clearChatHistory() => _history.clear();

}
