enum ActivationSource { manual, threshold, ai }

class ActivationEntry {
  ActivationEntry({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.source,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final String zoneId;
  final String zoneName;
  final ActivationSource source;
  final DateTime startedAt;
  DateTime? endedAt;

  Duration get duration =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  String get sourceLabel {
    switch (source) {
      case ActivationSource.manual:
        return 'Manual';
      case ActivationSource.threshold:
        return 'Threshold';
      case ActivationSource.ai:
        return 'AI-Driven';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'zoneName': zoneName,
        'source': source.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
      };

  static ActivationEntry fromJson(Map<String, dynamic> j) => ActivationEntry(
        id: j['id'] as String,
        zoneId: j['zoneId'] as String,
        zoneName: j['zoneName'] as String,
        source: ActivationSource.values.firstWhere(
          (e) => e.name == j['source'],
          orElse: () => ActivationSource.manual,
        ),
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] == null
            ? null
            : DateTime.parse(j['endedAt'] as String),
      );
}
