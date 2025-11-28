enum AlertSeverityEnum { info, warning, critical }

enum AlertStatusEnum { active, acknowledged, resolved }

class Alert {

  Alert({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.alertRuleId,
    required this.title,
    required this.message,
    required this.severity,
    required this.status,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'].toString(),
      userId: json['user_id'] ?? 0,
      plantId: json['plant_id'].toString(),
      alertRuleId: json['alert_rule_id'] ?? json['rule_id'] ?? 0,
      title: json['title'] ?? 'Alert',
      message: json['message'] ?? '',
      severity: _parseSeverity(json['severity']),
      status: _parseStatus(json['status']),
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'])
          : DateTime.now(),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'])
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }
  final String id;
  final int userId;
  final String plantId;
  final int alertRuleId;
  final String title;
  final String message;
  final AlertSeverityEnum severity;
  final AlertStatusEnum status;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == AlertStatusEnum.active;

  String get severityText {
    switch (severity) {
      case AlertSeverityEnum.info:
        return 'Info';
      case AlertSeverityEnum.warning:
        return 'Warning';
      case AlertSeverityEnum.critical:
        return 'Critical';
    }
  }

  static AlertSeverityEnum _parseSeverity(dynamic severity) {
    if (severity == null) return AlertSeverityEnum.info;
    final severityStr = severity.toString().toLowerCase();
    if (severityStr.contains('critical')) return AlertSeverityEnum.critical;
    if (severityStr.contains('warning')) return AlertSeverityEnum.warning;
    return AlertSeverityEnum.info;
  }

  static AlertStatusEnum _parseStatus(dynamic status) {
    if (status == null) return AlertStatusEnum.active;
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('acknowledged')) return AlertStatusEnum.acknowledged;
    if (statusStr.contains('resolved')) return AlertStatusEnum.resolved;
    return AlertStatusEnum.active;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plant_id': plantId,
        'alert_rule_id': alertRuleId,
        'title': title,
        'message': message,
        'severity': severity.name,
        'status': status.name,
        'triggered_at': triggeredAt.toIso8601String(),
        'acknowledged_at': acknowledgedAt?.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Alert copyWith({
    String? id,
    int? userId,
    String? plantId,
    int? alertRuleId,
    String? title,
    String? message,
    AlertSeverityEnum? severity,
    AlertStatusEnum? status,
    DateTime? triggeredAt,
    DateTime? acknowledgedAt,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Alert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plantId: plantId ?? this.plantId,
      alertRuleId: alertRuleId ?? this.alertRuleId,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}
