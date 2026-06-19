import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activation_entry.dart';

class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  static const _kKey = 'history_store.entries';

  final ValueNotifier<List<ActivationEntry>> entries =
      ValueNotifier<List<ActivationEntry>>([]);

  /// Read persisted entries. Call once at app startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      entries.value = [for (final j in list) ActivationEntry.fromJson(j)];
    } catch (_) {
      await prefs.remove(_kKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final e in entries.value) e.toJson()]),
    );
  }

  /// Append a new entry and return it. Caller keeps id to finalize later.
  ActivationEntry open({
    required String zoneId,
    required String zoneName,
    required ActivationSource source,
  }) {
    final entry = ActivationEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      zoneId: zoneId,
      zoneName: zoneName,
      source: source,
      startedAt: DateTime.now(),
    );
    entries.value = [entry, ...entries.value];
    _persist();
    return entry;
  }

  /// Find the open entry for this zone and close it. No-op if already closed.
  void closeForZone(String zoneId) {
    var changed = false;
    final next = [
      for (final e in entries.value)
        if (e.zoneId == zoneId && e.endedAt == null)
          () {
            changed = true;
            e.endedAt = DateTime.now();
            return e;
          }()
        else
          e,
    ];
    if (changed) {
      entries.value = next;
      _persist();
    }
  }

  /// Tick — used by UI / store consumers to force rebuilds while an entry is
  /// open (so its live "running" duration ticks up on the History screen).
  /// Deliberately does NOT persist: tick fires every second.
  void tick() {
    entries.value = List.unmodifiable(entries.value);
  }
}
