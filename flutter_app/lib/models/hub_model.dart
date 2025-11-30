/// Hub model representing a physical gateway device
/// Matches backend Hub schema from ServerModule
class Hub {
  Hub({
    required this.id,
    this.userId,
    required this.serial,
    this.iothubDeviceId,
    this.iothubConnectionString,
    this.name,
    this.lastSeen,
    this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Hub.fromJson(Map<String, dynamic> json) {
    return Hub(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      serial: json['serial'] ?? '',
      iothubDeviceId: json['iothub_device_id'],
      iothubConnectionString: json['iothub_connection_string'],
      name: json['name'],
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
      status: json['status'],
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  final int id;
  final int? userId;
  final String serial;
  final String? iothubDeviceId;
  final String? iothubConnectionString;
  final String? name;
  final DateTime? lastSeen;
  final String? status;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Check if hub is online based on status
  bool get isOnline => status == 'online' || status == 'active';

  /// Get display name (name or serial fallback)
  String get displayName => name ?? serial;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'serial': serial,
        'iothub_device_id': iothubDeviceId,
        'iothub_connection_string': iothubConnectionString,
        'name': name,
        'last_seen': lastSeen?.toIso8601String(),
        'status': status,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Hub copyWith({
    int? id,
    int? userId,
    String? serial,
    String? iothubDeviceId,
    String? iothubConnectionString,
    String? name,
    DateTime? lastSeen,
    String? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Hub(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        serial: serial ?? this.serial,
        iothubDeviceId: iothubDeviceId ?? this.iothubDeviceId,
        iothubConnectionString:
            iothubConnectionString ?? this.iothubConnectionString,
        name: name ?? this.name,
        lastSeen: lastSeen ?? this.lastSeen,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Format last seen as human-readable string
  String get formattedLastSeen {
    if (lastSeen == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
