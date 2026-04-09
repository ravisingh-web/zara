// lib/services/vosk_service.dart
// Z.A.R.A. v19 — Vosk REMOVED (stub file)
// Vosk wake word engine hata diya gaya.
// AccessibilityService still dispatches to this — stub silently ignores.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoskService {
  static final VoskService _instance = VoskService._internal();
  factory VoskService() => _instance;
  VoskService._internal();

  Future<void> dispatchNativeCall(MethodCall call) async {
    if (kDebugMode) {
      debugPrint('VoskService (REMOVED): ignored → ${call.method}');
    }
    // No-op: Vosk removed from this build.
  }
}
