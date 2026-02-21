// lib/services/ai_api_service.dart
// Z.A.R.A. — AI API Service
// ✅ Fixed: Removed ContentImage (using simpler approach)

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/constants/api_keys.dart';

class AiApiService {
  static final AiApiService _instance = AiApiService._internal();
  factory AiApiService() => _instance;
  AiApiService._internal();

  final List<Map<String, String>> _chatHistory = [];

  Future<String> generateCode({
    required String filename,
    required String logic,
    required String features,
  }) async {
    try {
      final apiKey = ApiKeys.qwen;
      if (!_isValid(apiKey)) {
        return '// ⚠️ Qwen API key not configured';
      }

      final prompt = 'Generate Flutter code for $filename. Logic: $logic. Features: $features.';

      final response = await http.post(
        Uri.parse('https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'qwen-turbo',
          'input': {'messages': [{'role': 'user', 'content': prompt}]},
          'parameters': {'temperature': 0.7, 'max_tokens': 8192}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String code = data['output']?['text'] ?? '';
        code = code.replaceAll('```dart', '').replaceAll('```', '').trim();
        return code;
      }
      return '// ⚠️ Qwen API Error: ${response.statusCode}';
    } catch (e) {
      return '// ⚠️ Error: $e';
    }
  }

  Future<String> emotionalChat({required String message, String? mood}) async {
    try {
      final apiKey = ApiKeys.llama;
      if (!_isValid(apiKey)) return 'Ji Sir, API key configure karein...';

      _chatHistory.add({'role': 'user', 'content': message});
      if (_chatHistory.length > 20) _chatHistory.removeAt(0);

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-70b-versatile',
          'messages': [
            {'role': 'system', 'content': 'You are Z.A.R.A., emotional AI girlfriend. Say "Sir". Use Hinglish.'},
            ..._chatHistory,
          ],
          'temperature': 0.9,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['choices']?[0]?['message']?['content'] ?? '';
        _chatHistory.add({'role': 'assistant', 'content': reply});
        return reply;
      }
      return 'Sir, network issue hai...';
    } catch (e) {
      return 'Ji Sir...';
    }
  }

  Future<String?> textToSpeech({required String text, String? voice}) async {
    try {
      final apiKey = ApiKeys.gemini;
      if (!_isValid(apiKey)) return null;

      final response = await http.post(
        Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': ApiKeys.languageCode, 'name': voice ?? ApiKeys.voiceName},
          'audioConfig': {'audioEncoding': 'MP3'}
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

  Future<Map<String, bool>> checkStatus() async {
    return {
      'gemini': _isValid(ApiKeys.gemini),
      'qwen': _isValid(ApiKeys.qwen),
      'llama': _isValid(ApiKeys.llama),
      'all': ApiKeys.isConfigured,
    };
  }

  bool _isValid(String key) {
    return key.isNotEmpty && key.length > 20 && !key.contains('your_');
  }

  void clearChatHistory() => _chatHistory.clear();
}
