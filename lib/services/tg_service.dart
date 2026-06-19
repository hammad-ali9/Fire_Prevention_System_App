import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tg_telemetry.dart';
import 'api_config.dart';

/// Telematics Guru (TG) EMEA03 client.
///
/// API flow confirmed from Digital Matter official docs:
///   1. GET /v2/user/organisations    → resolve numeric org ID
///   2. GET /v3/assets/{orgId}        → list assets, find by serial number
///   3. Parse asset JSON into TGTelemetry for the UI
///
/// Auth: `Authorization: Bearer {apiKey}` — API key used directly as token.
///
/// PRODUCTION NOTE: Move [ApiConfig.tgApiKey] to a Firebase Cloud Function
/// to avoid shipping credentials in the app binary.
class TGService {
  TGService._({http.Client? client}) : _client = client ?? http.Client();

  static final TGService instance = TGService._();

  /// Creates an isolated instance with an injected [client] — use in tests only.
  factory TGService.forTest(http.Client client) => TGService._(client: client);

  final http.Client _client;

  // serial → live telemetry notifier
  final Map<String, ValueNotifier<TGTelemetry?>> _notifiers = {};

  // serial → polling timer
  final Map<String, Timer> _timers = {};

  // Cached org ID — resolved once per session to avoid repeated org lookups.
  int? _cachedOrgId;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${ApiConfig.tgApiKey}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  // ── Public watch API ─────────────────────────────────────────────────────

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

  // ── Polling internals ─────────────────────────────────────────────────────

  void _startPolling(String serial) {
    _fetch(serial); // immediate first fetch
    _timers[serial] = Timer.periodic(ApiConfig.tgPollInterval, (_) {
      _fetch(serial);
    });
  }

  Future<void> _fetch(String serial) async {
    try {
      final telemetry = await fetchTelemetry(serial);
      if (_notifiers.containsKey(serial)) {
        _notifiers[serial]!.value = telemetry;
      }
    } catch (e) {
      dev.log('[TGService] fetch error for $serial: $e', name: 'TGService');
    }
  }

  // ── Public API methods ────────────────────────────────────────────────────

  /// Step 1: Get list of organisations this API key has access to.
  ///
  /// Endpoint: GET /v2/user/organisations
  /// Use this to validate credentials AND to resolve the numeric org ID.
  Future<List<Map<String, dynamic>>> fetchOrganisations() async {
    final uri = Uri.parse('${ApiConfig.tgBaseUrl}/v2/user/organisations');

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    dev.log(
      '[TGService] GET $uri → ${response.statusCode}',
      name: 'TGService',
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List) return body.cast<Map<String, dynamic>>();
      // Some TG versions wrap list in { "data": [...] }
      if (body is Map && body.containsKey('data')) {
        return (body['data'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw TGAuthException(
          'TG API auth failed (${response.statusCode}). Check API key.');
    }

    throw TGApiException(
        'TG API error ${response.statusCode}: ${response.body}');
  }

  /// Step 2: Get all assets for [orgId].
  ///
  /// Endpoint: GET /v3/assets/{orgId}
  /// Returns every asset in the org including last known position and status.
  Future<List<Map<String, dynamic>>> fetchAssets(int orgId) async {
    final uri = Uri.parse('${ApiConfig.tgBaseUrl}/v3/assets/$orgId');

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    dev.log(
      '[TGService] GET $uri → ${response.statusCode}',
      name: 'TGService',
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List) return body.cast<Map<String, dynamic>>();
      if (body is Map && body.containsKey('data')) {
        return (body['data'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw TGAuthException(
          'TG API auth failed (${response.statusCode}). Check API key.');
    }

    throw TGApiException(
        'TG API error ${response.statusCode}: ${response.body}');
  }

  /// Fetches the latest telemetry for [serial] from TG EMEA03.
  ///
  /// Flow:
  ///   1. Fetch organisations → resolve org ID (cached after first call).
  ///   2. Fetch assets for that org → find asset with matching serial.
  ///   3. Parse asset JSON into [TGTelemetry].
  Future<TGTelemetry> fetchTelemetry(String serial) async {
    // Resolve org ID once per session
    if (_cachedOrgId == null) {
      final orgs = await fetchOrganisations();
      if (orgs.isEmpty) {
        throw TGApiException(
            'No organisations found for this API key. '
            'Confirm Key 1 belongs to the Datanet IoT account.');
      }
      // Prefer "Datanet IoT" org; fall back to the first available org
      final org = orgs.firstWhere(
        (o) {
          final name = (o['name'] as String? ?? '').toLowerCase();
          return name.contains('datanet') || name.contains('iot');
        },
        orElse: () => orgs.first,
      );
      _cachedOrgId = (org['id'] as num).toInt();
      dev.log(
        '[TGService] resolved org "${org['name']}" → id $_cachedOrgId',
        name: 'TGService',
      );
    }

    final assets = await fetchAssets(_cachedOrgId!);

    final asset = assets.firstWhere(
      (a) {
        final s = '${a['serialNumber'] ?? a['serial'] ?? a['SerialNumber'] ?? a['deviceSerial'] ?? ''}';
        // TG prepends a 3-letter org prefix to third-party device serials
        // (e.g. "ABC1429272"). Match on suffix so both formats work.
        return s == serial || s.endsWith(serial);
      },
      orElse: () => throw TGNotFoundException(
          'Device $serial not found in TG org ${_cachedOrgId!}. '
          'Ask the client to confirm the device is registered in TG EMEA03.'),
    );

    return TGTelemetry.fromJson(serial, asset);
  }

  /// Sends a sprinkler ON/OFF command via TG API Key 2 (write credentials).
  ///
  /// Exact command endpoint and payload need confirmation from Digital Matter
  /// support — the command API varies by device firmware version.
  Future<bool> setSprinkler(String serial, {required bool active}) async {
    // Ensure org ID is resolved before sending a command
    if (_cachedOrgId == null) await fetchTelemetry(serial);

    final uri = Uri.parse(
      '${ApiConfig.tgBaseUrl}/v2/${_cachedOrgId!}/asset/$serial/command',
    );

    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${ApiConfig.tgApiKeyWrite}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'command': 'setOutput',
            'output': 'relay1',
            'value': active,
          }),
        )
        .timeout(const Duration(seconds: 15));

    dev.log(
      '[TGService] POST command $serial active=$active → ${response.statusCode}',
      name: 'TGService',
    );

    return response.statusCode == 200 || response.statusCode == 202;
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
}

// ── Exceptions ────────────────────────────────────────────────────────────────

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
