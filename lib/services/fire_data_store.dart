import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/fire_hotspot.dart';
import '../models/fire_incident.dart';

/// Shared, map-facing cache of the latest NASA FIRMS hotspots and NIFC/WFIGS
/// incidents + perimeters around the current focus point. Refreshed by
/// [LiveDataService]; consumed by the map layers.
class FireDataStore {
  FireDataStore._();
  static final FireDataStore instance = FireDataStore._();

  final ValueNotifier<List<FireHotspot>> hotspots =
      ValueNotifier<List<FireHotspot>>(const []);
  final ValueNotifier<List<FireIncident>> incidents =
      ValueNotifier<List<FireIncident>>(const []);

  /// Center the displayed data was last fetched around (for "stale vs here").
  LatLng? lastFocus;

  void setHotspots(List<FireHotspot> v) =>
      hotspots.value = List.unmodifiable(v);

  void setIncidents(List<FireIncident> v) =>
      incidents.value = List.unmodifiable(v);
}
