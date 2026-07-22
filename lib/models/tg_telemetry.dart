/// Live telemetry snapshot returned by the Telematics Guru (TG) EMEA03 API
/// for a single device (serial 1429272 — water sprinkler).
class TGTelemetry {
  const TGTelemetry({
    required this.serial,
    required this.isOnline,
    this.lastSeen,
    this.latitude,
    this.longitude,
    this.sprinklerActive,
    this.waterFlowRate,
    this.batteryVoltage,
    this.externalVoltage,
    this.insideTempC,
    this.cellularSignal,
    this.ignitionOn,
    this.immobilisedOrPending,
    this.assetName,
    this.raw = const {},
  });

  final String serial;

  /// True when the device last reported within [onlineThreshold].
  final bool isOnline;

  final DateTime? lastSeen;
  final double? latitude;
  final double? longitude;

  /// Sprinkler relay state — null when the device hasn't reported this param.
  final bool? sprinklerActive;

  /// Litres per minute, if reported.
  final double? waterFlowRate;

  final double? batteryVoltage;

  /// External supply voltage (the 12 V line feeding the device), if reported.
  final double? externalVoltage;

  /// Temperature inside the device enclosure, °C.
  final double? insideTempC;

  /// Cellular signal quality as reported by TG (e.g. "Excellent", "Good").
  final String? cellularSignal;

  /// Ignition digital input — null when the device hasn't reported it.
  final bool? ignitionOn;

  /// TG's `immobilisedOrAboutToBeImmobilised` flag (v2 asset list): true when
  /// the valve output is commanded ON — either already executed or queued
  /// waiting for the device's next check-in. Null when the flag couldn't be
  /// read.
  final bool? immobilisedOrPending;

  final String? assetName;

  /// Raw JSON payload from TG — kept for debugging and future field expansion.
  final Map<String, dynamic> raw;

  /// A stationary Arrow tracker heartbeats roughly every 30–60 min (live
  /// device 1429272 was seen 40 min between reports), so anything under an
  /// hour flags a healthy device "Offline". 2 h ≈ two missed heartbeats.
  static const Duration onlineThreshold = Duration(hours: 2);

  String get statusLabel => isOnline ? 'Online' : 'Offline';

  /// Rough state-of-charge from a single Li-ion cell (3.30 V empty → 4.20 V
  /// full). Null when no voltage reported. Clamped 0..100.
  int? get batteryPercent {
    final v = batteryVoltage;
    if (v == null) return null;
    final pct = ((v - 3.30) / (4.20 - 3.30)) * 100;
    return pct.clamp(0, 100).round();
  }

  /// Battery voltage as a display string, or '—' when unreported.
  String get batteryLabel =>
      batteryVoltage == null ? '—' : '${batteryVoltage!.toStringAsFixed(2)} V';

  /// Human-readable valve/sprinkler state.
  String get sprinklerLabel => sprinklerActive == null
      ? 'Unknown'
      : (sprinklerActive! ? 'Active' : 'Standby');

  /// True while a valve command is queued in TG but the device hasn't
  /// executed it yet: the commanded state ([immobilisedOrPending]) disagrees
  /// with the reported valve position. Devices check in ~hourly, so this can
  /// stay true for a while.
  bool get valveCommandPending {
    final commanded = immobilisedOrPending;
    if (commanded == null) return false;
    return commanded != (sprinklerActive ?? false);
  }

  /// The state the pending command will produce — true = valve opening.
  /// Only meaningful while [valveCommandPending].
  bool get pendingTargetOn => immobilisedOrPending == true;

  /// Inside temperature as a display string, or '—' when unreported.
  String get insideTempLabel =>
      insideTempC == null ? '—' : '${insideTempC!.toStringAsFixed(1)} °C';

  /// External supply voltage as a display string, or '—' when unreported.
  String get externalVoltageLabel => externalVoltage == null
      ? '—'
      : '${externalVoltage!.toStringAsFixed(1)} V';

  String get lastSeenLabel {
    if (lastSeen == null) return 'Never';
    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Parses the JSON envelope returned by TG's device telemetry endpoint.
  /// Field paths are based on Digital Matter's TG REST API response format —
  /// update if the actual payload differs.
  factory TGTelemetry.fromJson(String serial, Map<String, dynamic> json) {
    final DateTime? lastSeen = _parseDate(
      json['lastReportedUtc'] ?? json['lastSeen'] ?? json['updatedAt'],
    );

    final bool isOnline = lastSeen != null &&
        DateTime.now().difference(lastSeen) < TGTelemetry.onlineThreshold;

    // Position may be nested under 'position', 'location', or at root level.
    final pos = json['position'] as Map<String, dynamic>? ??
        json['location'] as Map<String, dynamic>? ??
        json;

    final double? lat = _toDouble(pos['latitude'] ?? pos['lat']);
    final double? lng = _toDouble(pos['longitude'] ?? pos['lng'] ?? pos['lon']);

    // Device parameters / I/O — TG wraps these in a 'parameters' or 'io' map.
    final params = json['parameters'] as Map<String, dynamic>? ??
        json['io'] as Map<String, dynamic>? ??
        {};

    // Sprinkler relay — TG typically labels digital outputs as 'digitalOutput1'
    // or a user-named field. Adjust the key once confirmed with Digital Matter.
    final sprinklerRaw = params['sprinklerActive'] ??
        params['digitalOutput1'] ??
        params['relay1'] ??
        params['output1'];
    final bool? sprinklerActive = sprinklerRaw == null
        ? null
        : (sprinklerRaw == true ||
            sprinklerRaw == 1 ||
            sprinklerRaw.toString().toLowerCase() == 'true');

    final double? flow = _toDouble(
      params['waterFlowRate'] ?? params['flowRate'] ?? params['flow'],
    );

    final double? battery = _toDouble(
      json['batteryVoltage'] ?? params['battery'] ?? params['batteryV'],
    );

    return TGTelemetry(
      serial: serial,
      isOnline: isOnline,
      lastSeen: lastSeen,
      latitude: lat,
      longitude: lng,
      sprinklerActive: sprinklerActive,
      waterFlowRate: flow,
      batteryVoltage: battery,
      assetName: json['assetName'] as String? ?? json['name'] as String?,
      raw: json,
    );
  }

  /// Parses the `GET /v1/asset/{assetId}` (AssetDetailed) response from the
  /// Telematics Guru REST API — verified live against asset 103028 on EMEA03.
  ///
  /// Analog/digital inputs arrive as `[{key, value}]` pairs with
  /// pre-formatted string values ("4.2 V", "28.52 C", "Closed"), so numeric
  /// fields are parsed from the leading number and digital states are matched
  /// against their TG io-map state names ("Open"/"Closed", "On"/"Off").
  factory TGTelemetry.fromTgAsset(
    String serial,
    Map<String, dynamic> json, {
    bool? immobilisedOrPending,
  }) {
    // "2026-07-03T05:47:33.26" — UTC with no zone suffix.
    final DateTime? lastSeen = _parseUtcDate(json['lastConnectedUtc']);
    final bool isOnline = lastSeen != null &&
        DateTime.now().difference(lastSeen) < TGTelemetry.onlineThreshold;

    final analogs = _ioPairs(json['analogInputs']);
    final digitals = _ioPairs(json['digitalInputs']);

    final String? valve = digitals['Valve position'];
    final String? ignition = digitals['Ignition'];

    return TGTelemetry(
      serial: serial,
      isOnline: isOnline,
      lastSeen: lastSeen,
      latitude: _toDouble(json['lastLatitude']),
      longitude: _toDouble(json['lastLongitude']),
      // Io-map: activeStateName "Open", inactiveStateName "Closed".
      sprinklerActive:
          valve == null ? null : valve.toLowerCase() == 'open',
      waterFlowRate: null, // no flow sensor on the POC device
      batteryVoltage: _leadingNumber(analogs['Battery Voltage']),
      externalVoltage: _leadingNumber(analogs['External Voltage']),
      insideTempC: _leadingNumber(analogs['Inside Temperature']),
      cellularSignal: analogs['Cellular Signal'],
      ignitionOn: ignition == null ? null : ignition.toLowerCase() == 'on',
      immobilisedOrPending: immobilisedOrPending,
      assetName: json['name'] as String?,
      raw: json,
    );
  }

  /// Flattens TG's `[{key: ..., value: ...}]` input lists into a map.
  static Map<String, String> _ioPairs(dynamic list) {
    final out = <String, String>{};
    if (list is List) {
      for (final e in list) {
        if (e is Map && e['key'] != null && e['value'] != null) {
          out[e['key'].toString()] = e['value'].toString();
        }
      }
    }
    return out;
  }

  /// Extracts the leading number from a formatted TG value ("4.2 V" → 4.2).
  static double? _leadingNumber(String? s) {
    if (s == null) return null;
    final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(0)!);
  }

  /// Parses a UTC timestamp that may lack a zone suffix (TG omits the 'Z').
  static DateTime? _parseUtcDate(dynamic v) {
    if (v == null) return null;
    var s = v.toString().trim();
    if (s.isEmpty) return null;
    final hasZone =
        s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
    if (!hasZone) s = '${s}Z';
    return DateTime.tryParse(s);
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
