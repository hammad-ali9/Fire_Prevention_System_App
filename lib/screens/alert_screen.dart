import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../routes/app_routes.dart';
import '../services/alert_store.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/status_bar.dart';

/// ALERT list — Figma node 1:1511. Renders from [AlertStore]; supports
/// filtering (All / Active / Resolved) and per-card Acknowledge / Resolve.
class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  String _filter = 'Active';

  bool _matches(AppAlert a) {
    switch (_filter) {
      case 'All':
        return true;
      case 'Active':
        return a.status == AlertStatus.active;
      case 'Resolved':
        return a.status == AlertStatus.resolved ||
            a.status == AlertStatus.acknowledged;
    }
    return true;
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
                title: 'Alerts',
                trailing: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE9E9E9)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.more_horiz, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('All'),
                  const SizedBox(width: 17),
                  _filterChip('Active'),
                  const SizedBox(width: 17),
                  _filterChip('Resolved'),
                ],
              ),
            ),
            const SizedBox(height: 21),
            Expanded(
              child: ValueListenableBuilder<List<AppAlert>>(
                valueListenable: AlertStore.instance.alerts,
                builder: (context, all, _) {
                  final filtered = all.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No alerts in this view.',
                        style: TextStyle(color: Color(0xFF565656)),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _AlertCard(
                      alert: filtered[i],
                      onView: () => Navigator.pushNamed(
                          context, AppRoutes.envScan),
                      onAction: () {
                        final a = filtered[i];
                        AlertStore.instance.setStatus(
                          a.id,
                          a.severity == AlertSeverity.high
                              ? AlertStatus.resolved
                              : AlertStatus.acknowledged,
                        );
                      },
                    ),
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

  Widget _filterChip(String label) {
    final selected = label == _filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = label),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFF3F3F4),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: selected ? Colors.white : AppColors.primary,
              height: 19 / 16,
              letterSpacing: -0.315,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onView,
    required this.onAction,
  });

  final AppAlert alert;
  final VoidCallback onView;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isHigh = alert.severity == AlertSeverity.high;
    final resolved = alert.status != AlertStatus.active;
    final cardBg =
        isHigh ? const Color(0xFFFFEBE8) : const Color(0xFFFEF6EB);
    final iconBg =
        isHigh ? const Color(0xFFFFE5E5) : const Color(0xFFFFEED6);
    final iconColor =
        isHigh ? const Color(0xFFFF1919) : const Color(0xFFFF9E18);
    final badgeColor =
        isHigh ? const Color(0xFFFF1919) : const Color(0xFFFF9E18);
    final ctaColor =
        isHigh ? const Color(0xFFBA0C0C) : const Color(0xFFFF9E18);

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 22, 15, 18),
      decoration: BoxDecoration(
        color: resolved ? const Color(0xFFF4F6F9) : cardBg,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(27),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.brightness_high,
                    color: iconColor, size: 23),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF272727),
                        height: 19 / 14,
                        letterSpacing: -0.315,
                      ),
                    ),
                    Text(
                      alert.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0x80161616),
                        height: 19 / 12,
                        letterSpacing: -0.315,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 74,
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26.543),
                ),
                child: Text(
                  resolved ? _statusLabel(alert.status) : 'Active',
                  style: TextStyle(
                    color: resolved
                        ? const Color(0xFF00A92A)
                        : badgeColor,
                    fontSize: 11.261,
                    height: 15.283 / 11.261,
                    letterSpacing: -0.2534,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _miniMeta(
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                    value: alert.zoneName,
                  ),
                ),
                Container(
                  width: 1,
                  color: Colors.white,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _miniMeta(
                      label: 'Time',
                      icon: Icons.access_time_rounded,
                      value: _hm(alert.createdAt),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!resolved) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: Colors.white),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onView,
                    child: Container(
                      height: 51,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: Color(0xFF393C43),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.0345,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: onAction,
                    child: Container(
                      height: 51,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ctaColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isHigh ? 'Resolve' : 'Acknowledge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.0345,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(AlertStatus s) {
    switch (s) {
      case AlertStatus.acknowledged:
        return 'Acknowledged';
      case AlertStatus.resolved:
        return 'Resolved';
      case AlertStatus.active:
        return 'Active';
    }
  }

  static String _hm(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  Widget _miniMeta({
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
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF272727),
                  height: 19 / 14,
                  letterSpacing: -0.315,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
