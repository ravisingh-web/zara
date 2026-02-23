// lib/services/location_service.dart
// Z.A.R.A. — Location Service for Guardian Mode
// ✅ GPS Tracking • Reverse Geocoding • Geofencing • Safe Zones
// ✅ Permission Handling • Stream Updates • Production-Ready

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  Placemark? _currentAddress;
  bool _isTracking = false;
  String? _lastError;

  Future<void> initialize() async {
    await _checkPermissionStatus();
    if (kDebugMode) {
      debugPrint('📍 Location Service Initialized');
      debugPrint('  • Permission: ${await _getPermissionStatusText()}');
    }
  }

  Future<bool> checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  Future<String> _getPermissionStatusText() async {
    final status = await Permission.locationWhenInUse.status;
    return switch (status) {
      PermissionStatus.granted => 'Granted',
      PermissionStatus.denied => 'Denied',
      PermissionStatus.permanentlyDenied => 'Permanently Denied',
      PermissionStatus.restricted => 'Restricted',
      PermissionStatus.limited => 'Limited',
      PermissionStatus.provisional => 'Provisional',
    };
  }

  Future<PermissionStatus> _checkPermissionStatus() async =>
      await Permission.locationWhenInUse.status;

  Future<bool> requestPermission() async {
    try {
      if (await checkPermission()) return true;
      final status = await Permission.locationWhenInUse.request();
      if (kDebugMode) debugPrint('🔐 Location permission: ${status.name}');
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Permission request error: $e');
      return false;
    }
  }

  Future<void> openSettings() async => await openAppSettings();

  Future<bool> isPermissionPermanentlyDenied() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isPermanentlyDenied;
  }

  Future<Position?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh && _currentPosition != null) {
        final age = DateTime.now().difference(_currentPosition!.timestamp);
        if (age < const Duration(minutes: 1)) {
          if (kDebugMode)
            debugPrint('📍 Using cached location (${age.inSeconds}s old)');
          return _currentPosition;
        }
      }
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          _lastError = 'Location permission denied';
          if (kDebugMode) debugPrint('⚠️ $_lastError');
          return null;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      _currentPosition = position;
      unawaited(_getAddressFromLocation(position));
      if (kDebugMode) {
        debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
        debugPrint('  • Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
      }
      return position;
    } catch (e) {
      _lastError = 'Location error: $e';
      if (kDebugMode) debugPrint('⚠️ $_lastError');
      return null;
    }
  }

  Future<Placemark?> getAddressFromCoordinates({Position? position}) async {
    try {
      final pos = position ?? _currentPosition;
      if (pos == null) return null;
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        _currentAddress = placemarks.first;
        if (kDebugMode)
          debugPrint('🏠 Address: ${_formatAddress(_currentAddress!)}');
        return _currentAddress;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Geocoding error: $e');
      return null;
    }
  }

  Future<void> _getAddressFromLocation(Position position) async =>
      await getAddressFromCoordinates(position: position);

  String _formatAddress(Placemark address) {
    final parts = <String>[];
    if (address.street?.isNotEmpty == true) parts.add(address.street!);
    if (address.subLocality?.isNotEmpty == true) parts.add(address.subLocality!);
    if (address.locality?.isNotEmpty == true) parts.add(address.locality!);
    if (address.administrativeArea?.isNotEmpty == true) parts.add(address.administrativeArea!);
    if (address.postalCode?.isNotEmpty == true) parts.add(address.postalCode!);
    if (address.country?.isNotEmpty == true) parts.add(address.country!);
    return parts.isNotEmpty ? parts.join(', ') : 'Address unavailable';
  }

  Future<bool> startTracking({
    Duration interval = const Duration(seconds: 30),
    double distanceFilter = 10,
    Function(Position)? onLocationUpdate,
  }) async {
    if (_isTracking) {
      if (kDebugMode) debugPrint('📍 Already tracking');
      return true;
    }
    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        _lastError = 'Location permission denied for tracking';
        if (kDebugMode) debugPrint('⚠️ $_lastError');
        return false;
      }
    }
    try {
      _isTracking = true;
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        timeLimit: null,
      );
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          unawaited(_getAddressFromLocation(position));
          onLocationUpdate?.call(position);
          if (kDebugMode)
            debugPrint('📍 Tracking update: ${position.latitude}, ${position.longitude}');
        },
        onError: (error) {
          _lastError = 'Tracking error: $error';
          if (kDebugMode) debugPrint('⚠️ $_lastError');
        },
        cancelOnError: false,
      );
      if (kDebugMode) debugPrint('📍 Location tracking started');
      return true;
    } catch (e) {
      _isTracking = false;
      _lastError = 'Start tracking error: $e';
      if (kDebugMode) debugPrint('⚠️ $_lastError');
      return false;
    }
  }

  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    if (kDebugMode) debugPrint('📍 Location tracking stopped');
  }

  Future<bool> toggleTracking({
    Duration interval = const Duration(seconds: 30),
    double distanceFilter = 10,
    Function(Position)? onLocationUpdate,
  }) async {
    if (_isTracking) {
      await stopTracking();
      return false;
    } else {
      return await startTracking(
        interval: interval,
        distanceFilter: distanceFilter,
        onLocationUpdate: onLocationUpdate,
      );
    }
  }

  Future<bool> saveSafeLocation({
    String name = 'Home',
    double radiusMeters = 100.0,
  }) async {
    try {
      if (_currentPosition == null) {
        final position = await getCurrentLocation();
        if (position == null) {
          _lastError = 'Cannot save safe location: No GPS fix';
          return false;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('safe_location_lat', _currentPosition!.latitude);
      await prefs.setDouble('safe_location_lng', _currentPosition!.longitude);
      await prefs.setString('safe_location_name', name);
      await prefs.setDouble('safe_location_radius', radiusMeters);
      await prefs.setInt('safe_location_saved_at', DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode) debugPrint('🏠 Safe location saved: $name');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Save safe location error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadSafeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('safe_location_lat');
      final lng = prefs.getDouble('safe_location_lng');
      final name = prefs.getString('safe_location_name');
      final radius = prefs.getDouble('safe_location_radius');
      final savedAt = prefs.getInt('safe_location_saved_at');
      if (lat != null && lng != null) {
        return {
          'latitude': lat,
          'longitude': lng,
          'name': name ?? 'Safe Location',
          'radiusMeters': radius ?? 100.0,
          'savedAt': savedAt != null ? DateTime.fromMillisecondsSinceEpoch(savedAt) : null,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Load safe location error: $e');
      return null;
    }
  }

  Future<bool> deleteSafeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('safe_location_lat');
      await prefs.remove('safe_location_lng');
      await prefs.remove('safe_location_name');
      await prefs.remove('safe_location_radius');
      await prefs.remove('safe_location_saved_at');
      if (kDebugMode) debugPrint('🗑️ Safe location deleted');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Delete safe location error: $e');
      return false;
    }
  }

  Future<bool> isOutsideSafeZone({
    double? radiusMeters,
    bool useCurrentLocation = false,
  }) async {
    try {
      final safeLocation = await loadSafeLocation();
      if (safeLocation == null) {
        if (kDebugMode) debugPrint('⚠️ No safe location configured');
        return false;
      }
      Position? currentPos = _currentPosition;
      if (currentPos == null || useCurrentLocation) {
        currentPos = await getCurrentLocation();
        if (currentPos == null) {
          _lastError = 'Cannot check safe zone: No GPS fix';
          return false;
        }
      }
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        safeLocation['latitude'] as double,
        safeLocation['longitude'] as double,
      );
      final effectiveRadius = radiusMeters ?? (safeLocation['radiusMeters'] as double? ?? 100.0);
      final isOutside = distance > effectiveRadius;
      if (kDebugMode && isOutside)
        debugPrint('⚠️ Device moved ${distance.toStringAsFixed(0)}m from safe zone');
      return isOutside;
    } catch (e) {
      _lastError = 'Safe zone check error: $e';
      if (kDebugMode) debugPrint('⚠️ $_lastError');
      return false;
    }
  }

  Future<double?> getDistanceFromSafeZone() async {
    try {
      final safeLocation = await loadSafeLocation();
      if (safeLocation == null || _currentPosition == null) return null;
      return Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        safeLocation['latitude'] as double,
        safeLocation['longitude'] as double,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Distance calculation error: $e');
      return null;
    }
  }

  Position? get currentPosition => _currentPosition;
  Placemark? get currentAddress => _currentAddress;
  String getFormattedAddress() => _currentAddress == null ? 'Location unavailable' : _formatAddress(_currentAddress!);
  
  String getGoogleMapsLink() => _currentPosition == null
      ? ''
      : 'http://googleusercontent.com/maps.google.com/${_currentPosition!.latitude},${_currentPosition!.longitude}';
      
  String getAppleMapsLink() => _currentPosition == null
      ? ''
      : 'https://maps.apple.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      
  String getUniversalMapsLink() => getGoogleMapsLink();
  bool get isTracking => _isTracking;
  String? get lastError => _lastError;
  
  void clearCache() {
    _currentPosition = null;
    _currentAddress = null;
    _lastError = null;
    if (kDebugMode) debugPrint('🗑️ Location cache cleared');
  }

  void dispose() {
    stopTracking();
    clearCache();
    if (kDebugMode) debugPrint('📍 Location Service disposed');
  }
}

extension LocationServiceHelpers on LocationService {
  Future<Map<String, dynamic>?> getCurrentLocationWithAddress() async {
    final position = await getCurrentLocation();
    if (position == null) return null;
    await getAddressFromCoordinates(position: position);
    return {
      'position': position,
      'address': currentAddress,
      'formattedAddress': getFormattedAddress(),
      'mapsLink': getGoogleMapsLink(),
    };
  }

  Future<bool> isGuardianReady() async {
    final hasPermission = await checkPermission();
    final hasPosition = currentPosition != null || (await getCurrentLocation()) != null;
    return hasPermission && hasPosition;
  }

  Future<Position?> waitForLocation({
    Duration timeout = const Duration(seconds: 15),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    if (_currentPosition != null) {
      final age = DateTime.now().difference(_currentPosition!.timestamp);
      if (age < const Duration(minutes: 1)) return _currentPosition;
    }
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      final position = await getCurrentLocation(forceRefresh: true);
      if (position != null) return position;
      await Future.delayed(pollInterval);
    }
    return null;
  }

  String exportLocationData() {
    final pos = currentPosition;
    if (pos == null) return '{}';
    return '{"latitude": ${pos.latitude}, "longitude": ${pos.longitude}, "accuracy": ${pos.accuracy}, "address": "${getFormattedAddress()}", "mapsLink": "${getGoogleMapsLink()}"}';
  }
}

abstract final class LocationConstants {
  static const LocationAccuracy guardianAccuracy = LocationAccuracy.high;
  static const Duration defaultTrackingInterval = Duration(seconds: 30);
  static const double defaultDistanceFilter = 10.0;
  static const double defaultSafeZoneRadius = 100.0;
  static const Duration maxCacheAge = Duration(minutes: 1);
  static const Duration locationFetchTimeout = Duration(seconds: 10);
}

