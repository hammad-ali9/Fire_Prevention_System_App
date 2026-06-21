import 'package:latlong2/latlong.dart';

/// Central config for the external data APIs (NOAA/NWS, NASA FIRMS,
/// NIFC/WFIGS) and geolocation fallbacks. Swap keys / endpoints here before
/// shipping production builds.
class ApiConfig {
  ApiConfig._();

  // ── Geolocation ────────────────────────────────────────────────────────
  /// Used when GPS is denied, unavailable, or the device sits outside the
  /// NWS coverage area. Los Angeles, CA — wildfire-relevant and inside US
  /// so NOAA/NWS + FIRMS + NIFC all return data.
  static const LatLng fallbackCenter = LatLng(34.0522, -118.2437);

  // ── Open-Meteo (primary, global) ───────────────────────────────────────
  /// Free, key-less, worldwide current-conditions API. Returns temperature
  /// (°C), relative humidity (%), wind speed (km/h) and wind direction
  /// (degrees the wind blows FROM). Used as the primary weather source so the
  /// app works outside the US; NWS is kept for US Red Flag warnings.
  static const String openMeteoBase = 'https://api.open-meteo.com';

  // ── NOAA / National Weather Service ────────────────────────────────────
  /// api.weather.gov requires a descriptive User-Agent with contact info.
  /// No API key. US + territories only — returns 404 elsewhere.
  static const String nwsBase = 'https://api.weather.gov';
  static const String nwsUserAgent =
      '(MakeItRain-FirePrevention-POC, rajahammad9897@gmail.com)';

  // ── NASA FIRMS ─────────────────────────────────────────────────────────
  /// Free MAP_KEY — register at:
  ///   https://firms.modaps.eosdis.nasa.gov/api/area/
  /// Without a key the FIRMS layer is silently skipped (POC stays functional).
  static const String firmsMapKey = '409a2f4350cc220bde431fb43f6fbd5e';
  static const String firmsBase =
      'https://firms.modaps.eosdis.nasa.gov/api/area/csv';

  /// Satellite source. VIIRS S-NPP NRT = 375 m, good US near-real-time.
  static const String firmsSource = 'VIIRS_SNPP_NRT';

  /// Day range for the FIRMS area query (1–10).
  static const int firmsDayRange = 1;

  static bool get firmsEnabled =>
      firmsMapKey.isNotEmpty && firmsMapKey != 'YOUR_FIRMS_MAP_KEY';

  // ── NIFC / WFIGS (ArcGIS Feature Services) ─────────────────────────────
  /// Public, key-less ArcGIS REST query endpoints from the NIFC Open Data
  /// portal. Append the standard `query?...&f=geojson` params.
  static const String nifcIncidentsQuery =
      'https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/'
      'WFIGS_Incident_Locations_Current/FeatureServer/0/query';
  static const String nifcPerimetersQuery =
      'https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/'
      'WFIGS_Interagency_Perimeters_Current/FeatureServer/0/query';

  // ── Device telemetry (Digital Matter — Device Manager API, direct) ─────
  // The app reads device data straight from the Device Manager (OEM Server)
  // API. These are the working "OneMinute Digital Tech" credentials (scope:
  // Device Manager); the device lives on the US instance (api.oemserver.com).
  //
  // Auth: `Authorization: Bearer {key}`. Key 1 = read, Key 2 = commands.
  //
  // SCOPE LIMIT (verified against all 311 API endpoints): the DM API exposes
  // last-known POSITION + timestamps + online state only. Valve position,
  // battery voltage and other decoded I/O are NOT readable here — they live in
  // Telematics Guru. So [TGTelemetry.sprinklerActive] / batteryVoltage /
  // waterFlowRate stay null on this path. Lighting those up needs a TG API key.
  //
  // POC NOTE: keys are embedded in the binary (acceptable for a POC). For
  // production, proxy them through a backend so they don't ship in the APK.
  static const String dmBaseUrl = 'https://api.oemserver.com';
  static const String dmApiKey =
      '_iv0RqzAmkhwOtUx_0Vee9.IoP7Hddn5D0ypG4B21XoBnnEGV5Mg7iA3z5EafgCJ0Rg.1';
  static const String dmApiKeyWrite =
      'h9isPPJTujJGZb74jxtm2S.lyifC3CEdkmi037SpF0s43e561TvRNJvqg2RorD08wU8.2';

  /// Default Device Manager product id for the POC device (1429272 =
  /// Arrow-Global-Bluetooth = product 128). The `Get` endpoint requires it.
  static const int dmDefaultProductId = 128;

  /// How often to poll the DM API for fresh position/state (no live stream).
  static const Duration dmPollInterval = Duration(seconds: 30);

  // ── Polling cadence ────────────────────────────────────────────────────
  /// NWS observations update ~hourly; FIRMS/NIFC every few hours. Keep these
  /// generous so the POC never rate-limits.
  static const Duration weatherRefresh = Duration(minutes: 10);
  static const Duration fireDataRefresh = Duration(minutes: 15);

  /// Half-width (degrees) of the bbox used for FIRMS/NIFC area queries
  /// around a focus point. ~0.5° ≈ 55 km — wide enough for proximity risk,
  /// tight enough that far-off fires don't dominate the zone score.
  static const double areaBboxHalfDeg = 0.5;
}
