import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../services/tg_api_service.dart';
import '../services/tg_service.dart';
import '../theme/app_colors.dart';

/// Coordinates + device identity captured from the "Add Zone via Device" flow.
/// Forwarded to [ZoneCreationScreen] so the pin opens on the device's live
/// position and the device is registered to the zone once it's saved.
class AddZoneViaDeviceResult {
  const AddZoneViaDeviceResult({
    required this.name,
    required this.center,
    required this.serial,
    required this.region,
    required this.type,
  });

  final String? name;
  final LatLng center;
  final String serial;
  final String region;
  final String type;
}

/// ADD ZONE VIA DEVICE — the second entry from the Zone List "+" menu.
///
/// The user identifies a device (serial + server region); the app pulls its
/// latest telemetry from Telematics Guru, reads the reported lat/lng, and uses
/// that as the seed location for the new zone. Resolves via [show] to an
/// [AddZoneViaDeviceResult] the caller pushes onto [ZoneCreationScreen].
class AddZoneViaDeviceSheet {
  static Future<AddZoneViaDeviceResult?> show(BuildContext context) {
    return showModalBottomSheet<AddZoneViaDeviceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _Sheet(),
    );
  }
}

class _Sheet extends StatefulWidget {
  const _Sheet();

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final _name = TextEditingController();
  final _serial = TextEditingController();
  final _region = TextEditingController();

  String _type = 'gps_tracker';

  bool _loading = false;
  String? _error;
  // Populated once a location is successfully fetched.
  LatLng? _location;
  String? _assetName;
  bool? _online;

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _region.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    setState(() {
      _type = type;
      // Reset a fetched location — the identity changed.
      _location = null;
      _error = null;
      if (type == 'sprinkler') {
        // Auto-fill the known demo device credentials (matches AddDeviceSheet).
        _serial.text = '1429272';
        _region.text = 'EMEA03';
      } else {
        if (_serial.text == '1429272') _serial.clear();
        if (_region.text == 'EMEA03') _region.clear();
      }
    });
  }

  Future<void> _fetchLocation() async {
    final serial = _serial.text.trim();
    if (serial.isEmpty) {
      setState(() => _error = 'Enter the device serial number first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _location = null;
    });
    try {
      final t = await TGApiService.instance.fetchTelemetryOnce(serial);
      if (!mounted) return;
      final lat = t.latitude, lng = t.longitude;
      if (lat == null || lng == null) {
        setState(() {
          _loading = false;
          _error =
              'Device $serial was found but has not reported a location yet. '
              'Wait for its next check-in, or add the zone manually.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _location = LatLng(lat, lng);
        _assetName = t.assetName;
        _online = t.isOnline;
      });
    } on TGNotFoundException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No device with serial $serial found in Telematics Guru. '
            'Check the serial and server region.';
      });
    } on TGAuthException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Telematics Guru rejected the credentials (auth failed).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach Telematics Guru from this network. This is '
            'usually the IP allowlist — see the device flow for the guide.';
      });
    }
  }

  void _continue() {
    final center = _location;
    if (center == null) return;
    Navigator.pop(
      context,
      AddZoneViaDeviceResult(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        center: center,
        serial: _serial.text.trim(),
        region: _region.text.trim(),
        type: _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: h * 0.9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 55,
                      height: 55,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE9E9E9)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 22, color: Color(0xFF272727)),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Add Zone via Device',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF272727),
                          letterSpacing: -0.315,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 55),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The zone is created at the device\'s last reported '
                      'location.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF62748E),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label('Zone Name (Optional)'),
                    const SizedBox(height: 8),
                    _field(_name, Icons.layers_outlined, 'e.g. Zone A'),
                    const SizedBox(height: 20),
                    _label('Device Type'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _typeChip(
                            'gps_tracker',
                            'GPS Tracker',
                            Icons.gps_fixed_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _typeChip(
                            'sprinkler',
                            'Water Sprinkler',
                            Icons.water_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _label('Device Serial Number'),
                    const SizedBox(height: 8),
                    _field(_serial, Icons.tag_rounded, 'e.g. 1429272',
                        onChanged: (_) {
                      if (_location != null || _error != null) {
                        setState(() {
                          _location = null;
                          _error = null;
                        });
                      }
                    }),
                    const SizedBox(height: 16),
                    _label('Server Region'),
                    const SizedBox(height: 8),
                    _field(_region, Icons.public_rounded, 'e.g. EMEA03'),
                    const SizedBox(height: 20),
                    _fetchButton(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _errorCard(_error!),
                    ],
                    if (_location != null) ...[
                      const SizedBox(height: 14),
                      _locationCard(_location!),
                    ],
                    const SizedBox(height: 20),
                    _continueButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111214),
          letterSpacing: -0.028,
        ),
      );

  Widget _field(
    TextEditingController controller,
    IconData icon,
    String hint, {
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F4),
        borderRadius: BorderRadius.circular(43),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF393C43)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\n')),
              ],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF393C43),
                letterSpacing: -0.048,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9AA0A6),
                  letterSpacing: -0.048,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String id, String label, IconData icon) {
    final selected = _type == id;
    final fg = selected ? Colors.white : const Color(0xFF393C43);
    return GestureDetector(
      onTap: () => _selectType(id),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(43),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                  letterSpacing: -0.048,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fetchButton() {
    return GestureDetector(
      onTap: _loading ? null : _fetchLocation,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(43),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF62748E)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.my_location_rounded,
                      size: 18, color: Color(0xFF314158)),
                  SizedBox(width: 8),
                  Text(
                    'Fetch Device Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF314158),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFBA0C0C).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFBA0C0C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFBA0C0C),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(LatLng loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _assetName?.isNotEmpty == true
                      ? 'Location found — $_assetName'
                      : 'Location found',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              if (_online != null)
                Text(
                  _online! ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _online!
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF90A1B9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lat ${loc.latitude.toStringAsFixed(5)},  '
            'Lng ${loc.longitude.toStringAsFixed(5)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF166534),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueButton() {
    final enabled = _location != null;
    return GestureDetector(
      onTap: enabled ? _continue : null,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(61),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_outlined, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              'Continue on Map',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.315,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
