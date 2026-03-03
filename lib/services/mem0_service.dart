// lib/services/mem0_service.dart
// Z.A.R.A. v7.0 — Mem0 Long-Term Memory
// Real API: https://api.mem0.ai/v1/memories
// Ravi ji ki har baat yaad rakhti hai Zara

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zara/core/constants/api_keys.dart';

class Mem0Service {
  static final Mem0Service _i = Mem0Service._();
  factory Mem0Service() => _i;
  Mem0Service._();

  static const _baseUrl = 'https://api.mem0.ai/v1';

  // ── Add Memory ─────────────────────────────────────────────────────────────
  // Call karo jab conversation khatam ho ya koi important baat ho
  Future<bool> addMemory(String userMessage, String assistantReply) async {
    final key    = ApiKeys.mem0Key;
    final userId = ApiKeys.mem0UserId;
    if (key.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/memories/'),
        headers: {
          'Authorization': 'Token $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messages': [
            {'role': 'user',      'content': userMessage},
            {'role': 'assistant', 'content': assistantReply},
          ],
          'user_id': userId,
          'metadata': {
            'app': 'zara',
            'owner': ApiKeys.ownerName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (kDebugMode) debugPrint('Mem0 ✅ memory saved');
        return true;
      }
      if (kDebugMode) debugPrint('Mem0 addMemory ❌ ${resp.statusCode}: ${resp.body}');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Mem0 addMemory error: $e');
      return false;
    }
  }

  // ── Search Memories ────────────────────────────────────────────────────────
  // Relevant memories fetch karo current message ke liye
  Future<String> searchMemories(String query) async {
    final key    = ApiKeys.mem0Key;
    final userId = ApiKeys.mem0UserId;
    if (key.isEmpty) return '';

    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/memories/search/'),
        headers: {
          'Authorization': 'Token $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query':   query,
          'user_id': userId,
          'limit':   10,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data     = jsonDecode(resp.body);
        final memories = data['memories'] as List? ?? data as List? ?? [];
        if (memories.isEmpty) return '';

        final sb = StringBuffer();
        sb.writeln('=== Ravi ji ke baare mein yaadein ===');
        for (final m in memories.take(10)) {
          final text  = m['memory'] as String? ?? m['text'] as String? ?? '';
          if (text.isNotEmpty) sb.writeln('• $text');
        }
        final result = sb.toString().trim();
        if (kDebugMode) debugPrint('Mem0 🧠 ${memories.length} memories found');
        return result;
      }
      if (kDebugMode) debugPrint('Mem0 search ❌ ${resp.statusCode}');
      return '';
    } catch (e) {
      if (kDebugMode) debugPrint('Mem0 search error: $e');
      return '';
    }
  }

  // ── Get All Memories ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllMemories() async {
    final key    = ApiKeys.mem0Key;
    final userId = ApiKeys.mem0UserId;
    if (key.isEmpty) return [];

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/memories/?user_id=$userId'),
        headers: {'Authorization': 'Token $key'},
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = data['memories'] as List? ?? data as List? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('Mem0 getAll error: $e');
      return [];
    }
  }

  // ── Delete Memory ──────────────────────────────────────────────────────────
  Future<bool> deleteMemory(String memoryId) async {
    final key = ApiKeys.mem0Key;
    if (key.isEmpty) return false;
    try {
      final resp = await http.delete(
        Uri.parse('$_baseUrl/memories/$memoryId/'),
        headers: {'Authorization': 'Token $key'},
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) { return false; }
  }

  // ── Clear All Memories ─────────────────────────────────────────────────────
  Future<bool> clearAllMemories() async {
    final key    = ApiKeys.mem0Key;
    final userId = ApiKeys.mem0UserId;
    if (key.isEmpty) return false;
    try {
      final resp = await http.delete(
        Uri.parse('$_baseUrl/memories/?user_id=$userId'),
        headers: {'Authorization': 'Token $key'},
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) { return false; }
  }
}
