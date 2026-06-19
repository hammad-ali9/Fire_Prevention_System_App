import 'dart:async';
import 'dart:math' as math;

import '../models/activation_entry.dart';
import '../models/alert.dart';
import '../models/zone.dart';
import 'alert_store.dart';
import 'fire_data_store.dart';
import 'history_store.dart';
import 'make_it_rain_controller.dart';
import 'risk_engine.dart';
import 'settings_store.dart';
import 'zone_store.dart';

/// Random-walks zone telemetry and reacts to thresholds: emits alerts and
/// auto-activates / auto-stops zones according to [SettingsStore]. Lives for
/// the lifetime of the app process (started from main()).
class TelemetrySimulator {
  TelemetrySimulator._();
  static final TelemetrySimulator instance = TelemetrySimulator._();

  Timer? _timer;
  final _rand = math.Random();

  void start({Duration interval = const Duration(seconds: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    final zones = ZoneStore.instance.zones.value;
    if (zones.isEmpty) return;
    final settings = SettingsStore.instance.current;

    for (final z in zones) {
      _stepZone(z, settings);
      _maybeRaiseAlerts(z, settings);
      _maybeAutoActivate(z, settings);
      // Risk > 80% → prompt the operator for manual "Make it Rain" activation.
      MakeItRainController.instance.onRisk(z);
    }

    // Mutated in place; push a notification so listeners rebuild.
    ZoneStore.instance.notify();
    // Keep history rows ticking their "running" duration on screen.
    HistoryStore.instance.tick();
  }

  void _stepZone(Zone z, AppSettings s) {
    final w = z.hasLiveWeather ? z.liveWeather : null;

    if (w != null) {
      // Live data is authoritative — pin telemetry to the real readings with
      // only tiny jitter so the bars feel alive without drifting away from
      // reality. Wind direction is taken straight from the API.
      z.temperature =
          _clamp((w.temperature ?? z.temperature) + _drift(0.2), 5, 60);
      z.humidity = _clamp((w.humidity ?? z.humidity) + _drift(0.4), 0, 100);
      z.windSpeed =
          _clamp((w.windSpeed ?? z.windSpeed) + _drift(0.5), 0, 120);
      if (w.windDirection != null) z.windDirection = w.windDirection!;
    } else {
      // No live data — demo bias toward fire-weather thresholds so the POC
      // can still demonstrate threshold crossings.
      final tempPull = (s.tempThreshold + 6 - z.temperature) * 0.04;
      final humPull = (s.humidityThreshold - 6 - z.humidity) * 0.04;
      final windPull = (s.windThreshold + 6 - z.windSpeed) * 0.04;
      z.temperature = _clamp(z.temperature + _drift(1.2) + tempPull, 5, 60);
      z.humidity = _clamp(z.humidity + _drift(2.0) + humPull, 0, 100);
      z.windSpeed = _clamp(z.windSpeed + _drift(3.5) + windPull, 0, 120);
      z.windDirection = (z.windDirection + _drift(8)) % 360;
      if (z.windDirection < 0) z.windDirection += 360;
    }

    // Pass weather: null so the engine scores the drifted zone state; if we
    // passed `w` it would override the zone's mutated values with raw NWS
    // readings and the demo pull would never reach the threshold band.
    // FIRMS/NIFC proximity still contribute through hotspots/incidents.
    final r = RiskEngine.compute(
      zone: z,
      s: s,
      weather: null,
      hotspots: FireDataStore.instance.hotspots.value,
      incidents: FireDataStore.instance.incidents.value,
    );
    z.riskPercent = _clamp(z.riskPercent * 0.55 + r.percent * 0.45, 0, 100);
  }

  void _maybeRaiseAlerts(Zone z, AppSettings s) {
    if (!s.enableAlerts) return;

    void emit({
      required AlertSeverity sev,
      required String title,
      required String subtitle,
    }) {
      if (AlertStore.instance.hasRecentForZone(z.id, title)) return;
      AlertStore.instance.add(AppAlert(
        id: '${z.id}-${DateTime.now().microsecondsSinceEpoch}',
        zoneId: z.id,
        zoneName: z.fullLabel,
        severity: sev,
        title: title,
        subtitle: subtitle,
        createdAt: DateTime.now(),
      ));
    }

    if (z.riskPercent >= s.riskThreshold) {
      emit(
        sev: AlertSeverity.high,
        title: 'High Fire Risk',
        subtitle: 'Risk ${z.riskPercent.toStringAsFixed(0)}% in ${z.name}',
      );
    } else if (z.riskPercent >= s.riskThreshold * 0.7) {
      emit(
        sev: AlertSeverity.medium,
        title: 'Elevated Risk',
        subtitle: 'Risk ${z.riskPercent.toStringAsFixed(0)}% in ${z.name}',
      );
    }

    if (z.temperature >= s.tempThreshold + 10) {
      emit(
        sev: AlertSeverity.high,
        title: 'Critical Temperature',
        subtitle: '${z.temperature.toStringAsFixed(0)} °C in ${z.name}',
      );
    }
  }

  void _maybeAutoActivate(Zone z, AppSettings s) {
    if (!s.autoActivation) return;
    final store = ZoneStore.instance;

    final shouldFire = switch (s.activationMode) {
      ActivationMode.off => false,
      ActivationMode.threshold => z.riskPercent >= s.riskThreshold,
      ActivationMode.ai =>
        z.riskPercent >= s.riskThreshold * 0.95 ||
            z.temperature >= s.tempThreshold + 8,
    };

    // Each zone auto-activates independently once its own risk crosses the
    // trigger. Multiple zones can be auto-activated in parallel.
    if (shouldFire && !z.isActive) {
      store.activate(
        z.id,
        source: s.activationMode == ActivationMode.ai
            ? ActivationSource.ai
            : ActivationSource.threshold,
      );
    } else if (z.isActive &&
        store.sourceFor(z.id) != ActivationSource.manual &&
        z.riskPercent < s.riskThreshold * 0.6) {
      // Auto-stop only auto-triggered activations once risk falls
      // comfortably below the trigger band. Manual activations stay on
      // until the user stops them.
      store.deactivate(z.id);
    }
  }

  double _drift(double scale) => (_rand.nextDouble() - 0.5) * 2 * scale;

  double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}
