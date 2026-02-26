// lib/services/camera_service.dart
// Z.A.R.A. — Camera Service for Guardian Mode
// ✅ 100% Real Working • No Dummy • Production-Ready • Android Compliant

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
  bool _isCapturing = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _cameras = await cam.availableCameras();
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('📸 Camera Service: ${_cameras?.length ?? 0} cameras found');
        final cams = _cameras;
        if (cams != null) {
          for (var i = 0; i < cams.length; i++) {
            debugPrint('  • Camera $i: ${cams[i].lensDirection}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Camera initialization error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<bool> checkPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.camera.request();
      if (kDebugMode) {
        debugPrint('🔐 Camera permission: ${status.isGranted ? "Granted ✓" : "Denied ✗"}');
      }
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Permission request error: $e');
      return false;
    }
  }

  Future<bool> isPermissionPermanentlyDenied() async {
    try {
      final status = await Permission.camera.status;
      return status.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open settings error: $e');
    }
  }

  Future<void> initializeFrontCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Camera permission denied — Enable in Settings for Guardian Mode');
      }
    }
    await initialize();
    final cameras = _cameras;
    if (cameras == null || cameras.isEmpty) {
      throw Exception('No cameras available on this device');
    }
    cam.CameraDescription? targetCamera;
    try {
      targetCamera = cameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.front,
      );
      if (kDebugMode) debugPrint('📸 Using front camera for Guardian Mode');
    } catch (_) {      targetCamera = cameras.first;
      if (kDebugMode) debugPrint('⚠️ Front camera not found — using back camera fallback');
    }
    if (targetCamera == null) {
      throw Exception('No usable camera found');
    }
    await _controller?.dispose();
    _controller = null;
    _controller = cam.CameraController(
      targetCamera,
      cam.ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );
    bool initialized = false;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await _controller!.initialize();
        initialized = true;
        break;
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Camera init attempt ${attempt + 1} failed: $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _controller?.dispose();
          _controller = cam.CameraController(
            targetCamera,
            cam.ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: cam.ImageFormatGroup.jpeg,
          );
        }
      }
    }
    if (!initialized) {
      throw Exception('Camera failed to initialize after 2 attempts');
    }
    if (kDebugMode) debugPrint('✅ Camera initialized successfully');
  }

  Future<void> initializeBackCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) throw Exception('Camera permission denied');
    }
    await initialize();
    final cameras = _cameras;
    if (cameras == null || cameras.isEmpty) {
      throw Exception('No cameras available');
    }    cam.CameraDescription? targetCamera;
    try {
      targetCamera = cameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.back,
      );
    } catch (_) {
      targetCamera = cameras.first;
    }
    if (targetCamera == null) throw Exception('No usable camera found');
    await _controller?.dispose();
    _controller = cam.CameraController(
      targetCamera,
      cam.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (kDebugMode) debugPrint('✅ Back camera initialized');
  }

  Future<String?> captureIntruderPhoto() async {
    if (_isCapturing) {
      if (kDebugMode) debugPrint('⚠️ Capture already in progress');
      return null;
    }
    _isCapturing = true;
    try {
      if (_controller == null || _controller?.value.isInitialized != true) {
        await initializeFrontCamera();
      }
      if (_controller == null || _controller?.value.isInitialized != true) {
        throw Exception('Camera not initialized — Check permissions');
      }
      if (_controller!.value.isTakingPicture) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      final cam.XFile photo = await _controller!.takePicture();
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Storage directory unavailable');
      }
      final zaraFolder = Directory('${directory.path}/Pictures/ZARA_Intruders');
      if (!await zaraFolder.exists()) {
        await zaraFolder.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath = '${zaraFolder.path}/intruder_$timestamp.jpg';
      final sourceFile = File(photo.path);
      if (!await sourceFile.exists()) {
        throw Exception('Captured photo not found');      }
      final savedFile = await sourceFile.copy(photoPath);
      try {
        await sourceFile.delete();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('🚨 Intruder photo saved: $photoPath');
        debugPrint('📁 File size: ${await savedFile.length()} bytes');
      }
      return savedFile.path;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Photo capture error: $e');
      return null;
    } finally {
      _isCapturing = false;
      await dispose();
    }
  }

  Future<String?> capturePhoto({String? customFilename, String? customFolder}) async {
    if (_isCapturing) return null;
    _isCapturing = true;
    try {
      if (_controller == null || _controller?.value.isInitialized != true) {
        await initializeFrontCamera();
      }
      if (_controller == null || _controller?.value.isInitialized != true) {
        throw Exception('Camera not initialized');
      }
      final cam.XFile photo = await _controller!.takePicture();
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage unavailable');
      final targetFolder = customFolder ?? '${directory.path}/Pictures/ZARA';
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
    } finally {
      _isCapturing = false;
    }
  }

  Future<List<File>> getIntruderPhotos() async {    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return [];
      final zaraFolder = Directory('${directory.path}/Pictures/ZARA_Intruders');
      if (!await zaraFolder.exists()) return [];
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

  Future<int> getIntruderPhotoCount() async {
    final photos = await getIntruderPhotos();
    return photos.length;
  }

  Future<File?> getLatestIntruderPhoto() async {
    final photos = await getIntruderPhotos();
    return photos.isNotEmpty ? photos.first : null;
  }

  Future<bool> deleteIntruderPhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) debugPrint('🗑️ Intruder photo deleted: $photoPath');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Delete photo error: $e');
      return false;
    }
  }

  Future<int> clearAllIntruderPhotos() async {
    try {
      final photos = await getIntruderPhotos();
      int deleted = 0;
      for (final photo in photos) {
        if (await deleteIntruderPhoto(photo.path)) {
          deleted++;
        }      }
      if (kDebugMode) debugPrint('🗑️ Cleared $deleted intruder photos');
      return deleted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Clear all photos error: $e');
      return 0;
    }
  }

  bool get isCameraReady {
    return _controller != null &&
           _controller?.value.isInitialized == true &&
           _controller?.value.isTakingPicture == false;
  }

  cam.CameraLensDirection? get currentLensDirection {
    if (_controller == null) return null;
    final cameras = _cameras;
    if (cameras == null) return null;
    try {
      final camera = cameras.firstWhere(
        (c) => c.name == _controller!.description.name,
      );
      return camera.lensDirection;
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleFlash() async {
    if (!isCameraReady) return;
    try {
      final current = _controller!.value.flashMode;
      final next = current == cam.FlashMode.off ? cam.FlashMode.torch : cam.FlashMode.off;
      await _controller!.setFlashMode(next);
      if (kDebugMode) {
        debugPrint('🔦 Flash: ${next == cam.FlashMode.torch ? "ON" : "OFF"}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Flash toggle error: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Controller dispose error: $e');
    }
    _controller = null;    _isCapturing = false;
    if (kDebugMode) debugPrint('📸 Camera Service disposed');
  }

  Future<void> reinitialize() async {
    await dispose();
    _isInitialized = false;
    await initialize();
  }

  List<cam.CameraDescription>? get availableCameras => _cameras;

  bool get hasFrontCamera {
    final cameras = _cameras;
    if (cameras == null) return false;
    return cameras.any((c) => c.lensDirection == cam.CameraLensDirection.front);
  }

  bool get hasBackCamera {
    final cameras = _cameras;
    if (cameras == null) return false;
    return cameras.any((c) => c.lensDirection == cam.CameraLensDirection.back);
  }
}

extension CameraServiceHelpers on CameraService {
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
      }    }
    return null;
  }
}
