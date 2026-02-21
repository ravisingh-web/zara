// lib/services/auto_type_service.dart
// Z.A.R.A. — Auto-Type Code Generation Service
// Types code directly into any text editor

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AutoTypeService {
  static final AutoTypeService _instance = AutoTypeService._internal();
  factory AutoTypeService() => _instance;
  AutoTypeService._internal();

  static const MethodChannel _channel = MethodChannel('com.mahakal.zara/accessibility');
  
  StreamController<Map<dynamic, dynamic>>? _eventController;
  Stream<Map<dynamic, dynamic>>? get eventStream => _eventController?.stream;
  
  bool _isTyping = false;
  bool get isTyping => _isTyping;
  
  String? _currentFilePath;
  String? get currentFilePath => _currentFilePath;

  /// Initialize service
  Future<void> initialize() async {
    _eventController = StreamController<Map<dynamic, dynamic>>.broadcast();
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSecurityEvent') {
        final data = call.arguments as Map<dynamic, dynamic>;
        debugPrint('🔐 Event: ${data['type']}');
        _eventController?.add(data);
        await _handleEvent(data);
      }
    });
    
    debugPrint('✅ Auto-Type Service Initialized');
  }

  /// Check if Accessibility Service is enabled
  Future<bool> isEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkAccessibilityEnabled');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ Check enabled error: $e');
      return false;
    }
  }

  /// Open Accessibility Settings
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('⚠️ Open settings error: $e');
    }
  }

  /// AUTO-TYPE: Generate and type code into active text field
  Future<bool> typeCode({
    required String code,
    String? filename,
    String? description,
  }) async {
    try {
      if (!await isEnabled()) {
        debugPrint('⚠️ Accessibility Service not enabled');
        return false;
      }

      _isTyping = true;
      _currentFilePath = filename;

      debugPrint('⌨️ Auto-typing ${code.length} characters...');

      // Save to file first (backup)
      if (filename != null) {
        await _saveToFile(filename, code);
      }

      // Type via accessibility
      await _channel.invokeMethod('typeText', {'text': code});

      debugPrint('✅ Auto-type completed');
      _isTyping = false;
      return true;

    } catch (e) {
      debugPrint('⚠️ Auto-type error: $e');
      _isTyping = false;
      return false;
    }
  }

  /// Save code to file (backup)
  Future<void> _saveToFile(String filename, String code) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final zaraFolder = Directory('${directory.path}/ZARA/Projects');
      
      if (!await zaraFolder.exists()) {
        await zaraFolder.create(recursive: true);
      }

      final file = File('${zaraFolder.path}/$filename');
      await file.writeAsString(code);
      
      debugPrint('💾 Code saved: ${file.path}');
      
      _currentFilePath = file.path;
    } catch (e) {
      debugPrint('⚠️ Save file error: $e');
    }
  }

  /// Open file in editor app
  Future<bool> openInEditor(String filePath) async {
    try {
      // Try to open with default editor
      // This would need url_launcher or open_file package
      debugPrint('📂 Opening in editor: $filePath');
      return true;
    } catch (e) {
      debugPrint('⚠️ Open editor error: $e');
      return false;
    }
  }

  /// Click on UI element by text
  Future<bool> clickOnText(String text) async {
    try {
      await _channel.invokeMethod('clickOnText', {'text': text});
      return true;
    } catch (e) {
      debugPrint('⚠️ Click error: $e');
      return false;
    }
  }

  /// Open app by package name
  Future<bool> openApp(String packageName) async {
    try {
      await _channel.invokeMethod('openApp', {'package': packageName});
      return true;
    } catch (e) {
      debugPrint('⚠️ Open app error: $e');
      return false;
    }
  }

  /// Handle incoming events
  Future<void> _handleEvent(Map<dynamic, dynamic> event) async {
    final type = event['type'] as String?;
    
    switch (type) {
      case 'text_field_focused':
        debugPrint('📝 Text field focused - ready to type');
        break;
      case 'auto_type_success':
        debugPrint('✅ Auto-type success: ${event['data']}');
        break;
      case 'auto_type_error':
        debugPrint('❌ Auto-type error: ${event['data']}');
        break;
    }
  }

  @override
  void dispose() {
    _eventController?.close();
  }
}
