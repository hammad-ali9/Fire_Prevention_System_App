import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/tg_telemetry.dart';
import 'tg_api_service.dart';
import 'tg_service.dart';

/// Live device telemetry — Telematics Guru REST API, with a Firestore stream
/// taking over if the Cloud Functions backend is ever deployed.
///
/// Primary path (current POC state): [TGApiService] polls the TG API for the
/// full decoded picture — valve position, battery voltage, external voltage,
/// inside temperature, cellular signal, position. TG authenticates by
/// credentials only (no IP allowlist), so this works on any network,
/// cellular included.
///
/// Backend path (dormant until the Blaze-plan deploy): the DM **HTTP
/// Connector** POSTs each report to the `dmConnectorIngest` Cloud Function,
/// which writes the normalized doc to Firestore `devices/{serial}`. Once that
/// doc produces data it wins over TG polling (it's push-based, no 30 s lag).
///
/// Valve control tries the `dmSetOutput` callable first, then falls back to
/// the direct DM async-message endpoint ([TGService.setSprinkler]).
///
/// Web is a design-preview target with Firebase skipped — [watch] returns an
/// idle notifier and [setSprinkler] is a no-op there.
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  /// Cloud Functions region — must match the deploy region in `functions/`.
  static const String _region = 'europe-west1';

  final Map<String, ValueNotifier<TGTelemetry?>> _notifiers = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subs = {};
  // Serials whose Firestore doc has produced data — the TG poll stops
  // overwriting these (the Firestore doc is push-based and fresher).
  final Set<String> _firestoreLive = {};
  final Map<String, VoidCallback> _tgListeners = {};

  /// Returns the [ValueNotifier] for [serial], starting the TG API poll on
  /// first watch, plus a Firestore stream that takes over if the backend is
  /// ever deployed.
  ValueNotifier<TGTelemetry?> watch(String serial) {
    final existing = _notifiers[serial];
    if (existing != null) return existing;
    final n = ValueNotifier<TGTelemetry?>(null);
    _notifiers[serial] = n;
    if (!kIsWeb) {
      _subscribe(serial);
      _subscribeTgPoll(serial);
    }
    return n;
  }

  void _subscribe(String serial) {
    // No Firebase app (unit tests, platforms where init is skipped) — the
    // TG poll still feeds the notifier, so just skip the Firestore stream.
    if (Firebase.apps.isEmpty) return;
    final ref =
        FirebaseFirestore.instance.collection('devices').doc(serial);
    _subs[serial] = ref.snapshots().listen(
      (snap) {
        final data = snap.data();
        if (data == null) return; // no doc yet — connector hasn't reported
        _firestoreLive.add(serial);
        _notifiers[serial]?.value = _map(serial, data);
      },
      onError: (Object e) => dev.log(
        '[TelemetryService] stream error for $serial: $e',
        name: 'TelemetryService',
      ),
    );
  }

  /// TG API polling — feeds the notifier while the Firestore doc has never
  /// reported (backend not deployed / connector not wired).
  void _subscribeTgPoll(String serial) {
    final tgNotifier = TGApiService.instance.watch(serial);
    void onTg() {
      if (_firestoreLive.contains(serial)) return;
      final t = tgNotifier.value;
      if (t != null) _notifiers[serial]?.value = t;
    }

    tgNotifier.addListener(onTg);
    _tgListeners[serial] = onTg;
    onTg(); // pick up a value that arrived before the listener attached
  }

  /// Stops the streams and disposes the notifier for [serial].
  void unwatch(String serial) {
    _subs.remove(serial)?.cancel();
    final l = _tgListeners.remove(serial);
    if (l != null) {
      // Remove our listener before TGApiService disposes its notifier.
      TGApiService.instance.watch(serial).removeListener(l);
      TGApiService.instance.unwatch(serial);
    }
    _firestoreLive.remove(serial);
    _notifiers.remove(serial)?.dispose();
  }

  /// Why the last [setSprinkler] call failed, per attempted path — for the UI
  /// to show something actionable instead of a generic "command failed".
  /// Null after a successful command.
  String? lastCommandError;

  /// Toggles the device's valve relay. Paths, in order:
  ///   1. Direct DM async 0x0100 immobilise — the ONLY path hardware-verified
  ///      to actually move the valve (live test 2026-07-05, ~90 s round trip).
  ///      May be unreachable from some networks (possible IP allowlist).
  ///   2. `dmSetOutput` Cloud Functions callable (if the backend is deployed)
  ///      — same 0x0100, sent server-side.
  /// TG immobilisation is deliberately NOT in this chain: TG accepts the
  /// request (200 "queued") but its dispatcher never delivers it to the
  /// device (observed across many connects, 2026-07-03 and 2026-07-05) — so
  /// treating that 200 as success shows the user a forever-"Queued" button
  /// while nothing happens. Better to fail loudly with the real DM/backend
  /// error. Re-add only if DM/TG support fixes the dispatcher.
  /// Returns true when any path queued the command; on failure
  /// [lastCommandError] carries the collected reasons.
  Future<bool> setSprinkler(String serial, {required bool active}) async {
    if (kIsWeb) return false;
    final reasons = <String>[];
    try {
      final ok = await TGService.instance.setSprinkler(serial, active: active);
      if (ok) {
        lastCommandError = null;
        return true;
      }
      reasons.add('DM: not queued');
    } catch (e) {
      dev.log(
        '[TelemetryService] direct DM setSprinkler failed for $serial: $e — '
        'trying backend callable',
        name: 'TelemetryService',
      );
      reasons.add('DM: $e');
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('dmSetOutput');
      final res = await callable
          .call<Map<String, dynamic>>({'serial': serial, 'active': active})
          .timeout(const Duration(seconds: 12));
      if (res.data['queued'] == true) {
        lastCommandError = null;
        return true;
      }
      reasons.add('Backend: not queued');
    } catch (e) {
      dev.log(
        '[TelemetryService] setSprinkler callable failed for $serial: $e',
        name: 'TelemetryService',
      );
      reasons.add('Backend: $e');
    }
    lastCommandError = reasons.join('\n');
    return false;
  }

  /// Backend is usable when a user is signed in — the `dmSetOutput` callable
  /// requires auth. Firebase itself works on any network (unlike the
  /// IP-allowlisted DM pull API), so this never fails on cellular.
  bool get backendReady => !kIsWeb && FirebaseAuth.instance.currentUser != null;

  /// Credentials check for pre-activation: the TG API authenticating (primary
  /// telemetry path — works on any network), Firebase sign-in (backend path),
  /// or the DM API key (valve-command path) as a last resort.
  Future<bool> credentialsOk() async {
    if (kIsWeb) return false;
    try {
      return await TGApiService.instance.backendReachable();
    } catch (e) {
      dev.log('[TelemetryService] TG credentialsOk failed: $e',
          name: 'TelemetryService');
    }
    if (FirebaseAuth.instance.currentUser != null) return true;
    try {
      return await TGService.instance.backendReachable();
    } catch (e) {
      dev.log('[TelemetryService] credentialsOk DM fallback failed: $e',
          name: 'TelemetryService');
      return false;
    }
  }

  /// Whether the device exists for us: the TG API answering for the serial
  /// (primary), a telemetry doc in Firestore (backend path), or the direct DM
  /// API (last resort). Returns false when the device is definitively not
  /// found; rethrows other errors (auth / timeout) so callers can distinguish
  /// "not found" from "couldn't check".
  Future<bool> deviceKnown(String serial) async {
    if (kIsWeb) return false;
    try {
      await TGApiService.instance.fetchTelemetryOnce(serial);
      return true;
    } on TGNotFoundException {
      return false;
    } catch (e) {
      dev.log(
        '[TelemetryService] TG deviceKnown($serial) unavailable: $e — '
        'trying Firestore / DM',
        name: 'TelemetryService',
      );
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('devices')
          .doc(serial)
          .get()
          .timeout(const Duration(seconds: 8));
      if (snap.exists) return true;
    } catch (e) {
      dev.log(
        '[TelemetryService] Firestore deviceKnown($serial) unavailable: $e — '
        'trying direct DM API',
        name: 'TelemetryService',
      );
    }
    try {
      await TGService.instance.fetchTelemetryOnce(serial);
      return true;
    } on TGNotFoundException {
      return false;
    }
  }

  /// Maps a Firestore `devices/{serial}` doc → [TGTelemetry].
  TGTelemetry _map(String serial, Map<String, dynamic> d) {
    final ts = d['lastSeen'];
    DateTime? lastSeen;
    if (ts is Timestamp) {
      lastSeen = ts.toDate();
    } else if (ts != null) {
      lastSeen = DateTime.tryParse(ts.toString());
    }
    final online = lastSeen != null &&
        DateTime.now().difference(lastSeen) < TGTelemetry.onlineThreshold;

    return TGTelemetry(
      serial: serial,
      isOnline: online,
      lastSeen: lastSeen,
      latitude: _toDouble(d['latitude']),
      longitude: _toDouble(d['longitude']),
      sprinklerActive: d['sprinklerActive'] as bool?,
      waterFlowRate: _toDouble(d['waterFlowRate']),
      batteryVoltage: _toDouble(d['batteryVoltage']),
      assetName: d['assetName'] as String?,
      raw: d,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    for (final e in _tgListeners.entries) {
      TGApiService.instance.watch(e.key).removeListener(e.value);
      TGApiService.instance.unwatch(e.key);
    }
    _tgListeners.clear();
    _firestoreLive.clear();
    for (final n in _notifiers.values) {
      n.dispose();
    }
    _notifiers.clear();
  }
}
