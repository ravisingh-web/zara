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
/// 
/// This service enables Z.A.R.A. to automatically type generated code
/// into any active text editor on the device using Android Accessibility Service.
/// 
/// Features:
/// - Auto-type code into Flutter/Dart editors (Acode, VS Code, etc.)
/// - Automatic file backup before typing
/// - Event streaming for typing progress/status
/// - Integration with AccessibilityService for native typing
/// 
/// ⚠️ Requires: Accessibility Service enabled + Text field focused
class AutoTypeService {
  // ========== Singleton Pattern ==========
  
  static final AutoTypeService _instance = AutoTypeService._internal();
  factory AutoTypeService() => _instance;
  AutoTypeService._internal();

  // ========== Platform Channel ==========
  
  /// Method channel for Flutter ↔ Native Accessibility communication
  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');

  // ========== Event Streaming ==========
  
  /// Stream controller for auto-type events
  StreamController<Map<String, dynamic>>? _eventController;
  
  /// Public stream for listening to auto-type events
  Stream<Map<String, dynamic>>? get eventStream => _eventController?.stream;

  // ========== Service State ==========
  
  /// Whether auto-type is currently in progress
  bool _isTyping = false;
  bool get isTyping => _isTyping;
  
  /// Path to currently typed/saved file (for reference)
  String? _currentFilePath;
  String? get currentFilePath => _currentFilePath;
  
  /// Current typing progress (0.0 to 1.0) for UI feedback
  double _typingProgress = 0.0;
  double get typingProgress => _typingProgress;

  // ========== Initialization ==========
  
  /// Initialize the auto-type service
  /// 
  /// Sets up:
  /// - Event stream for typing status updates
  /// - Method channel handler for native callbacks
  /// 
  /// Call once at app startup after AccessibilityService initialization
  Future<void> initialize() async {
    try {
      // Initialize event stream
      _eventController = StreamController<Map<String, dynamic>>.broadcast();

      // Set up method channel handler for native → Flutter events
      _channel.setMethodCallHandler(_handleNativeCall);

      if (kDebugMode) {
        debugPrint('✅ Auto-Type Service Initialized');
        debugPrint('💡 Tip: Focus a text field before calling typeCode()');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Auto-Type Service init error: $e');
      }
      rethrow;
    }
  }

  /// Handle method calls from native Android Accessibility Service
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSecurityEvent':
        // Forward security events to event stream
        final data = call.arguments as Map<dynamic, dynamic>;
        final typedData = _sanitizeEventData(data);
        _eventController?.add(typedData);
        await _handleEvent(typedData);
        return true;
        
      case 'onAutoTypeProgress':
        // Update typing progress for UI feedback
        final progress = call.arguments['progress'] as double? ?? 0.0;
        _typingProgress = progress;
        _eventController?.add({'type': 'progress', 'data': {'progress': progress}});
        return true;
        
      case 'onAutoTypeComplete':
        // Typing completed successfully
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
        // Typing failed
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

  /// Sanitize event data from native (ensure type safety)
  Map<String, dynamic> _sanitizeEventData(Map<dynamic, dynamic> data) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key is String) {
        sanitized[entry.key as String] = entry.value;
      }
    }
    return sanitized;
  }

  // ========== Core Auto-Type Functionality ==========
  
  /// Type code into the currently focused text field
  /// 
  /// [code]: The code string to type
  /// [filename]: Optional filename for backup save
  /// [description]: Optional description for logging
  /// [backupFirst]: Whether to save file before typing (default: true)
  /// [delayBetweenChars]: Delay between keystrokes in ms (default: 10ms for speed)
  /// 
  /// Returns: true if typing was queued successfully, false on error
  Future<bool> typeCode({
    required String code,
    String? filename,
    String? description,
    bool backupFirst = true,
    int delayBetweenChars = 10,
  }) async {
    try {
      // Check if Accessibility Service is enabled
      if (!await isEnabled()) {
        if (kDebugMode) {
          debugPrint('⚠️ Accessibility Service not enabled — Auto-Type unavailable');
        }
        return false;
      }

      // Check if a text field is focused
      if (!await isTextFieldFocused()) {
        if (kDebugMode) {
          debugPrint('⚠️ No text field focused — Please focus an editor first');
        }
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

      // Save backup file first (if requested)
      if (backupFirst && filename != null) {
        await _saveToFile(filename, code, description: description);
      }

      // Queue typing via Accessibility Service
      final result = await _channel.invokeMethod<bool>('queueAutoType', {
      return false;
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

  /// Type code with smart formatting (adds imports, class wrapper if needed)
  Future<bool> typeCodeSmart({
    required String code,
    required String filename,
    String? description,
    bool addImports = true,
    bool wrapInClass = false,
  }) async {
    // Smart formatting logic
    var formattedCode = code;
    
    // Add imports if requested and not present
    if (addImports && !formattedCode.contains('import ')) {
      final imports = [
        "import 'package:flutter/material.dart';",
        "import 'package:provider/provider.dart';",
      ].join('\n');
      formattedCode = '$imports\n\n$formattedCode';
    }
    
    // Wrap in class if requested
    if (wrapInClass && !formattedCode.contains('class ')) {
      final className = _filenameToClassName(filename);
      formattedCode = '''
class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Generated by Z.A.R.A.'),
      ),
    );
  }
}

$code
''';
    }
    
    return typeCode(
      code: formattedCode,
      filename: filename,
      description: description,
    );
  }

  /// Convert filename to Dart class name (e.g., 'main.dart' → 'Main')
  String _filenameToClassName(String filename) {
    final name = filename.replaceAll('.dart', '').split('/').last;
    return name.split('_').map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    }).join('');
  }

  // ========== File Backup ==========
  
  /// Save code to file in ZARA/Projects folder
  Future<String?> _saveToFile(String filename, String code, {String? description}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final zaraFolder = Directory('${directory.path}/ZARA/Projects');

      // Create folder if not exists
      if (!await zaraFolder.exists()) {
        await zaraFolder.create(recursive: true);
      }

      // Build file path
      final filePath = '${zaraFolder.path}/$filename';
      final file = File(filePath);

      // Add header comment with metadata
      final header = '''// $filename
// Generated by Z.A.R.A. • ${DateTime.now().toString()}
${description != null ? '// Description: $description\n' : ''}// ⚠️ Auto-typed via Accessibility Service
// Sir, ready hoon! ❤️

''';

      // Write file
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

  /// Get list of saved code files from ZARA/Projects
  Future<List<File>> getSavedCodeFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final zaraFolder = Directory('${directory.path}/ZARA/Projects');
      
      if (!await zaraFolder.exists()) return [];
      
      final files = await zaraFolder.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get saved files error: $e');
      return [];
    }
  }

  // ========== Editor Integration ==========
  
  /// Open file in default code editor app
  /// 
  /// Note: Requires url_launcher or open_file package for full implementation
  Future<bool> openInEditor(String filePath) async {
    try {
      if (!await File(filePath).exists()) {
        if (kDebugMode) debugPrint('⚠️ File not found: $filePath');
        return false;
      }

      // TODO: Implement with url_launcher or open_file package
      // For now, just log the path for manual opening
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

  /// Open specific editor app by package name
  Future<void> openEditorApp(String packageName) async {
    try {
      await _channel.invokeMethod('openApp', {'package': packageName});
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open editor app error: $e');
      return false;
    }
  }

  // ========== Accessibility Bridge Methods ==========
  
  /// Check if Accessibility Service is enabled
  Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAccessibilityEnabled');
      return false;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check enabled error: $e');
      return false;
    }
  }

  /// Open Accessibility Settings for user to enable service
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      return false;
      if (kDebugMode) {
        debugPrint('🔓 Opened Accessibility Settings');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open settings error: $e');
    }
  }

  /// Check if a text input field is currently focused
  Future<bool> isTextFieldFocused() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTextFieldFocused');
      return false;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Check text field error: $e');
      return false;
    }
  }

  /// Click on UI element by visible text (for navigation)
  Future<bool?> clickOnText(String text) async {
    try {
      final result = await _channel.invokeMethod<bool>('clickOnText', {'text': text});
      return false;
      if (kDebugMode) debugPrint('👆 Click on "$text": ${result ?? false}');
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Click on text error: $e');
      return false;
    }
  }

  /// Open app by package name
  Future<bool?> openApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('openApp', {'package': packageName});
      return false;
      if (kDebugMode) debugPrint('📱 Open app "$packageName": ${result ?? false}');
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open app error: $e');
      return false;
    }
  }

  // ========== Event Handling ==========
  
  /// Handle incoming auto-type events from native
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
        if (kDebugMode && progress % 0.25 < 0.01) {
          // Log at 25% intervals to avoid spam
          debugPrint('⌨️ Typing progress: ${(progress * 100).toInt()}%');
        }
        break;
        
      default:
        if (kDebugMode) debugPrint('🔐 Auto-Type Event: $type');
    }
  }

  // ========== Utility Methods ==========
  
  /// Cancel any pending auto-type operation
  Future<void> cancelAutoType() async {
    try {
      await _channel.invokeMethod('cancelAutoType');
      return false;
      _isTyping = false;
      _typingProgress = 0.0;
      if (kDebugMode) debugPrint('⌨️ Auto-Type Cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cancel auto-type error: $e');
    }
  }

  /// Get detailed service status for debugging
  Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final status = await _channel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      return false;
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
  
  /// Dispose service and clean up resources
  void dispose() {
    _eventController?.close();
    _eventController = null;
    _isTyping = false;
    _typingProgress = 0.0;
    _currentFilePath = null;
    
    if (kDebugMode) {
      debugPrint('⌨️ Auto-Type Service disposed');
    }
  }
}

// ========== Extension: Convenience Methods ==========

/// Extension to add convenience methods for AutoTypeService
extension AutoTypeServiceHelpers on AutoTypeService {
  /// Quick check: Is auto-type ready to use?
  Future<bool> isReady() async {
    final enabled = await isEnabled();
    final fieldFocused = await isTextFieldFocused();
    return enabled && fieldFocused && !isTyping;
  }
  
  /// Type code with progress callback
  Future<bool> typeCodeWithProgress({
    required String code,
    String? filename,
    void Function(double progress)? onProgress,
  }) async {
    // Subscribe to progress events
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
  
  /// Wait for auto-type to complete (with timeout)
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

/// Constants for auto-type event types (for type-safe filtering)
abstract final class AutoTypeEventType {
  static const String textFieldFocused = 'text_field_focused';
  static const String autoTypeSuccess = 'auto_type_success';
  static const String autoTypeError = 'auto_type_error';
  static const String progress = 'progress';
  static const String cancelled = 'cancelled';
}
