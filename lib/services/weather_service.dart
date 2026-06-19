import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/live_weather.dart';
import 'api_config.dart';

/// NOAA / National Weather Service client (api.weather.gov).
///
/// Flow: `/points/{lat},{lng}` → station list → station's latest observation.
/// Also checks `/alerts/active` for Red Flag Warnings / Fire Weather Watches.
/// US + territories only — any non-US point yields a 404, returning null so
/// callers fall back to the simulator.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  Map<String, String> get _headers => {
        'User-Agent': ApiConfig.nwsUserAgent,
        'Accept': 'application/geo+json',
      };

  /// Primary entry point. Open-Meteo (global) first; if it's unreachable fall
  /// back to NOAA/NWS (US only). Red Flag status always comes from NWS.
  Future<LiveWeather?> fetch(LatLng at) async {
    final om = await _fetchOpenMeteo(at);
    if (om != null) return om;
    return _fetchNws(at);
  }

  /// Open-Meteo current conditions — worldwide, no API key. Wind direction is
  /// the meteorological bearing the wind blows FROM, matching our convention.
  Future<LiveWeather?> _fetchOpenMeteo(LatLng at) async {
    try {
      final lat = at.latitude.toStringAsFixed(4);
      final lng = at.longitude.toStringAsFixed(4);
      final uri = Uri.parse(
          '${ApiConfig.openMeteoBase}/v1/forecast?latitude=$lat&longitude=$lng'
          '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,'
          'wind_direction_10m&wind_speed_unit=kmh');
      final res =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final cur = (jsonDecode(res.body)['current'] as Map?)
          ?.cast<String, dynamic>();
      if (cur == null) return null;

      double? num2(Object? v) => v is num ? v.toDouble() : null;
      final temp = num2(cur['temperature_2m']);
      final hum = num2(cur['relative_humidity_2m']);
      final wind = num2(cur['wind_speed_10m']);
      final dir = num2(cur['wind_direction_10m']);
      if (temp == null && hum == null && wind == null) return null;

      return LiveWeather(
        temperature: temp,
        humidity: hum,
        windSpeed: wind,
        windDirection: dir,
        redFlag: await _hasRedFlag(at),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<LiveWeather?> _fetchNws(LatLng at) async {
    try {
      final lat = at.latitude.toStringAsFixed(4);
      final lng = at.longitude.toStringAsFixed(4);

      final pointsRes = await http
          .get(Uri.parse('${ApiConfig.nwsBase}/points/$lat,$lng'),
              headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (pointsRes.statusCode != 200) return null; // non-US → 404

      final props = (jsonDecode(pointsRes.body)['properties'] as Map?)
          ?.cast<String, dynamic>();
      final stationsUrl = props?['observationStations'] as String?;
      final hourlyUrl = props?['forecastHourly'] as String?;
      if (stationsUrl == null) return null;

      final stationsRes = await http
          .get(Uri.parse(stationsUrl), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (stationsRes.statusCode != 200) return null;

      final features =
          (jsonDecode(stationsRes.body)['features'] as List?) ?? const [];
      if (features.isEmpty) return null;
      final stationId =
          (features.first['properties'] as Map?)?['stationIdentifier'];
      if (stationId == null) return null;

      final obsRes = await http
          .get(
            Uri.parse(
                '${ApiConfig.nwsBase}/stations/$stationId/observations/latest'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 12));
      if (obsRes.statusCode != 200) return null;

      final obs = (jsonDecode(obsRes.body)['properties'] as Map?)
          ?.cast<String, dynamic>();
      if (obs == null) return null;

      var temp = _value(obs['temperature']); // wmoUnit:degC
      var hum = _value(obs['relativeHumidity']); // wmoUnit:percent
      var wind = _windKmh(obs['windSpeed']);
      var dir = _value(obs['windDirection']); // degrees

      // Stations frequently report nulls between updates — backfill any
      // missing metric from the gridpoint hourly forecast so the zone shows
      // real numbers instead of the simulated defaults.
      if ((temp == null || hum == null || wind == null || dir == null) &&
          hourlyUrl != null) {
        final fc = await _hourly(hourlyUrl);
        temp ??= fc?.temperature;
        hum ??= fc?.humidity;
        wind ??= fc?.windSpeed;
        dir ??= fc?.windDirection;
      }

      return LiveWeather(
        temperature: temp,
        humidity: hum,
        windSpeed: wind,
        windDirection: dir,
        redFlag: await _hasRedFlag(at),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// First period of the NWS gridpoint hourly forecast — used to backfill
  /// metrics the latest station observation left null.
  Future<LiveWeather?> _hourly(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final periods = ((jsonDecode(res.body)['properties'] as Map?)?[
              'periods'] as List?) ??
          const [];
      if (periods.isEmpty) return null;
      final p = (periods.first as Map).cast<String, dynamic>();

      double? temp;
      final t = p['temperature'];
      if (t is num) {
        final unit = (p['temperatureUnit'] ?? 'F').toString();
        temp = unit == 'F' ? (t - 32) * 5 / 9 : t.toDouble();
      }

      return LiveWeather(
        temperature: temp,
        humidity: _value(p['relativeHumidity']),
        windSpeed: _windStrKmh(p['windSpeed']?.toString()),
        windDirection: _compassToDeg(p['windDirection']?.toString()),
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Forecast windSpeed is a string like "10 mph" / "5 to 10 mph". Take the
  /// first number and convert mph → km/h.
  double? _windStrKmh(String? s) {
    if (s == null) return null;
    final m = RegExp(r'\d+(\.\d+)?').firstMatch(s);
    if (m == null) return null;
    final mph = double.tryParse(m.group(0)!);
    return mph == null ? null : mph * 1.60934;
  }

  static const _compass = {
    'N': 0.0, 'NNE': 22.5, 'NE': 45.0, 'ENE': 67.5,
    'E': 90.0, 'ESE': 112.5, 'SE': 135.0, 'SSE': 157.5,
    'S': 180.0, 'SSW': 202.5, 'SW': 225.0, 'WSW': 247.5,
    'W': 270.0, 'WNW': 292.5, 'NW': 315.0, 'NNW': 337.5,
  };

  double? _compassToDeg(String? s) =>
      s == null ? null : _compass[s.toUpperCase().trim()];

  /// NWS observation values are `{ "value": <num|null>, "unitCode": "..." }`.
  double? _value(Object? node) {
    if (node is! Map) return null;
    final v = node['value'];
    return v == null ? null : (v as num).toDouble();
  }

  /// windSpeed unitCode is `wmoUnit:km_h-1` or `wmoUnit:m_s-1`. Normalize → km/h.
  double? _windKmh(Object? node) {
    if (node is! Map) return null;
    final v = node['value'];
    if (v == null) return null;
    final kmh = (v as num).toDouble();
    final unit = (node['unitCode'] ?? '').toString();
    return unit.contains('m_s') ? kmh * 3.6 : kmh;
  }

  Future<bool> _hasRedFlag(LatLng at) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '${ApiConfig.nwsBase}/alerts/active?point=${at.latitude.toStringAsFixed(4)},${at.longitude.toStringAsFixed(4)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final feats = (jsonDecode(res.body)['features'] as List?) ?? const [];
      for (final f in feats) {
        final event =
            ((f['properties'] as Map?)?['event'] ?? '').toString().toLowerCase();
        if (event.contains('red flag') || event.contains('fire weather')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
