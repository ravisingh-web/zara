// lib/services/camera_service.dart
// Z.A.R.A. — Camera Service for Guardian Mode
// ✅ Fully functional Front/Back camera control
// ✅ Intruder photo capture and gallery save logic

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart' as cam;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  cam.CameraController? _controller;
  List<cam.CameraDescription>? _cameras;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _cameras = await cam.availableCameras();
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('📸 Camera Service: ${_cameras?.length ?? 0} cameras found');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Camera initialization error: $e');
      rethrow;
    }
  }

  Future<bool> checkPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    if (kDebugMode) debugPrint('🔐 Camera permission: ${status.isGranted ? "Granted" : "Denied"}');
    return status.isGranted;
  }

  Future<void> initializeFrontCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) throw Exception('Camera permission denied');
    }
    await initialize();
    
    final cameras = _cameras ?? [];
    if (cameras.isEmpty) throw Exception('No cameras available');
    
    // Find the front camera
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == cam.CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    
    await _controller?.dispose();
    
    // Low resolution is faster and better for background/quick captures
    _controller = cam.CameraController(
      frontCamera, 
      cam.ResolutionPreset.medium, 
      enableAudio: false, 
      imageFormatGroup: cam.ImageFormatGroup.jpeg
    );
    
    await _controller!.initialize();
    if (kDebugMode) debugPrint('📸 Front camera initialized successfully');
  }

  // Chupke se (stealth) intruder ki photo capture karne ka main function
  Future<String?> captureIntruderPhoto() async {
    try {
      // 1. Initialize if not ready
      if (_controller == null || !_controller!.value.isInitialized) {
        await initializeFrontCamera();
      }
      
      if (_controller == null || !_controller!.value.isInitialized) {
         throw Exception('Camera failed to initialize');
      }
      
      // 2. Click Photo
      final cam.XFile photo = await _controller!.takePicture();
      
      // 3. Save to standard Pictures directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage unavailable');
      
      // Navigate to public Pictures folder
      final zaraFolder = Directory('${directory.path}/Pictures/ZARA_Intruders');
      if (!await zaraFolder.exists()) {
        await zaraFolder.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath = '${zaraFolder.path}/intruder_$timestamp.jpg';
      
      final savedFile = await File(photo.path).copy(photoPath);
      
      // Clean up cache
      await File(photo.path).delete();
      
      if (kDebugMode) debugPrint('🚨 Intruder photo saved at: $photoPath');
      
      // Stop camera after capture to save battery
      await dispose(); 
      
      return savedFile.path;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Photo capture error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    if (kDebugMode) debugPrint('📸 Camera Service disposed (Camera Released)');
  }
}
