import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import '../models/tg_telemetry.dart';
import 'tg_service.dart';

class DeviceStore {
  DeviceStore._();
  static final DeviceStore instance = DeviceStore._();

  static const _kKey = 'device_store.devices';

  final ValueNotifier<List<Device>> _devices = ValueNotifier([]);
  ValueNotifier<List<Device>> get devices => _devices;

  List<Device> forZone(String zoneId) =>
      _devices.value.where((d) => d.zoneId == zoneId).toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final loaded = list.map(Device.fromJson).toList();
      _devices.value = loaded;
      // Resume TG polling for any TG devices restored from disk.
      for (final d in loaded) {
        if (d.isTGDevice && d.serialNumber.isNotEmpty) {
          TGService.instance.watch(d.serialNumber);
        }
      }
    } catch (_) {
      await prefs.remove(_kKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(_devices.value.map((d) => d.toJson()).toList()),
    );
  }

  void add(Device device) {
    _devices.value = [..._devices.value, device];
    if (device.isTGDevice && device.serialNumber.isNotEmpty) {
      TGService.instance.watch(device.serialNumber);
    }
    _persist();
  }

  void remove(String id) {
    final device = _devices.value.where((d) => d.id == id).firstOrNull;
    _devices.value = _devices.value.where((d) => d.id != id).toList();
    if (device != null &&
        device.isTGDevice &&
        device.serialNumber.isNotEmpty) {
      final stillUsed = _devices.value
          .any((d) => d.serialNumber == device.serialNumber && d.isTGDevice);
      if (!stillUsed) TGService.instance.unwatch(device.serialNumber);
    }
    _persist();
  }

  /// Whether a device with [serialNumber] already exists in any zone.
  bool containsSerial(String serialNumber) =>
      _devices.value.any((d) => d.serialNumber == serialNumber);

  /// Live telemetry notifier for a TG device — null if not a TG device or
  /// no serial is set.
  ValueNotifier<TGTelemetry?>? telemetryFor(Device device) {
    if (!device.isTGDevice || device.serialNumber.isEmpty) return null;
    return TGService.instance.watch(device.serialNumber);
  }
}
