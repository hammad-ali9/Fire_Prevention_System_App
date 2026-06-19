import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api_config.dart';

/// Resolves the device's current position with a graceful permission flow.
/// Every failure path (services off, permission denied, timeout, web) falls
/// back to [ApiConfig.fallbackCenter] so callers always get a usable LatLng.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  LatLng? _cached;

  /// Last resolved position, if any. Null until [resolve] has run once.
  LatLng? get lastKnown => _cached;

  /// Returns the device location, or the configured fallback. Never throws.
  Future<LatLng> resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fallback();
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return _fallback();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _cached = LatLng(pos.latitude, pos.longitude);
      return _cached!;
    } catch (_) {
      return _fallback();
    }
  }

  LatLng _fallback() {
    _cached ??= ApiConfig.fallbackCenter;
    return _cached!;
  }
}
