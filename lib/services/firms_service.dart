import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/fire_hotspot.dart';
import 'api_config.dart';

/// NASA FIRMS client — near-real-time active-fire / thermal-anomaly
/// detections via the area CSV API. Requires a free MAP_KEY
/// ([ApiConfig.firmsMapKey]); without one [fetchArea] no-ops to an empty list
/// so the rest of the app keeps working.
class FirmsService {
  FirmsService._();
  static final FirmsService instance = FirmsService._();

  /// Hotspots within a bbox built around [center]. Empty on any failure.
  Future<List<FireHotspot>> fetchArea(LatLng center) async {
    if (!ApiConfig.firmsEnabled) return const [];
    try {
      final h = ApiConfig.areaBboxHalfDeg;
      // FIRMS area expects: west,south,east,north
      final bbox = '${center.longitude - h},${center.latitude - h},'
          '${center.longitude + h},${center.latitude + h}';
      final url = '${ApiConfig.firmsBase}/${ApiConfig.firmsMapKey}/'
          '${ApiConfig.firmsSource}/$bbox/${ApiConfig.firmsDayRange}';

      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const [];

      final lines = res.body
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.length < 2) return const []; // header only / empty

      final header = lines.first.split(',');
      final idx = {
        for (var i = 0; i < header.length; i++) header[i].trim(): i,
      };

      final out = <FireHotspot>[];
      for (final line in lines.skip(1)) {
        final hs = FireHotspot.fromCsvRow(line.split(','), idx);
        if (hs != null) out.add(hs);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
