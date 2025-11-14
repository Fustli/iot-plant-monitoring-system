class Device {
  final int id;
  final int userId;
  final int deviceTypeId;
  final String uniqueIdentifier;
  final String deviceName;
  final bool isActive;
  final DateTime? lastDataReceived;
  final DateTime? lastHeartbeat;
  final String? locationDescription;
  final double? batteryLevel;
  final int? rssi;
  final DateTime createdAt;
  final DateTime updatedAt;

  Device({
    required this.id,
    required this.userId,
    required this.deviceTypeId,
    required this.uniqueIdentifier,
    required this.deviceName,
    required this.isActive,
    this.lastDataReceived,
    this.lastHeartbeat,
    this.locationDescription,
    this.batteryLevel,
    this.rssi,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOnline {
    if (lastHeartbeat == null) return false;
    final duration = DateTime.now().difference(lastHeartbeat!);
    return duration.inMinutes < 5;
  }

  String get statusText => isOnline ? 'Online' : 'Offline';

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      userId: json['user_id'],
      deviceTypeId: json['device_type_id'],
      uniqueIdentifier: json['unique_identifier'],
      deviceName: json['device_name'],
      isActive: json['is_active'] ?? true,
      lastDataReceived: json['last_data_received'] != null ? DateTime.parse(json['last_data_received']) : null,
      lastHeartbeat: json['last_heartbeat'] != null ? DateTime.parse(json['last_heartbeat']) : null,
      locationDescription: json['location_description'],
      batteryLevel: (json['battery_level'] as num?)?.toDouble(),
      rssi: json['rssi'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'device_type_id': deviceTypeId,
    'unique_identifier': uniqueIdentifier,
    'device_name': deviceName,
    'is_active': isActive,
    'last_data_received': lastDataReceived?.toIso8601String(),
    'last_heartbeat': lastHeartbeat?.toIso8601String(),
    'location_description': locationDescription,
    'battery_level': batteryLevel,
    'rssi': rssi,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
