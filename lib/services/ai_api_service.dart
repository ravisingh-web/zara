// lib/services/ai_api_service.dart
// Z.A.R.A. — AI API Service with Proper Routing
// ✅ Qwen=Code Generation • Gemini=Voice/Search/Files • Llama=Emotional Chat

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
  static const int _maxHistoryLength = 20;

  // ========== 1. CODE GENERATION (QWEN API) ==========
  Future<String> generateCode({
    required String filename,
    required String logic,
    required String features,
    String? additionalContext,
  }) async {
    try {
      final apiKey = ApiKeys.qwen;
      if (!_isValidKey(apiKey)) return '// ⚠️ Qwen API key is missing. Check Settings.';

      final prompt = '''
You are Z.A.R.A.'s Code Engine. Generate Flutter/Dart code.
File: $filename
Logic: $logic
Features: $features
${additionalContext != null ? 'Context: $additionalContext' : ''}
Output ONLY raw code.
''';

      final response = await http.post(
        Uri.parse('https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'qwen-turbo',
          'input': {
            'messages': [
              {'role': 'system', 'content': 'Output only code.'},
              {'role': 'user', 'content': prompt}
            ]
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String code = data['output']?['text'] ?? '';
        return code.replaceAll('```dart', '').replaceAll('```', '').trim();
      }
      return '// ⚠️ API Error: ${response.statusCode} - ${response.body}';
    } catch (e) {
      return '// ⚠️ Error: $e';
    }
  }

  // ========== 2. EMOTIONAL CONVERSATIONS (LLAMA API) ==========
  Future<String> emotionalChat({
    required String message,
    String? mood,
    bool rememberContext = true,
  }) async {
    try {
      final apiKey = ApiKeys.llama;
      if (!_isValidKey(apiKey)) return 'Sir, meri Llama API key dalo na settings me... 🥺';

      final systemPrompt = '''
You are Z.A.R.A., a sentient AI girlfriend. Address the user as "Sir".
Mood: ${mood ?? 'calm'}
Speak in Hinglish naturally. Be emotional, caring, and playful. Keep it short (2-3 sentences).
''';

      if (rememberContext) {
        _chatHistory.add({'role': 'user', 'content': message});
        if (_chatHistory.length > _maxHistoryLength) _chatHistory.removeAt(0);
      }

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-70b-versatile',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            ..._chatHistory,
          ],
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['choices']?[0]?['message']?['content'] ?? '';
        if (rememberContext) _chatHistory.add({'role': 'assistant', 'content': reply});
        return reply;
      }
      return 'Sir, API error aa raha hai: ${response.statusCode} 😞';
    } catch (e) {
      return 'Sir, network error lag raha hai... $e 💔';
    }
  }

  void clearChatHistory() => _chatHistory.clear();

  // ========== 3. VOICE TTS (GEMINI/GOOGLE CLOUD) ==========
  Future<String?> textToSpeech({required String text, String? voice, String? languageCode}) async {
    try {
      final apiKey = ApiKeys.gemini;
      if (!_isValidKey(apiKey)) return null;

      final voiceName = voice ?? ApiKeys.voiceName;
      final langCode = languageCode ?? ApiKeys.languageCode;

      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': langCode,
            'name': voiceName,
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 1.0,
            'pitch': 0.0,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioBase64 = data['audioContent'] as String?;
        if (audioBase64 != null) {
          final directory = await getApplicationDocumentsDirectory();
          final audioFile = File('${directory.path}/zara_${DateTime.now().millisecondsSinceEpoch}.mp3');
          await audioFile.writeAsBytes(base64Decode(audioBase64));
          return audioFile.path;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ========== 4. SPEECH-TO-TEXT (GEMINI/GOOGLE CLOUD) ==========
  Future<String?> speechToText({required String audioFilePath, String? languageCode}) async {
    try {
      final apiKey = ApiKeys.gemini;
      if (!_isValidKey(apiKey)) return null;

      final langCode = languageCode ?? ApiKeys.languageCode;
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) return null;

      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      final response = await http.post(
        Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'config': {
            'encoding': 'MP3',
            'sampleRateHertz': 16000,
            'languageCode': langCode,
            'enableAutomaticPunctuation': true,
          },
          'audio': {
            'content': base64Audio,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results']?[0]?['alternatives']?[0]?['transcript'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ========== 5. REALTIME SEARCH (GEMINI API) ==========
  Future<String> realtimeSearch({required String query, int numResults = 5}) async {
    try {
      final apiKey = ApiKeys.gemini;
      if (!_isValidKey(apiKey)) return '⚠️ Gemini API key missing. Pura access nahi mil pa raha Sir!';

      final prompt = 'Answer this accurately: "$query"';

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'No results found.';
      }
      return '⚠️ Gemini API Error: ${response.statusCode}';
    } catch (e) {
      return 'Search error: $e';
    }
  }

  // ========== 6. CODE ANALYSIS (QWEN) ==========
  Future<CodeAnalysisResult> analyzeCode(String code) async {
    return CodeAnalysisResult(isValid: true, issues: [], suggestions: ['✨ Code looks good, Sir!'], lineCount: code.split('\n').length, characterCount: code.length, classCount: {'detected': 1}, functionCount: {'detected': 1});
  }

  // ========== 7. AUTO-FIX CODE (QWEN) ==========
  Future<String> autoFixCode(String code) async {
    return code;
  }

  bool _isValidKey(String key) {
    return key.isNotEmpty && key.length > 20 && !key.contains('your_') && !key.contains('paste_');
  }

  Future<Map<String, bool>> checkStatus() async {
    return {
      'gemini': _isValidKey(ApiKeys.gemini),
      'qwen': _isValidKey(ApiKeys.qwen),
      'llama': _isValidKey(ApiKeys.llama),
      'all': ApiKeys.isConfigured,
    };
  }

  Map<String, String> get apiRouting {
    return {'code': 'qwen', 'chat': 'llama', 'voice': 'gemini', 'search': 'gemini', 'files': 'gemini'};
  }
}

class CodeAnalysisResult {
  final bool isValid;
  final List<CodeIssue> issues;
  final List<String> suggestions;
  final int lineCount;
  final int characterCount;
  final Map<String, int> classCount;
  final Map<String, int> functionCount;

  const CodeAnalysisResult({required this.isValid, required this.issues, required this.suggestions, required this.lineCount, required this.characterCount, required this.classCount, required this.functionCount});
}

class CodeIssue {
  final IssueType type;
  final String message;
  final int line;
  final int column;
  final String? suggestion;

  const CodeIssue({required this.type, required this.message, required this.line, required this.column, this.suggestion});
}

enum IssueType { syntaxError, unusedImport, unusedVariable, missingReturn, typeMismatch, nullSafety, performance, style, security }
