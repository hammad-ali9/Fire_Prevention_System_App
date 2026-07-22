import 'package:flutter_test/flutter_test.dart';
import 'package:rainfire/models/tg_telemetry.dart';

void main() {
  group('TGTelemetry.fromJson —', () {
    // ── Happy-path payloads ──────────────────────────────────────────────────

    test('parses a fully-populated TG response correctly', () {
      final now = DateTime.now().toUtc();
      final json = {
        'assetName': 'Sprinkler-A',
        'lastReportedUtc': now.toIso8601String(),
        'position': {'latitude': -33.8688, 'longitude': 151.2093},
        'parameters': {
          'sprinklerActive': true,
          'waterFlowRate': 12.5,
        },
        'batteryVoltage': 3.85,
      };

      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.serial, '1429272');
      expect(t.isOnline, isTrue);
      expect(t.assetName, 'Sprinkler-A');
      expect(t.latitude, closeTo(-33.8688, 0.0001));
      expect(t.longitude, closeTo(151.2093, 0.0001));
      expect(t.sprinklerActive, isTrue);
      expect(t.waterFlowRate, closeTo(12.5, 0.01));
      expect(t.batteryVoltage, closeTo(3.85, 0.01));
    });

    test('marks device offline when lastReportedUtc is older than threshold', () {
      final staleTime = DateTime.now()
          .subtract(TGTelemetry.onlineThreshold + const Duration(minutes: 1))
          .toUtc();
      final json = {'lastReportedUtc': staleTime.toIso8601String()};

      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.isOnline, isFalse);
    });

    test('marks device online when lastReportedUtc is within threshold', () {
      final recentTime =
          DateTime.now().subtract(const Duration(minutes: 5)).toUtc();
      final json = {'lastReportedUtc': recentTime.toIso8601String()};

      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.isOnline, isTrue);
    });

    test('falls back to alternate date field names (lastSeen / updatedAt)', () {
      final now = DateTime.now().toUtc().toIso8601String();

      final t1 = TGTelemetry.fromJson('1429272', {'lastSeen': now});
      expect(t1.isOnline, isTrue);

      final t2 = TGTelemetry.fromJson('1429272', {'updatedAt': now});
      expect(t2.isOnline, isTrue);
    });

    test('parses position from root-level lat/lng keys', () {
      final json = {
        'lastReportedUtc': DateTime.now().toUtc().toIso8601String(),
        'lat': 51.5074,
        'lng': -0.1278,
      };

      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.latitude, closeTo(51.5074, 0.0001));
      expect(t.longitude, closeTo(-0.1278, 0.0001));
    });

    test('falls back to "location" wrapper key for position', () {
      final json = {
        'lastReportedUtc': DateTime.now().toUtc().toIso8601String(),
        'location': {'latitude': 40.7128, 'longitude': -74.0060},
      };

      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.latitude, closeTo(40.7128, 0.0001));
      expect(t.longitude, closeTo(-74.0060, 0.0001));
    });

    test('reads sprinklerActive from alternate output key names', () {
      final now = DateTime.now().toUtc().toIso8601String();

      for (final key in ['digitalOutput1', 'relay1', 'output1']) {
        final json = {
          'lastReportedUtc': now,
          'parameters': {key: true},
        };
        final t = TGTelemetry.fromJson('1429272', json);
        expect(t.sprinklerActive, isTrue, reason: 'key: $key');
      }
    });

    test('coerces numeric 1 and string "true" to sprinklerActive = true', () {
      final now = DateTime.now().toUtc().toIso8601String();

      final t1 = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': now,
        'parameters': {'sprinklerActive': 1},
      });
      expect(t1.sprinklerActive, isTrue);

      final t2 = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': now,
        'parameters': {'sprinklerActive': 'true'},
      });
      expect(t2.sprinklerActive, isTrue);
    });

    test('reads parameters from "io" wrapper key', () {
      final json = {
        'lastReportedUtc': DateTime.now().toUtc().toIso8601String(),
        'io': {'sprinklerActive': false, 'waterFlowRate': 0.0},
      };

      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.sprinklerActive, isFalse);
      expect(t.waterFlowRate, 0.0);
    });

    // ── Null / missing fields ────────────────────────────────────────────────

    test('handles completely empty payload without throwing', () {
      final t = TGTelemetry.fromJson('1429272', {});

      expect(t.serial, '1429272');
      expect(t.isOnline, isFalse);
      expect(t.lastSeen, isNull);
      expect(t.latitude, isNull);
      expect(t.longitude, isNull);
      expect(t.sprinklerActive, isNull);
      expect(t.waterFlowRate, isNull);
      expect(t.batteryVoltage, isNull);
    });

    test('returns null sprinklerActive when parameter is absent', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': DateTime.now().toUtc().toIso8601String(),
        'parameters': {'waterFlowRate': 5.0},
      });

      expect(t.sprinklerActive, isNull);
    });

    test('ignores malformed date string and treats device as offline', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': 'not-a-date',
      });

      expect(t.isOnline, isFalse);
      expect(t.lastSeen, isNull);
    });

    test('preserves raw JSON in .raw field', () {
      final json = {'lastReportedUtc': 'bad', 'customField': 'xyz'};
      final t = TGTelemetry.fromJson('1429272', json);

      expect(t.raw['customField'], 'xyz');
    });

    // ── Computed labels ──────────────────────────────────────────────────────

    test('statusLabel is "Online" when device is online', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': DateTime.now().toUtc().toIso8601String(),
      });
      expect(t.statusLabel, 'Online');
    });

    test('statusLabel is "Offline" when device is offline', () {
      final t = TGTelemetry.fromJson('1429272', {});
      expect(t.statusLabel, 'Offline');
    });

    test('lastSeenLabel returns "Never" when lastSeen is null', () {
      final t = TGTelemetry.fromJson('1429272', {});
      expect(t.lastSeenLabel, 'Never');
    });

    test('lastSeenLabel returns "Just now" for a very recent report', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': DateTime.now().toUtc().toIso8601String(),
      });
      expect(t.lastSeenLabel, 'Just now');
    });

    test('lastSeenLabel returns minutes ago for a report 5 minutes old', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
      });
      expect(t.lastSeenLabel, '5m ago');
    });

    test('lastSeenLabel returns hours ago for a report 3 hours old', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': DateTime.now()
            .subtract(const Duration(hours: 3))
            .toUtc()
            .toIso8601String(),
      });
      expect(t.lastSeenLabel, '3h ago');
    });

    test('lastSeenLabel returns days ago for a report 2 days old', () {
      final t = TGTelemetry.fromJson('1429272', {
        'lastReportedUtc': DateTime.now()
            .subtract(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
      });
      expect(t.lastSeenLabel, '2d ago');
    });
  });

  group('TGTelemetry.fromTgAsset —', () {
    // Real GET /v1/asset/103028 payload captured live from EMEA03 on
    // 2026-07-03 (timestamp replaced so the online check stays deterministic).
    Map<String, dynamic> livePayload({String? lastConnectedUtc}) => {
          'lastLatitude': 29.4962831,
          'lastLongitude': -98.4903971,
          'analogInputs': [
            {'key': 'Battery Voltage', 'value': '4.2 V'},
            {'key': 'Cellular Signal', 'value': 'Excellent'},
            {'key': 'External Voltage', 'value': '12.1 V'},
            {'key': 'Inside Temperature', 'value': '28.52 C'},
          ],
          'digitalInputs': [
            {'key': 'Ignition', 'value': 'Off'},
            {'key': 'Valve position', 'value': 'Closed'},
          ],
          'id': 103028,
          'name': '00000_Valve Control',
          'code': 'MIR-Valve',
          'lastConnectedUtc': lastConnectedUtc ?? '2026-07-03T05:47:33.26',
        };

    test('parses the live EMEA03 asset payload', () {
      final t = TGTelemetry.fromTgAsset('1429272', livePayload());

      expect(t.serial, '1429272');
      expect(t.assetName, '00000_Valve Control');
      expect(t.latitude, closeTo(29.4962831, 0.0000001));
      expect(t.longitude, closeTo(-98.4903971, 0.0000001));
      expect(t.batteryVoltage, closeTo(4.2, 0.001));
      expect(t.externalVoltage, closeTo(12.1, 0.001));
      expect(t.insideTempC, closeTo(28.52, 0.001));
      expect(t.cellularSignal, 'Excellent');
      expect(t.sprinklerActive, isFalse); // Valve position: Closed
      expect(t.ignitionOn, isFalse);
      expect(t.waterFlowRate, isNull); // no flow sensor on POC device
    });

    test('treats "Open" valve position as sprinklerActive = true', () {
      final json = livePayload();
      json['digitalInputs'] = [
        {'key': 'Valve position', 'value': 'Open'},
      ];
      final t = TGTelemetry.fromTgAsset('1429272', json);
      expect(t.sprinklerActive, isTrue);
    });

    test('parses the zone-less TG timestamp as UTC', () {
      final recent = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 10))
          .toIso8601String()
          .replaceAll('Z', ''); // TG omits the zone suffix
      final t = TGTelemetry.fromTgAsset(
          '1429272', livePayload(lastConnectedUtc: recent));
      expect(t.isOnline, isTrue);
      expect(t.lastSeen, isNotNull);
    });

    test('marks device offline when lastConnectedUtc exceeds threshold', () {
      final stale = DateTime.now()
          .toUtc()
          .subtract(TGTelemetry.onlineThreshold + const Duration(minutes: 1))
          .toIso8601String()
          .replaceAll('Z', '');
      final t = TGTelemetry.fromTgAsset(
          '1429272', livePayload(lastConnectedUtc: stale));
      expect(t.isOnline, isFalse);
    });

    test('handles missing inputs without throwing', () {
      final t = TGTelemetry.fromTgAsset('1429272', {'id': 103028});
      expect(t.sprinklerActive, isNull);
      expect(t.batteryVoltage, isNull);
      expect(t.externalVoltage, isNull);
      expect(t.insideTempC, isNull);
      expect(t.cellularSignal, isNull);
      expect(t.ignitionOn, isNull);
      expect(t.isOnline, isFalse);
    });

    test('display labels format the live values', () {
      final t = TGTelemetry.fromTgAsset('1429272', livePayload());
      expect(t.insideTempLabel, '28.5 °C');
      expect(t.externalVoltageLabel, '12.1 V');
      expect(t.batteryLabel, '4.20 V');
      expect(t.sprinklerLabel, 'Standby');
    });
  });
}
