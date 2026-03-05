// lib/services/automation_service.dart
// Z.A.R.A. v9.0 — Automation: n8n Webhook + Google Sheets
//
// ✅ sendLog()              — send any event to n8n webhook
// ✅ logConversation()      — log user↔Zara turns to Sheets via n8n
// ✅ logGodModeCommand()    — log every God Mode execution
// ✅ logSecurityEvent()     — Guardian mode alerts
// ✅ startPolling()         — poll Sheets for new rows, fire onNewSheetRow
// ✅ stopPolling()          — stop polling
// ✅ appendSheetRow()       — write new row to Sheets via n8n
// ✅ dispose()              — cleanup
//
// Migration: Pipedream → n8n
//   n8n free tier: https://cloud.n8n.io
//   Self-hosted:   https://docs.n8n.io/hosting/
//   Endpoint:      POST https://your-n8n-server/webhook/zara
//   Payload:       same JSON structure — existing logic unchanged

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zara/core/constants/api_keys.dart';

class AutomationService {
  static final AutomationService _i = AutomationService._();
  factory AutomationService() => _i;
  AutomationService._();

  // Callback — ZaraProvider subscribes → Zara speaks new row aloud
  void Function(String rowText)? onNewSheetRow;

  Timer?  _pollTimer;
  int     _lastRowCount = 0;
  bool    _polling      = false;
  bool    _disposed     = false;

  // ══════════════════════════════════════════════════════════════════════════
  // n8n WEBHOOK — send any event
  //
  // n8n Setup:
  //   1. Sign up at https://cloud.n8n.io (free) OR self-host
  //   2. New Workflow → Add node → Webhook
  //      Method: POST | Path: /webhook/zara
  //   3. Add node → Google Sheets → Append Row
  //      Map incoming JSON fields to sheet columns
  //   4. (Optional) Webhook → Header Auth
  //      Header name: X-Zara-Token → paste token in Settings
  //   5. Activate workflow → copy webhook URL → paste in Z.A.R.A. Settings
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> sendLog({
    required String type,
    required String content,
    Map<String, dynamic>? extra,
  }) async {
    final url = ApiKeys.n8nWebhookUrl;
    if (url.isEmpty) return false;

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (ApiKeys.n8nAuthToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${ApiKeys.n8nAuthToken}';
        headers['X-Zara-Token']  = ApiKeys.n8nAuthToken;
      }

      final resp = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'timestamp': DateTime.now().toIso8601String(),
              'owner':     ApiKeys.ownerName,
              'type':      type,
              'content':   content,
              if (extra != null) ...extra,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) debugPrint('n8n ✅ ${resp.statusCode} [$type]');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      if (kDebugMode) debugPrint('n8n sendLog: $e');
      return false;
    }
  }

  /// Log conversation turn — user message + Zara reply
  Future<void> logConversation(String userMsg, String zaraReply) async {
    if (ApiKeys.n8nWebhookUrl.isEmpty) return;
    unawaited(sendLog(
      type:    'conversation',
      content: userMsg,
      extra: {
        'user_message': userMsg,
        'zara_reply':   zaraReply,
        'model':        ApiKeys.geminiModel,
        'owner':        ApiKeys.ownerName,
      },
    ));
  }

  /// Log God Mode command execution
  Future<void> logGodModeCommand(String command, bool success) async {
    if (ApiKeys.n8nWebhookUrl.isEmpty) return;
    unawaited(sendLog(
      type:    'god_mode',
      content: command,
      extra:   {'success': success},
    ));
  }

  /// Log Guardian/security event
  Future<void> logSecurityEvent(String eventType, {String? photoPath}) async {
    if (ApiKeys.n8nWebhookUrl.isEmpty) return;
    unawaited(sendLog(
      type:    'security',
      content: eventType,
      extra: {
        if (photoPath != null) 'photo_path': photoPath,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GOOGLE SHEETS POLLING via n8n
  //
  // n8n workflow for read:
  //   Webhook (path: /webhook/zara) → Switch node (action == 'read_sheet')
  //   → Google Sheets (Read Rows) → Respond to Webhook
  //   Response body: { "rows": [ [...], [...] ] }
  // ══════════════════════════════════════════════════════════════════════════

  void startPolling({Duration interval = const Duration(minutes: 2)}) {
    if (_polling || _disposed) return;
    if (ApiKeys.n8nWebhookUrl.isEmpty || ApiKeys.sheetsId.isEmpty) return;
    _polling   = true;
    _pollTimer = Timer.periodic(interval, (_) => _pollSheets());
    if (kDebugMode) debugPrint('📊 Sheets polling via n8n: every ${interval.inMinutes}m');
  }

  void stopPolling() {
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollSheets() async {
    if (!_polling || _disposed || ApiKeys.n8nWebhookUrl.isEmpty) return;
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (ApiKeys.n8nAuthToken.isNotEmpty)
          'Authorization': 'Bearer ${ApiKeys.n8nAuthToken}',
        if (ApiKeys.n8nAuthToken.isNotEmpty)
          'X-Zara-Token': ApiKeys.n8nAuthToken,
      };

      final resp = await http
          .post(
            Uri.parse(ApiKeys.n8nWebhookUrl),
            headers: headers,
            body: jsonEncode({
              'action':      'read_sheet',
              'spreadsheet': ApiKeys.sheetsId,
              'owner':       ApiKeys.ownerName,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return;

      final data  = jsonDecode(resp.body) as Map<String, dynamic>;
      final rows  = (data['rows'] as List?) ?? [];
      final count = rows.length;

      if (_lastRowCount == 0) { _lastRowCount = count; return; }
      if (count > _lastRowCount) {
        final newRows = rows.skip(_lastRowCount).toList();
        _lastRowCount = count;
        for (final row in newRows) {
          final text = _rowToText(row);
          if (text.isNotEmpty) onNewSheetRow?.call(text);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_pollSheets: $e');
    }
  }

  String _rowToText(dynamic row) {
    if (row is Map)  return row.values.where((v) => v != null && '$v'.isNotEmpty).join(', ');
    if (row is List) return row.join(', ');
    return row.toString();
  }

  Future<bool> appendSheetRow(Map<String, dynamic> rowData) async {
    final url = ApiKeys.n8nWebhookUrl;
    if (url.isEmpty || ApiKeys.sheetsId.isEmpty) return false;
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (ApiKeys.n8nAuthToken.isNotEmpty)
          'Authorization': 'Bearer ${ApiKeys.n8nAuthToken}',
      };

      final resp = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'action':      'append_row',
              'spreadsheet': ApiKeys.sheetsId,
              'row':         rowData,
              'timestamp':   DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      if (kDebugMode) debugPrint('appendSheetRow: $e');
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    stopPolling();
  }
}
