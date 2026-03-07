// lib/services/automation_service.dart
// Z.A.R.A. v10.0 — AutomationService STUB
//
// ❌ n8n webhook   — REMOVED (not needed, LiveKit handles real-time comms)
// ❌ Google Sheets — REMOVED (no logging dependency)
//
// This file is kept as a no-op stub so existing imports don't break.
// All methods return silently without doing anything.
// You can safely delete this file and remove its import from any file
// after confirming no other code references it.

class AutomationService {
  static final AutomationService _i = AutomationService._();
  factory AutomationService() => _i;
  AutomationService._();

  // No-op callbacks — kept for API compatibility
  void Function(String rowText)? onNewSheetRow;

  // All methods are no-ops
  Future<bool> sendLog({
    required String type,
    required String content,
    Map<String, dynamic>? extra,
  }) async => false;

  Future<void> logConversation(String userMsg, String zaraReply) async {}
  Future<void> logGodModeCommand(String command, bool success)    async {}
  Future<void> logSecurityEvent(String eventType, {String? photoPath}) async {}

  void startPolling({Duration interval = const Duration(minutes: 2)}) {}
  void stopPolling() {}

  Future<bool> appendSheetRow(Map<String, dynamic> rowData) async => false;

  void dispose() {}
}
