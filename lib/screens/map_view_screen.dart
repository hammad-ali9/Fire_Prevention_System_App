import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/fire_hotspot.dart';
import '../models/fire_incident.dart';
import '../models/zone.dart';
import '../services/api_config.dart';
import '../services/fire_data_store.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/map_config.dart';
import '../services/zone_store.dart';
import '../widgets/location_search_bar.dart';
import '../widgets/status_bar.dart';

/// MAP VIEW — Figma node 32:21562. Shows the active zone's polygon on a live
/// map with a building-photo backdrop and a fire-risk detail card overlay.
class MapViewScreen extends StatelessWidget {
  const MapViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ValueListenableBuilder<List<Zone>>(
          valueListenable: ZoneStore.instance.zones,
          builder: (context, zones, _) {
            return ValueListenableBuilder<List<String>>(
              valueListenable: ZoneStore.instance.activeZoneIds,
              builder: (context, _, _) {
                final active = ZoneStore.instance.activeZone;
                final zone = active ?? (zones.isNotEmpty ? zones.first : null);
                return _MapView(zone: zone);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView({required this.zone});
  final Zone? zone;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final MapController _map = MapController();

  /// Map center: zone if one exists, else device GPS (LA fallback). Resolved
  /// async on first build when there's no zone to anchor to.
  late LatLng _center;
  bool _locating = false;

  /// Location chosen from the search dropdown. Drawn as a pin on the map.
  LatLng? _searched;
  String? _searchedLabel;

  @override
  void initState() {
    super.initState();
    _center = widget.zone?.center ??
        LocationService.instance.lastKnown ??
        ApiConfig.fallbackCenter;
    // Defer GPS resolve until after the first frame — calling setState()
    // synchronously during initState crashes the build (blank screen).
    if (widget.zone == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoLocate(initial: true),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fitZone(widget.zone!),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final z = widget.zone;
    if (z != null && z.id != oldWidget.zone?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitZone(z));
    }
  }

  void _fitZone(Zone z) {
    if (z.polygon.isEmpty) return;
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(z.polygon),
          padding: const EdgeInsets.fromLTRB(20, 120, 20, 240),
          maxZoom: 19,
        ),
      );
    } catch (_) {}
  }

  Future<void> _autoLocate({bool initial = false}) async {
    if (_locating || !mounted) return;
    setState(() => _locating = true);
    final here = await LocationService.instance.resolve();
    if (!mounted) return;
    setState(() {
      _center = here;
      _locating = false;
    });
    // MapController throws if used before the map is rendered.
    try {
      _map.move(here, initial ? 13 : 15);
    } catch (_) {}
  }

  void _goToSearched(GeocodeResult r) {
    setState(() {
      _searched = r.center;
      _searchedLabel = r.text;
      _center = r.center;
    });
    try {
      _map.move(r.center, 15);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;

    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<List<FireHotspot>>(
            valueListenable: FireDataStore.instance.hotspots,
            builder: (context, hotspots, _) {
              return ValueListenableBuilder<List<FireIncident>>(
                valueListenable: FireDataStore.instance.incidents,
                builder: (context, incidents, _) {
                  return FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 14,
                      maxZoom: 19,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: MapConfig.tileUrlTemplate(),
                        userAgentPackageName: MapConfig.userAgent,
                        maxZoom: 19,
                      ),
                      // NIFC/WFIGS official fire perimeters (authoritative).
                      PolygonLayer(
                        polygons: [
                          for (final inc in incidents)
                            for (final ring in inc.perimeter)
                              Polygon(
                                points: ring,
                                color: const Color(0xFFBA0C0C)
                                    .withValues(alpha: 0.18),
                                borderColor: const Color(0xFFBA0C0C),
                                borderStrokeWidth: 1.5,
                              ),
                        ],
                      ),
                      if (zone != null)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: zone.polygon,
                              color: const Color(0xFF092C1B)
                                  .withValues(alpha: 0.22),
                              borderColor: const Color(0xFF272727),
                              borderStrokeWidth: 1.2,
                            ),
                          ],
                        ),
                      // NASA FIRMS active-fire hotspots.
                      MarkerLayer(
                        markers: [
                          for (final h in hotspots)
                            Marker(
                              point: h.point,
                              width: 16,
                              height: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFF6A00)
                                      .withValues(alpha: 0.85),
                                  border: Border.all(
                                      color: Colors.white, width: 1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // NIFC official incident points.
                      MarkerLayer(
                        markers: [
                          for (final inc in incidents)
                            if (!inc.hasPerimeter)
                              Marker(
                                point: inc.point,
                                width: 24,
                                height: 24,
                                child: const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Color(0xFFBA0C0C),
                                  size: 22,
                                ),
                              ),
                        ],
                      ),
                      if (zone != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: zone.center,
                              width: 28,
                              height: 28,
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF092C1B),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.location_on,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      if (_searched != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _searched!,
                              width: 36,
                              height: 36,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFBA0C0C),
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 280,
          child: GestureDetector(
            onTap: () => _autoLocate(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded,
                      color: Color(0xFF272727), size: 22),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ImageBackdrop(height: 220),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: _DetailCard(zone: zone),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const FakeStatusBar(),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x0F000000),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF5F6368), size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LocationSearchBar(
                        proximity: _center,
                        selectedLabel: _searchedLabel,
                        onSelected: _goToSearched,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: const Color(0xFFEDEDED),
            child: const NotchArea(),
          ),
        ),
      ],
    );
  }
}


class _ImageBackdrop extends StatelessWidget {
  const _ImageBackdrop({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(
        'assets/map.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.zone});
  final Zone? zone;

  Color _riskColor(String? level) {
    switch (level) {
      case 'HIGH':
        return const Color(0xFFBA0C0C);
      case 'ELEVATED':
        return const Color(0xFFFF9E18);
      case 'MODERATE':
        return const Color(0xFFE4A800);
      case 'LOW':
        return const Color(0xFF00A92A);
      default:
        return const Color(0xFF373737);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = zone?.isActive ?? false;
    final label = zone?.fullLabel ?? 'No zone selected';
    final level = zone?.riskLevel ?? 'NO';
    final pct = zone?.riskPercent ?? 0;
    final riskColor = _riskColor(zone?.riskLevel);
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$level Fire Risk · ${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: riskColor,
                          height: 13 / 16,
                          letterSpacing: -0.315,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF777777),
                          height: 13 / 14,
                          letterSpacing: -0.315,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: zone == null
                      ? null
                      : () {
                          if (isActive) {
                            ZoneStore.instance.deactivate(zone!.id);
                          } else {
                            ZoneStore.instance.activate(zone!.id);
                          }
                        },
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    color: isActive
                        ? const Color(0xFFBA0C0C)
                        : const Color(0xFF092C1B),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 19),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _meta(
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                    value: zone?.name ?? '—',
                  ),
                ),
                Container(
                  width: 1,
                  color: const Color(0x33D9D9D9),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _meta(
                      label: 'Time',
                      icon: Icons.access_time_rounded,
                      value: _nowHm(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: zone == null
                ? null
                : () {
                    if (isActive) {
                      ZoneStore.instance.deactivate(zone!.id);
                    } else {
                      ZoneStore.instance.activate(zone!.id);
                    }
                  },
            child: Container(
              height: 67,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFBA0C0C)
                    : const Color(0xFF092C1B),
                borderRadius: BorderRadius.circular(61),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.stop_circle_outlined
                        : Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? 'Stop $label' : 'Activate $label',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 19 / 16,
                      letterSpacing: -0.315,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0x80000000),
            height: 19 / 12,
            letterSpacing: -0.315,
          ),
        ),
        Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF272727)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF272727),
                height: 19 / 14,
                letterSpacing: -0.315,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _nowHm() {
    final t = DateTime.now();
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
