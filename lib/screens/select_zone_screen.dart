import 'package:flutter/material.dart';

import '../models/zone.dart';
import '../services/zone_store.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import 'add_zone_via_device_sheet.dart';
import 'create_zone_dialog.dart';
import '../widgets/status_bar.dart';
import 'zone_creation_screen.dart';
import 'zone_devices_screen.dart';

/// SELECT ZONE — Figma node 1:966.
/// Lists zones from [ZoneStore]; tapping a card pops the Zone back to the
/// caller (home), which then sets it active. Includes a live text-filter.
class SelectZoneScreen extends StatefulWidget {
  const SelectZoneScreen({super.key});

  @override
  State<SelectZoneScreen> createState() => _SelectZoneScreenState();
}

class _SelectZoneScreenState extends State<SelectZoneScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Bottom-sheet menu shown from the "+" button: pick how the zone's location
  /// is set — tap/type it manually, or seed it from a device's live position.
  Future<void> _showAddZoneMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddZoneMenu(),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'manual') {
      CreateZoneDialog.show(context);
      return;
    }
    // Via device: capture the device's live location, then confirm on the map.
    final result = await AddZoneViaDeviceSheet.show(context);
    if (result == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneCreationScreen(
          presetName: result.name,
          presetCenter: result.center,
          deviceSerial: result.serial,
          deviceRegion: result.region,
          deviceType: result.type,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Zone zone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete zone?'),
        content: Text(
          'Remove ${zone.fullLabel}? This stops any active protocol and '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBA0C0C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) ZoneStore.instance.removeZone(zone.id);
  }

  bool _matches(Zone z, String q) {
    if (q.isEmpty) return true;
    final ql = q.toLowerCase();
    return z.name.toLowerCase().contains(ql) ||
        z.sector.toLowerCase().contains(ql) ||
        z.riskLevel.toLowerCase().contains(ql);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const FakeStatusBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PageHeader(
                title: 'Zone List',
                trailing: GestureDetector(
                  onTap: () => _showAddZoneMenu(context),
                  child: Container(
                    width: 55,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE9E9E9)),
                    ),
                    child: const Icon(Icons.add_rounded, size: 22,
                        color: Color(0xFF272727)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 23),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _searchBar(),
            ),
            const SizedBox(height: 17),
            Expanded(
              child: ValueListenableBuilder<List<Zone>>(
                valueListenable: ZoneStore.instance.zones,
                builder: (context, zones, _) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _query,
                    builder: (context, value, _) {
                      if (zones.isEmpty) {
                        return _Empty(onAdd: () => _showAddZoneMenu(context));
                      }
                      const riskOrder = {
                        'HIGH': 0,
                        'ELEVATED': 1,
                        'MODERATE': 2,
                        'LOW': 3,
                      };
                      final filtered = zones
                          .where((z) => _matches(z, value.text.trim()))
                          .toList()
                        ..sort((a, b) {
                          final ra = riskOrder[a.riskLevel] ?? 99;
                          final rb = riskOrder[b.riskLevel] ?? 99;
                          if (ra != rb) return ra.compareTo(rb);
                          return b.riskPercent.compareTo(a.riskPercent);
                        });
                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No zones match "${value.text}".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF565656)),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ZoneCard(
                          zone: filtered[i],
                          isActive: filtered[i].isActive,
                          onSelect: () => Navigator.pop(context, filtered[i]),
                          onStop: () =>
                              ZoneStore.instance.deactivate(filtered[i].id),
                          onDelete: () => _confirmDelete(context, filtered[i]),
                          onSelectDevice: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ZoneDevicesScreen(zone: filtered[i]),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const NotchArea(),
          ],
        ),
      ),
    );
  }

  // SEARCH BAR — Figma node 32:20815. Single white pill, 1px #EAEAEA
  // border, radius 45, padding 17×14. Empty state shows the search icon +
  // placeholder centered as one group (Figma 32:20816, gap 7, justify-center).
  static const _hintStyle = TextStyle(
    fontSize: 16,
    color: Color(0xFF777777),
    letterSpacing: -0.315,
    height: 20.671 / 16,
  );

  Widget _searchBar() => Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEAEAEA)),
          borderRadius: BorderRadius.circular(45),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 24, color: Color(0xFF777777)),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: _query,
                textAlignVertical: TextAlignVertical.center,
                cursorColor: AppColors.primary,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Search anything',
                  hintStyle: _hintStyle,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF272727),
                  letterSpacing: -0.315,
                  height: 20.671 / 16,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _query,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _query.clear(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF777777)),
                  ),
                );
              },
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.layers_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'No zones yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF272727),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first zone on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0x99565656),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined,
                  color: Colors.white),
              label: const Text('Add Zone'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "+" action sheet: choose Manual vs Device as the zone's location
/// source. Pops 'manual' or 'device' to [_showAddZoneMenu].
class _AddZoneMenu extends StatelessWidget {
  const _AddZoneMenu();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                'Add Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF272727),
                ),
              ),
            ),
            _AddZoneOption(
              icon: Icons.edit_location_alt_outlined,
              title: 'Add Zone Manually',
              subtitle: 'Tap the map or enter latitude / longitude',
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            const SizedBox(height: 8),
            _AddZoneOption(
              icon: Icons.sensors_rounded,
              title: 'Add Zone via Device',
              subtitle: 'Use a device\'s live reported location',
              onTap: () => Navigator.pop(context, 'device'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddZoneOption extends StatelessWidget {
  const _AddZoneOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAEAEA)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF272727),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF62748E),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF90A1B9)),
          ],
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.isActive,
    required this.onSelect,
    required this.onStop,
    required this.onDelete,
    required this.onSelectDevice,
  });

  final Zone zone;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onStop;
  final VoidCallback onDelete;
  final VoidCallback onSelectDevice;

  /// Action-button fill by risk level — Figma node 53:5972 (ZONE LIST).
  /// HIGH=red, ELEVATED=orange, MODERATE=gold, LOW=forest green.
  Color get _riskButtonColor {
    switch (zone.riskLevel) {
      case 'HIGH':
        return const Color(0xFFBA0C0C);
      case 'ELEVATED':
        return const Color(0xFFFF9E18);
      case 'MODERATE':
        return const Color(0xFFC1903A);
      default: // LOW
        return const Color(0xFF092C1B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${zone.riskLevel} RISK',
                      style: const TextStyle(
                        color: Color(0xFF90A1B9),
                        fontSize: 16,
                        height: 24 / 16,
                        letterSpacing: 0.4875,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zone.fullLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172B),
                        height: 27 / 18,
                        letterSpacing: -0.4395,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onSelectDevice,
                child: Container(
                  height: 32,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Select Device',
                    style: TextStyle(
                      color: Color(0xFF314158),
                      fontSize: 14,
                      height: 24 / 14,
                      letterSpacing: -0.3125,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Color(0xFFBA0C0C)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: isActive ? onStop : onSelect,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFBA0C0C)
                    : _riskButtonColor,
                borderRadius: BorderRadius.circular(61),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    isActive
                        ? 'Stop ${zone.fullLabel}'
                        : 'Active ${zone.fullLabel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
}
