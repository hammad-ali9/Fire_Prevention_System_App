import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map_config.dart';

/// A single place returned by [GeocodingService.search].
class GeocodeResult {
  GeocodeResult({
    required this.text,
    required this.placeName,
    required this.center,
  });

  /// Primary label, e.g. "Pasadena".
  final String text;

  /// Full address, e.g. "Pasadena, California, United States".
  final String placeName;

  final LatLng center;
}

/// Place-name lookup backed by MapTiler's geocoding API. Reuses the existing
/// MapTiler key from [MapConfig] so the POC needs no extra credentials.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  /// Returns up to ~6 places matching [query]. Empty list on any error so the
  /// search UI degrades to "no results" instead of throwing.
  Future<List<GeocodeResult>> search(String query, {LatLng? proximity}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final params = <String, String>{
      'key': MapConfig.apiKey,
      'limit': '6',
    };
    // Proximity biases results toward where the user currently is on the map,
    // matching Google Maps' "near me" behavior.
    if (proximity != null) {
      params['proximity'] =
          '${proximity.longitude.toStringAsFixed(4)},'
          '${proximity.latitude.toStringAsFixed(4)}';
    }

    final uri = Uri.parse(
      'https://api.maptiler.com/geocoding/${Uri.encodeComponent(q)}.json',
    ).replace(queryParameters: params);

    try {
      final resp = await http.get(
        uri,
        headers: {'User-Agent': MapConfig.userAgent},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final features = (body['features'] as List?) ?? const [];
      final out = <GeocodeResult>[];
      for (final f in features) {
        if (f is! Map<String, dynamic>) continue;
        final parsed = _parse(f);
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  GeocodeResult? _parse(Map<String, dynamic> f) {
    final center = f['center'];
    if (center is! List || center.length < 2) return null;
    final lng = (center[0] as num?)?.toDouble();
    final lat = (center[1] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final text = (f['text'] as String?)?.trim() ?? '';
    final placeName = (f['place_name'] as String?)?.trim() ?? '';
    if (text.isEmpty && placeName.isEmpty) return null;
    return GeocodeResult(
      text: text.isNotEmpty ? text : placeName,
      placeName: placeName.isNotEmpty ? placeName : text,
      center: LatLng(lat, lng),
    );
  }
}
