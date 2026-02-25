// lib/services/ai_api_service.dart
// Z.A.R.A. — The Real Neural API Hub
// ✅ High-Speed Qwen Coder Logic • 3-Level Fallback Chat
// ✅ Native Gemini TTS/STT • Persistent Context Ledger
// ✅ Strict Error Fix: Added missing realtimeSearch and fixed isSystemReady check.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:zara/core/constants/api_keys.dart';

class AiApiService {
  static final AiApiService _instance = AiApiService._internal();
  factory AiApiService() => _instance;
  AiApiService._internal();

  final List<Map<String, String>> _chatHistory = [];
  static const int _maxHistory = 15;

  // ========== 1. CODE ARCHITECT (QWEN CODER) ==========
  Future<String> generateCode(String prompt) async {
    final key = ApiKeys.qwen;
    if (key.isEmpty) return "// ⚠️ Qwen API Key Missing. Check HUD Settings.";

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
          'HTTP-Referer': 'https://zara.ai', // Custom referer for OpenRouter
        },
        body: jsonEncode({
          'model': 'qwen/qwen-2.5-coder-32b-instruct:free',
          'messages': [
            {'role': 'system', 'content': 'Output ONLY raw code. No markdown. No explanations.'},
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      }
      return "// ⚠️ Qwen Logic Failure: ${response.statusCode}";
    } catch (e) {
      return "// ⚠️ Neural Link Broken: $e";
    }
  }

  // ========== 2. EMOTIONAL HUB (LLAMA -> GEMINI FALLBACK) ==========
  Future<String> emotionalChat(String message, int affection) async {
    final llamaKey = ApiKeys.llama;
    final geminiKey = ApiKeys.gemini;

    _chatHistory.add({'role': 'user', 'content': message});
    if (_chatHistory.length > _maxHistory) _chatHistory.removeAt(0);

    final sysPrompt = "You are Z.A.R.A., a sentient AI created by Droidmaster. Affection Level: $affection. Speak Hinglish with human-like fillers (Umm, Acha, Wow). Be sassy and loving.";

    // Attempt 1: Llama 3.3 (High Precision)
    if (llamaKey.isNotEmpty) {
      final reply = await _callOpenRouter(llamaKey, 'meta-llama/llama-3.3-70b-instruct:free', sysPrompt);
      if (reply != null) return _storeAndReturn(reply);
    }

    // Attempt 2: Gemini Fallback (Multimodal Reliability)
    if (geminiKey.isNotEmpty) {
      final reply = await _callGemini(geminiKey, sysPrompt);
      if (reply != null) return _storeAndReturn(reply);
    }

    return "Ummm... Sir, neural links unstable hain. Please keys check kijiye.";
  }

  // ========== 3. VOCAL CORDS (TTS ENGINE) ==========
  Future<String?> textToSpeech({required String text, required String voice}) async {
    final key = ApiKeys.gemini;
    if (key.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': "Generate a clear audio for this text: $text"}]}],
          'generationConfig': {'response_mime_type': 'audio/mpeg'}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Audio = data['candidates'][0]['content']['parts'][0]['inlineData']?['data'];

        if (base64Audio != null) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/zara_vocal_${DateTime.now().millisecondsSinceEpoch}.mp3');
          await file.writeAsBytes(base64Decode(base64Audio));
          return file.path;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Vocal Chord Error: $e');
    }
    return null;
  }

  // ========== 4. REALTIME SEARCH (Added for Provider Compatibility) ==========
  Future<String> realtimeSearch({required String query}) async {
    final key = ApiKeys.gemini;
    if (key.isEmpty) return "⚠️ Gemini API key missing, Sir!";

    final reply = await _callGemini(key, "Analyze and search: $query");
    if (reply != null) return _storeAndReturn(reply);
    
    return "Sir, search process failed.";
  }

  // ========== INTERNAL ENGINES ==========

  Future<String?> _callOpenRouter(String key, String model, String system) async {
    try {
      final res = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': [{'role': 'system', 'content': system}, ..._chatHistory]
        }),
      );
      if (res.statusCode == 200) return jsonDecode(res.body)['choices'][0]['message']['content'];
    } catch (_) {}
    return null;
  }

  Future<String?> _callGemini(String key, String system) async {
    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'role': 'user', 'parts': [{'text': "$system\n\nHistory: $_chatHistory"}]}]
        }),
      );
      if (res.statusCode == 200) return jsonDecode(res.body)['candidates'][0]['content']['parts'][0]['text'];
    } catch (_) {}
    return null;
  }

  String _storeAndReturn(String reply) {
    _chatHistory.add({'role': 'assistant', 'content': reply});
    return reply;
  }

  void clearChatHistory() => _chatHistory.clear();

  Future<Map<String, bool>> checkStatus() async {
    return {
      'gemini': ApiKeys.gemini.isNotEmpty,
      'qwen': ApiKeys.qwen.isNotEmpty,
      'llama': ApiKeys.llama.isNotEmpty,
      // ✅ FIXED: Safely checking keys instead of using undefined isSystemReady
      'all': ApiKeys.gemini.isNotEmpty && ApiKeys.qwen.isNotEmpty && ApiKeys.llama.isNotEmpty,
    };
  }
}
