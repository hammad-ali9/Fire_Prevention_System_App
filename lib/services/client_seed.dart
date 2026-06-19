import 'package:latlong2/latlong.dart';

import '../models/device.dart';
import '../models/zone.dart';
import 'device_store.dart';
import 'zone_store.dart';

/// Seeds the Datanet IoT sprinkler device (serial 1429272) on first launch.
///
/// - Skips if the serial is already registered (idempotent on every restart).
/// - Creates a placeholder zone "Datanet IoT" if no zones exist yet so the
///   device has somewhere to live in the UI.
/// - All values come directly from the client brief.
Future<void> seedClientDevice() async {
  const serial = '1429272';

  // Already seeded — nothing to do.
  if (DeviceStore.instance.containsSerial(serial)) return;

  // Ensure at least one zone exists to attach the device to.
  String zoneId;
  if (ZoneStore.instance.zones.value.isEmpty) {
    final zone = Zone(
      id: 'datanet-iot-zone',
      name: 'Datanet IoT',
      sector: 'EMEA03',
      // Placeholder center — update once the physical site coordinates are known.
      center: const LatLng(51.5074, -0.1278),
      polygon: const [
        LatLng(51.5124, -0.1328),
        LatLng(51.5124, -0.1228),
        LatLng(51.5024, -0.1228),
        LatLng(51.5024, -0.1328),
      ],
      riskPercent: 20,
    );
    ZoneStore.instance.addZone(zone);
    zoneId = zone.id;
  } else {
    zoneId = ZoneStore.instance.zones.value.first.id;
  }

  DeviceStore.instance.add(Device(
    id: 'datanet-sprinkler-$serial',
    zoneId: zoneId,
    type: 'sprinkler',
    serialNumber: serial,
    serverRegion: 'EMEA03',
    organization: 'Datanet IoT',
    description: 'Water sprinkler — client device (Digital Matter TG)',
    connector: 'TG',
    retrievalMode: 'query_tg',
    dataFields: ['Locations', 'Trip Data', 'Battery', 'Temperature'],
  ));
}
