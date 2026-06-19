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
  final String? assetName;

  /// Raw JSON payload from TG — kept for debugging and future field expansion.
  final Map<String, dynamic> raw;

  static const Duration onlineThreshold = Duration(minutes: 10);

  String get statusLabel => isOnline ? 'Online' : 'Offline';

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
