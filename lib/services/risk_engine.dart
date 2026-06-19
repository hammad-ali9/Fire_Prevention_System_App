import 'package:latlong2/latlong.dart';

import '../models/fire_hotspot.dart';
import '../models/fire_incident.dart';
import '../models/live_weather.dart';
import '../models/zone.dart';
import 'settings_store.dart';

/// Blended wildfire-risk score:
///
///   Risk = Weather risk (NOAA/NWS) + Active-fire proximity (NASA FIRMS)
///        + Official incident/perimeter proximity (NIFC/WFIGS)
///
/// Each component contributes 0..100; the result is a weighted blend clamped
/// to 0..100, plus the human-readable reasons that drove it.
class RiskResult {
  const RiskResult(this.percent, this.reasons);
  final double percent;
  final List<String> reasons;
}

class RiskEngine {
  RiskEngine._();

  static const _dist = Distance();

  static RiskResult compute({
    required Zone zone,
    required AppSettings s,
    LiveWeather? weather,
    List<FireHotspot> hotspots = const [],
    List<FireIncident> incidents = const [],
  }) {
    final reasons = <String>[];

    // ── Weather component (0..100) ───────────────────────────────────────
    final temp = weather?.temperature ?? zone.temperature;
    final hum = weather?.humidity ?? zone.humidity;
    final wind = weather?.windSpeed ?? zone.windSpeed;

    final tempPart = ((temp - s.tempThreshold) / 15).clamp(-1.0, 1.5);
    final humPart = ((s.humidityThreshold - hum) / 30).clamp(-1.0, 1.5);
    final windPart = ((wind - s.windThreshold) / 40).clamp(-1.0, 1.5);
    var weatherRisk = 40 + 28 * tempPart + 18 * humPart + 14 * windPart;
    if (weather?.redFlag == true) {
      weatherRisk += 20;
      reasons.add('Red Flag Warning active (NWS)');
    }
    weatherRisk = weatherRisk.clamp(0, 100);

    if (temp >= s.tempThreshold) reasons.add('Critical temperature spike');
    if (hum <= s.humidityThreshold) reasons.add('Low atmospheric humidity');
    if (wind >= s.windThreshold) reasons.add('High wind speed');

    // ── FIRMS active-fire proximity → additive bonus (0..40) ─────────────
    // Only fires genuinely near the zone add risk. A detection 25+ km away
    // is situational awareness, not a reason to flag the zone HIGH.
    double fireBonus = 0;
    final nearHotspotKm = _nearestKm(
        zone.center, [for (final h in hotspots) h.point]);
    if (nearHotspotKm != null && nearHotspotKm <= 25) {
      fireBonus = (40 * (1 - nearHotspotKm / 25)).clamp(0, 40).toDouble();
      reasons.add(
          'NASA FIRMS hotspot ${nearHotspotKm.toStringAsFixed(1)} km away');
    }

    // ── NIFC official incident / perimeter ───────────────────────────────
    // Inside an official perimeter, or an active fire within ~3 km, is the
    // only condition that overrides benign weather and forces severe risk.
    var insidePerimeter = false;
    for (final inc in incidents) {
      if (inc.hasPerimeter && _insideAny(zone.center, inc.perimeter)) {
        insidePerimeter = true;
        reasons.add('Inside official fire perimeter: ${inc.name}');
        break;
      }
    }
    double incidentBonus = 0;
    final nearIncKm =
        _nearestKm(zone.center, [for (final i in incidents) i.point]);
    if (nearIncKm != null && nearIncKm <= 30) {
      incidentBonus = (35 * (1 - nearIncKm / 30)).clamp(0, 35).toDouble();
      reasons.add(
          'Official fire ${nearIncKm.toStringAsFixed(0)} km away (NIFC)');
    }

    // ── Combine ──────────────────────────────────────────────────────────
    // Weather is the baseline; nearby real fire adds a capped bonus. Severe
    // overrides only when the zone is truly in danger.
    double percent;
    if (insidePerimeter) {
      percent = weatherRisk.clamp(85, 100).toDouble();
    } else if (nearHotspotKm != null && nearHotspotKm <= 3) {
      percent = weatherRisk.clamp(80, 100).toDouble();
    } else if (nearIncKm != null && nearIncKm <= 3) {
      percent = weatherRisk.clamp(80, 100).toDouble();
    } else {
      percent = (weatherRisk + fireBonus + incidentBonus).clamp(0.0, 100.0);
    }

    if (reasons.isEmpty) reasons.add('All telemetry within thresholds');
    return RiskResult(percent, reasons);
  }

  static double? _nearestKm(LatLng from, List<LatLng> pts) {
    double? best;
    for (final p in pts) {
      final km = _dist.as(LengthUnit.Kilometer, from, p);
      if (best == null || km < best) best = km;
    }
    return best;
  }

  static bool _insideAny(LatLng p, List<List<LatLng>> rings) {
    for (final ring in rings) {
      if (_pointInRing(p, ring)) return true;
    }
    return false;
  }

  /// Ray-casting point-in-polygon (lat/lng treated as planar — fine at the
  /// city scale this POC operates at).
  static bool _pointInRing(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      final hit = ((yi > p.latitude) != (yj > p.latitude)) &&
          (p.longitude <
              (xj - xi) * (p.latitude - yi) / (yj - yi) + xi);
      if (hit) inside = !inside;
    }
    return inside;
  }
}
