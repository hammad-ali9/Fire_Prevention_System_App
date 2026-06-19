enum AlertSeverity { high, medium }

enum AlertStatus { active, acknowledged, resolved }

class AppAlert {
  AppAlert({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.status = AlertStatus.active,
  });

  final String id;
  final String zoneId;
  final String zoneName;
  final AlertSeverity severity;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  AlertStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneId': zoneId,
        'zoneName': zoneName,
        'severity': severity.name,
        'title': title,
        'subtitle': subtitle,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  static AppAlert fromJson(Map<String, dynamic> j) => AppAlert(
        id: j['id'] as String,
        zoneId: j['zoneId'] as String,
        zoneName: j['zoneName'] as String,
        severity: AlertSeverity.values.firstWhere(
          (e) => e.name == j['severity'],
          orElse: () => AlertSeverity.medium,
        ),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        status: AlertStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => AlertStatus.active,
        ),
      );
}
