import 'package:latlong2/latlong.dart';

/// An authoritative NIFC/WFIGS wildfire — either a point incident location or
/// a mapped perimeter (or both, merged by name when available).
class FireIncident {
  const FireIncident({
    required this.name,
    required this.point,
    this.acres,
    this.containment,
    this.perimeter = const [],
  });

  final String name;
  final LatLng point;
  final double? acres;
  final double? containment; // percent 0..100
  final List<List<LatLng>> perimeter; // outer rings (multi-polygon)

  bool get hasPerimeter => perimeter.isNotEmpty;

  /// Parses an ArcGIS GeoJSON Feature into an incident. Returns null for
  /// geometry types we don't render.
  static FireIncident? fromGeoJson(Map<String, dynamic> feature) {
    final props = (feature['properties'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final geom = (feature['geometry'] as Map?)?.cast<String, dynamic>();
    if (geom == null) return null;

    final name = (props['IncidentName'] ??
            props['poly_IncidentName'] ??
            props['attr_IncidentName'] ??
            'Unnamed Fire')
        .toString();
    final acres = _num(props['DailyAcres'] ??
        props['GISAcres'] ??
        props['poly_GISAcres'] ??
        props['IncidentSize']);
    final containment = _num(props['PercentContained'] ??
        props['attr_PercentContained']);

    final type = geom['type'];
    final coords = geom['coordinates'];

    if (type == 'Point' && coords is List && coords.length >= 2) {
      return FireIncident(
        name: name,
        point: LatLng(
            (coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
        acres: acres,
        containment: containment,
      );
    }

    final rings = <List<LatLng>>[];
    if (type == 'Polygon' && coords is List) {
      _addPolygon(coords, rings);
    } else if (type == 'MultiPolygon' && coords is List) {
      for (final poly in coords) {
        _addPolygon(poly as List, rings);
      }
    }
    if (rings.isEmpty) return null;

    return FireIncident(
      name: name,
      point: _centroid(rings.first),
      acres: acres,
      containment: containment,
      perimeter: rings,
    );
  }

  static void _addPolygon(List polygon, List<List<LatLng>> out) {
    if (polygon.isEmpty) return;
    final outer = polygon.first as List; // ring 0 = outer boundary
    final ring = <LatLng>[
      for (final c in outer)
        if (c is List && c.length >= 2)
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    if (ring.length >= 3) out.add(ring);
  }

  static LatLng _centroid(List<LatLng> ring) {
    var lat = 0.0, lng = 0.0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / ring.length, lng / ring.length);
  }

  static double? _num(Object? v) =>
      v == null ? null : double.tryParse(v.toString());
}
