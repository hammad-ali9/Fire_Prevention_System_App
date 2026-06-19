import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import 'zone_creation_screen.dart';

/// CREATE NEW ZONE — Figma node 53:5677 (scrim) + 53:5678 (card).
///
/// A modal popup launched from the Select Zone "+" button. Name the zone,
/// pick a Location Method, then Save:
///  • Map            → opens the map picker to tap-drop the pin.
///  • Manual Location → enters latitude/longitude; those coordinates are
///                      plotted on the map picker (pin pre-dropped) for a
///                      final confirm + save.
class CreateZoneDialog extends StatefulWidget {
  const CreateZoneDialog({super.key});

  /// Shows the popup, then (if a method was confirmed) pushes the map picker
  /// on [context]'s navigator. Kept outside the dialog so navigation survives
  /// the dialog being dismissed.
  static Future<void> show(BuildContext context) async {
    final result = await showDialog<_CreateZoneResult>(
      context: context,
      barrierColor: const Color(0x66000000), // Figma scrim rgba(0,0,0,0.4)
      builder: (_) => const CreateZoneDialog(),
    );
    if (result == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneCreationScreen(
          presetName: result.name,
          presetCenter: result.center,
        ),
      ),
    );
  }

  @override
  State<CreateZoneDialog> createState() => _CreateZoneDialogState();
}

enum _LocMethod { map, manual }

class _CreateZoneResult {
  const _CreateZoneResult(this.name, this.center);
  final String? name;
  final LatLng? center; // null → Map method (tap to pick)
}

class _CreateZoneDialogState extends State<CreateZoneDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _lat = TextEditingController();
  final TextEditingController _lng = TextEditingController();

  _LocMethod _method = _LocMethod.map;

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  String? get _zoneName {
    final n = _name.text.trim();
    return n.isEmpty ? null : n;
  }

  void _onSave() {
    if (_method == _LocMethod.map) {
      Navigator.pop(context, _CreateZoneResult(_zoneName, null));
      return;
    }
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      _snack('Enter a valid latitude and longitude');
      return;
    }
    if (lat < -90 || lat > 90) {
      _snack('Latitude must be between -90 and 90');
      return;
    }
    if (lng < -180 || lng > 180) {
      _snack('Longitude must be between -180 and 180');
      return;
    }
    Navigator.pop(
      context,
      _CreateZoneResult(_zoneName, LatLng(lat, lng)),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final manual = _method == _LocMethod.manual;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: Colors.white,
      // Figma card 53:5678 — rounded 19.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 25, 16, 25),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 23),
              _label('Zone Name'),
              const SizedBox(height: 8),
              _inputPill(
                controller: _name,
                icon: Icons.mail_outline,
                hint: 'e.g. Zone A',
              ),
              const SizedBox(height: 20),
              const Text(
                'Location Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF272727),
                  letterSpacing: -0.315,
                  height: 19 / 16,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  // Figma widths 121 : 198 → flex ratio.
                  Expanded(
                    flex: 121,
                    child: _methodChip(
                      label: 'Map',
                      icon: Icons.map_outlined,
                      selected: !manual,
                      onTap: () => setState(() => _method = _LocMethod.map),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 198,
                    child: _methodChip(
                      label: 'Manual Location',
                      icon: Icons.my_location_outlined,
                      selected: manual,
                      onTap: () =>
                          setState(() => _method = _LocMethod.manual),
                    ),
                  ),
                ],
              ),
              if (manual) ...[
                const SizedBox(height: 23),
                _label('Latitude'),
                const SizedBox(height: 8),
                _inputPill(
                  controller: _lat,
                  icon: Icons.mail_outline,
                  hint: 'e.g. 34.0522',
                  number: true,
                ),
                const SizedBox(height: 23),
                _label('Longitude'),
                const SizedBox(height: 8),
                _inputPill(
                  controller: _lng,
                  icon: Icons.mail_outline,
                  hint: 'e.g. -118.2437',
                  number: true,
                ),
              ],
              const SizedBox(height: 28),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Header — Figma 53:5680: circular back (closes popup) + centered title.
  Widget _header() {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 55,
              height: 55,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE9E9E9)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Create New Zone',
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
    );
  }

  // Field label — Figma 53:5691 (#111214, 14, ls -0.028).
  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF111214),
          letterSpacing: -0.028,
        ),
      );

  // Input pill — Figma 53:5692 (bg #F3F3F4, radius 43, padding 16, leading
  // 24px icon + text). Disabled fields dim to signal they're inactive.
  Widget _inputPill({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool enabled = true,
    bool number = false,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(43),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF393C43)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                cursorColor: AppColors.primary,
                keyboardType: number
                    ? const TextInputType.numberWithOptions(
                        decimal: true, signed: true)
                    : TextInputType.text,
                inputFormatters: number
                    ? [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.\-]')),
                      ]
                    : null,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9AA0A6),
                    letterSpacing: -0.048,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF393C43),
                  letterSpacing: -0.048,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Segmented option — Figma 53:5700 (selected: bg #092C1B / white) vs
  // 53:5705 (unselected: bg #F3F3F4 / #393C43). Sized to content like Figma.
  Widget _methodChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : const Color(0xFF393C43);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48, // match Select Zone action button
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF3F3F4),
          borderRadius: BorderRadius.circular(43),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: fg,
                letterSpacing: -0.048,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Save Zone CTA — Figma 53:5727 (bg #092C1B, radius 61, fire icon + label).
  Widget _saveButton() {
    return GestureDetector(
      onTap: _onSave,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(61),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _method == _LocMethod.map
                  ? Icons.map_outlined
                  : Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 5),
            Text(
              _method == _LocMethod.map ? 'Go to map' : 'Save Zone',
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
    );
  }
}
