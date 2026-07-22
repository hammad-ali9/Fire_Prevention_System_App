import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/tg_telemetry.dart';
import 'api_config.dart';
import 'tg_service.dart' show TGApiException, TGAuthException, TGNotFoundException;

/// Telematics Guru REST API client — the app's primary telemetry source.
///
/// Endpoints (EMEA03, verified live 2026-07-03):
///
///   POST /v1/user/authenticate            → 24 h bearer token
///   GET  /v1/organisation/{orgId}/asset   → asset list (id, name)
///   GET  /v1/asset/{assetId}              → AssetDetailed incl. decoded I/O:
///        analogInputs  [Battery Voltage, External Voltage,
///                       Inside Temperature, Cellular Signal]
///        digitalInputs [Valve position (Open/Closed), Ignition]
///
/// Unlike the Digital Matter pull API, TG has no server-side IP allowlist —
/// it authenticates purely by credentials, so telemetry works from any
/// network (cellular included). The bearer token is cached and refreshed
/// ~1 h before expiry, plus once on an unexpected 401.
///
/// Valve CONTROL stays on the DM async-message path ([TGService.setSprinkler])
/// — TG's REST surface has no verified output-set endpoint for this device.
class TGApiService {
  TGApiService._({http.Client? client}) : _client = client ?? http.Client();

  static final TGApiService instance = TGApiService._();

  /// Creates an isolated instance with an injected [client] — tests only.
  factory TGApiService.forTest(http.Client client) =>
      TGApiService._(client: client);

  final http.Client _client;

  // ── Token management ──────────────────────────────────────────────────────

  String? _token;
  DateTime? _tokenExpiry;
  Future<String>? _authInFlight; // collapses concurrent refreshes

  bool get _tokenValid =>
      _token != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Returns a valid bearer token, authenticating if needed.
  Future<String> _getToken() {
    if (_tokenValid) return Future.value(_token);
    return _authInFlight ??= _authenticate().whenComplete(() {
      _authInFlight = null;
    });
  }

  Future<String> _authenticate() async {
    final uri = Uri.parse('${ApiConfig.tgBaseUrl}/v1/user/authenticate');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'Username': ApiConfig.tgUsername,
        'Password': ApiConfig.tgPassword,
      },
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw TGAuthException(
          'Telematics Guru sign-in failed (${resp.statusCode}). '
          'Check the TG credentials in ApiConfig.');
    }
    final body = jsonDecode(resp.body);
    final token = (body is Map) ? body['access_token'] as String? : null;
    if (token == null || token.isEmpty) {
      throw const TGAuthException(
          'Telematics Guru sign-in returned no access token.');
    }
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 86399;
    _token = token;
    // Refresh an hour early so a token never expires mid-poll.
    _tokenExpiry =
        DateTime.now().add(Duration(seconds: expiresIn - 3600));
    dev.log('[TGApiService] authenticated, token valid until $_tokenExpiry',
        name: 'TGApiService');
    return token;
  }

  /// GET with bearer auth; retries once with a fresh token on 401.
  Future<http.Response> _authedGet(String path) async {
    var token = await _getToken();
    var resp = await _client.get(
      Uri.parse('${ApiConfig.tgBaseUrl}$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode == 401) {
      _token = null; // token revoked/expired server-side — re-auth once
      token = await _getToken();
      resp = await _client.get(
        Uri.parse('${ApiConfig.tgBaseUrl}$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
    }
    return resp;
  }

  // ── Serial → asset id resolution ──────────────────────────────────────────

  final Map<String, int> _assetIdCache = {...ApiConfig.tgAssetIdBySerial};

  /// Resolves a DM device serial to its TG asset id. Order:
  ///   1. static POC map ([ApiConfig.tgAssetIdBySerial]) / cache;
  ///   2. asset whose `deviceSerial` matches (TG returned null for the first
  ///      org asset, but may populate it for newly connected devices);
  ///   3. asset whose name/code contains the serial (naming convention);
  ///   4. the org's ONLY asset (original single-device fallback).
  Future<int> resolveAssetId(String serial) async {
    final cached = _assetIdCache[serial];
    if (cached != null) return cached;

    final resp = await _authedGet(
        '/v1/organisation/${ApiConfig.tgOrganisationId}/asset');
    if (resp.statusCode != 200) {
      throw TGApiException(
          'Telematics Guru asset list failed (${resp.statusCode}).');
    }
    final body = jsonDecode(resp.body);
    if (body is! List || body.isEmpty) {
      throw TGNotFoundException(
          'No assets found in Telematics Guru org '
          '${ApiConfig.tgOrganisationId} for device $serial.');
    }
    final assets = body.whereType<Map>().toList(growable: false);

    Map? match;
    var how = '';
    for (final a in assets) {
      if ('${a['deviceSerial'] ?? ''}' == serial) {
        match = a;
        how = 'deviceSerial';
        break;
      }
    }
    if (match == null) {
      for (final a in assets) {
        if ('${a['name'] ?? ''} ${a['code'] ?? ''}'.contains(serial)) {
          match = a;
          how = 'name/code';
          break;
        }
      }
    }
    if (match == null && assets.length == 1) {
      match = assets.first;
      how = 'only asset';
    }
    if (match == null) {
      throw TGNotFoundException(
          'Device $serial has no Telematics Guru asset mapping and the org '
          'has ${assets.length} assets — add it to '
          'ApiConfig.tgAssetIdBySerial.');
    }
    final id = match['id'] as int;
    _assetIdCache[serial] = id;
    dev.log('[TGApiService] resolved serial $serial → asset $id ($how)',
        name: 'TGApiService');
    return id;
  }

  // ── One-shot reads ────────────────────────────────────────────────────────

  /// True when TG authenticates and the org answers. Throws on auth failure.
  Future<bool> backendReachable() async {
    final resp = await _authedGet('/v2/user/organisations');
    if (resp.statusCode == 200) return true;
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw TGAuthException(
          'Telematics Guru auth failed (${resp.statusCode}).');
    }
    throw TGApiException('Telematics Guru error ${resp.statusCode}.');
  }

  /// Reads TG's `immobilisedOrAboutToBeImmobilised` flag for [assetId] from
  /// the v2 asset list (the v1 detail endpoint omits it). Null on any failure
  /// — the flag only drives button state, never blocks telemetry.
  Future<bool?> _fetchImmobilisedFlag(int assetId) async {
    try {
      final resp = await _authedGet(
          '/v2/organisation/${ApiConfig.tgOrganisationId}/assets');
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is! List) return null;
      for (final a in body) {
        if (a is Map && a['id'] == assetId) {
          return a['immobilisedOrAboutToBeImmobilised'] as bool?;
        }
      }
    } catch (e) {
      dev.log('[TGApiService] immobilised-flag fetch failed: $e',
          name: 'TGApiService');
    }
    return null;
  }

  /// Fetches the latest decoded telemetry for [serial].
  Future<TGTelemetry> fetchTelemetryOnce(String serial) async {
    final assetId = await resolveAssetId(serial);
    final resp = await _authedGet('/v1/asset/$assetId');

    dev.log('[TGApiService] GET /v1/asset/$assetId → ${resp.statusCode}',
        name: 'TGApiService');

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        final pendingFlag = await _fetchImmobilisedFlag(assetId);
        return TGTelemetry.fromTgAsset(serial, body,
            immobilisedOrPending: pendingFlag);
      }
      throw TGApiException('Unexpected TG response shape for $serial.');
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw TGAuthException(
          'Telematics Guru auth failed (${resp.statusCode}).');
    }
    if (resp.statusCode == 404) {
      throw TGNotFoundException(
          'Asset $assetId (device $serial) not found in Telematics Guru.');
    }
    throw TGApiException(
        'Telematics Guru error ${resp.statusCode}: ${resp.body}');
  }

  // ── Commands ──────────────────────────────────────────────────────────────

  /// When true, "sprinkler ON" maps to TG immobilisation ACTIVE (output
  /// driven). Flip if the first hardware test shows the valve responding
  /// inverted — same unverified-polarity caveat as the DM async path, but the
  /// result is verifiable in-app: the next telemetry poll reports the actual
  /// "Valve position" feedback.
  static const bool valveOnIsImmobilise = true;

  /// Valve ON/OFF via TG's immobilisation command (drives the device's
  /// digital output — the Arrow's single output is the valve relay wire).
  /// Goes through TG, so it works from any network; the device must be
  /// online for prompt execution, otherwise TG queues the command.
  ///
  ///   ON  → POST /v2/asset/{id}/immobilisation  (body: delay minutes, 0 = now)
  ///   OFF → DELETE /v2/asset/{id}/immobilisation
  Future<bool> setSprinkler(String serial, {required bool active}) async {
    final assetId = await resolveAssetId(serial);
    final immobilise = valveOnIsImmobilise ? active : !active;
    final token = await _getToken();
    final uri =
        Uri.parse('${ApiConfig.tgBaseUrl}/v2/asset/$assetId/immobilisation');
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final resp = immobilise
        ? await _client
            .post(uri, headers: headers, body: '0')
            .timeout(const Duration(seconds: 15))
        : await _client
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 15));

    final ok = resp.statusCode == 200 || resp.statusCode == 202;
    dev.log(
      '[TGApiService] setSprinkler($serial, active=$active) → '
      '${resp.statusCode} (queued=$ok)',
      name: 'TGApiService',
    );
    if (ok) {
      // Refresh immediately so the pending flag reaches the UI without
      // waiting for the next 30 s poll tick.
      unawaited(_fetch(serial));
      return true;
    }
    // Surface the server's reason — TG returns e.g. "Device is already
    // immobilised or a request to immobilise it is pending" with a 500.
    throw TGApiException(
        'TG immobilisation ${resp.statusCode}: ${resp.body}');
  }

  // ── Polling watch API ─────────────────────────────────────────────────────

  final Map<String, ValueNotifier<TGTelemetry?>> _notifiers = {};
  final Map<String, Timer> _timers = {};

  /// Returns the [ValueNotifier] for [serial], starting polling if needed.
  ValueNotifier<TGTelemetry?> watch(String serial) {
    if (!_notifiers.containsKey(serial)) {
      _notifiers[serial] = ValueNotifier(null);
      _fetch(serial); // immediate first fetch
      _timers[serial] = Timer.periodic(ApiConfig.tgPollInterval, (_) {
        _fetch(serial);
      });
    }
    return _notifiers[serial]!;
  }

  /// Stops polling and disposes the notifier for [serial].
  void unwatch(String serial) {
    _timers.remove(serial)?.cancel();
    _notifiers.remove(serial)?.dispose();
  }

  Future<void> _fetch(String serial) async {
    try {
      final telemetry = await fetchTelemetryOnce(serial);
      _notifiers[serial]?.value = telemetry;
    } catch (e) {
      dev.log('[TGApiService] fetch error for $serial: $e',
          name: 'TGApiService');
    }
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
