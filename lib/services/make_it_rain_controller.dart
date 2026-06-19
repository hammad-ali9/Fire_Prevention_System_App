import 'package:flutter/material.dart';

import '../models/zone.dart';
import '../screens/make_it_rain_dialog.dart';
import 'settings_store.dart';
import 'zone_store.dart';

/// Watches zone risk and pops the "Make it Rain" prompt when a zone crosses
/// the critical threshold (> 80%). POC behaviour: one prompt per rising edge,
/// only when the zone isn't already active and no prompt is already on screen.
class MakeItRainController {
  MakeItRainController._();
  static final MakeItRainController instance = MakeItRainController._();

  /// Attach to [MaterialApp.navigatorKey] so the prompt can be shown from the
  /// telemetry loop (outside any widget's build context).
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Trigger at risk > the user-configured threshold (Settings → "Make it
  /// Rain Trigger", default 80%); re-arm only after risk falls 10% below it
  /// (hysteresis stops the dialog re-popping every tick).
  static const double _rearmGap = 10;

  /// Zones currently "armed" — already prompted, awaiting risk to fall before
  /// they can prompt again.
  final Set<String> _armed = <String>{};
  bool _showing = false;

  /// Called from the telemetry loop for each zone after its risk is updated.
  void onRisk(Zone zone) {
    final triggerAt = SettingsStore.instance.current.makeItRainThreshold;
    if (zone.riskPercent < triggerAt - _rearmGap) {
      _armed.remove(zone.id);
      return;
    }
    if (zone.riskPercent <= triggerAt) return;
    if (_armed.contains(zone.id)) return;
    if (zone.isActive) return; // already raining — nothing to ask
    if (_showing) return;

    _armed.add(zone.id);
    _prompt(zone);
  }

  Future<void> _prompt(Zone zone) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    // Re-check: the zone may have been activated between scheduling and showing.
    if (ZoneStore.instance.isZoneActive(zone.id)) return;
    _showing = true;
    try {
      await MakeItRainDialog.show(ctx, zone);
    } finally {
      _showing = false;
    }
  }
}
