// lib/services/camera_service.dart
// Z.A.R.A. — Camera Service for Guardian Mode
// ✅ Intruder Photo Capture • Permission Handling • File Management
// ✅ Front Camera Priority • High Resolution • Error Handling • Production-Ready

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Camera service for Z.A.R.A. Guardian Mode
/// Handles: Permission requests, camera initialization, intruder photo capture, file management
/// Uses front camera by default for discreet security monitoring
class CameraService {
  // ========== Singleton Pattern ==========
  
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  // ========== Camera State ==========
  
  /// Camera controller for capturing photos
  CameraController? _controller;
  
  /// List of available cameras on device
  List<CameraDescription>? _cameras;
  
  /// Whether camera service has been initialized
  bool _isInitialized = false;
  
  /// Whether front camera is currently active
  bool _isFrontCameraActive = false;

  // ========== Initialization ==========
  
  /// Initialize camera service — discovers available cameras
  /// Call once at app startup before using camera features
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Discover available cameras
      _cameras = await availableCameras();
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('📸 Camera Service: ${_cameras?.length ?? 0} cameras found');
        for (var i = 0; i < (_cameras?.length ?? 0); i++) {
          debugPrint('  • Camera $i: ${_cameras![i].lensDirection}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Camera initialization error: $e');
      }
      rethrow;
    }
  }

  // ========== Permission Handling ==========
  
  /// Check if camera permission is already granted
  Future<bool> checkPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission from user
  /// Returns true if granted, false if denied/permanently denied
  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    
    if (kDebugMode) {
      debugPrint('🔐 Camera permission: ${status.isGranted ? "Granted" : "Denied"}');
    }
    return status.isGranted;
  }

  /// Check if permission is permanently denied (user must enable in Settings)
  Future<bool> isPermissionPermanentlyDenied() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings for manual permission enable
  Future<void> openSettings() async {
    await openAppSettings();
  }

  // ========== Camera Setup ==========
  
  /// Initialize front camera for intruder detection (Guardian Mode)
  /// Prefers front camera, falls back to first available camera
  Future<void> initializeFrontCamera() async {
    // Check and request permission
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Camera permission denied — Enable in Settings for Guardian Mode');
      }
    }

    // Initialize service if not already done
    await initialize();

    // Find front-facing camera
    final frontCamera = _cameras?.firstWhere ?? _cameras?.first ?? _cameras?.first(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras?.first ?? (throw Exception('No camera available')),
    );

    if (frontCamera != null) {
      // Dispose existing controller if any
      await _controller?.dispose();
      
      // Create new controller with high resolution
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,  // No audio needed for security photos
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _controller!.initialize();
      _isFrontCameraActive = true;
      
      if (kDebugMode) {
        debugPrint('📸 Front camera initialized for Guardian mode');
      }
    }
  }

  /// Initialize back camera (for general photo capture)
  Future<void> initializeBackCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Camera permission denied');
      }
    }

    await initialize();

    final backCamera = _cameras?.firstWhere ?? _cameras?.first ?? _cameras?.first(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras?.first ?? (throw Exception('No camera available')),
    );

    if (backCamera != null) {
      await _controller?.dispose();
      
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _controller!.initialize();
      _isFrontCameraActive = false;
      
      if (kDebugMode) {
        debugPrint('📸 Back camera initialized');
      }
    }
  }

  // ========== Photo Capture ==========
  
  /// Capture intruder photo for Guardian Mode security
  /// Saves to /Pictures/ZARA/ folder with timestamp filename
  /// 
  /// Returns: Path to saved photo, or null on error
  Future<String?> captureIntruderPhoto() async {
    try {
      // Ensure camera is initialized
      if (_controller == null || !_controller!.value.isInitialized) {
        await initializeFrontCamera();
      }

      if (_controller == null || !_controller!.value.isInitialized) {
        throw Exception('Camera not initialized — Check permissions');
      }

      // Ensure camera is ready
      if (!_controller!.value.isTakingPicture) {
        // Small delay to ensure camera is ready
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Capture photo
      final XFile photo = await _controller!.takePicture();

      // Get storage directory for saving
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create ZARA folder in Pictures
      final zaraFolder = Directory('${directory.path}/../Pictures/ZARA');
      if (!await zaraFolder.exists()) {
        await zaraFolder.create(recursive: true);
      }

      // Generate unique timestamp filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath = '${zaraFolder.path}/intruder_$timestamp.jpg';

      // Copy photo to ZARA folder
      final savedFile = await File(photo.path).copy(photoPath);

      if (kDebugMode) {
        debugPrint('📸 Intruder photo saved: $photoPath');
        debugPrint('📁 File size: ${await savedFile.length()} bytes');
      }

      return savedFile.path;

    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Photo capture error: $e');
      }
      return null;
    }
  }

  /// Capture general photo (for user-initiated photos)
  Future<String?> capturePhoto({
    String? customFilename,
    String? customFolder,
  }) async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        await initializeFrontCamera();
      }

      if (_controller == null || !_controller!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      final XFile photo = await _controller!.takePicture();

      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage unavailable');

      final targetFolder = customFolder ?? '${directory.path}/../Pictures/ZARA';
      final folder = Directory(targetFolder);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final filename = customFilename ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final photoPath = '${folder.path}/$filename';

      final savedFile = await File(photo.path).copy(photoPath);
      return savedFile.path;

    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ General photo capture error: $e');
      return null;
    }
  }

  // ========== Photo Management ==========
  
  /// Get list of all intruder photos from ZARA folder
  /// Returns list of File objects sorted by modification time (newest first)
  Future<List<File>> getIntruderPhotos() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return [];

      final zaraFolder = Directory('${directory.path}/../Pictures/ZARA');
      if (!await zaraFolder.exists()) {
        return [];
      }

      final files = await zaraFolder.list().toList();
      
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.jpg') || file.path.endsWith('.jpeg'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get photos error: $e');
      return [];
    }
  }

  /// Get count of stored intruder photos
  Future<int> getIntruderPhotoCount() async {
    final photos = await getIntruderPhotos();
    return photos.length;
  }

  /// Get latest intruder photo (most recent)
  Future<File?> getLatestIntruderPhoto() async {
    final photos = await getIntruderPhotos();
    return photos.isNotEmpty ? photos.first : null;
  }

  /// Delete a specific intruder photo by path
  Future<bool> deleteIntruderPhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          debugPrint('🗑️ Intruder photo deleted: $photoPath');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Delete photo error: $e');
      return false;
    }
  }

  /// Delete intruder photo by index (from getIntruderPhotos list)
  Future<bool> deleteIntruderPhotoByIndex(int index) async {
    try {
      final photos = await getIntruderPhotos();
      if (index >= 0 && index < photos.length) {
        return await deleteIntruderPhoto(photos[index].path);
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Delete by index error: $e');
      return false;
    }
  }

  /// Clear all intruder photos from ZARA folder
  /// Returns count of deleted files
  Future<int> clearAllIntruderPhotos() async {
    try {
      final photos = await getIntruderPhotos();
      int deleted = 0;
      
      for (final photo in photos) {
        if (await deleteIntruderPhoto(photo.path)) {
          deleted++;
        }
      }
      
      if (kDebugMode) {
        debugPrint('🗑️ Cleared $deleted intruder photos');
      }
      return deleted;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Clear all photos error: $e');
      return 0;
    }
  }

  // ========== Camera Controls ==========
  
  /// Check if camera is currently initialized and ready
  bool get isCameraReady => 
      _controller != null && 
      _controller!.value.isInitialized && 
      !_controller!.value.isTakingPicture;

  /// Get current camera resolution preset
  String? get currentCameraName => 
      _controller?.description.name;

  /// Toggle flash/torch (if supported)
  Future<void> toggleFlash() async {
    if (!isCameraReady) return;
    
    try {
      final current = _controller!.value.flashMode;
      final next = current == FlashMode.off ? FlashMode.always : FlashMode.off;
      await _controller!.setFlashMode(next);
      
      if (kDebugMode) {
        debugPrint('🔦 Flash toggled: ${next == FlashMode.always ? "ON" : "OFF"}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Flash toggle error: $e');
    }
  }

  /// Set flash mode explicitly
  Future<void> setFlashMode(FlashMode mode) async {
    if (!isCameraReady) return;
    
    try {
      await _controller!.setFlashMode(mode);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Set flash mode error: $e');
    }
  }

  // ========== Lifecycle & Cleanup ==========
  
  /// Dispose camera controller and release resources
  /// Call when service is no longer needed (app close, screen dispose)
  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _cameras = null;
    _isInitialized = false;
    _isFrontCameraActive = false;
    
    if (kDebugMode) {
      debugPrint('📸 Camera Service disposed');
    }
  }

  /// Re-initialize camera (useful after permission grant or app resume)
  Future<void> reinitialize() async {
    dispose();
    await initialize();
  }

  // ========== Utility Methods ==========
  
  /// Get list of available camera descriptions
  List<CameraDescription>? get availableCameras => _cameras;

  /// Check if front camera is available on device
  bool get hasFrontCamera {
    return _cameras?.any((c) => c.lensDirection == CameraLensDirection.front) ?? false;
  }

  /// Check if back camera is available on device
  bool get hasBackCamera {
    return _cameras?.any((c) => c.lensDirection == CameraLensDirection.back) ?? false;
  }

  /// Get current camera lens direction
  CameraLensDirection? get currentLensDirection {
    if (_controller == null) return null;
    final camera = _cameras?.firstWhere ?? _cameras?.first ?? _cameras?.first(
      (c) => c.name == _controller!.description.name,
      orElse: () => _cameras?.first ?? (throw Exception('Camera not found')),
    );
    return camera?.lensDirection;
  }
}

// ========== Extension: Camera Helpers ==========

/// Extension to add convenience methods for CameraService
extension CameraServiceHelpers on CameraService {
  /// Quick check: Is Guardian Mode camera ready?
  Future<bool> isGuardianReady() async {
    if (!await checkPermission()) return false;
    if (!isCameraReady) {
      try {
        await initializeFrontCamera();
      } catch (_) {
        return false;
      }
    }
    return isCameraReady;
  }

  /// Capture photo with auto-retry on failure
  Future<String?> captureWithRetry({
    int maxAttempts = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await captureIntruderPhoto();
        if (result != null) return result;
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(retryDelay);
      }
    }
    return null;
  }
}
