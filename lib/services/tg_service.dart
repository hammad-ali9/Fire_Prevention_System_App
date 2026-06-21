import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tg_telemetry.dart';
import 'api_config.dart';

/// Device telemetry client — Digital Matter **Device Manager API** (direct).
///
/// The app polls the DM (OEM Server) API straight from the device, no backend:
///
///   GET {dmBaseUrl}/v1/TrackingDevice/Get?product={productId}&id={serial}
///   Auth: `Authorization: Bearer {ApiConfig.dmApiKey}`
///
/// What this path delivers (verified against the live device):
///   • last-known position (lat/long), GPS/comms timestamps, online state.
///
/// What it CANNOT deliver (not exposed by any DM endpoint — lives in Telematics
/// Guru): valve/relay state, battery voltage, analogues. Those fields stay null
/// here. Valve CONTROL is likewise unavailable via a simple call (DM only has
/// the low-level `AsyncMessaging/Send`, which needs a per-product message spec),
/// so [setSprinkler] is a no-op that reports failure until a TG key is wired.
///
/// The class name + public surface are kept identical to the previous
/// implementations so [DeviceStore] and the screens need no changes.
class TGService {
  TGService._({http.Client? client}) : _client = client ?? http.Client();

  static final TGService instance = TGService._();

  /// Creates an isolated instance with an injected [client] — tests only.
  factory TGService.forTest(http.Client client) => TGService._(client: client);

  final http.Client _client;

  // serial → live telemetry notifier
  final Map<String, ValueNotifier<TGTelemetry?>> _notifiers = {};

  // serial → polling timer
  final Map<String, Timer> _timers = {};

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${ApiConfig.dmApiKey}',
        'Accept': 'application/json',
      };

  // ── Public watch API ───────────────────────────────────────────────────────

  /// Returns the [ValueNotifier] for [serial], starting polling if needed.
  ValueNotifier<TGTelemetry?> watch(String serial) {
    if (!_notifiers.containsKey(serial)) {
      _notifiers[serial] = ValueNotifier(null);
      _startPolling(serial);
    }
    return _notifiers[serial]!;
  }

  /// Stops polling and disposes the notifier for [serial].
  void unwatch(String serial) {
    _timers.remove(serial)?.cancel();
    _notifiers.remove(serial)?.dispose();
  }

  // ── Polling internals ───────────────────────────────────────────────────────

  void _startPolling(String serial) {
    _fetch(serial); // immediate first fetch
    _timers[serial] = Timer.periodic(ApiConfig.dmPollInterval, (_) {
      _fetch(serial);
    });
  }

  Future<void> _fetch(String serial) async {
    try {
      final telemetry = await fetchTelemetryOnce(serial);
      if (_notifiers.containsKey(serial)) {
        _notifiers[serial]!.value = telemetry;
      }
    } catch (e) {
      dev.log('[TGService] fetch error for $serial: $e', name: 'TGService');
    }
  }

  // ── One-shot reads ──────────────────────────────────────────────────────────

  /// True if the DM API is reachable and the key authenticates.
  /// Throws [TGAuthException] on 401/403, [TGApiException] otherwise.
  Future<bool> backendReachable() async {
    final uri =
        Uri.parse('${ApiConfig.dmBaseUrl}/v1/TrackingDevice/GetDeviceList');
    final resp = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) return true;
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw TGAuthException(
          'Device Manager auth failed (${resp.statusCode}). Check the API key.');
    }
    throw TGApiException('Device Manager error ${resp.statusCode}.');
  }

  /// Fetches the latest telemetry for [serial] from the DM API.
  ///
  /// Endpoint: GET /v1/TrackingDevice/Get?product={productId}&id={serial}
  Future<TGTelemetry> fetchTelemetryOnce(
    String serial, {
    int? productId,
  }) async {
    final product = productId ?? ApiConfig.dmDefaultProductId;
    final uri = Uri.parse(
      '${ApiConfig.dmBaseUrl}/v1/TrackingDevice/Get'
      '?product=$product&id=$serial',
    );

    final resp = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    dev.log('[TGService] GET $uri → ${resp.statusCode}', name: 'TGService');

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) return _mapDevice(serial, body);
      throw TGApiException('Unexpected DM response shape for $serial.');
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw TGAuthException(
          'Device Manager auth failed (${resp.statusCode}). Check the API key.');
    }
    if (resp.statusCode == 404) {
      throw TGNotFoundException(
          'Device $serial not found on the Device Manager account '
          '(product $product). Confirm the serial and that this key can see it.');
    }
    throw TGApiException(
        'Device Manager error ${resp.statusCode}: ${resp.body}');
  }

  /// Maps a DM `TrackingDevice/Get` response → [TGTelemetry].
  ///
  /// Only position + timestamps + online are available from this API; the
  /// valve/battery/flow fields are intentionally null (see class docs).
  TGTelemetry _mapDevice(String serial, Map<String, dynamic> d) {
    final lastSeen = _parseUtc(
      d['LastCommsUTC'] ?? d['LastGpsUpdateUtc'] ?? d['LastCommitSuccessUTC'],
    );
    final isOnline = lastSeen != null &&
        DateTime.now().difference(lastSeen) < TGTelemetry.onlineThreshold;

    return TGTelemetry(
      serial: serial,
      isOnline: isOnline,
      lastSeen: lastSeen,
      latitude: _toDouble(d['LastPositionLatitude']),
      longitude: _toDouble(d['LastPositionLongitude']),
      // Not available via the Device Manager API (TG-only):
      sprinklerActive: null,
      waterFlowRate: null,
      batteryVoltage: null,
      assetName: null,
      raw: d,
    );
  }

  // ── Commands ────────────────────────────────────────────────────────────────

  /// Valve ON/OFF via the Device Manager async "Set Digital Output" message
  /// (MessageType 0x004). The Arrow Global has a single switched-ground output
  /// (harness Wire 6) = output index 0, so the valve relay is bit b0.
  ///
  /// Payload (4 bytes) = [LogicalLevel UINT16 LE][ChangeMask UINT16 LE], sent
  /// base64-encoded in `Data`:
  ///   ON  → level bit set,   mask = this output's bit
  ///   OFF → level bit clear, mask = this output's bit
  ///
  /// ⚠️ NOT YET VERIFIED ON HARDWARE. The DM doc's own byte-order example is
  /// self-contradictory, and the logical→physical polarity depends on the
  /// device's active-high system parameter — so ON might map to valve-closed
  /// until confirmed. DM also cannot read the output back, so verify the actual
  /// valve change in the Telematics Guru portal after sending. The device must
  /// be ONLINE; otherwise the command queues until [ExpiryDateUTC] (24h here).
  Future<bool> setSprinkler(String serial, {required bool active}) async {
    final data = _setOutputData(on: active, outputIndex: _valveOutputIndex);
    final uri = Uri.parse(
      '${ApiConfig.dmBaseUrl}/v1/AsyncMessaging/Send?serial=$serial',
    );
    final body = jsonEncode({
      'MessageType': 4, // 0x004 = Set Digital Output
      'CANAddress': 0, // unused for output control (Arrow is non-CAN)
      'ExpiryDateUTC': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
      'SendAfterDateUTC': null,
      'Flags': 0,
      'Data': base64Encode(data),
    });

    final resp = await _client
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${ApiConfig.dmApiKeyWrite}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    final ok = resp.statusCode == 200 || resp.statusCode == 202;
    dev.log(
      '[TGService] setSprinkler($serial, active=$active) → '
      '${resp.statusCode} (queued=$ok)',
      name: 'TGService',
    );
    return ok;
  }

  /// Output index wired to the valve relay. Arrow Global exposes one output
  /// (harness Wire 6) = index 0. Change if the relay is on a different output.
  static const int _valveOutputIndex = 0;

  /// Builds the 4-byte "Set Digital Output" (0x004) payload:
  /// [LogicalLevel UINT16 LE][ChangeMask UINT16 LE]. The change mask addresses
  /// only [outputIndex] so other outputs are left untouched.
  static List<int> _setOutputData({
    required bool on,
    required int outputIndex,
  }) {
    final mask = 1 << outputIndex; // apply to this output only
    final level = on ? mask : 0; // set/clear its bit
    return [
      level & 0xFF, (level >> 8) & 0xFF, // logical level, little-endian
      mask & 0xFF, (mask >> 8) & 0xFF, // change mask, little-endian
    ];
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    for (final n in _notifiers.values) {
      n.dispose();
    }
    _notifiers.clear();
    _client.close();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Parses a DM timestamp (UTC, usually no zone suffix e.g.
  /// "2026-06-16T20:17:13.540") into a [DateTime]. Appends 'Z' when the string
  /// carries no zone so it is read as UTC, not local.
  static DateTime? _parseUtc(dynamic v) {
    if (v == null) return null;
    var s = v.toString().trim();
    if (s.isEmpty) return null;
    final hasZone = s.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
    if (!hasZone) s = '${s}Z';
    return DateTime.tryParse(s);
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

// ── Exceptions (kept for callers that reference them) ────────────────────────

class TGApiException implements Exception {
  const TGApiException(this.message);
  final String message;
  @override
  String toString() => 'TGApiException: $message';
}

class TGAuthException extends TGApiException {
  const TGAuthException(super.message);
}

class TGNotFoundException extends TGApiException {
  const TGNotFoundException(super.message);
}
