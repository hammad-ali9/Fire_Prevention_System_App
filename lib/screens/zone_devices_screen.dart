import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/tg_telemetry.dart';
import '../models/zone.dart';
import '../services/device_store.dart';
import '../services/tg_service.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/status_bar.dart';
import 'add_device_sheet.dart';

class ZoneDevicesScreen extends StatelessWidget {
  const ZoneDevicesScreen({super.key, required this.zone});

  final Zone zone;

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
                title: 'Devices',
                trailing: GestureDetector(
                  onTap: () => AddDeviceSheet.show(context, zone),
                  child: Container(
                    width: 55,
                    height: 55,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE9E9E9)),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 22, color: Color(0xFF272727)),
                  ),
                ),
              ),
            ),
            // zone name badge
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    zone.fullLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder<List<Device>>(
                valueListenable: DeviceStore.instance.devices,
                builder: (context, allDevices, _) {
                  final devices = allDevices
                      .where((d) => d.zoneId == zone.id)
                      .toList();
                  if (devices.isEmpty) return const _Empty();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final telemetryNotifier =
                          DeviceStore.instance.telemetryFor(devices[i]);
                      return telemetryNotifier != null
                          ? ValueListenableBuilder<TGTelemetry?>(
                              valueListenable: telemetryNotifier,
                              builder: (context, telemetry, _) =>
                                  _DeviceCard(
                                device: devices[i],
                                telemetry: telemetry,
                                onRemove: () =>
                                    DeviceStore.instance.remove(devices[i].id),
                                onToggleSprinkler: telemetry != null
                                    ? (active) => TGService.instance
                                        .setSprinkler(devices[i].serialNumber,
                                            active: active)
                                    : null,
                              ),
                            )
                          : _DeviceCard(
                              device: devices[i],
                              onRemove: () =>
                                  DeviceStore.instance.remove(devices[i].id),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Device card
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onRemove,
    this.telemetry,
    this.onToggleSprinkler,
  });

  final Device device;
  final TGTelemetry? telemetry;
  final VoidCallback onRemove;
  final Future<bool> Function(bool active)? onToggleSprinkler;

  @override
  Widget build(BuildContext context) {
    final bool isSprinkler = device.type == 'sprinkler';
    final bool online = telemetry?.isOnline ?? false;
    final bool? sprinklerOn = telemetry?.sprinklerActive;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEAEAEA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSprinkler
                      ? const Color(0xFFE8F4FD)
                      : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(device.typeIcon,
                    size: 22,
                    color: isSprinkler
                        ? const Color(0xFF0284C7)
                        : AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.typeLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172B),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.typeSubtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF90A1B9),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Online / offline badge (TG devices) or static Active badge
              _StatusBadge(
                isTG: device.isTGDevice,
                isOnline: online,
                isLoading: device.isTGDevice && telemetry == null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(
                    icon: Icons.tag_rounded,
                    text: device.serialNumber.isEmpty
                        ? 'No serial'
                        : device.serialNumber,
                  ),
                  const SizedBox(height: 4),
                  _MetaRow(
                    icon: Icons.cable_rounded,
                    text: device.connectorLabel,
                  ),
                  if (telemetry?.lastSeen != null) ...[
                    const SizedBox(height: 4),
                    _MetaRow(
                      icon: Icons.access_time_rounded,
                      text: 'Last seen ${telemetry!.lastSeenLabel}',
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () => _confirmRemove(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBA0C0C).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFBA0C0C),
                  ),
                ),
              ),
            ],
          ),
          // Sprinkler-specific telemetry panel
          if (isSprinkler && telemetry != null) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            const SizedBox(height: 10),
            _SprinklerPanel(
              telemetry: telemetry!,
              sprinklerOn: sprinklerOn,
              onToggle: onToggleSprinkler,
            ),
          ],
          // Loading shimmer while waiting for first TG response
          if (device.isTGDevice && telemetry == null) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            const SizedBox(height: 10),
            Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF90A1B9),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Connecting to TG EMEA03…',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF90A1B9),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Device',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text(
          'Remove ${device.typeLabel} (${device.serialNumber.isEmpty ? 'no serial' : device.serialNumber}) from this zone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF62748E))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRemove();
            },
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFBA0C0C),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isTG,
    required this.isOnline,
    required this.isLoading,
  });
  final bool isTG;
  final bool isOnline;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isTG) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Active',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Syncing…',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF90A1B9),
          ),
        ),
      );
    }
    final color = isOnline ? const Color(0xFF16A34A) : const Color(0xFFBA0C0C);
    final bg = isOnline
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFFE5E5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SprinklerPanel extends StatelessWidget {
  const _SprinklerPanel({
    required this.telemetry,
    required this.sprinklerOn,
    required this.onToggle,
  });
  final TGTelemetry telemetry;
  final bool? sprinklerOn;
  final Future<bool> Function(bool)? onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sprinkler Status',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF90A1B9),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sprinklerOn == null
                        ? 'Unknown'
                        : sprinklerOn!
                            ? 'Active — Water flowing'
                            : 'Standby',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: sprinklerOn == true
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF0F172B),
                    ),
                  ),
                ],
              ),
            ),
            if (onToggle != null)
              GestureDetector(
                onTap: () => onToggle!(!(sprinklerOn ?? false)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sprinklerOn == true
                        ? const Color(0xFFFFE5E5)
                        : const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sprinklerOn == true ? 'Turn Off' : 'Turn On',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sprinklerOn == true
                          ? const Color(0xFFBA0C0C)
                          : const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (telemetry.waterFlowRate != null) ...[
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.water_drop_outlined,
            text: '${telemetry.waterFlowRate!.toStringAsFixed(1)} L/min',
          ),
        ],
        if (telemetry.batteryVoltage != null) ...[
          const SizedBox(height: 4),
          _MetaRow(
            icon: Icons.battery_5_bar_rounded,
            text: '${telemetry.batteryVoltage!.toStringAsFixed(2)} V',
          ),
        ],
        if (telemetry.latitude != null && telemetry.longitude != null) ...[
          const SizedBox(height: 4),
          _MetaRow(
            icon: Icons.location_on_outlined,
            text:
                '${telemetry.latitude!.toStringAsFixed(5)}, ${telemetry.longitude!.toStringAsFixed(5)}',
          ),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF90A1B9)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF62748E),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty();

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
              child: const Icon(Icons.devices_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text(
              'No devices yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF272727),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first device to this zone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0x99565656),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
