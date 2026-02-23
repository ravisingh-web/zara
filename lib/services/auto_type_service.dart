// lib/services/auto_type_service.dart
// Z.A.R.A. — Auto-Type Code Generation Service
// ✅ Types Code into Any Text Editor • File Backup • Accessibility Bridge
// ✅ Platform Channel • Event Streaming • Production-Ready

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Auto-Type Service for Z.A.R.A.
/// Enables auto-typing code into any text editor via Android Accessibility Service.
class AutoTypeService {
  // ========== Singleton Pattern ==========
  static final AutoTypeService _instance = AutoTypeService._internal();
  factory AutoTypeService() => _instance;
  AutoTypeService._internal();

  // ========== Platform Channel ==========
  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');

  // ========== Event Streaming ==========
  StreamController<Map<String, dynamic>>? _eventController;
  Stream<Map<String, dynamic>>? get eventStream => _eventController?.stream;

  // ========== Service State ==========
  bool _isTyping = false;
  bool get isTyping => _isTyping;
  String? _currentFilePath;
  String? get currentFilePath => _currentFilePath;
  double _typingProgress = 0.0;
  double get typingProgress => _typingProgress;

  // ========== Initialization ==========
  Future<void> initialize() async {
    try {
      _eventController = StreamController<Map<String, dynamic>>.broadcast();
      _channel.setMethodCallHandler(_handleNativeCall);
      if (kDebugMode) {
        debugPrint('✅ Auto-Type Service Initialized');
        debugPrint('💡 Tip: Focus a text field before calling typeCode()');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Auto-Type Service init error: $e');
      rethrow;
    }
  }

  /// Handle method calls from native Android Accessibility Service
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSecurityEvent':
        final data = call.arguments as Map<dynamic, dynamic>;
        final typedData = _sanitizeEventData(data);
        _eventController?.add(typedData);
        await _handleEvent(typedData);
        return true;
      case 'onAutoTypeProgress':
        final progress = call.arguments['progress'] as double? ?? 0.0;
        _typingProgress = progress;
        _eventController?.add({'type': 'progress', 'data': {'progress': progress}});
        return true;
      case 'onAutoTypeComplete':
        _isTyping = false;
        _typingProgress = 1.0;
        final charsTyped = call.arguments['characters'] as int? ?? 0;
        _eventController?.add({
          'type': 'auto_type_success',
          'data': {'characters': charsTyped, 'timestamp': DateTime.now().millisecondsSinceEpoch}
        });
        if (kDebugMode) debugPrint('✅ Auto-Type Complete: $charsTyped characters typed');
        return true;
      case 'onAutoTypeError':
        _isTyping = false;
        final error = call.arguments['error'] as String? ?? 'Unknown error';
        _eventController?.add({
          'type': 'auto_type_error',
          'data': {'error': error, 'timestamp': DateTime.now().millisecondsSinceEpoch}
        });
        if (kDebugMode) debugPrint('⚠️ Auto-Type Error: $error');
        return true;
      default:
        if (kDebugMode) debugPrint('❓ Unknown auto-type method: ${call.method}');
        return null;
    }
  }

  Map<String, dynamic> _sanitizeEventData(Map<dynamic, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key is String) sanitized[entry.key as String] = entry.value;
    }
    return sanitized;
  }

  // ========== Core Auto-Type Functionality ==========
  Future<bool> typeCode({
    required String code,
    String? filename,
    String? description,
    bool backupFirst = true,
    int delayBetweenChars = 10,
  }) async {
    try {
      if (!await isEnabled()) {
        if (kDebugMode) debugPrint('⚠️ Accessibility Service not enabled — Auto-Type unavailable');
        return false;
      }
      if (!await isTextFieldFocused()) {
        if (kDebugMode) debugPrint('⚠️ No text field focused — Please focus an editor first');
        return false;
      }
      _isTyping = true;
      _typingProgress = 0.0;
      _currentFilePath = filename;
      if (kDebugMode) {
        debugPrint('⌨️ Auto-typing ${code.length} characters...');
        if (filename != null) debugPrint('📁 Backup: $filename');
        if (description != null) debugPrint('📝 Description: $description');
      }
      if (backupFirst && filename != null) await _saveToFile(filename, code, description: description);
      
      // ✅ FIXED: Proper invokeMethod call
      final result = await _channel.invokeMethod<bool>('queueAutoType', {
        'text': code,
        'delayMs': delayBetweenChars,
        'filename': filename,
      });
      
      if (result == true) {
        if (kDebugMode) debugPrint('✅ Auto-Type Queued Successfully');
        return true;
      } else {
        _isTyping = false;
        if (kDebugMode) debugPrint('⚠️ Auto-Type Queue Failed');
        return false;
      }
    } catch (e) {
      _isTyping = false;
      _typingProgress = 0.0;
      if (kDebugMode) debugPrint('⚠️ Auto-Type Error: $e');
      return false;
    }
  }

  Future<bool> typeCodeSmart({
    required String code,
    required String filename,
    String? description,
    bool addImports = true,
    bool wrapInClass = false,
  }) async {
    var formattedCode = code;
    if (addImports && !formattedCode.contains('import ')) {
      final imports = ["import 'package:flutter/material.dart';", "import 'package:provider/provider.dart';"].join('\n');
      formattedCode = '$imports\n\n$formattedCode';
    }
    if (wrapInClass && !formattedCode.contains('class ')) {
      final className = _filenameToClassName(filename);
      formattedCode = '''
class $className extends StatelessWidget {
  const $className({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Generated by Z.A.R.A.')));
  }
}
$code
''';
    }
    return typeCode(code: formattedCode, filename: filename, description: description);
  }

  String _filenameToClassName(String filename) {
    final name = filename.replaceAll('.dart', '').split('/').last;
    return name.split('_').map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    }).join('');
  }

  // ========== File Backup ==========
  Future<String?> _saveToFile(String filename, String code, {String? description}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final zaraFolder = Directory('${directory.path}/ZARA/Projects');
      if (!await zaraFolder.exists()) await zaraFolder.create(recursive: true);
      final filePath = '${zaraFolder.path}/$filename';
      final file = File(filePath);
      final header = '''// $filename
// Generated by Z.A.R.A. • ${DateTime.now().toString()}
${description != null ? '// Description: $description\n' : ''}// ⚠️ Auto-typed via Accessibility Service
// Sir, ready hoon! ❤️

''';
      await file.writeAsString(header + code);
      _currentFilePath = filePath;
      if (kDebugMode) {
        debugPrint('💾 Code saved: $filePath');
        debugPrint('📊 File size: ${await file.length()} bytes');
      }
      return filePath;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Save file error: $e');
      return null;
    }
  }

  Future<List<File>> getSavedCodeFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final zaraFolder = Directory('${directory.path}/ZARA/Projects');
      if (!await zaraFolder.exists()) return [];
      final files = await zaraFolder.list().toList();
      return files.whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get saved files error: $e');
      return [];
    }
  }

  // ========== Editor Integration ==========
  Future<bool> openInEditor(String filePath) async {
    try {
      if (!await File(filePath).exists()) {
        if (kDebugMode) debugPrint('⚠️ File not found: $filePath');
        return false;
      }
      if (kDebugMode) {
        debugPrint('📂 Open in editor: $filePath');
        debugPrint('💡 Manual: Use a file manager to open with Acode/VS Code');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open editor error: $e');
      return false;
    }
  }

  /// ✅ FIXED: Return type is Future<void>, no return value needed
  Future<void> openEditorApp(String packageName) async {
    try {
      await _channel.invokeMethod('openApp', {'package': packageName});
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open editor app error: $e');
    }
  }

  // ========== Accessibility Bridge Methods ==========
  Future<bool> isEnabled() async {
    try {
      // ✅ FIXED: Proper return of result
      final result = await _channel.invokeMethod<bool>('checkAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check enabled error: $e');
      return false;
    }
  }

  /// ✅ FIXED: Return type is Future<void>, no return value needed
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      if (kDebugMode) debugPrint('🔓 Opened Accessibility Settings');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open settings error: $e');
    }
  }

  Future<bool> isTextFieldFocused() async {
    try {
      // ✅ FIXED: Proper return of result
      final result = await _channel.invokeMethod<bool>('isTextFieldFocused');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check text field error: $e');
      return false;
    }
  }

  Future<bool?> clickOnText(String text) async {
    try {
      final result = await _channel.invokeMethod<bool>('clickOnText', {'text': text});
      if (kDebugMode) debugPrint('👆 Click on "$text": ${result ?? false}');
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Click on text error: $e');
      return false;
    }
  }

  Future<bool?> openApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('openApp', {'package': packageName});
      if (kDebugMode) debugPrint('📱 Open app "$packageName": ${result ?? false}');
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open app error: $e');
      return false;
    }
  }

  // ========== Event Handling ==========
  Future<void> _handleEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};
    switch (type) {
      case 'text_field_focused':
        if (kDebugMode) debugPrint('📝 Text field focused — Ready to type');
        break;
      case 'auto_type_success':
        final chars = data['characters'] as int? ?? 0;
        if (kDebugMode) debugPrint('✅ Auto-Type Success: $chars characters typed');
        break;
      case 'auto_type_error':
        final error = data['error'] as String? ?? 'Unknown';
        if (kDebugMode) debugPrint('❌ Auto-Type Error: $error');
        break;
      case 'progress':
        final progress = data['progress'] as double? ?? 0.0;
        if (kDebugMode && progress % 0.25 < 0.01) debugPrint('⌨️ Typing progress: ${(progress * 100).toInt()}%');
        break;
      default:
        if (kDebugMode) debugPrint('🔐 Auto-Type Event: $type');
    }
  }

  // ========== Utility Methods ==========
  /// ✅ FIXED: Return type is Future<void>, no return value needed
  Future<void> cancelAutoType() async {
    try {
      await _channel.invokeMethod('cancelAutoType');
      _isTyping = false;
      _typingProgress = 0.0;
      if (kDebugMode) debugPrint('⌨️ Auto-Type Cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cancel auto-type error: $e');
    }
  }

  /// ✅ FIXED: Proper return of map, no premature return false
  Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final status = await _channel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      return {
        'enabled': await isEnabled(),
        'isTyping': _isTyping,
        'progress': _typingProgress,
        'currentFile': _currentFilePath,
        'textFieldFocused': await isTextFieldFocused(),
        ...?status?.map((key, value) => MapEntry(key.toString(), value)),
      };
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get service status error: $e');
      return {};
    }
  }

  // ========== Lifecycle ==========
  void dispose() {
    _eventController?.close();
    _eventController = null;
    _isTyping = false;
    _typingProgress = 0.0;
    _currentFilePath = null;
    if (kDebugMode) debugPrint('⌨️ Auto-Type Service disposed');
  }
}

// ========== Extension: Convenience Methods ==========
extension AutoTypeServiceHelpers on AutoTypeService {
  Future<bool> isReady() async {
    final enabled = await isEnabled();
    final fieldFocused = await isTextFieldFocused();
    return enabled && fieldFocused && !isTyping;
  }

  Future<bool> typeCodeWithProgress({
    required String code,
    String? filename,
    void Function(double progress)? onProgress,
  }) async {
    final subscription = eventStream?.listen((event) {
      if (event['type'] == 'progress' && onProgress != null) {
        final progress = event['data']?['progress'] as double? ?? 0.0;
        onProgress(progress);
      }
    });
    try {
      return await typeCode(code: code, filename: filename);
    } finally {
      await subscription?.cancel();
    }
  }

  Future<bool> waitForCompletion({Duration timeout = const Duration(seconds: 60)}) async {
    if (!isTyping) return true;
    final startTime = DateTime.now();
    while (isTyping && DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return !isTyping;
  }
}

// ========== Event Type Constants ==========
abstract final class AutoTypeEventType {
  static const String textFieldFocused = 'text_field_focused';
  static const String autoTypeSuccess = 'auto_type_success';
  static const String autoTypeError = 'auto_type_error';
  static const String progress = 'progress';
  static const String cancelled = 'cancelled';
}
