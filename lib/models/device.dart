import 'package:flutter/material.dart';

class Device {
  Device({
    required this.id,
    required this.zoneId,
    required this.type,
    required this.serialNumber,
    this.serverRegion = '',
    this.organization = '',
    this.description = '',
    this.connector = 'TG',
    this.retrievalMode = 'query_tg',
    this.dataFields = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String zoneId;
  final String type; // 'gps_tracker' | 'zone_sensor' | 'env_monitor' | 'asset_tag' | 'sprinkler'
  final String serialNumber;
  final String serverRegion;
  final String organization;
  final String description;
  final String connector; // 'TG' | 'Direct MQTT' | 'Webhook Push'
  final String retrievalMode; // 'query_tg' | 'webhook'
  final List<String> dataFields;
  final DateTime createdAt;

  bool get isTGDevice => connector == 'TG';

  String get typeLabel {
    switch (type) {
      case 'gps_tracker':
        return 'GPS Tracker';
      case 'zone_sensor':
        return 'Zone Sensor';
      case 'env_monitor':
        return 'Env. Monitor';
      case 'asset_tag':
        return 'Asset Tag';
      case 'sprinkler':
        return 'Water Sprinkler';
      default:
        return type;
    }
  }

  String get typeSubtitle {
    switch (type) {
      case 'gps_tracker':
        return 'Location & Motion';
      case 'zone_sensor':
        return 'Area monitoring';
      case 'env_monitor':
        return 'Temp, humidity';
      case 'asset_tag':
        return 'Inventory & BLE';
      case 'sprinkler':
        return 'Water sprinkler · TG EMEA03';
      default:
        return '';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'gps_tracker':
        return Icons.gps_fixed_rounded;
      case 'zone_sensor':
        return Icons.sensors_rounded;
      case 'env_monitor':
        return Icons.thermostat_rounded;
      case 'asset_tag':
        return Icons.bluetooth_searching_rounded;
      case 'sprinkler':
        return Icons.water_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  String get connectorLabel {
    switch (connector) {
      case 'TG':
        return 'TG (EMEA 03)';
      case 'Direct MQTT':
        return 'Direct MQTT';
      case 'Webhook Push':
        return 'Web hook Push';
      default:
        return connector;
    }
  }

  String get retrievalLabel =>
      retrievalMode == 'query_tg' ? 'Query from TG' : 'Webhook (Push)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'type': type,
        'serialNumber': serialNumber,
        'serverRegion': serverRegion,
        'organization': organization,
        'description': description,
        'connector': connector,
        'retrievalMode': retrievalMode,
        'dataFields': dataFields,
        'createdAt': createdAt.toIso8601String(),
      };

  static Device fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as String,
        zoneId: j['zoneId'] as String,
        type: j['type'] as String,
        serialNumber: j['serialNumber'] as String,
        serverRegion: j['serverRegion'] as String? ?? '',
        organization: j['organization'] as String? ?? '',
        description: j['description'] as String? ?? '',
        connector: j['connector'] as String? ?? 'TG',
        retrievalMode: j['retrievalMode'] as String? ?? 'query_tg',
        dataFields: (j['dataFields'] as List?)?.cast<String>() ?? const [],
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : null,
      );
}
