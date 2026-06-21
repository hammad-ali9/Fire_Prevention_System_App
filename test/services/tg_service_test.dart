import 'dart:convert';

import 'package:fire_prevention/services/tg_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tests the Device-Manager-API-backed [TGService]: it polls
/// `GET /v1/TrackingDevice/Get` and maps the response into [TGTelemetry].
/// Only position + timestamps + online are available on this path; valve,
/// battery and flow are intentionally null (they live in Telematics Guru).

const _serial = '1429272';

// A realistic DM TrackingDevice/Get payload (UTC timestamps, no zone suffix).
Map<String, dynamic> _dmDevice({String? lastComms}) => {
      'ICCID': '89882280666087567230',
      'ModemIMEI': '869487067702380',
      'LastPositionLatitude': 29.4963399,
      'LastPositionLongitude': -98.4904228,
      'LastGpsUpdateUtc': '2026-06-16T20:17:03.000',
      'LastCommsUTC': lastComms ?? '2026-06-16T20:17:13.540',
      'DeviceId': 1357680,
      'ProductId': 128,
      'IsEnabled': true,
    };

void main() {
  group('fetchTelemetryOnce()', () {
    test('maps a DM device response into TGTelemetry', () async {
      final client = MockClient((req) async {
        expect(req.url.path, contains('/v1/TrackingDevice/Get'));
        expect(req.url.queryParameters['id'], _serial);
        expect(req.url.queryParameters['product'], '128');
        expect(req.headers['Authorization'], startsWith('Bearer '));
        return http.Response(jsonEncode(_dmDevice()), 200);
      });
      final service = TGService.forTest(client);

      final t = await service.fetchTelemetryOnce(_serial);
      expect(t.serial, _serial);
      expect(t.latitude, closeTo(29.4963399, 1e-6));
      expect(t.longitude, closeTo(-98.4904228, 1e-6));
      expect(t.lastSeen, isNotNull);
      // Not available via the Device Manager API:
      expect(t.sprinklerActive, isNull);
      expect(t.batteryVoltage, isNull);
      expect(t.waterFlowRate, isNull);

      service.dispose();
    });

    test('parses DM UTC timestamp (no zone) as UTC, not local', () async {
      final client = MockClient(
        (req) async => http.Response(jsonEncode(_dmDevice()), 200),
      );
      final service = TGService.forTest(client);

      final t = await service.fetchTelemetryOnce(_serial);
      expect(t.lastSeen!.toUtc().toIso8601String(),
          startsWith('2026-06-16T20:17:13'));

      service.dispose();
    });

    test('throws TGAuthException on 401', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final service = TGService.forTest(client);
      expect(
        () => service.fetchTelemetryOnce(_serial),
        throwsA(isA<TGAuthException>()),
      );
      service.dispose();
    });

    test('throws TGNotFoundException on 404', () async {
      final client =
          MockClient((req) async => http.Response('No data.', 404));
      final service = TGService.forTest(client);
      expect(
        () => service.fetchTelemetryOnce('999'),
        throwsA(isA<TGNotFoundException>()),
      );
      service.dispose();
    });
  });

  group('watch()', () {
    test('emits mapped telemetry from the first poll', () async {
      final client = MockClient(
        (req) async => http.Response(jsonEncode(_dmDevice()), 200),
      );
      final service = TGService.forTest(client);

      final notifier = service.watch(_serial);
      await _untilNotNull(notifier);

      expect(notifier.value!.latitude, closeTo(29.4963399, 1e-6));
      service.dispose();
    });
  });

  group('backendReachable()', () {
    test('true when the key authenticates', () async {
      final client =
          MockClient((req) async => http.Response('[]', 200));
      final service = TGService.forTest(client);
      expect(await service.backendReachable(), isTrue);
      service.dispose();
    });

    test('throws TGAuthException on 401', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final service = TGService.forTest(client);
      expect(service.backendReachable, throwsA(isA<TGAuthException>()));
      service.dispose();
    });
  });

  group('setSprinkler()', () {
    test('sends a Set-Digital-Output (0x004) async command and reports queued',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, contains('/v1/AsyncMessaging/Send'));
        expect(req.url.queryParameters['serial'], _serial);
        expect(req.headers['Authorization'], startsWith('Bearer '));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['MessageType'], 4);
        // Data is a base64 payload: ON for output 0 → level 0x0001, mask 0x0001.
        expect(base64Decode(body['Data'] as String), [1, 0, 1, 0]);
        return http.Response('', 202);
      });
      final service = TGService.forTest(client);
      expect(await service.setSprinkler(_serial, active: true), isTrue);
      service.dispose();
    });

    test('OFF clears the output level bit', () async {
      final client = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(base64Decode(body['Data'] as String), [0, 0, 1, 0]);
        return http.Response('', 202);
      });
      final service = TGService.forTest(client);
      expect(await service.setSprinkler(_serial, active: false), isTrue);
      service.dispose();
    });
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Future<void> _untilNotNull<T>(ValueNotifier<T?> n,
    {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (n.value == null) {
    if (DateTime.now().isAfter(deadline)) fail('No value within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
