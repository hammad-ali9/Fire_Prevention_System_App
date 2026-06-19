import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alert.dart';
import '../models/zone.dart';
import '../services/alert_store.dart';
import '../services/settings_store.dart';
import '../services/zone_store.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/page_header.dart';
import '../widgets/status_bar.dart';

/// REPORTS — Figma node 1:698. Live aggregates from all stores.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const FakeStatusBar(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: PageHeader(title: 'Reports'),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: ValueListenableBuilder<List<Zone>>(
                valueListenable: ZoneStore.instance.zones,
                builder: (context, zones, _) {
                  return ValueListenableBuilder<List<AppAlert>>(
                    valueListenable: AlertStore.instance.alerts,
                    builder: (context, alerts, _) {
                      return ValueListenableBuilder<AppSettings>(
                        valueListenable: SettingsStore.instance.settings,
                        builder: (context, settings, _) =>
                            _content(context, zones, alerts, settings),
                      );
                    },
                  );
                },
              ),
            ),
            const AppBottomNav(active: NavTab.report),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<Zone> zones,
    List<AppAlert> alerts,
    AppSettings settings,
  ) {
    final activeAlerts =
        alerts.where((a) => a.status == AlertStatus.active).toList();
    final acknowledged = alerts
        .where((a) =>
            a.status == AlertStatus.acknowledged ||
            a.status == AlertStatus.resolved)
        .length;

    final focus = ZoneStore.instance.activeZone ??
        (zones.isNotEmpty ? zones.first : null);
    final risk = focus?.riskPercent ?? 0;
    final temp = focus?.temperature ?? 0;
    final hum = focus?.humidity ?? 0;
    final wind = focus?.windSpeed ?? 0;

    final riskColor = _riskColor(focus?.riskLevel);
    final tempOver = temp >= settings.tempThreshold;
    final humLow = hum <= settings.humidityThreshold;
    final windOver = wind >= settings.windThreshold;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            title: 'Current Status',
            rows: [
              _Row('Risk Level',
                  '${risk.toStringAsFixed(0)}% ( ${focus?.riskLevel ?? "—"} )',
                  valueColor: riskColor),
              _Row('Active Alerts', '${activeAlerts.length}',
                  valueColor: activeAlerts.isEmpty
                      ? const Color(0xFF092C1B)
                      : const Color(0xFFBA0C0C)),
              _Row(
                'System Status',
                ZoneStore.instance.activeZone == null ? 'Idle' : 'Active',
                valueColor: ZoneStore.instance.activeZone == null
                    ? const Color(0xFF565656)
                    : const Color(0xFF00A92A),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Environmental Conditions',
            rows: [
              _Row('Temperature', '${temp.toStringAsFixed(0)} °C',
                  valueColor: tempOver
                      ? const Color(0xFFBA0C0C)
                      : const Color(0xFF092C1B)),
              _Row('Humidity', '${hum.toStringAsFixed(0)}%',
                  valueColor: humLow
                      ? const Color(0xFFFF9E18)
                      : const Color(0xFF092C1B)),
              _Row('Wind Speed', '${wind.toStringAsFixed(0)} Km/h',
                  valueColor: windOver
                      ? const Color(0xFFBA0C0C)
                      : const Color(0xFF092C1B)),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Alert Summary',
            rows: [
              _Row('Total Alerts', '${alerts.length}'),
              _Row('Pending Review', '${activeAlerts.length}',
                  valueColor: activeAlerts.isEmpty
                      ? const Color(0xFF092C1B)
                      : const Color(0xFFFF9E18)),
              _Row('Acknowledged', '$acknowledged',
                  valueColor: const Color(0xFF00A92A)),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Active Thresholds',
            rows: [
              _Row('Temperature',
                  '${settings.tempThreshold.toStringAsFixed(0)} °C'),
              _Row('Humidity',
                  '${settings.humidityThreshold.toStringAsFixed(0)}%'),
              _Row('Wind Speed',
                  '${settings.windThreshold.toStringAsFixed(0)} Km/h'),
              _Row('Risk Threshold',
                  '${settings.riskThreshold.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 24),
          _DownloadReportPill(
            onTap: () => _previewReport(
              context,
              zones: zones,
              alerts: alerts,
              settings: settings,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _previewReport(
    BuildContext context, {
    required List<Zone> zones,
    required List<AppAlert> alerts,
    required AppSettings settings,
  }) {
    final text = _buildReport(zones, alerts, settings);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Report Snapshot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172B),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF0F172B),
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF092C1B),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildReport(
    List<Zone> zones,
    List<AppAlert> alerts,
    AppSettings settings,
  ) {
    final now = DateTime.now();
    final ts = '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
    final active =
        alerts.where((a) => a.status == AlertStatus.active).toList();
    final ack = alerts
        .where((a) =>
            a.status == AlertStatus.acknowledged ||
            a.status == AlertStatus.resolved)
        .length;
    final activeZone = ZoneStore.instance.activeZone;
    final buf = StringBuffer()
      ..writeln('Fire Prevention — Report')
      ..writeln('Generated: $ts')
      ..writeln('=' * 32)
      ..writeln()
      ..writeln('THRESHOLDS')
      ..writeln(
          '  Temperature : ${settings.tempThreshold.toStringAsFixed(0)} °C')
      ..writeln(
          '  Humidity    : ${settings.humidityThreshold.toStringAsFixed(0)} %')
      ..writeln(
          '  Wind        : ${settings.windThreshold.toStringAsFixed(0)} km/h')
      ..writeln(
          '  Risk Trigger: ${settings.riskThreshold.toStringAsFixed(0)} %')
      ..writeln('  Mode        : ${settings.activationMode.name}')
      ..writeln('  Auto-Activ. : ${settings.autoActivation}')
      ..writeln('  Alerts      : ${settings.enableAlerts}')
      ..writeln()
      ..writeln('SYSTEM')
      ..writeln('  Total zones    : ${zones.length}')
      ..writeln('  Active zone    : ${activeZone?.fullLabel ?? "—"}')
      ..writeln('  Total alerts   : ${alerts.length}')
      ..writeln('  Active alerts  : ${active.length}')
      ..writeln('  Closed alerts  : $ack')
      ..writeln()
      ..writeln('ZONES');
    for (final z in zones) {
      buf
        ..writeln('  • ${z.fullLabel}')
        ..writeln(
            '      risk=${z.riskPercent.toStringAsFixed(0)}% (${z.riskLevel})')
        ..writeln(
            '      temp=${z.temperature.toStringAsFixed(0)}°C  '
            'hum=${z.humidity.toStringAsFixed(0)}%  '
            'wind=${z.windSpeed.toStringAsFixed(0)}km/h')
        ..writeln('      active=${z.isActive}');
    }
    if (active.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('ACTIVE ALERTS');
      for (final a in active) {
        buf.writeln('  [${a.severity.name.toUpperCase()}] '
            '${a.title} — ${a.zoneName} '
            '(${_pad(a.createdAt.hour)}:${_pad(a.createdAt.minute)})');
      }
    }
    return buf.toString();
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

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
        return const Color(0xFF092C1B);
    }
  }
}

class _DownloadReportPill extends StatelessWidget {
  const _DownloadReportPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(61),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF092C1B),
          borderRadius: BorderRadius.circular(61),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.download_rounded, color: Colors.white, size: 24),
            SizedBox(width: 5),
            Text(
              'Download Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
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

class _Row {
  const _Row(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172B),
              height: 27 / 18,
              letterSpacing: -0.4395,
            ),
          ),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0x80565656),
                      fontWeight: FontWeight.w500,
                      height: 19 / 16,
                      letterSpacing: -0.315,
                    ),
                  ),
                  Text(
                    r.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: r.valueColor ?? const Color(0xFF092C1B),
                      height: 24 / 14,
                      letterSpacing: -0.3125,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
