import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/fire_incident.dart';
import 'api_config.dart';

/// NIFC / WFIGS client — authoritative US wildfire incident locations and
/// interagency perimeters via public ArcGIS Feature Service GeoJSON queries,
/// constrained to a bbox around a focus point. Empty on any failure.
class NifcService {
  NifcService._();
  static final NifcService instance = NifcService._();

  Future<List<FireIncident>> fetchPerimeters(LatLng center) =>
      _query(ApiConfig.nifcPerimetersQuery, center);

  Future<List<FireIncident>> fetchIncidents(LatLng center) =>
      _query(ApiConfig.nifcIncidentsQuery, center);

  Future<List<FireIncident>> _query(String base, LatLng center) async {
    try {
      final h = ApiConfig.areaBboxHalfDeg;
      // Comma-form envelope (xmin,ymin,xmax,ymax) — universally honored by
      // ArcGIS FeatureServers. The JSON-envelope form is silently ignored by
      // some, which would return the entire national dataset and make every
      // zone look like it's next to a fire.
      final bbox = '${center.longitude - h},${center.latitude - h},'
          '${center.longitude + h},${center.latitude + h}';
      final uri = Uri.parse(base).replace(queryParameters: {
        'where': '1=1',
        'outFields': '*',
        'geometry': bbox,
        'geometryType': 'esriGeometryEnvelope',
        'inSR': '4326',
        'outSR': '4326',
        'spatialRel': 'esriSpatialRelIntersects',
        'returnGeometry': 'true',
        'resultRecordCount': '250',
        'f': 'geojson',
      });

      final res =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(res.body);
      final feats = (body['features'] as List?) ?? const [];
      final out = <FireIncident>[];
      for (final f in feats) {
        final inc =
            FireIncident.fromGeoJson((f as Map).cast<String, dynamic>());
        if (inc != null) out.add(inc);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
