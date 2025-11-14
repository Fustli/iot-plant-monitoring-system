enum AlertSeverity { info, warning, critical }

enum AlertStatus { active, acknowledged, resolved }

class Alert {
  final int id;
  final int userId;
  final int plantId;
  final int ruleId;
  final AlertSeverity severity;
  final AlertStatus status;
  final String message;
  final double? triggeredValue;
  final double? thresholdValue;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Alert({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.ruleId,
    required this.severity,
    required this.status,
    required this.message,
    this.triggeredValue,
    this.thresholdValue,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == AlertStatus.active;

  String get severityText {
    switch (severity) {
      case AlertSeverity.info:
        return 'Info';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      userId: json['user_id'],
      plantId: json['plant_id'],
      ruleId: json['rule_id'],
      severity: AlertSeverity.values.byName(json['severity']),
      status: AlertStatus.values.byName(json['status']),
      message: json['message'],
      triggeredValue: (json['triggered_value'] as num?)?.toDouble(),
      thresholdValue: (json['threshold_value'] as num?)?.toDouble(),
      triggeredAt: DateTime.parse(json['triggered_at']),
      acknowledgedAt: json['acknowledged_at'] != null ? DateTime.parse(json['acknowledged_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'plant_id': plantId,
    'rule_id': ruleId,
    'severity': severity.name,
    'status': status.name,
    'message': message,
    'triggered_value': triggeredValue,
    'threshold_value': thresholdValue,
    'triggered_at': triggeredAt.toIso8601String(),
    'acknowledged_at': acknowledgedAt?.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
