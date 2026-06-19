import 'package:latlong2/latlong.dart';

import 'live_weather.dart';

/// One monitored area. Coordinates are real WGS-84; the polygon is rendered on
/// the live map; thresholds drive AI auto-activation; telemetry is mutated by
/// the [TelemetrySimulator] at runtime.
class Zone {
  Zone({
    required this.id,
    required this.name,
    required this.sector,
    required this.center,
    required this.polygon,
    this.temperature = 28,
    this.humidity = 45,
    this.windSpeed = 12,
    this.windDirection = 0,
    this.riskPercent = 30,
    this.isActive = false,
  });

  final String id;
  String name;
  String sector;
  LatLng center;
  List<LatLng> polygon;

  // Live telemetry — updated by simulator.
  double temperature; // °C
  double humidity; // %
  double windSpeed; // km/h
  double windDirection; // degrees, meteorological — wind blows FROM this
  double riskPercent; // 0..100

  /// 8-point compass abbreviation for [windDirection] (e.g. "NW").
  String get windCompass {
    const pts = [
      'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
    ];
    return pts[(((windDirection % 360) + 22.5) ~/ 45) % 8];
  }

  /// 16-point compass abbreviation for [windDirection] (e.g. "ESE") — the
  /// direction the wind blows FROM (meteorological convention).
  String get windCompass16 {
    const pts = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    return pts[(((windDirection % 360) + 11.25) ~/ 22.5) % 16];
  }

  /// Latest NOAA/NWS observation for this zone, if it sits in NWS coverage
  /// (US). Null → telemetry is simulated and risk falls back to the
  /// random-walk model. Set by [LiveDataService].
  LiveWeather? liveWeather;

  /// True when [liveWeather] exists and is recent (< 90 min old).
  bool get hasLiveWeather {
    final w = liveWeather;
    if (w == null || !w.hasAny) return false;
    return DateTime.now().difference(w.fetchedAt) <
        const Duration(minutes: 90);
  }

  bool isActive;

  String get fullLabel => '$name - $sector';

  /// Serialize for SharedPreferences storage. [liveWeather] is intentionally
  /// dropped — it's re-fetched from NWS on the next refresh cycle.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sector': sector,
        'centerLat': center.latitude,
        'centerLng': center.longitude,
        'polygon': [
          for (final p in polygon) [p.latitude, p.longitude],
        ],
        'temperature': temperature,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'windDirection': windDirection,
        'riskPercent': riskPercent,
        'isActive': isActive,
      };

  static Zone fromJson(Map<String, dynamic> j) {
    final poly = (j['polygon'] as List?) ?? const [];
    return Zone(
      id: j['id'] as String,
      name: j['name'] as String,
      sector: j['sector'] as String,
      center: LatLng(
        (j['centerLat'] as num).toDouble(),
        (j['centerLng'] as num).toDouble(),
      ),
      polygon: [
        for (final p in poly)
          if (p is List && p.length >= 2)
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      temperature: (j['temperature'] as num?)?.toDouble() ?? 28,
      humidity: (j['humidity'] as num?)?.toDouble() ?? 45,
      windSpeed: (j['windSpeed'] as num?)?.toDouble() ?? 12,
      windDirection: (j['windDirection'] as num?)?.toDouble() ?? 0,
      riskPercent: (j['riskPercent'] as num?)?.toDouble() ?? 30,
      isActive: (j['isActive'] as bool?) ?? false,
    );
  }

  /// Severity bucket used by chips / colors across the UI.
  String get riskLevel {
    if (riskPercent >= 75) return 'HIGH';
    if (riskPercent >= 50) return 'ELEVATED';
    if (riskPercent >= 25) return 'MODERATE';
    return 'LOW';
  }
}
