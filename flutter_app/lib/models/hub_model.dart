/// Hub model representing a physical gateway device
class Hub {
  Hub({
    required this.id,
    required this.userId,
    required this.hubId,
    required this.hubLink,
    required this.name,
    this.location,
    this.description,
    required this.isOnline,
    this.lastSeen,
    this.lastHeartbeat,
    this.ipAddress,
    this.macAddress,
    this.firmwareVersion,
    this.uptimeSeconds,
    this.messagesSent,
    this.messagesReceived,
    this.errorsCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Hub.fromJson(Map<String, dynamic> json) {
    return Hub(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      hubId: json['hub_id'] ?? '',
      hubLink: json['hub_link'] ?? '',
      name: json['name'] ?? 'Unknown Hub',
      location: json['location'],
      description: json['description'],
      isOnline: json['is_online'] ?? false,
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.parse(json['last_heartbeat'])
          : null,
      ipAddress: json['ip_address'],
      macAddress: json['mac_address'],
      firmwareVersion: json['firmware_version'],
      uptimeSeconds: json['uptime_seconds'],
      messagesSent: json['messages_sent'],
      messagesReceived: json['messages_received'],
      errorsCount: json['errors_count'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  final int id;
  final int userId;
  final String hubId;
  final String hubLink;
  final String name;
  final String? location;
  final String? description;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? lastHeartbeat;
  final String? ipAddress;
  final String? macAddress;
  final String? firmwareVersion;
  final int? uptimeSeconds;
  final int? messagesSent;
  final int? messagesReceived;
  final int? errorsCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'hub_id': hubId,
        'hub_link': hubLink,
        'name': name,
        'location': location,
        'description': description,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'last_heartbeat': lastHeartbeat?.toIso8601String(),
        'ip_address': ipAddress,
        'mac_address': macAddress,
        'firmware_version': firmwareVersion,
        'uptime_seconds': uptimeSeconds,
        'messages_sent': messagesSent,
        'messages_received': messagesReceived,
        'errors_count': errorsCount,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Hub copyWith({
    int? id,
    int? userId,
    String? hubId,
    String? hubLink,
    String? name,
    String? location,
    String? description,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? lastHeartbeat,
    String? ipAddress,
    String? macAddress,
    String? firmwareVersion,
    int? uptimeSeconds,
    int? messagesSent,
    int? messagesReceived,
    int? errorsCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Hub(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        hubId: hubId ?? this.hubId,
        hubLink: hubLink ?? this.hubLink,
        name: name ?? this.name,
        location: location ?? this.location,
        description: description ?? this.description,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
        lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
        ipAddress: ipAddress ?? this.ipAddress,
        macAddress: macAddress ?? this.macAddress,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
        messagesSent: messagesSent ?? this.messagesSent,
        messagesReceived: messagesReceived ?? this.messagesReceived,
        errorsCount: errorsCount ?? this.errorsCount,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Format uptime as human-readable string
  String get formattedUptime {
    if (uptimeSeconds == null) return 'Unknown';
    final duration = Duration(seconds: uptimeSeconds!);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
