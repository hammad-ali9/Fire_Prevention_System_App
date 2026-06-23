import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/zone.dart';
import '../services/fire_data_store.dart';
import '../services/risk_engine.dart';
import '../services/settings_store.dart';
import '../services/zone_store.dart';
import '../widgets/page_header.dart';
import '../widgets/status_bar.dart';

/// ENVIRONMENTAL SCAN — Figma node 1:1207. Live values derived from the
/// active zone (or first zone) + global settings.
class EnvironmentalScanScreen extends StatelessWidget {
  const EnvironmentalScanScreen({super.key});

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
                title: 'Environmental Scan',
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
            Expanded(
              child: ValueListenableBuilder<List<Zone>>(
                valueListenable: ZoneStore.instance.zones,
                builder: (context, zones, _) {
                  return ValueListenableBuilder<AppSettings>(
                    valueListenable: SettingsStore.instance.settings,
                    builder: (context, settings, _) {
                      final zone = ZoneStore.instance.activeZone ??
                          (zones.isNotEmpty ? zones.first : null);
                      if (zone == null) return const _Empty();
                      return _Body(zone: zone, settings: settings);
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Add a zone to see the environmental scan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF565656)),
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.zone, required this.settings});
  final Zone zone;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    // Reasons come from the blended NOAA/NWS + FIRMS + NIFC risk engine so
    // the analysis matches the gauge and the map.
    final reasons = RiskEngine.compute(
      zone: zone,
      s: settings,
      weather: zone.hasLiveWeather ? zone.liveWeather : null,
      hotspots: FireDataStore.instance.hotspots.value,
      incidents: FireDataStore.instance.incidents.value,
    ).reasons;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  child: Center(
                    child: _RiskGauge(
                      percent: (zone.riskPercent / 100).clamp(0.0, 1.0),
                      level: zone.riskLevel,
                    ),
                  ),
                ),
                _telemetryCard(),
                const SizedBox(height: 17),
                _systemAnalysisCard(reasons),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _ProtocolPill(
            label:
                zone.isActive ? 'Stop Sprinklers' : 'Initiate Protocol',
            color: zone.isActive
                ? const Color(0xFFBA0C0C)
                : const Color(0xFF092C1B),
            onTap: () {
              if (zone.isActive) {
                ZoneStore.instance.deactivate(zone.id);
              } else {
                ZoneStore.instance.activate(zone.id);
              }
              // Return to the dashboard root rather than spawning a fresh home
              // on top of this pushed screen.
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
        ),
      ],
    );
  }

  Widget _telemetryCard() => Container(
        padding: const EdgeInsets.fromLTRB(14, 17, 14, 18),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAEAEA)),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Live Telemetry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF272727),
                    height: 19 / 16,
                    letterSpacing: -0.315,
                  ),
                ),
                Icon(Icons.more_horiz, color: Color(0xFF272727), size: 24),
              ],
            ),
            const SizedBox(height: 21),
            Stack(
              children: [
                const Positioned.fill(child: _ChartGridLines(count: 5)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(
                      label: 'Temperate',
                      valueLabel:
                          '(${zone.temperature.toStringAsFixed(0)} °C)',
                      valueColor: zone.temperature >= settings.tempThreshold
                          ? const Color(0xFFCE200C)
                          : const Color(0xFF22AC04),
                      fraction:
                          (zone.temperature / 60).clamp(0.05, 1.0),
                      gradient: const [
                        Color(0xFFC91707),
                        Color(0xFFE84C25)
                      ],
                    ),
                    const SizedBox(height: 13),
                    _bar(
                      label: 'Humidity',
                      valueLabel: '(${zone.humidity.toStringAsFixed(0)}%)',
                      valueColor:
                          zone.humidity <= settings.humidityThreshold
                              ? const Color(0xFFDF6F29)
                              : const Color(0xFF22AC04),
                      fraction: (zone.humidity / 100).clamp(0.05, 1.0),
                      gradient: const [
                        Color(0xFFE37734),
                        Color(0xFFD35202)
                      ],
                    ),
                    const SizedBox(height: 13),
                    _bar(
                      label: 'Wind',
                      valueLabel:
                          '(${zone.windSpeed.toStringAsFixed(0)}Km/h ${zone.windCompass16})',
                      valueColor: zone.windSpeed >= settings.windThreshold
                          ? const Color(0xFFCE200C)
                          : const Color(0xFF22AC04),
                      fraction: (zone.windSpeed / 120).clamp(0.05, 1.0),
                      gradient: const [
                        Color(0xFF3DDD1A),
                        Color(0xFF1FA701)
                      ],
                      trailing: _WindFlowArrow(
                        fromDeg: zone.windDirection,
                        color: zone.windSpeed >= settings.windThreshold
                            ? const Color(0xFFCE200C)
                            : const Color(0xFF22AC04),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0%', style: _scaleStyle),
                Text('25%', style: _scaleStyle),
                Text('50%', style: _scaleStyle),
                Text('75%', style: _scaleStyle),
                Text('100%', style: _scaleStyle),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFEAEAEA)),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F8E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  // Arrow points the way the wind blows TO (fromDeg + 180).
                  child: Transform.rotate(
                    angle: (zone.windDirection + 180) * math.pi / 180,
                    child: const Icon(Icons.arrow_upward_rounded,
                        size: 22, color: Color(0xFF22AC04)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wind Direction',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0x80565656),
                          height: 19 / 12,
                          letterSpacing: -0.315,
                        ),
                      ),
                      Text(
                        'From ${zone.windCompass16} '
                        '(${zone.windDirection.toStringAsFixed(0)}°)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF272727),
                          height: 19 / 16,
                          letterSpacing: -0.315,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _bar({
    required String label,
    required String valueLabel,
    required Color valueColor,
    required double fraction,
    required List<Color> gradient,
    Widget? trailing,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0C2C1F),
                  height: 19 / 14,
                  letterSpacing: -0.315,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                  height: 19 / 14,
                  letterSpacing: -0.315,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (ctx, c) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              height: 20,
              width: c.maxWidth * fraction,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
              ),
            );
          }),
        ],
      );

  Widget _systemAnalysisCard(List<String> reasons) => Container(
        padding: const EdgeInsets.fromLTRB(14, 17, 14, 0),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEAEAEA)),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Analysis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF272727),
                height: 19 / 16,
                letterSpacing: -0.315,
              ),
            ),
            const SizedBox(height: 19),
            const Text(
              'High Risk Due to:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF272727),
                height: 19 / 14,
                letterSpacing: -0.315,
              ),
            ),
            const SizedBox(height: 5),
            for (final r in reasons) _reason(r),
          ],
        ),
      );

  Widget _reason(String text) => Container(
        height: 43,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFEAEAEA), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const _AsteriskGlyph(size: 9, color: Color(0xFFBA0C0C)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0x80565656),
                  height: 19 / 12,
                  letterSpacing: -0.315,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ChartGridLines extends StatelessWidget {
  const _ChartGridLines({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final seg = c.maxWidth / (count - 1);
      return Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i == count - 1 ? null : i * seg,
              right: i == count - 1 ? 0 : null,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: const Color(0xFFEAEAEA)),
            ),
        ],
      );
    });
  }
}

class _ProtocolPill extends StatelessWidget {
  const _ProtocolPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(61),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(61),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: 5),
            Text(
              label,
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

/// Boxicons-style 6-pointed asterisk used in System Analysis bullets (Figma
/// `temaki:asterisk`). Material doesn't ship the exact glyph so we paint it.
class _AsteriskGlyph extends StatelessWidget {
  const _AsteriskGlyph({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AsteriskPainter(color: color),
    );
  }
}

class _AsteriskPainter extends CustomPainter {
  _AsteriskPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final stroke = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.22;
    for (var i = 0; i < 3; i++) {
      final t = i * math.pi / 3;
      final dx = math.cos(t) * r * 0.95;
      final dy = math.sin(t) * r * 0.95;
      canvas.drawLine(Offset(c.dx - dx, c.dy - dy),
          Offset(c.dx + dx, c.dy + dy), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _AsteriskPainter old) => old.color != color;
}

const _scaleStyle = TextStyle(
    color: Color(0xFF8E8E8E), fontSize: 12, fontWeight: FontWeight.w500);

/// Small arrow pointing the way the wind is flowing TO. [fromDeg] is the
/// meteorological bearing the wind blows FROM, so the arrow points
/// `fromDeg + 180`. North (0°) = up.
class _WindFlowArrow extends StatelessWidget {
  const _WindFlowArrow({required this.fromDeg, required this.color});
  final double fromDeg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final toRad = (fromDeg + 180) * math.pi / 180;
    return Transform.rotate(
      angle: toRad,
      child: Icon(Icons.arrow_upward_rounded, size: 16, color: color),
    );
  }
}

class _RiskGauge extends StatelessWidget {
  const _RiskGauge({required this.percent, required this.level});
  final double percent;
  final String level;

  // Open ring: starts at 135° (bottom-left), sweeps clockwise 270° to bottom-right.
  // Gap of 90° on the right side, matching the Figma asset.
  static const double _startAngle = 3 * math.pi / 4;
  static const double _totalSweep = 1.5 * math.pi;

  @override
  Widget build(BuildContext context) {
    final isHigh = percent >= 0.75;
    // Hue follows risk severity — green low → amber mid → red high.
    final gaugeColors = percent >= 0.75
        ? const [Color(0xFFE84C25), Color(0xFFC91707)]
        : percent >= 0.5
            ? const [Color(0xFFFFA200), Color(0xFFE84C25)]
            : percent >= 0.25
                ? const [Color(0xFFFFD400), Color(0xFFFFA200)]
                : const [Color(0xFF3DDD1A), Color(0xFF1FA701)];

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _GaugePainter(
              percent: percent,
              startAngle: _startAngle,
              totalSweep: _totalSweep,
              colors: gaugeColors,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  text: (percent * 100).toStringAsFixed(0),
                  style: const TextStyle(
                    color: Color(0xFF404040),
                    fontSize: 39.433,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                  children: const [
                    TextSpan(
                      text: '%',
                      style: TextStyle(
                        color: Color(0xFF404040),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AsteriskGlyph(
                    size: 24,
                    color: isHigh
                        ? const Color(0xFFC91707)
                        : const Color(0xFFFFA200),
                  ),
                  const SizedBox(width: 2),
                  ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isHigh
                          ? const [Color(0xFFC91707), Color(0xFFE84C25)]
                          : const [Color(0xFFFFA200), Color(0xFFE84C25)],
                    ).createShader(rect),
                    child: Text(
                      '$level RISK',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.percent,
    required this.startAngle,
    required this.totalSweep,
    required this.colors,
  });

  final double percent;
  final double startAngle;
  final double totalSweep;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Faint track for the unfilled portion of the C-arc.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF1F1F1);
    canvas.drawArc(rect, startAngle, totalSweep, false, track);

    // Colored arc proportional to risk %. SweepGradient is anchored to the
    // *full* ring range so the visible segment keeps its hue regardless of
    // how short it gets.
    final fillSweep = totalSweep * percent.clamp(0.0, 1.0);
    if (fillSweep <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + totalSweep,
        colors: colors,
        tileMode: TileMode.clamp,
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, fillSweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.percent != percent || old.colors != colors;
}
