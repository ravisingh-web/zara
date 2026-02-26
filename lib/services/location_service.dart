// lib/services/location_service.dart
// Z.A.R.A. — Live Location Engine for Guardian Mode
// ✅ 100% Real GPS • Geofencing • Safe Zones • Android Compliant

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

  Position? _currentPosition;
  Placemark? _currentAddress;
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  String? _lastError;

  static const String _kSafeLat = 'zara_safe_lat';
  static const String _kSafeLng = 'zara_safe_lng';
  static const String _kSafeName = 'zara_safe_name';
  static const String _kSafeRadius = 'zara_safe_radius';

  Future<void> initialize() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && kDebugMode) {
      debugPrint('⚠️ GPS hardware disabled — Enable in Settings');
    }
    if (kDebugMode) debugPrint('📍 Location System: Initialized');
  }

  Future<bool> checkPermission() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (kDebugMode) debugPrint('🔐 Location: ${status.isGranted ? "Granted" : "Denied"}');
      return status.isGranted;    } catch (_) {
      return false;
    }
  }

  Future<bool> isPermissionPermanentlyDenied() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      return status.isPermanentlyDenied;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }

  Future<Position?> getCurrentLocation({bool forceRefresh = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _lastError = 'GPS disabled — Enable in Settings';
        return await Geolocator.getLastKnownPosition();
      }
      if (!await checkPermission()) {
        if (!await requestPermission()) {
          _lastError = 'Permission denied';
          return null;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      _currentPosition = position;
      unawaited(_getAddressFromCoordinates(position));
      return position;
    } on TimeoutException {
      _currentPosition = await Geolocator.getLastKnownPosition();
      return _currentPosition;
    } catch (e) {
      _lastError = 'Location error: $e';
      return null;
    }
  }

  Future<Placemark?> _getAddressFromCoordinates(Position position) async {
    try {      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        _currentAddress = placemarks.first;
        return _currentAddress;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

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

  String getFormattedAddress() {
    final addr = _currentAddress;
    return addr == null ? 'Address syncing...' : _formatAddress(addr);
  }

  Future<bool> startTracking({Function(Position)? onLocationUpdate, double distanceFilter = 10}) async {
    if (_isTracking) return true;
    if (!await checkPermission() || !await Geolocator.isLocationServiceEnabled()) return false;
    try {
      _isTracking = true;
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilter.toInt()),
      ).listen((Position position) {
        _currentPosition = position;
        unawaited(_getAddressFromCoordinates(position));
        onLocationUpdate?.call(position);
      }, onError: (e) => _lastError = 'Tracking error: $e', cancelOnError: false);
      return true;
    } catch (e) {
      _isTracking = false;
      _lastError = 'Start tracking error: $e';
      return false;
    }
  }

  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;    _isTracking = false;
  }

  bool get isTracking => _isTracking;

  Future<bool> saveSafeLocation({String name = 'Home', double radiusMeters = 100.0}) async {
    try {
      if (_currentPosition == null) {
        final pos = await getCurrentLocation();
        if (pos == null) return false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kSafeLat, _currentPosition!.latitude);
      await prefs.setDouble(_kSafeLng, _currentPosition!.longitude);
      await prefs.setString(_kSafeName, name);
      await prefs.setDouble(_kSafeRadius, radiusMeters);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadSafeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kSafeLat);
      final lng = prefs.getDouble(_kSafeLng);
      if (lat == null || lng == null) return null;
      return {
        'latitude': lat,
        'longitude': lng,
        'name': prefs.getString(_kSafeName) ?? 'Safe Location',
        'radiusMeters': prefs.getDouble(_kSafeRadius) ?? 100.0,
      };
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteSafeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSafeLat);
      await prefs.remove(_kSafeLng);
      await prefs.remove(_kSafeName);
      await prefs.remove(_kSafeRadius);
      return true;
    } catch (_) {
      return false;
    }  }

  Future<bool> isOutsideSafeZone({double? radiusMeters}) async {
    try {
      final safe = await loadSafeLocation();
      if (safe == null) return false;
      Position? pos = _currentPosition;
      if (pos == null) {
        pos = await getCurrentLocation();
        if (pos == null) return false;
      }
      final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        safe['latitude'] as double, safe['longitude'] as double,
      );
      final radius = radiusMeters ?? (safe['radiusMeters'] as double? ?? 100.0);
      return distance > radius;
    } catch (_) {
      return false;
    }
  }

  Future<double?> getDistanceFromSafeZone() async {
    try {
      final safe = await loadSafeLocation();
      if (safe == null || _currentPosition == null) return null;
      return Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        safe['latitude'] as double, safe['longitude'] as double,
      );
    } catch (_) {
      return null;
    }
  }

  String getGoogleMapsLink() {
    final pos = _currentPosition;
    if (pos == null) return 'No GPS Lock';
    return 'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
  }

  String getAppleMapsLink() {
    final pos = _currentPosition;
    if (pos == null) return 'No GPS Lock';
    return 'https://maps.apple.com/?q=${pos.latitude},${pos.longitude}';
  }

  Position? get currentPosition => _currentPosition;
  Placemark? get currentAddress => _currentAddress;
  String? get lastError => _lastError;
  void clearCache() {
    _currentPosition = null;
    _currentAddress = null;
    _lastError = null;
  }

  void dispose() {
    stopTracking();
    clearCache();
  }
}

extension LocationServiceHelpers on LocationService {
  Future<Map<String, dynamic>?> getGuardianTrackingData() async {
    final pos = await getCurrentLocation(forceRefresh: true);
    if (pos == null) return null;
    return {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'mapsLink': getGoogleMapsLink(),
      'address': getFormattedAddress(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<bool> isGuardianReady() async {
    return await checkPermission() &&
           await Geolocator.isLocationServiceEnabled() &&
           (currentPosition != null || (await getCurrentLocation()) != null);
  }

  Future<Position?> waitForLocation({Duration timeout = const Duration(seconds: 15), Duration pollInterval = const Duration(seconds: 1)}) async {
    if (_currentPosition != null) {
      final age = DateTime.now().difference(_currentPosition!.timestamp);
      if (age < const Duration(minutes: 1)) return _currentPosition;
    }
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      final pos = await getCurrentLocation(forceRefresh: true);
      if (pos != null) return pos;
      await Future.delayed(pollInterval);
    }
    return null;
  }
}
