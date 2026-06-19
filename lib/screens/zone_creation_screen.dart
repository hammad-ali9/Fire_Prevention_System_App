import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/zone.dart';
import '../routes/app_routes.dart';
import '../services/api_config.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/map_config.dart';
import '../services/zone_store.dart';
import '../theme/app_colors.dart';
import '../widgets/location_search_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/status_bar.dart';

/// First-run zone creation. Real MapTiler tiles; tap the map to drop a pin,
/// then name + save. Routes to /home once at least one zone is registered.
class ZoneCreationScreen extends StatefulWidget {
  const ZoneCreationScreen({
    super.key,
    this.presetName,
    this.presetCenter,
  });

  /// Pre-filled zone name forwarded from [CreateZoneScreen].
  final String? presetName;

  /// Pin coordinate forwarded from the manual-coordinate flow. When set, the
  /// pin is pre-dropped here and the map opens centered on it.
  final LatLng? presetCenter;

  @override
  State<ZoneCreationScreen> createState() => _ZoneCreationScreenState();
}

class _ZoneCreationScreenState extends State<ZoneCreationScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _sector = TextEditingController();

  late LatLng _initialCenter;
  LatLng? _pickedCenter;

  @override
  void initState() {
    super.initState();
    // No manual coordinate forwarded → open on the device's location
    // (LA fallback if GPS denied / unavailable), not a fixed country.
    _initialCenter = widget.presetCenter ??
        LocationService.instance.lastKnown ??
        ApiConfig.fallbackCenter;
    _pickedCenter = widget.presetCenter;
    if (widget.presetName != null) _name.text = widget.presetName!;
    if (widget.presetCenter == null) _autoLocate();
  }

  Future<void> _autoLocate() async {
    final here = await LocationService.instance.resolve();
    if (!mounted) return;
    setState(() => _initialCenter = here);
    // Guard: MapController throws if used before the map is rendered.
    try {
      _mapController.move(here, 13);
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapController.dispose();
    _name.dispose();
    _sector.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    setState(() => _pickedCenter = latlng);
  }

  void _onSearchSelected(GeocodeResult r) {
    setState(() {
      _initialCenter = r.center;
      _pickedCenter = r.center;
    });
    try {
      _mapController.move(r.center, 15);
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, (cam.zoom + delta).clamp(2.0, 19.0));
  }

  Future<void> _saveZone() async {
    final center = _pickedCenter;
    final name = _name.text.trim().isEmpty ? 'Zone A' : _name.text.trim();
    final sector =
        _sector.text.trim().isEmpty ? 'Primary Sector' : _sector.text.trim();
    if (center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the map to drop a zone pin first')),
      );
      return;
    }
    final zone = Zone(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      sector: sector,
      center: center,
      polygon: ZoneStore.defaultPolygonAround(center),
    );
    ZoneStore.instance.addZone(zone);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _pickedCenter;
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 13,
                  onTap: _onMapTap,
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
                  if (center != null)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: ZoneStore.defaultPolygonAround(center),
                          color: AppColors.primary.withValues(alpha: 0.18),
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  if (center != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: const [
                      TextSourceAttribution(MapConfig.attribution),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom sheet stays pinned to the bottom; lifts above the
            // keyboard via Scaffold's resizeToAvoidBottomInset. Placed
            // before the top chrome so the search dropdown overlays it.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _bottomSheet(),
                  ),
                  Container(
                    color: Colors.white,
                    child: const NotchArea(),
                  ),
                ],
              ),
            ),
            // Top chrome: status bar + search/topCard. Anchored separately
            // so the search dropdown can overlay both the map and the
            // bottom sheet without pushing layout around.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const FakeStatusBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _topCard(),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 260,
              child: _zoomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCard() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEAEAEA)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF272727)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LocationSearchBar(
            proximity: _pickedCenter ?? _initialCenter,
            onSelected: _onSearchSelected,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _pickedCenter = null),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.refresh_rounded,
                color: Color(0xFF272727)),
          ),
        ),
      ],
    );
  }

  Widget _zoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomBtn(Icons.add, () => _zoomBy(1)),
          Container(height: 1, width: 32, color: const Color(0xFFEAEAEA)),
          _zoomBtn(Icons.remove, () => _zoomBy(-1)),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: const Color(0xFF272727), size: 22),
      ),
    );
  }

  Widget _bottomSheet() {
    final placed = _pickedCenter != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                placed ? Icons.check_circle : Icons.touch_app_outlined,
                color: placed ? const Color(0xFF00A92A) : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                placed ? 'Pin placed — name the zone' : 'Tap on map to drop pin',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF272727),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              hintText: 'Zone name (e.g. Zone A)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sector,
            decoration: const InputDecoration(
              hintText: 'Sector (e.g. South Sector)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Save Zone',
            icon: Icons.check_rounded,
            onPressed: placed ? _saveZone : null,
          ),
        ],
      ),
    );
  }
}
