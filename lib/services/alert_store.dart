import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert.dart';
import 'notification_service.dart';

class AlertStore {
  AlertStore._();
  static final AlertStore instance = AlertStore._();

  static const _kKey = 'alert_store.alerts';

  final ValueNotifier<List<AppAlert>> alerts =
      ValueNotifier<List<AppAlert>>([]);

  /// Read persisted alerts. Call once at app startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      alerts.value = [for (final j in list) AppAlert.fromJson(j)];
    } catch (_) {
      await prefs.remove(_kKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final a in alerts.value) a.toJson()]),
    );
  }

  void add(AppAlert a) {
    alerts.value = [a, ...alerts.value];
    _persist();
    NotificationService.instance.showAlert(a);
  }

  /// Replace status for a given alert id.
  void setStatus(String id, AlertStatus status) {
    alerts.value = [
      for (final a in alerts.value)
        if (a.id == id) (a..status = status) else a,
    ];
    _persist();
  }

  /// True if any alert exists for the given zone+title within the cooldown
  /// window — used by simulator to throttle re-emits without silencing rising
  /// risk for too long. Window deliberately short (60s) so the user sees
  /// continued alerts when a zone keeps breaching thresholds.
  bool hasRecentForZone(String zoneId, String title) {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    return alerts.value.any((a) =>
        a.zoneId == zoneId &&
        a.title == title &&
        a.createdAt.isAfter(cutoff));
  }

  int countActive() =>
      alerts.value.where((a) => a.status == AlertStatus.active).length;

  int countAcknowledged() => alerts.value
      .where((a) =>
          a.status == AlertStatus.acknowledged ||
          a.status == AlertStatus.resolved)
      .length;
}
