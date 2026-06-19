import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activation_entry.dart';
import '../models/zone.dart';
import 'history_store.dart';
import 'live_data_service.dart';

/// Zone registry shared across screens. Backed by SharedPreferences so zones
/// (and their activation state) survive app restarts.
///
/// Multiple zones can be active in parallel. [activeZoneIds] is the ordered
/// list of currently-active zone ids (activation order — newest last); the
/// home-screen carousel iterates it. [_sources] tracks how each active zone
/// was triggered so the telemetry simulator only auto-stops what it
/// auto-started.
class ZoneStore {
  ZoneStore._();
  static final ZoneStore instance = ZoneStore._();

  static const _kZonesKey = 'zone_store.zones';
  static const _kActiveIdsKey = 'zone_store.active_ids';

  final ValueNotifier<List<Zone>> zones = ValueNotifier<List<Zone>>([]);
  final ValueNotifier<List<String>> activeZoneIds =
      ValueNotifier<List<String>>(<String>[]);

  final Map<String, ActivationSource> _sources = {};

  /// Read persisted zones + activation state into memory. Call once at app
  /// startup before runApp so the first frame already sees the user's data.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kZonesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        zones.value = [for (final j in list) Zone.fromJson(j)];
      } catch (_) {
        // Corrupted payload — clear it so we don't loop on the same error.
        await prefs.remove(_kZonesKey);
      }
    }
    final ids = prefs.getStringList(_kActiveIdsKey);
    if (ids != null) {
      // Drop any stale ids whose zone no longer exists.
      final known = {for (final z in zones.value) z.id};
      activeZoneIds.value = ids.where(known.contains).toList(growable: false);
      for (final id in activeZoneIds.value) {
        _sources[id] = ActivationSource.manual;
        findById(id)?.isActive = true;
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kZonesKey,
      jsonEncode([for (final z in zones.value) z.toJson()]),
    );
    await prefs.setStringList(_kActiveIdsKey, activeZoneIds.value);
  }

  bool get hasZones => zones.value.isNotEmpty;

  /// Active zones in activation order. Stale ids (zone removed) are skipped.
  List<Zone> get activeZones => [
        for (final id in activeZoneIds.value) ?findById(id),
      ];

  /// First active zone — compatibility shim for single-zone screens
  /// (reports, map, env-scan) that still operate on one focus zone.
  Zone? get activeZone => activeZones.isEmpty ? null : activeZones.first;

  bool isZoneActive(String id) => activeZoneIds.value.contains(id);

  ActivationSource? sourceFor(String id) => _sources[id];

  Zone? findById(String id) {
    for (final z in zones.value) {
      if (z.id == id) return z;
    }
    return null;
  }

  void addZone(Zone z) {
    zones.value = [...zones.value, z];
    _persist();
    // Pull real NWS/FIRMS/NIFC data for the new zone now — don't wait for
    // the next poll cycle (otherwise it shows default 28°C for ~10 min).
    LiveDataService.instance.refreshForZone(z);
  }

  /// Re-emit the zone list — telemetry mutates Zone objects in place so we
  /// need a notification to trigger rebuilds. Deliberately does NOT persist:
  /// telemetry refreshes every few seconds and would thrash storage; the
  /// next live-data refresh after restart will repopulate it anyway.
  void notify() {
    zones.value = List.unmodifiable(zones.value);
  }

  /// Activate [id] alongside any other active zones (parallel). No-op if
  /// already active or unknown.
  void activate(
    String id, {
    ActivationSource source = ActivationSource.manual,
  }) {
    if (isZoneActive(id)) return;
    final z = findById(id);
    if (z == null) return;
    z.isActive = true;
    _sources[id] = source;
    activeZoneIds.value = [...activeZoneIds.value, id];
    HistoryStore.instance.open(
      zoneId: z.id,
      zoneName: z.fullLabel,
      source: source,
    );
    notify();
    _persist();
  }

  /// Deactivate a single zone. Other active zones are untouched.
  void deactivate(String id) {
    if (!isZoneActive(id)) return;
    HistoryStore.instance.closeForZone(id);
    findById(id)?.isActive = false;
    _sources.remove(id);
    activeZoneIds.value =
        activeZoneIds.value.where((e) => e != id).toList(growable: false);
    notify();
    _persist();
  }

  void deactivateAll() {
    for (final id in [...activeZoneIds.value]) {
      deactivate(id);
    }
  }

  // ── Backward-compat shims for single-active call sites ──────────────────

  /// `setActive(null)` clears everything; `setActive(id)` adds [id]
  /// (parallel — does NOT stop other zones).
  void setActive(
    String? id, {
    ActivationSource source = ActivationSource.manual,
  }) {
    if (id == null) {
      deactivateAll();
    } else {
      activate(id, source: source);
    }
  }

  /// Stops the first active zone. Prefer [deactivate] with an explicit id.
  void stopActive() {
    final z = activeZone;
    if (z != null) deactivate(z.id);
  }

  /// Square polygon around a tapped point — fine for the POC at typical
  /// latitudes; production would replace this with a vertex-by-vertex drawer.
  static List<LatLng> defaultPolygonAround(LatLng c, {double meters = 220}) {
    final dLat = meters / 111320.0;
    final dLng = meters / (111320.0 * math.cos(c.latitudeInRad));
    return [
      LatLng(c.latitude + dLat, c.longitude - dLng),
      LatLng(c.latitude + dLat, c.longitude + dLng),
      LatLng(c.latitude - dLat, c.longitude + dLng),
      LatLng(c.latitude - dLat, c.longitude - dLng),
    ];
  }
}
