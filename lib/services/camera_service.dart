// lib/services/camera_service.dart
// Z.A.R.A. — REAL Camera Service for Guardian Mode
// Intruder Photo Capture • No Fake Stuff

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  /// Initialize cameras (call once at app startup)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _cameras = await availableCameras();
      _isInitialized = true;
      debugPrint('📸 Camera Service: ${_cameras?.length} cameras found');
    } catch (e) {
      debugPrint('⚠️ Camera initialization error: $e');
    }
  }

  /// Check camera permission
  Future<bool> checkPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Initialize front camera for intruder detection
  Future<void> initializeFrontCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Camera permission denied');
      }
    }

    await initialize();
    
    // Find front camera
    final frontCamera = _cameras?.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    if (frontCamera != null) {
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      debugPrint('📸 Front camera initialized for Guardian mode');
    }
  }

  /// Capture intruder photo (REAL photo saved to storage)
  Future<String?> captureIntruderPhoto() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        await initializeFrontCamera();
      }

      if (!_controller!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      // Capture photo
      final XFile photo = await _controller!.takePicture();

      // Save to ZARA folder in Pictures
      final directory = await getExternalStorageDirectory();
      final zaraFolder = Directory('${directory?.path}/../Pictures/ZARA');
      
      if (!await zaraFolder.exists()) {
        await zaraFolder.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath = '${zaraFolder.path}/intruder_$timestamp.jpg';

      // Copy photo to ZARA folder
      final savedFile = await File(photo.path).copy(photoPath);

      debugPrint('📸 Intruder photo saved: $photoPath');
      return savedFile.path;

    } catch (e) {
      debugPrint('⚠️ Photo capture error: $e');
      return null;
    }
  }

  /// Get all intruder photos from ZARA folder
  Future<List<File>> getIntruderPhotos() async {
    final directory = await getExternalStorageDirectory();
    final zaraFolder = Directory('${directory?.path}/../Pictures/ZARA');
    
    if (!await zaraFolder.exists()) {
      return [];
    }

    final files = await zaraFolder.list().toList();
    return files
        .whereType<File>()
        .where((file) => file.path.endsWith('.jpg'))
        .toList();
  }

  /// Delete intruder photo
  Future<bool> deleteIntruderPhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Intruder photo deleted: $photoPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Delete photo error: $e');
      return false;
    }
  }

  /// Clear all intruder photos
  Future<int> clearAllIntruderPhotos() async {
    final photos = await getIntruderPhotos();
    int deleted = 0;
    
    for (final photo in photos) {
      if (await deleteIntruderPhoto(photo.path)) {
        deleted++;
      }
    }
    
    debugPrint('🗑️ Cleared $deleted intruder photos');
    return deleted;
  }

  @override
  void dispose() {
    _controller?.dispose();
  }
}
