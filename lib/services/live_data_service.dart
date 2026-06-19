import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../models/zone.dart';
import 'api_config.dart';
import 'fire_data_store.dart';
import 'firms_service.dart';
import 'location_service.dart';
import 'nifc_service.dart';
import 'weather_service.dart';
import 'zone_store.dart';

/// Orchestrates the live data feeds and pushes them into the app state:
///  • NOAA/NWS  → per-zone [Zone.liveWeather]
///  • NASA FIRMS + NIFC/WFIGS → [FireDataStore] (map layers + risk engine)
///
/// Runs on long intervals (NWS ~hourly, FIRMS/NIFC every few hours upstream)
/// so it never rate-limits. The [TelemetrySimulator] consumes whatever this
/// service has populated and otherwise simulates.
class LiveDataService {
  LiveDataService._();
  static final LiveDataService instance = LiveDataService._();

  Timer? _weatherTimer;
  Timer? _fireTimer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    // Kick off immediately, then on cadence.
    _refreshWeather();
    _refreshFireData();
    _weatherTimer =
        Timer.periodic(ApiConfig.weatherRefresh, (_) => _refreshWeather());
    _fireTimer =
        Timer.periodic(ApiConfig.fireDataRefresh, (_) => _refreshFireData());
  }

  void stop() {
    _weatherTimer?.cancel();
    _fireTimer?.cancel();
    _weatherTimer = null;
    _fireTimer = null;
    _started = false;
  }

  /// Focus point for area (FIRMS/NIFC) queries: active zone → first zone →
  /// device GPS → configured fallback.
  Future<LatLng> _focus() async {
    final zones = ZoneStore.instance.zones.value;
    final z = ZoneStore.instance.activeZone ??
        (zones.isNotEmpty ? zones.first : null);
    if (z != null) return z.center;
    return LocationService.instance.lastKnown ??
        await LocationService.instance.resolve();
  }

  /// Immediately pull live data for a freshly-created zone so it shows real
  /// numbers right away instead of waiting for the next poll cycle.
  Future<void> refreshForZone(Zone z) async {
    final w = await WeatherService.instance.fetch(z.center);
    if (w != null) {
      z.liveWeather = w;
      ZoneStore.instance.notify();
    }
    FireDataStore.instance.lastFocus = z.center;
    final hotspots = await FirmsService.instance.fetchArea(z.center);
    FireDataStore.instance.setHotspots(hotspots);
    final perims = await NifcService.instance.fetchPerimeters(z.center);
    final points = await NifcService.instance.fetchIncidents(z.center);
    FireDataStore.instance.setIncidents([...perims, ...points]);
    ZoneStore.instance.notify();
  }

  Future<void> _refreshWeather() async {
    final zones = ZoneStore.instance.zones.value;
    if (zones.isEmpty) return;
    var changed = false;
    for (final z in zones) {
      final w = await WeatherService.instance.fetch(z.center);
      if (w != null) {
        z.liveWeather = w;
        changed = true;
      }
    }
    if (changed) ZoneStore.instance.notify();
  }

  Future<void> _refreshFireData() async {
    final focus = await _focus();
    FireDataStore.instance.lastFocus = focus;

    final hotspots = await FirmsService.instance.fetchArea(focus);
    FireDataStore.instance.setHotspots(hotspots);

    // Perimeters + point incidents, merged for the map / risk engine.
    final perims = await NifcService.instance.fetchPerimeters(focus);
    final points = await NifcService.instance.fetchIncidents(focus);
    FireDataStore.instance.setIncidents([...perims, ...points]);

    // Risk depends on this data — nudge listeners.
    ZoneStore.instance.notify();
  }
}
