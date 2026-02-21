// lib/services/location_service.dart
// Z.A.R.A. — REAL Location Service for Guardian Mode
// GPS Tracking • Geofencing • No Fake Stuff

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

  /// Check location permission
  Future<bool> checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  /// Request location permission
  Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Get current location (REAL GPS coordinates)
  Future<Position?> getCurrentLocation() async {
    try {
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          throw Exception('Location permission denied');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      
      // Get address from coordinates (REAL reverse geocoding)
      await _getAddressFromLocation(position);

      debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
      return position;

    } catch (e) {
      debugPrint('⚠️ Location error: $e');
      return null;
    }
  }

  /// Get address from coordinates
  Future<void> _getAddressFromLocation(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        _currentAddress = placemarks.first;
        debugPrint('🏠 Address: ${_currentAddress?.toString()}');
      }
    } catch (e) {
      debugPrint('⚠️ Geocoding error: $e');
    }
  }

  /// Start continuous location tracking (for Guardian mode)
  Future<void> startTracking({
    Duration interval = const Duration(seconds: 30),
    Function(Position)? onLocationUpdate,
  }) async {
    if (_isTracking) return;

    if (!await checkPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw Exception('Location permission denied');
      }
    }

    _isTracking = true;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _currentPosition = position;
      _getAddressFromLocation(position);
      
      debugPrint('📍 Tracking: ${position.latitude}, ${position.longitude}');
      onLocationUpdate?.call(position);
    });

    debugPrint('📍 Location tracking started');
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    debugPrint('📍 Location tracking stopped');
  }

  /// Get current position
  Position? get currentPosition => _currentPosition;

  /// Get current address
  Placemark? get currentAddress => _currentAddress;

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Get location as shareable link (Google Maps)
  String getGoogleMapsLink() {
    if (_currentPosition == null) return '';
    return 'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
  }

  /// Get formatted address string
  String getFormattedAddress() {
    if (_currentAddress == null) return 'Location unavailable';
    
    final address = _currentAddress!;
    return '${address.street}, ${address.subLocality}, ${address.locality}, ${address.postalCode}';
  }

  /// Save safe location (for geofencing)
  Future<void> saveSafeLocation({String name = 'Home'}) async {
    if (_currentPosition == null) {
      await getCurrentLocation();
    }

    if (_currentPosition != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('safe_location_lat', _currentPosition!.latitude);
      await prefs.setDouble('safe_location_lng', _currentPosition!.longitude);
      await prefs.setString('safe_location_name', name);
      
      debugPrint('🏠 Safe location saved: $name');
    }
  }

  /// Load saved safe location
  Future<Map<String, dynamic>?> loadSafeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    
    final lat = prefs.getDouble('safe_location_lat');
    final lng = prefs.getDouble('safe_location_lng');
    final name = prefs.getString('safe_location_name');
    
    if (lat != null && lng != null) {
      return {
        'latitude': lat,
        'longitude': lng,
        'name': name ?? 'Safe Location',
      };
    }
    return null;
  }

  /// Check if device moved from safe location (geofencing)
  Future<bool> isOutsideSafeZone({double radiusMeters = 100}) async {
    final safeLocation = await loadSafeLocation();
    if (safeLocation == null || _currentPosition == null) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      safeLocation['latitude'] as double,
      safeLocation['longitude'] as double,
    );

    final isOutside = distance > radiusMeters;
    
    if (isOutside) {
      debugPrint('⚠️ Device moved ${distance.toStringAsFixed(0)}m from safe zone');
    }
    
    return isOutside;
  }

  @override
  void dispose() {
    stopTracking();
  }
}
