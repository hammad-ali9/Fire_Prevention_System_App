import 'package:latlong2/latlong.dart';

/// A NASA FIRMS satellite thermal-anomaly detection. NOTE: a hotspot is a
/// detection, not a confirmed wildfire — cross-check with NIFC incidents.
class FireHotspot {
  const FireHotspot({
    required this.point,
    required this.confidence,
    required this.brightness,
    required this.frp,
    required this.acquired,
    required this.satellite,
  });

  final LatLng point;
  final String confidence; // 'l' | 'n' | 'h'  (VIIRS: low/nominal/high)
  final double brightness; // bright_ti4 (K)
  final double frp; // fire radiative power (MW)
  final DateTime acquired;
  final String satellite;

  /// Parses one FIRMS area-CSV row given the header column index map.
  static FireHotspot? fromCsvRow(List<String> row, Map<String, int> idx) {
    double? d(String k) {
      final i = idx[k];
      if (i == null || i >= row.length) return null;
      return double.tryParse(row[i].trim());
    }

    String s(String k) {
      final i = idx[k];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    final lat = d('latitude');
    final lng = d('longitude');
    if (lat == null || lng == null) return null;

    DateTime acq;
    try {
      final date = s('acq_date'); // YYYY-MM-DD
      final time = s('acq_time').padLeft(4, '0'); // HHMM
      acq = DateTime.parse(
        '${date}T${time.substring(0, 2)}:${time.substring(2)}:00Z',
      );
    } catch (_) {
      acq = DateTime.now().toUtc();
    }

    return FireHotspot(
      point: LatLng(lat, lng),
      confidence: s('confidence').isEmpty ? 'n' : s('confidence'),
      brightness: d('bright_ti4') ?? 0,
      frp: d('frp') ?? 0,
      acquired: acq,
      satellite: s('satellite'),
    );
  }
}
