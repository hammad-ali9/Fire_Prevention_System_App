import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../models/zone.dart';
import '../routes/app_routes.dart';
import '../services/alert_store.dart';
import '../services/auth_service.dart';
import '../services/zone_store.dart';
import '../theme/app_colors.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/status_bar.dart';

/// HOME / Dashboard — live data from [ZoneStore] and [AlertStore]. Risk % and
/// metrics reflect the active zone (or the first zone when none active).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController =
      PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickZoneFromRoot() async {
    final picked =
        await Navigator.pushNamed<Object?>(context, AppRoutes.selectZone);
    if (!mounted) return;
    if (picked is Zone) {
      // Parallel activation — adds to the carousel, keeps existing ones.
      ZoneStore.instance.activate(picked.id);
    }
  }

  /// Keep [_currentPage] inside the active-zone range; if a zone was stopped
  /// and the page fell off the end, snap the controller after layout.
  int _clampPage(int len) {
    if (len == 0) return 0;
    final clamped = _currentPage > len - 1 ? len - 1 : _currentPage;
    if (clamped != _currentPage) {
      _currentPage = clamped;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) _pageController.jumpToPage(clamped);
      });
    }
    return clamped;
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
            Expanded(
              child: ValueListenableBuilder<List<Zone>>(
                valueListenable: ZoneStore.instance.zones,
                builder: (context, zones, _) {
                  return ValueListenableBuilder<List<String>>(
                    valueListenable: ZoneStore.instance.activeZoneIds,
                    builder: (context, _, _) {
                      final activeZones = ZoneStore.instance.activeZones;
                      final idx = _clampPage(activeZones.length);
                      final focus = activeZones.isNotEmpty
                          ? activeZones[idx]
                          : (zones.isNotEmpty ? zones.first : null);
                      return _Dashboard(
                        zones: zones,
                        activeZones: activeZones,
                        focus: focus,
                        controller: _pageController,
                        currentPage: idx,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                      );
                    },
                  );
                },
              ),
            ),
            ValueListenableBuilder<List<String>>(
              valueListenable: ZoneStore.instance.activeZoneIds,
              builder: (context, _, _) {
                final activeZones = ZoneStore.instance.activeZones;
                final idx = _clampPage(activeZones.length);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: activeZones.isEmpty
                      ? _SelectZoneCta(onTap: _pickZoneFromRoot)
                      : _ActiveZoneControls(
                          zone: activeZones[idx],
                          onAdd: _pickZoneFromRoot,
                          onStop: () => ZoneStore.instance
                              .deactivate(activeZones[idx].id),
                        ),
                );
              },
            ),
            const AppBottomNav(active: NavTab.dashboard),
          ],
        ),
      ),
    );
  }
}

class _SelectZoneCta extends StatelessWidget {
  const _SelectZoneCta({required this.onTap});
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 24),
            SizedBox(width: 5),
            Text(
              'Select Zone',
              style: TextStyle(
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

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.zones,
    required this.activeZones,
    required this.focus,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<Zone> zones;
  final List<Zone> activeZones;
  final Zone? focus;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GreetingRow(),
          const SizedBox(height: 22),
          if (activeZones.isEmpty)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.envScan),
              child: _RiskCard(zone: focus),
            )
          else
            _ZoneCarousel(
              zones: activeZones,
              controller: controller,
              currentPage: currentPage,
              onPageChanged: onPageChanged,
            ),
          const SizedBox(height: 17),
          _MetricsRow(zone: focus),
          const SizedBox(height: 28),
          ValueListenableBuilder<List<AppAlert>>(
            valueListenable: AlertStore.instance.alerts,
            builder: (context, all, _) {
              final activeAlerts =
                  all.where((a) => a.status == AlertStatus.active).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AlertsHeader(
                    activeCount: activeAlerts.length,
                    onSeeAll: () =>
                        Navigator.pushNamed(context, AppRoutes.alert),
                  ),
                  const SizedBox(height: 15),
                  if (activeAlerts.isEmpty)
                    const _NoAlerts()
                  else
                    for (var i = 0;
                        i < activeAlerts.length && i < 2;
                        i++)
                      _AlertRow(
                        alert: activeAlerts[i],
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.envScan),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow();

  @override
  Widget build(BuildContext context) {
    final user = kIsWeb ? null : AuthService.instance.currentUser;
    final displayName = _firstName(user);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hello',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    height: 21 / 24,
                    letterSpacing: -0.315,
                  ),
                ),
                Text(
                  '$displayName!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    height: 24 / 24,
                    letterSpacing: -0.315,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fire Prevention System',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0x80565656),
                    height: 13 / 16,
                    letterSpacing: -0.315,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.alert),
            child: ValueListenableBuilder<List<AppAlert>>(
              valueListenable: AlertStore.instance.alerts,
              builder: (context, all, _) {
                final active =
                    all.where((a) => a.status == AlertStatus.active).length;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: const Color(0xFFE9E9E9)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.notifications_none_rounded,
                          size: 25),
                    ),
                    if (active > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBA0C0C),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            active > 99 ? '99+' : '$active',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal carousel of active zones — peeking neighbour + dot indicator.
class _ZoneCarousel extends StatelessWidget {
  const _ZoneCarousel({
    required this.zones,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<Zone> zones;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 217,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: zones.length,
            padEnds: false,
            itemBuilder: (context, i) {
              return Padding(
                padding: EdgeInsets.only(
                    right: i == zones.length - 1 ? 0 : 11),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.envScan),
                  child: _RiskCard(zone: zones[i]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < zones.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentPage ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == currentPage
                      ? AppColors.primary
                      : const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActiveZoneControls extends StatelessWidget {
  const _ActiveZoneControls({
    required this.zone,
    required this.onAdd,
    required this.onStop,
  });
  final Zone zone;
  final VoidCallback onAdd;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ZoneActionPill(
            label: 'Select Zone',
            background: AppColors.primary,
            onTap: onAdd,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _ZoneActionPill(
            label: 'Stop ${zone.name}',
            background: const Color(0xFFBA0C0C),
            onTap: onStop,
          ),
        ),
      ],
    );
  }
}

class _ZoneActionPill extends StatelessWidget {
  const _ZoneActionPill({
    required this.label,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(61),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 19 / 16,
                  letterSpacing: -0.315,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.zone});
  final Zone? zone;

  @override
  Widget build(BuildContext context) {
    final risk = zone?.riskPercent ?? 0;
    final level = zone?.riskLevel ?? 'NO ZONE';
    // Card hue + caption follow the actual risk bucket — a benign zone must
    // not look like an extreme one.
    final (List<Color> grad, String caption) = switch (level) {
      'HIGH' => (
          const [Color(0xFFBA0C0C), Color(0xFF540505)],
          'Extreme conditions detected'
        ),
      'ELEVATED' => (
          const [Color(0xFFF2740C), Color(0xFF7A3905)],
          'Elevated fire conditions'
        ),
      'MODERATE' => (
          const [Color(0xFFE0A100), Color(0xFF7A5800)],
          'Moderate fire conditions'
        ),
      'LOW' => (
          const [Color(0xFF1E9E4A), Color(0xFF0B4A22)],
          'Conditions nominal'
        ),
      _ => (
          const [Color(0xFF6B6B6B), Color(0xFF333333)],
          'No zone selected'
        ),
    };
    return Container(
      height: 217,
      padding: const EdgeInsets.fromLTRB(17, 28, 17, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: grad,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 21.7,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    zone != null
                        ? '${zone!.name} ZONE RISK'
                        : 'NO ZONE RISK',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 20.671 / 16,
                      letterSpacing: -0.315,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.more_horiz, color: Colors.white, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${risk.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 61.722,
              fontWeight: FontWeight.w600,
              height: 70.139 / 61.722,
              letterSpacing: -0.8837,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Risk Scores',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 13 / 12,
              letterSpacing: -0.315,
            ),
          ),
          const Spacer(),
          Container(
            height: 0.5,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 20.671 / 16,
                letterSpacing: -0.315,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.zone});
  final Zone? zone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.thermostat_rounded,
            iconBg: const Color(0xFFFFF1F1),
            iconColor: const Color(0xFFE53935),
            label: 'Temperature',
            value: (zone?.temperature ?? 0).toStringAsFixed(0),
            unit: '°C',
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-1, 0),
            child: _MetricTile(
              icon: Icons.water_drop_outlined,
              iconBg: const Color(0xFFFFF4EC),
              iconColor: const Color(0xFFFB923C),
              label: 'Humidity',
              value: (zone?.humidity ?? 0).toStringAsFixed(0),
              unit: '%',
            ),
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(-2, 0),
            child: _MetricTile(
              icon: Icons.air_rounded,
              iconBg: const Color(0xFFE9F8E9),
              iconColor: const Color(0xFF22AC04),
              label: 'Wind',
              value: (zone?.windSpeed ?? 0).toStringAsFixed(0),
              unit: 'km/h',
              windFromDeg: zone?.windDirection,
              windCompass: zone?.windCompass16,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader({required this.activeCount, required this.onSeeAll});
  final int activeCount;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Active Alerts ($activeCount)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF272727),
            height: 19 / 18,
            letterSpacing: -0.315,
          ),
        ),
        InkWell(
          onTap: onSeeAll,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF272727), size: 24),
          ),
        ),
      ],
    );
  }
}

class _NoAlerts extends StatelessWidget {
  const _NoAlerts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle, color: Color(0xFF00A92A), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No active alerts — all zones nominal.',
              style: TextStyle(
                color: Color(0xFF114E2A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onTap});
  final AppAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isHigh = alert.severity == AlertSeverity.high;
    final bg = isHigh ? const Color(0xFFFFE5E5) : const Color(0xFFFEF3C6);
    final iconColor =
        isHigh ? const Color(0xFFBA0C0C) : const Color(0xFFE4A800);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7.5),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFEAEAEA), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(27),
              ),
              alignment: Alignment.center,
              child: Icon(
                isHigh ? Icons.brightness_high : Icons.error_rounded,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${alert.title} - ${alert.zoneName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF272727),
                      height: 19 / 14,
                      letterSpacing: -0.315,
                    ),
                  ),
                  Text(
                    'Time: ${_clockTime(alert.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0x80565656),
                      height: 19 / 12,
                      letterSpacing: -0.315,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.north_east_rounded,
                color: Color(0xFF272727), size: 20),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    this.windFromDeg,
    this.windCompass,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  /// Meteorological wind direction (degrees the wind blows FROM). When set,
  /// the tile shows an arrow pointing the way the wind is flowing TO.
  final double? windFromDeg;
  final String? windCompass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (windFromDeg != null)
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(15.5),
                  ),
                  alignment: Alignment.center,
                  // Arrow points the way the wind is flowing TO (fromDeg+180).
                  // North (0°) = up.
                  child: Transform.rotate(
                    angle: (windFromDeg! + 180) * math.pi / 180,
                    child: Icon(Icons.arrow_upward_rounded,
                        size: 18, color: iconColor),
                  ),
                ),
                const Spacer(),
                if (windCompass != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      windCompass!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
              ],
            )
          else
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(15.5),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: iconColor),
            ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF272727),
              height: 19 / 16,
              letterSpacing: -0.315,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 31.528,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF272727),
                  height: 31 / 31.528,
                  letterSpacing: -0.6207,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13.538,
                    color: Color(0xFFD9D9D9),
                    height: 17 / 13.538,
                    letterSpacing: -0.2665,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _firstName(User? user) {
  if (user == null) return 'there';
  final name = user.displayName?.trim();
  if (name != null && name.isNotEmpty) return name.split(' ').first;
  final email = user.email;
  if (email != null && email.contains('@')) return email.split('@').first;
  return 'there';
}

String _clockTime(DateTime t) {
  final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '$h : $m $ampm';
}
