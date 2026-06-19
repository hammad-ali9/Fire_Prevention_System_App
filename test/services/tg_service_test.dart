import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fire_prevention/services/tg_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

String _recentUtc() =>
    DateTime.now().subtract(const Duration(minutes: 2)).toUtc().toIso8601String();

String _staleUtc() =>
    DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String();

// Default org list — numeric id 42, name "Datanet IoT"
final _defaultOrgs = [
  {'id': 42, 'name': 'Datanet IoT'}
];

// Default asset matching serial 1429272
Map<String, dynamic> _assetJson({
  String serial = '1429272',
  String? lastReportedUtc,
  bool sprinklerActive = false,
  double waterFlowRate = 0.0,
  double batteryVoltage = 3.8,
  String name = 'Sprinkler-A',
}) =>
    {
      'serialNumber': serial,
      'name': name,
      'lastReportedUtc': lastReportedUtc ?? _recentUtc(),
      'latitude': -33.8688,
      'longitude': 151.2093,
      'parameters': {
        'sprinklerActive': sprinklerActive,
        'waterFlowRate': waterFlowRate,
      },
      'batteryVoltage': batteryVoltage,
    };

/// Creates a TGService that routes requests by URL path.
///
/// Covers the real 3-step API flow:
///   GET /v2/user/organisations  → [orgs]
///   GET /v3/assets/{orgId}      → [assets]
///   POST /v2/{orgId}/asset/…/command → status [commandStatus]
TGService _routedService({
  List<Map<String, dynamic>>? orgs,
  List<Map<String, dynamic>>? assets,
  int orgStatus = 200,
  int assetStatus = 200,
  int commandStatus = 202,
}) {
  final orgList = orgs ?? _defaultOrgs;
  final assetList = assets ?? [_assetJson()];

  return TGService.forTest(MockClient((req) async {
    final path = req.url.path;

    if (path.endsWith('/organisations')) {
      return _json(orgList, status: orgStatus);
    }
    if (RegExp(r'/v3/assets/\d+').hasMatch(path)) {
      return _json(assetList, status: assetStatus);
    }
    if (path.contains('/command')) {
      return _json({'status': 'accepted'}, status: commandStatus);
    }
    return _json({'error': 'not found'}, status: 404);
  }));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── fetchOrganisations ───────────────────────────────────────────────────

  group('TGService.fetchOrganisations —', () {
    test('returns parsed org list on 200', () async {
      final service = _routedService();

      final orgs = await service.fetchOrganisations();

      expect(orgs.length, 1);
      expect(orgs.first['name'], 'Datanet IoT');
      expect(orgs.first['id'], 42);
    });

    test('throws TGAuthException on 401', () async {
      final service = _routedService(orgStatus: 401);

      expect(
        () => service.fetchOrganisations(),
        throwsA(isA<TGAuthException>()),
      );
    });

    test('throws TGAuthException on 403', () async {
      final service = _routedService(orgStatus: 403);

      expect(
        () => service.fetchOrganisations(),
        throwsA(isA<TGAuthException>()),
      );
    });

    test('throws TGApiException on 500', () async {
      final service = _routedService(orgStatus: 500);

      expect(
        () => service.fetchOrganisations(),
        throwsA(isA<TGApiException>()),
      );
    });

    test('sends Authorization Bearer header', () async {
      String? capturedAuth;
      final service = TGService.forTest(MockClient((req) async {
        capturedAuth = req.headers['Authorization'];
        return _json(_defaultOrgs);
      }));

      await service.fetchOrganisations();

      expect(capturedAuth, startsWith('Bearer '));
    });
  });

  // ── fetchTelemetry ───────────────────────────────────────────────────────

  group('TGService.fetchTelemetry —', () {
    test('parses a successful response into TGTelemetry', () async {
      final service = _routedService(
        assets: [
          _assetJson(
            sprinklerActive: true,
            waterFlowRate: 8.3,
            batteryVoltage: 3.9,
            name: 'Sprinkler-A',
          )
        ],
      );

      final t = await service.fetchTelemetry('1429272');

      expect(t.serial, '1429272');
      expect(t.isOnline, isTrue);
      expect(t.assetName, 'Sprinkler-A');
      expect(t.sprinklerActive, isTrue);
      expect(t.waterFlowRate, closeTo(8.3, 0.01));
      expect(t.batteryVoltage, closeTo(3.9, 0.01));
    });

    test('sends Authorization Bearer header on both org and asset calls', () async {
      final captured = <String>[];
      final service = TGService.forTest(MockClient((req) async {
        captured.add(req.headers['Authorization'] ?? '');
        final path = req.url.path;
        if (path.endsWith('/organisations')) return _json(_defaultOrgs);
        return _json([_assetJson()]);
      }));

      await service.fetchTelemetry('1429272');

      expect(captured.length, 2);
      expect(captured.every((h) => h.startsWith('Bearer ')), isTrue);
    });

    test('org request hits /v2/user/organisations', () async {
      Uri? orgUri;
      final service = TGService.forTest(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/organisations')) {
          orgUri = req.url;
          return _json(_defaultOrgs);
        }
        return _json([_assetJson()]);
      }));

      await service.fetchTelemetry('1429272');

      expect(orgUri?.path, contains('/v2/user/organisations'));
    });

    test('asset request URL contains the org ID', () async {
      Uri? assetUri;
      final service = TGService.forTest(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/organisations')) return _json(_defaultOrgs);
        assetUri = req.url;
        return _json([_assetJson()]);
      }));

      await service.fetchTelemetry('1429272');

      // Org id 42 from _defaultOrgs must appear in the assets path
      expect(assetUri?.path, contains('42'));
    });

    test('throws TGAuthException when org call returns 401', () async {
      final service = _routedService(orgStatus: 401);

      expect(
        () => service.fetchTelemetry('1429272'),
        throwsA(isA<TGAuthException>()),
      );
    });

    test('throws TGNotFoundException when serial is not in asset list', () async {
      final service = _routedService(
        assets: [_assetJson(serial: '9999999')], // different serial
      );

      expect(
        () => service.fetchTelemetry('1429272'),
        throwsA(isA<TGNotFoundException>()),
      );
    });

    test('parses offline device (stale timestamp) correctly', () async {
      final service = _routedService(
        assets: [_assetJson(lastReportedUtc: _staleUtc())],
      );

      final t = await service.fetchTelemetry('1429272');

      expect(t.isOnline, isFalse);
      expect(t.statusLabel, 'Offline');
    });

    test('returns null sprinklerActive when field is absent', () async {
      final service = _routedService(
        assets: [
          {
            'serialNumber': '1429272',
            'lastReportedUtc': _recentUtc(),
            'parameters': {'waterFlowRate': 0.0},
          }
        ],
      );

      final t = await service.fetchTelemetry('1429272');

      expect(t.sprinklerActive, isNull);
    });

    test('org ID is cached — second fetchTelemetry makes only one HTTP call', () async {
      int callCount = 0;
      final service = TGService.forTest(MockClient((req) async {
        callCount++;
        final path = req.url.path;
        if (path.endsWith('/organisations')) return _json(_defaultOrgs);
        return _json([_assetJson()]);
      }));

      await service.fetchTelemetry('1429272'); // 2 calls: orgs + assets
      callCount = 0;
      await service.fetchTelemetry('1429272'); // only 1 call: assets (org cached)

      expect(callCount, 1);
    });
  });

  // ── setSprinkler ─────────────────────────────────────────────────────────

  group('TGService.setSprinkler —', () {
    test('sends POST with correct payload for turn-on command', () async {
      Map<String, dynamic>? capturedBody;
      String? capturedAuth;

      final service = TGService.forTest(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/organisations')) return _json(_defaultOrgs);
        if (RegExp(r'/v3/assets/\d+').hasMatch(path)) return _json([_assetJson()]);
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        capturedAuth = req.headers['Authorization'];
        return _json({'status': 'accepted'}, status: 202);
      }));

      final result = await service.setSprinkler('1429272', active: true);

      expect(result, isTrue);
      expect(capturedBody?['value'], isTrue);
      expect(capturedAuth, startsWith('Bearer '));
    });

    test('sends active=false for turn-off command', () async {
      Map<String, dynamic>? capturedBody;

      final service = TGService.forTest(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/organisations')) return _json(_defaultOrgs);
        if (RegExp(r'/v3/assets/\d+').hasMatch(path)) return _json([_assetJson()]);
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return _json({'status': 'accepted'}, status: 202);
      }));

      await service.setSprinkler('1429272', active: false);

      expect(capturedBody?['value'], isFalse);
    });

    test('returns true on 200 response', () async {
      final service = _routedService(commandStatus: 200);
      // Prime the org cache
      await service.fetchTelemetry('1429272');

      expect(await service.setSprinkler('1429272', active: true), isTrue);
    });

    test('returns true on 202 accepted response', () async {
      final service = _routedService(commandStatus: 202);
      await service.fetchTelemetry('1429272');

      expect(await service.setSprinkler('1429272', active: true), isTrue);
    });

    test('returns false on non-2xx response', () async {
      final service = _routedService(commandStatus: 400);
      await service.fetchTelemetry('1429272');

      expect(await service.setSprinkler('1429272', active: true), isFalse);
    });

    test('POST URL contains the serial number', () async {
      Uri? capturedUri;

      final service = TGService.forTest(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/organisations')) return _json(_defaultOrgs);
        if (RegExp(r'/v3/assets/\d+').hasMatch(path)) return _json([_assetJson()]);
        capturedUri = req.url;
        return _json({}, status: 202);
      }));

      await service.setSprinkler('1429272', active: true);

      expect(capturedUri.toString(), contains('1429272'));
    });
  });

  // ── Exception hierarchy ───────────────────────────────────────────────────

  group('TGService exception hierarchy —', () {
    test('TGAuthException is a TGApiException', () {
      expect(const TGAuthException('test'), isA<TGApiException>());
    });

    test('TGNotFoundException is a TGApiException', () {
      expect(const TGNotFoundException('test'), isA<TGApiException>());
    });

    test('TGApiException.toString includes the message', () {
      const e = TGApiException('something went wrong');
      expect(e.toString(), contains('something went wrong'));
    });
  });
}
