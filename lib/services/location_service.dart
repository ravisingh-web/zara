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

/// Location Service for Z.A.R.A. Guardian Mode
/// 
/// Provides real-time GPS tracking and location-based security features:
/// - Current location with reverse geocoding (address lookup)
/// - Continuous tracking stream for Guardian Mode monitoring
/// - Safe zone geofencing with distance calculations
/// - Google Maps link generation for easy sharing
/// 
/// Features:
/// - High accuracy GPS with configurable update intervals
/// - Automatic permission requests with fallback handling
/// - SharedPreferences persistence for safe location storage
/// - Formatted address display with locality/sublocality details
/// 
/// ⚠️ Requires: Location permission (When In Use or Always)
/// User must grant permission for Guardian Mode location tracking
class LocationService {
  // ========== Singleton Pattern ==========
  
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ========== Location State ==========
  
  /// Stream subscription for continuous location updates
  StreamSubscription<Position>? _positionStream;
  
  /// Current GPS position (cached)
  Position? _currentPosition;
  
  /// Current address from reverse geocoding (cached)
  Placemark? _currentAddress;
  
  /// Whether continuous tracking is active
  bool _isTracking = false;
  
  /// Last known error (for debugging)
  String? _lastError;

  // ========== Initialization ==========
  
  /// Initialize location service (pre-load permissions status)
  /// Call once at app startup
  Future<void> initialize() async {
    // Pre-check permission status for faster response
    await _checkPermissionStatus();
    
    if (kDebugMode) {
      debugPrint('📍 Location Service Initialized');
      debugPrint('  • Permission: ${await _getPermissionStatusText()}');
    }
  }

  // ========== Permission Handling ==========
  
  /// Check if location permission is granted
  Future<bool> checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isAlways;
  }

  /// Get detailed permission status text for UI display
  Future<String> _getPermissionStatusText() async {
    final status = await Permission.locationWhenInUse.status;
    return switch (status) {
      PermissionStatus.granted => 'Granted (When In Use)',
      PermissionStatus.granted => 'Granted (Always)',
      PermissionStatus.denied => 'Denied',
      PermissionStatus.permanentlyDenied => 'Permanently Denied',
      PermissionStatus.restricted => 'Restricted',
      PermissionStatus.limited => 'Limited',
      PermissionStatus.provisional => 'Provisional',
    };
  }

  /// Check current permission status (for debugging)
  Future<PermissionStatus> _checkPermissionStatus() async {
    return await Permission.locationWhenInUse.status;
  }

  /// Request location permission from user
  /// 
  /// Returns true if granted, false if denied/permanently denied
  Future<bool> requestPermission() async {
    try {
      // First check if already granted
      if (await checkPermission()) {
        return true;
      }
      
      // Request permission
      final status = await Permission.locationWhenInUse.request();
      
      if (kDebugMode) {
        debugPrint('🔐 Location permission: ${status.name}');
      }
      
      return status.isGranted || status.isAlways;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Permission request error: $e');
      }
      return false;
    }
  }

  /// Open app settings for manual permission enable
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Check if permission is permanently denied (user must enable in Settings)
  Future<bool> isPermissionPermanentlyDenied() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isPermanentlyDenied;
  }

  // ========== Current Location ==========
  
  /// Get current GPS location with reverse geocoding
  /// 
  /// [timeout]: Maximum time to wait for GPS fix (default: 10 seconds)
  /// [forceRefresh]: Whether to bypass cache and fetch fresh location
  /// 
  /// Returns: Position object with latitude/longitude, or null on error
  Future<Position?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
    bool forceRefresh = false,
  }) async {
    try {
      // Return cached position if available and not forcing refresh
      if (!forceRefresh && _currentPosition != null) {
        // Check if cache is less than 1 minute old
        final age = DateTime.now().difference(_currentPosition!.timestamp);
        if (age < const Duration(minutes: 1)) {
          if (kDebugMode) debugPrint('📍 Using cached location (${age.inSeconds}s old)');
          return _currentPosition;
        }
      }

      // Check and request permission
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          _lastError = 'Location permission denied';
          if (kDebugMode) debugPrint('⚠️ $_lastError');
          return null;
        }
      }

      // Get fresh location with high accuracy
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      // Cache the position
      _currentPosition = position;
      
      // Fetch address in background (don't block return)
      unawaited(_getAddressFromLocation(position));

      if (kDebugMode) {
        debugPrint('📍 Location: ${position.latitude}, ${position.longitude}');
        debugPrint('  • Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
        debugPrint('  • Speed: ${position.speed.toStringAsFixed(1)} m/s');
        debugPrint('  • Timestamp: ${position.timestamp}');
      }

      return position;

    } catch (e) {
      _lastError = 'Location error: $e';
      if (kDebugMode) {
        debugPrint('⚠️ $_lastError');
      }
      return null;
    }
  }

  // ========== Reverse Geocoding ==========
  
  /// Get human-readable address from GPS coordinates
  /// 
  /// [position]: GPS position to geocode (uses _currentPosition if null)
  /// 
  /// Returns: Placemark with address details, or null on error
  Future<Placemark?> getAddressFromCoordinates({Position? position}) async {
    try {
      final pos = position ?? _currentPosition;
      if (pos == null) return null;

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
        localeIdentifier: 'en_US', // Consistent formatting
      );

      if (placemarks.isNotEmpty) {
        _currentAddress = placemarks.first;
        
        if (kDebugMode) {
          debugPrint('🏠 Address: ${_formatAddress(_currentAddress!)}');
        }
        return _currentAddress;
      }
      
      return null;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Geocoding error: $e');
      return null;
    }
  }

  /// Internal: Update address cache from position
  Future<void> _getAddressFromLocation(Position position) async {
    await getAddressFromCoordinates(position: position);
  }

  /// Format Placemark into readable address string
  String _formatAddress(Placemark address) {
    final parts = <String>[];
    
    if (address.street != null && address.street!.isNotEmpty) {
      parts.add(address.street!);
    }
    if (address.subLocality != null && address.subLocality!.isNotEmpty) {
      parts.add(address.subLocality!);
    }
    if (address.locality != null && address.locality!.isNotEmpty) {
      parts.add(address.locality!);
    }
    if (address.administrativeArea != null && address.administrativeArea!.isNotEmpty) {
      parts.add(address.administrativeArea!);
    }
    if (address.postalCode != null && address.postalCode!.isNotEmpty) {
      parts.add(address.postalCode!);
    }
    if (address.country != null && address.country!.isNotEmpty) {
      parts.add(address.country!);
    }
    
    return parts.isNotEmpty ? parts.join(', ') : 'Address unavailable';
  }

  // ========== Continuous Tracking ==========
  
  /// Start continuous location tracking for Guardian Mode
  /// 
  /// [interval]: Minimum time between updates (default: 30 seconds)
  /// [distanceFilter]: Minimum distance change to trigger update (default: 10 meters)
  /// [onLocationUpdate]: Callback fired on each new position
  /// 
  /// Returns: true if tracking started successfully
  Future<bool> startTracking({
    Duration interval = const Duration(seconds: 30),
    double distanceFilter = 10,
    Function(Position)? onLocationUpdate,
  }) async {
    if (_isTracking) {
      if (kDebugMode) debugPrint('📍 Already tracking — ignoring duplicate start');
      return true;
    }

    // Check and request permission
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

      // Configure location settings for battery-efficient tracking
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        timeLimit: null, // No timeout for continuous stream
      );

      // Start listening to position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          // Update cache
          _currentPosition = position;
          
          // Update address in background
          unawaited(_getAddressFromLocation(position));
          
          // Call user callback if provided
          onLocationUpdate?.call(position);
          
          if (kDebugMode) {
            debugPrint('📍 Tracking update: ${position.latitude}, ${position.longitude}');
          }
        },
        onError: (error) {
          _lastError = 'Tracking error: $error';
          if (kDebugMode) debugPrint('⚠️ $_lastError');
        },
        cancelOnError: false, // Continue on transient errors
      );

      if (kDebugMode) {
        debugPrint('📍 Location tracking started');
        debugPrint('  • Interval: ${interval.inSeconds}s');
        debugPrint('  • Distance filter: ${distanceFilter}m');
      }
      
      return true;
      
    } catch (e) {
      _isTracking = false;
      _lastError = 'Start tracking error: $e';
      if (kDebugMode) debugPrint('⚠️ $_lastError');
      return false;
    }
  }

  /// Stop continuous location tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    
    if (kDebugMode) {
      debugPrint('📍 Location tracking stopped');
    }
  }

  /// Toggle tracking state (convenience method)
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

  // ========== Safe Zone / Geofencing ==========
  
  /// Save current location as a "safe zone" reference point
  /// 
  /// [name]: Human-readable name for this safe location (e.g., 'Home', 'Office')
  /// [radiusMeters]: Default radius for geofencing checks (stored for reference)
  /// 
  /// Returns: true if saved successfully
  Future<bool> saveSafeLocation({
    String name = 'Home',
    double radiusMeters = 100,
  }) async {
    try {
      // Ensure we have current location
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

      if (kDebugMode) {
        debugPrint('🏠 Safe location saved: $name');
        debugPrint('  • Coordinates: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        debugPrint('  • Radius: ${radiusMeters}m');
      }
      
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Save safe location error: $e');
      return false;
    }
  }

  /// Load saved safe location from SharedPreferences
  /// 
  /// Returns: Map with latitude, longitude, name, radius, and timestamp
  /// Returns null if no safe location is saved
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

  /// Delete saved safe location
  Future<bool> deleteSafeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('safe_location_lat');
      await prefs.remove('safe_location_lng');
      await prefs.remove('safe_location_name');
      await prefs.remove('safe_location_radius');
      await prefs.remove('safe_location_saved_at');

      if (kDebugMode) {
        debugPrint('🗑️ Safe location deleted');
      }
      return true;
      
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Delete safe location error: $e');
      return false;
    }
  }

  /// Check if device has moved outside the safe zone
  /// 
  /// [radiusMeters]: Override default radius for this check
  /// [useCurrentLocation]: If true, fetch fresh location first (default: false)
  /// 
  /// Returns: true if outside safe zone, false if inside or error
  Future<bool> isOutsideSafeZone({
    double? radiusMeters,
    bool useCurrentLocation = false,
  }) async {
    try {
      // Load safe location config
      final safeLocation = await loadSafeLocation();
      if (safeLocation == null) {
        if (kDebugMode) debugPrint('⚠️ No safe location configured');
        return false; // Can't check if no reference point
      }

      // Get current position
      Position? currentPos = _currentPosition;
      if (currentPos == null || useCurrentLocation) {
        currentPos = await getCurrentLocation();
        if (currentPos == null) {
          _lastError = 'Cannot check safe zone: No GPS fix';
          return false;
        }
      }

      // Calculate distance using Haversine formula (built into Geolocator)
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        safeLocation['latitude'] as double,
        safeLocation['longitude'] as double,
      );

      final effectiveRadius = radiusMeters ?? (safeLocation['radiusMeters'] as double? ?? 100.0);
      final isOutside = distance > effectiveRadius;

      if (kDebugMode && isOutside) {
        debugPrint('⚠️ Device moved ${distance.toStringAsFixed(0)}m from safe zone "${safeLocation['name']}"');
        debugPrint('  • Radius: ${effectiveRadius}m');
        debugPrint('  • Current: ${currentPos.latitude}, ${currentPos.longitude}');
        debugPrint('  • Safe: ${safeLocation['latitude']}, ${safeLocation['longitude']}');
      }

      return isOutside;
      
    } catch (e) {
      _lastError = 'Safe zone check error: $e';
      if (kDebugMode) debugPrint('⚠️ $_lastError');
      return false;
    }
  }

  /// Get distance from safe zone in meters (positive = outside, negative = inside)
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

  // ========== Utility Methods ==========
  
  /// Get current position (cached)
  Position? get currentPosition => _currentPosition;

  /// Get current address (cached, from reverse geocoding)
  Placemark? get currentAddress => _currentAddress;

  /// Get formatted address string for display
  String getFormattedAddress() {
    if (_currentAddress == null) return 'Location unavailable';
    return _formatAddress(_currentAddress!);
  }

  /// Get Google Maps URL for current location
  String getGoogleMapsLink() {
    if (_currentPosition == null) return '';
    return 'https://www.google.com/maps?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
  }

  /// Get Apple Maps URL for current location (iOS fallback)
  String getAppleMapsLink() {
    if (_currentPosition == null) return '';
    return 'https://maps.apple.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
  }

  /// Get universal maps URL (tries Google first, falls back to Apple)
  String getUniversalMapsLink() {
    if (_currentPosition == null) return '';
    // Google Maps works on both Android and iOS
    return getGoogleMapsLink();
  }

  /// Check if tracking is currently active
  bool get isTracking => _isTracking;

  /// Get last error message (for debugging)
  String? get lastError => _lastError;

  /// Clear cached location data
  void clearCache() {
    _currentPosition = null;
    _currentAddress = null;
    _lastError = null;
    
    if (kDebugMode) {
      debugPrint('🗑️ Location cache cleared');
    }
  }

  // ========== Lifecycle ==========
  
  /// Dispose service and clean up resources
  @override
  void dispose() {
    stopTracking();
    clearCache();
    
    if (kDebugMode) {
      debugPrint('📍 Location Service disposed');
    }
  }
}

// ========== Extension: Convenience Methods ==========

/// Extension to add convenience methods for LocationService
extension LocationServiceHelpers on LocationService {
  /// Quick get: Current location with address
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
  
  /// Quick check: Is Guardian Mode location ready?
  Future<bool> isGuardianReady() async {
    final hasPermission = await checkPermission();
    final hasPosition = currentPosition != null || (await getCurrentLocation()) != null;
    return hasPermission && hasPosition;
  }
  
  /// Wait for location fix (with timeout)
  Future<Position?> waitForLocation({
    Duration timeout = const Duration(seconds: 15),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    // Return cached if available and fresh
    if (_currentPosition != null) {
      final age = DateTime.now().difference(_currentPosition!.timestamp);
      if (age < const Duration(minutes: 1)) {
        return _currentPosition;
      }
    }
    
    // Poll for fresh location
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      final position = await getCurrentLocation(forceRefresh: true);
      if (position != null) return position;
      await Future.delayed(pollInterval);
    }
    
    return null; // Timeout
  }
  
  /// Export location data as JSON string (for backup/debug)
  String exportLocationData() {
    final pos = currentPosition;
    final addr = currentAddress;
    
    if (pos == null) return '{}';
    
    return '''
{
  "latitude": ${pos.latitude},
  "longitude": ${pos.longitude},
  "accuracy": ${pos.accuracy},
  "altitude": ${pos.altitude},
  "speed": ${pos.speed},
  "heading": ${pos.heading},
  "timestamp": "${pos.timestamp.toIso8601String()}",
  "address": "${getFormattedAddress()}",
  "mapsLink": "${getGoogleMapsLink()}"
}
''';
  }
}

// ========== Constants ==========

/// Location-related constants for Z.A.R.A.
abstract final class LocationConstants {
  /// Default accuracy for Guardian Mode tracking
  static const LocationAccuracy guardianAccuracy = LocationAccuracy.high;
  
  /// Default update interval for continuous tracking
  static const Duration defaultTrackingInterval = Duration(seconds: 30);
  
  /// Default distance filter for battery-efficient tracking
  static const double defaultDistanceFilter = 10.0; // meters
  
  /// Default safe zone radius
  static const double defaultSafeZoneRadius = 100.0; // meters
  
  /// Maximum age for cached location to be considered "fresh"
  static const Duration maxCacheAge = Duration(minutes: 1);
  
  /// GPS timeout for single location fetch
  static const Duration locationFetchTimeout = Duration(seconds: 10);
}
