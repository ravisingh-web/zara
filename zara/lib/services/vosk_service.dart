// lib/services/vosk_service.dart
// Z.A.R.A. v19 — Vosk REMOVED (stub file)
// Vosk wake word engine hata diya gaya.
// AccessibilityService still dispatches to this — stub handles silently.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoskService {
  static final VoskService _instance = VoskService._internal();
  factory VoskService() => _instance;
  VoskService._internal();

  /// Called by AccessibilityService for vosk-related native events.
  /// Since Vosk is removed, all events are silently ignored.
  Future<void> dispatchNativeCall(MethodCall call) async {
    if (kDebugMode) {
      debugPrint('VoskService (REMOVED): ignored native call → ${call.method}');
    }
    // No-op: Vosk has been removed from this build.
  }
}
