import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';

class LocationResult {
  final LatLngPoint point;
  final bool isLive;
  final String? error;

  const LocationResult({
    required this.point,
    this.isLive = false,
    this.error,
  });
}

class LocationService {
  static const LatLngPoint defaultFallbackLocation = LatLngPoint(
    latitude: 28.4595,
    longitude: 77.0266,
    address: 'MG Road, Sector 28, Gurugram',
  );

  final Geocoding? geocoding;

  LocationService({this.geocoding});

  Geocoding? get _safeGeocoding {
    if (geocoding != null) return geocoding;
    try {
      return Geocoding();
    } catch (_) {
      return null;
    }
  }

  /// Check whether GPS hardware / service is enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationService: error checking service enabled: $e');
      return false;
    }
  }

  /// Check current permission status without prompting.
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('LocationService: error checking permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Request runtime location permission from the operating system.
  Future<LocationPermission> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission;
    } catch (e) {
      debugPrint('LocationService: error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Returns true if permission is granted (whileInUse or always).
  bool isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Fetch the current single position and reverse-geocode to a readable address.
  Future<LocationResult> getCurrentLocation({bool requestIfDenied = false}) async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          point: defaultFallbackLocation,
          isLive: false,
          error: 'Location services are disabled on this device.',
        );
      }

      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult(
          point: defaultFallbackLocation,
          isLive: false,
          error: 'Location permissions are denied.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          point: defaultFallbackLocation,
          isLive: false,
          error: 'Location permissions are permanently denied. Please enable in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final address = await reverseGeocode(position.latitude, position.longitude);
      final point = LatLngPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      return LocationResult(
        point: point,
        isLive: true,
      );
    } catch (e) {
      debugPrint('LocationService: error fetching current location: $e');
      return LocationResult(
        point: defaultFallbackLocation,
        isLive: false,
        error: e.toString(),
      );
    }
  }

  /// Subscribe to real-time location changes with continuous navigation accuracy.
  Stream<Position>? getPositionStream({
    int distanceFilterMeters = 0,
  }) {
    try {
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: distanceFilterMeters,
          forceLocationManager: false,
          intervalDuration: const Duration(milliseconds: 1000),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.otherNavigation,
          distanceFilter: distanceFilterMeters,
          pauseLocationUpdatesAutomatically: false,
        );
      } else {
        locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        );
      }
      return Geolocator.getPositionStream(locationSettings: locationSettings);
    } catch (e) {
      debugPrint('LocationService: error getting position stream: $e');
      return null;
    }
  }

  /// Forward geocode an address string to coordinate locations.
  Future<List<Location>> locationFromAddress(String address) async {
    try {
      final geo = _safeGeocoding;
      if (geo != null) {
        return await geo.locationFromAddress(address);
      }
      return const [];
    } catch (e) {
      debugPrint('LocationService: forward geocoding failed: $e');
      return const [];
    }
  }

  /// Reverse geocode coordinates to human-readable address.
  Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final geo = _safeGeocoding;
      if (geo != null) {
        final placemarks = await geo.placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];
          if (p.street != null && p.street!.isNotEmpty) {
            parts.add(p.street!);
          } else if (p.name != null && p.name!.isNotEmpty) {
            parts.add(p.name!);
          }
          if (p.subLocality != null && p.subLocality!.isNotEmpty) {
            parts.add(p.subLocality!);
          }
          if (p.locality != null && p.locality!.isNotEmpty) {
            parts.add(p.locality!);
          } else if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) {
            parts.add(p.subAdministrativeArea!);
          }
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            parts.add(p.administrativeArea!);
          }

          if (parts.isNotEmpty) {
            return parts.toSet().join(', ');
          }
        }
      }
    } catch (e) {
      debugPrint('LocationService: reverse geocoding failed: $e');
    }

    // Fallback: formatted coordinate string
    final latStr = latitude >= 0
        ? '${latitude.toStringAsFixed(4)}°N'
        : '${(-latitude).toStringAsFixed(4)}°S';
    final lonStr = longitude >= 0
        ? '${longitude.toStringAsFixed(4)}°E'
        : '${(-longitude).toStringAsFixed(4)}°W';
    return '$latStr, $lonStr';
  }
}
