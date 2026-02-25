// lib/services/location_service.dart
// Z.A.R.A. — Live Location Engine for Guardian Mode
// ✅ Hardware GPS Check • Exact Google Maps URL • Precision Tracking
// ✅ 100% Real Logic • Fail-Safe Timeouts • Background Geocoding

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  Placemark? _currentAddress;
  String? _lastError;

  // ========== System Initialization ==========

  Future<void> initialize() async {
    await checkPermission();
    if (kDebugMode) debugPrint('📍 Location System: Satellite Uplink Initialized.');
  }

  // ========== Permission Gatekeeper ==========

  Future<bool> checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (kDebugMode) debugPrint('🔐 GPS Access: ${status.name}');
    return status.isGranted;
  }

  // ========== 🚨 THE REAL GUARDIAN LOCATION FETCHER ==========

  Future<Position?> getCurrentLocation({bool forceRefresh = true}) async {
    try {
      // 1. Hardware Check: Is GPS actually ON?
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError = 'CRITICAL: GPS Hardware is disabled.';
        return await Geolocator.getLastKnownPosition(); // Fallback to last location
      }

      // 2. Permission Check
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          _lastError = 'CRITICAL: Location permission denied by user.';
          return null;
        }
      }

      // 3. Precision Satellite Lock (With Fail-Safe Timeout)
      if (kDebugMode) debugPrint('🛰️ Z.A.R.A. locking onto coordinates...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation, // Max precision for security
        timeLimit: const Duration(seconds: 10), // Don't hang the system if GPS is weak
      );

      _currentPosition = position;

      // 4. Background Geocoding (Fetch readable address without blocking the thread)
      _getAddressFromCoordinates(position).ignore();

      if (kDebugMode) debugPrint('📍 Target Locked: ${position.latitude}, ${position.longitude}');
      return position;

    } on TimeoutException {
      // If live lock fails due to being indoors, fetch the last known accurate ping
      if (kDebugMode) debugPrint('⚠️ Satellite timeout. Falling back to last known ping.');
      _currentPosition = await Geolocator.getLastKnownPosition();
      return _currentPosition;
    } catch (e) {
      _lastError = 'Location fetch error: $e';
      if (kDebugMode) debugPrint('⚠️ $_lastError');
      return null;
    }
  }

  // ========== Reverse Geocoding (Coordinates to Street Address) ==========

  Future<Placemark?> _getAddressFromCoordinates(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        _currentAddress = placemarks.first;
        return _currentAddress;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Reverse Geocoding failure: $e');
      return null;
    }
  }

  // ========== Formatting & Data Output ==========

  String getFormattedAddress() {
    if (_currentAddress == null) return 'Address currently syncing...';
    
    final parts = <String>[];
    if (_currentAddress!.street?.isNotEmpty == true) parts.add(_currentAddress!.street!);
    if (_currentAddress!.subLocality?.isNotEmpty == true) parts.add(_currentAddress!.subLocality!);
    if (_currentAddress!.locality?.isNotEmpty == true) parts.add(_currentAddress!.locality!);
    if (_currentAddress!.postalCode?.isNotEmpty == true) parts.add(_currentAddress!.postalCode!);
    
    return parts.isNotEmpty ? parts.join(', ') : 'Exact street unmapped';
  }

  // ✅ FIXED: The Real Google Maps Coordinate URL
  String getGoogleMapsLink() {
    if (_currentPosition == null) return 'No GPS Lock';
    return 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
  }

  Position? get currentPosition => _currentPosition;
  String? get lastError => _lastError;
}

// ========== Tactical Extension for Guardian Engine ==========
extension LocationServiceHelpers on LocationService {
  
  /// Fetches all relevant tracking data for email/SMS alerts instantly
  Future<Map<String, dynamic>?> getGuardianTrackingData() async {
    final position = await getCurrentLocation(forceRefresh: true);
    if (position == null) return null;

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'mapsLink': getGoogleMapsLink(),
      'address': getFormattedAddress(),
    };
  }
}
