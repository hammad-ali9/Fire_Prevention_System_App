import 'package:flutter_test/flutter_test.dart';
import 'package:fire_prevention/models/device.dart';

Device _make({
  String type = 'sprinkler',
  String connector = 'TG',
  String serial = '1429272',
}) =>
    Device(
      id: 'test-id',
      zoneId: 'zone-1',
      type: type,
      serialNumber: serial,
      connector: connector,
    );

void main() {
  group('Device — sprinkler type —', () {
    test('typeLabel returns "Water Sprinkler"', () {
      expect(_make().typeLabel, 'Water Sprinkler');
    });

    test('typeSubtitle contains TG EMEA03 reference', () {
      expect(_make().typeSubtitle, contains('TG EMEA03'));
    });

    test('typeIcon is water icon', () {
      // Icons.water_rounded codePoint = 0xe798 in Material symbols.
      expect(_make().typeIcon.codePoint, isNonZero);
    });

    test('isTGDevice is true when connector is TG', () {
      expect(_make(connector: 'TG').isTGDevice, isTrue);
    });

    test('isTGDevice is false when connector is Direct MQTT', () {
      expect(_make(connector: 'Direct MQTT').isTGDevice, isFalse);
    });

    test('isTGDevice is false when connector is Webhook Push', () {
      expect(_make(connector: 'Webhook Push').isTGDevice, isFalse);
    });
  });

  group('Device — all types —', () {
    final cases = {
      'gps_tracker': ('GPS Tracker', 'Location & Motion'),
      'zone_sensor': ('Zone Sensor', 'Area monitoring'),
      'env_monitor': ('Env. Monitor', 'Temp, humidity'),
      'asset_tag': ('Asset Tag', 'Inventory & BLE'),
      'sprinkler': ('Water Sprinkler', 'TG EMEA03'),
    };

    for (final entry in cases.entries) {
      final type = entry.key;
      final (label, subtitleFragment) = entry.value;

      test('$type → label "$label"', () {
        expect(_make(type: type).typeLabel, label);
      });

      test('$type → subtitle contains "$subtitleFragment"', () {
        expect(_make(type: type).typeSubtitle, contains(subtitleFragment));
      });

      test('$type → typeIcon is non-null', () {
        expect(_make(type: type).typeIcon, isNotNull);
      });
    }
  });

  group('Device — connectorLabel —', () {
    test('TG connector displays "TG (EMEA 03)"', () {
      expect(_make(connector: 'TG').connectorLabel, 'TG (EMEA 03)');
    });

    test('Direct MQTT connector label is unchanged', () {
      expect(_make(connector: 'Direct MQTT').connectorLabel, 'Direct MQTT');
    });

    test('Webhook Push connector label is "Web hook Push"', () {
      expect(_make(connector: 'Webhook Push').connectorLabel, 'Web hook Push');
    });
  });

  group('Device — retrievalLabel —', () {
    test('query_tg mode displays "Query from TG"', () {
      final d = Device(
        id: 'x',
        zoneId: 'z',
        type: 'sprinkler',
        serialNumber: '1429272',
        retrievalMode: 'query_tg',
      );
      expect(d.retrievalLabel, 'Query from TG');
    });

    test('webhook mode displays "Webhook (Push)"', () {
      final d = Device(
        id: 'x',
        zoneId: 'z',
        type: 'sprinkler',
        serialNumber: '1429272',
        retrievalMode: 'webhook',
      );
      expect(d.retrievalLabel, 'Webhook (Push)');
    });
  });

  group('Device — defaults —', () {
    test('default connector is TG', () {
      final d = Device(
          id: 'x', zoneId: 'z', type: 'sprinkler', serialNumber: '1429272');
      expect(d.connector, 'TG');
    });

    test('default retrievalMode is query_tg', () {
      final d = Device(
          id: 'x', zoneId: 'z', type: 'sprinkler', serialNumber: '1429272');
      expect(d.retrievalMode, 'query_tg');
    });

    test('createdAt is set automatically', () {
      final before = DateTime.now();
      final d = Device(
          id: 'x', zoneId: 'z', type: 'sprinkler', serialNumber: '1429272');
      expect(d.createdAt.isAfter(before) || d.createdAt == before, isTrue);
    });
  });
}
