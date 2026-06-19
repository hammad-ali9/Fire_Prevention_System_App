import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fire_prevention/models/device.dart';
import 'package:fire_prevention/services/device_store.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Device _sprinkler({String serial = '1429272', String id = 'dev-1'}) => Device(
      id: id,
      zoneId: 'zone-A',
      type: 'sprinkler',
      serialNumber: serial,
      connector: 'TG',
    );

Device _gps({String id = 'dev-gps'}) => Device(
      id: id,
      zoneId: 'zone-A',
      type: 'gps_tracker',
      serialNumber: 'GPS001',
      connector: 'Direct MQTT',
    );

// DeviceStore is a singleton — reset its internal list between tests.
void _resetStore() {
  final store = DeviceStore.instance;
  // Remove all devices by collecting IDs first to avoid mutation-during-iteration.
  final ids = store.devices.value.map((d) => d.id).toList();
  for (final id in ids) {
    store.remove(id);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(_resetStore);
  tearDown(_resetStore);

  group('DeviceStore.add —', () {
    test('adds a device and notifies listeners', () {
      final store = DeviceStore.instance;
      int callCount = 0;
      store.devices.addListener(() => callCount++);

      store.add(_sprinkler());

      expect(store.devices.value.length, 1);
      expect(callCount, greaterThan(0));

      store.devices.removeListener(() => callCount++);
    });

    test('stores multiple devices independently', () {
      final store = DeviceStore.instance;

      store.add(_sprinkler(id: 'dev-1'));
      store.add(_sprinkler(serial: '9999999', id: 'dev-2'));
      store.add(_gps(id: 'dev-3'));

      expect(store.devices.value.length, 3);
    });

    test('preserves all device fields after add', () {
      final store = DeviceStore.instance;
      final device = _sprinkler();

      store.add(device);

      final stored = store.devices.value.first;
      expect(stored.serialNumber, '1429272');
      expect(stored.type, 'sprinkler');
      expect(stored.connector, 'TG');
      expect(stored.zoneId, 'zone-A');
    });
  });

  group('DeviceStore.remove —', () {
    test('removes a device by id', () {
      final store = DeviceStore.instance;
      store.add(_sprinkler(id: 'dev-1'));
      store.add(_gps(id: 'dev-2'));

      store.remove('dev-1');

      expect(store.devices.value.length, 1);
      expect(store.devices.value.first.id, 'dev-2');
    });

    test('removing a non-existent id is a no-op', () {
      final store = DeviceStore.instance;
      store.add(_sprinkler());

      store.remove('does-not-exist');

      expect(store.devices.value.length, 1);
    });

    test('notifies listeners after remove', () {
      final store = DeviceStore.instance;
      store.add(_sprinkler(id: 'dev-1'));

      int callCount = 0;
      store.devices.addListener(() => callCount++);

      store.remove('dev-1');

      expect(callCount, greaterThan(0));
      store.devices.removeListener(() => callCount++);
    });
  });

  group('DeviceStore.forZone —', () {
    test('returns only devices belonging to the requested zone', () {
      final store = DeviceStore.instance;
      store.add(Device(
          id: 'a', zoneId: 'zone-A', type: 'sprinkler', serialNumber: '001'));
      store.add(Device(
          id: 'b', zoneId: 'zone-B', type: 'gps_tracker', serialNumber: '002'));
      store.add(Device(
          id: 'c', zoneId: 'zone-A', type: 'zone_sensor', serialNumber: '003'));

      final zoneA = store.forZone('zone-A');
      final zoneB = store.forZone('zone-B');

      expect(zoneA.length, 2);
      expect(zoneB.length, 1);
    });

    test('returns empty list for an unknown zone', () {
      final store = DeviceStore.instance;
      store.add(_sprinkler());

      expect(store.forZone('no-such-zone'), isEmpty);
    });
  });

  group('DeviceStore.telemetryFor —', () {
    test('returns a ValueNotifier for a TG device with a serial', () {
      final store = DeviceStore.instance;
      final device = _sprinkler();
      store.add(device);

      final notifier = store.telemetryFor(device);

      expect(notifier, isNotNull);
    });

    test('returns null for a non-TG device', () {
      final store = DeviceStore.instance;
      final device = _gps();
      store.add(device);

      expect(store.telemetryFor(device), isNull);
    });

    test('returns null for a TG device with empty serial', () {
      final store = DeviceStore.instance;
      final device = Device(
        id: 'no-serial',
        zoneId: 'zone-A',
        type: 'sprinkler',
        serialNumber: '',
        connector: 'TG',
      );
      store.add(device);

      expect(store.telemetryFor(device), isNull);
    });

    test('same notifier is returned for same serial on repeated calls', () {
      final store = DeviceStore.instance;
      final device = _sprinkler();
      store.add(device);

      final n1 = store.telemetryFor(device);
      final n2 = store.telemetryFor(device);

      expect(identical(n1, n2), isTrue);
    });
  });
}
