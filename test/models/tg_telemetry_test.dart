import 'package:flutter_test/flutter_test.dart';
import 'package:fire_prevention/models/tg_telemetry.dart';

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
}
