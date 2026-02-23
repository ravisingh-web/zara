// lib/services/camera_service.dart
// Z.A.R.A. — Camera Service for Guardian Mode

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart' as cam; // ✅ ALIAS ADDED
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
      _cameras = await cam.availableCameras(); // ✅ FORCE PACKAGE CALL
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

  Future<bool> isPermissionPermanentlyDenied() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  Future<void> openSettings() async => await openAppSettings();

  Future<void> initializeFrontCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) throw Exception('Camera permission denied');
    }
    await initialize();
    final cameras = _cameras ?? [];
    if (cameras.isEmpty) throw Exception('No cameras available');
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == cam.CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    await _controller?.dispose();
    _controller = cam.CameraController(frontCamera, cam.ResolutionPreset.high, enableAudio: false, imageFormatGroup: cam.ImageFormatGroup.jpeg);
    await _controller!.initialize();
    if (kDebugMode) debugPrint('📸 Front camera initialized');
  }

  Future<void> initializeBackCamera() async {
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) throw Exception('Camera permission denied');
    }
    await initialize();
    final cameras = _cameras ?? [];
    if (cameras.isEmpty) throw Exception('No cameras available');
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == cam.CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    await _controller?.dispose();
    _controller = cam.CameraController(backCamera, cam.ResolutionPreset.high, enableAudio: false, imageFormatGroup: cam.ImageFormatGroup.jpeg);
    await _controller!.initialize();
    if (kDebugMode) debugPrint('📸 Back camera initialized');
  }

  Future<String?> captureIntruderPhoto() async {
    try {
      if (_controller?.value.isInitialized != true) await initializeFrontCamera();
      if (_controller?.value.isInitialized != true) throw Exception('Camera not initialized');
      if (_controller?.value.isTakingPicture == false) await Future.delayed(const Duration(milliseconds: 200));
      final cam.XFile photo = await _controller!.takePicture();
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage unavailable');
      final zaraFolder = Directory('${directory.path}/../Pictures/ZARA');
      if (!await zaraFolder.exists()) await zaraFolder.create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final photoPath = '${zaraFolder.path}/intruder_$timestamp.jpg';
      final savedFile = await File(photo.path).copy(photoPath);
      if (kDebugMode) debugPrint('📸 Intruder photo saved: $photoPath');
      return savedFile.path;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Photo capture error: $e');
      return null;
    }
  }

  Future<String?> capturePhoto({String? customFilename, String? customFolder}) async {
    try {
      if (_controller?.value.isInitialized != true) await initializeFrontCamera();
      if (_controller?.value.isInitialized != true) throw Exception('Camera not initialized');
      final cam.XFile photo = await _controller!.takePicture();
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage unavailable');
      final targetFolder = customFolder ?? '${directory.path}/../Pictures/ZARA';
      final folder = Directory(targetFolder);
      if (!await folder.exists()) await folder.create(recursive: true);
      final filename = customFilename ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final photoPath = '${folder.path}/$filename';
      final savedFile = await File(photo.path).copy(photoPath);
      return savedFile.path;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ General photo capture error: $e');
      return null;
    }
  }

  Future<List<File>> getIntruderPhotos() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return [];
      final zaraFolder = Directory('${directory.path}/../Pictures/ZARA');
      if (!await zaraFolder.exists()) return [];
      final files = await zaraFolder.list().toList();
      return files.whereType<File>().where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.jpeg')).toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Get photos error: $e');
      return [];
    }
  }

  Future<int> getIntruderPhotoCount() async => (await getIntruderPhotos()).length;

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

  Future<bool> deleteIntruderPhotoByIndex(int index) async {
    try {
      final photos = await getIntruderPhotos();
      if (index >= 0 && index < photos.length) return await deleteIntruderPhoto(photos[index].path);
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Delete by index error: $e');
      return false;
    }
  }

  Future<int> clearAllIntruderPhotos() async {
    try {
      final photos = await getIntruderPhotos();
      int deleted = 0;
      for (final photo in photos) {
        if (await deleteIntruderPhoto(photo.path)) deleted++;
      }
      if (kDebugMode) debugPrint('🗑️ Cleared $deleted intruder photos');
      return deleted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Clear all photos error: $e');
      return 0;
    }
  }

  bool get isCameraReady => _controller != null && _controller!.value.isInitialized && !_controller!.value.isTakingPicture;
  String? get currentCameraName => _controller?.description.name;

  Future<void> toggleFlash() async {
    if (!isCameraReady) return;
    try {
      final current = _controller!.value.flashMode;
      final next = current == cam.FlashMode.off ? cam.FlashMode.always : cam.FlashMode.off;
      await _controller!.setFlashMode(next);
      if (kDebugMode) debugPrint('🔦 Flash toggled: ${next == cam.FlashMode.always ? "ON" : "OFF"}');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Flash toggle error: $e');
    }
  }

  Future<void> setFlashMode(cam.FlashMode mode) async {
    if (!isCameraReady) return;
    try {
      await _controller!.setFlashMode(mode);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Set flash mode error: $e');
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _cameras = null;
    _isInitialized = false;
    if (kDebugMode) debugPrint('📸 Camera Service disposed');
  }

  Future<void> reinitialize() async {
    dispose();
    await initialize();
  }

  List<cam.CameraDescription>? get availableCameras => _cameras;
  bool get hasFrontCamera => _cameras?.any((c) => c.lensDirection == cam.CameraLensDirection.front) ?? false;
  bool get hasBackCamera => _cameras?.any((c) => c.lensDirection == cam.CameraLensDirection.back) ?? false;

  cam.CameraLensDirection? get currentLensDirection {
    if (_controller == null) return null;
    final cameras = _cameras ?? [];
    if (cameras.isEmpty) return null;
    final camera = cameras.firstWhere(
      (c) => c.name == _controller!.description.name,
      orElse: () => cameras.first,
    );
    return camera.lensDirection;
  }
}

extension CameraServiceHelpers on CameraService {
  Future<bool> isGuardianReady() async {
    if (!await checkPermission()) return false;
    if (!isCameraReady) {
      try { await initializeFrontCamera(); } catch (_) { return false; }
    }
    return isCameraReady;
  }

  Future<String?> captureWithRetry({int maxAttempts = 3, Duration retryDelay = const Duration(milliseconds: 500)}) async {
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

