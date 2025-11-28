enum HealthStatus {
  excellent,
  good,
  warning,
  critical;

  String get displayName {
    switch (this) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.warning:
        return 'Needs Care';
      case HealthStatus.critical:
        return 'Critical';
    }
  }
}

class Plant {
  Plant({
    required this.id,
    required this.userId,
    required this.plantTypeId,
    required this.name,
    required this.location,
    required this.plantingDate,
    this.lastWatered,
    required this.isHealthy,
    required this.healthStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrl,
    required this.currentMoisture,
    required this.currentTemperature,
    required this.currentLight,
  });

  // Updated to handle nested device/sensor data from a real API
  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'].toString(),
      userId: json['user_id'] ?? 0,
      plantTypeId: json['plant_type_id'] ?? 0,
      name: json['plant_name'] ?? json['name'] ?? 'Unknown Plant',
      location: json['location'] ?? 'Unknown',
      plantingDate: json['planting_date'] != null
          ? DateTime.parse(json['planting_date'])
          : DateTime.now(),
      lastWatered: json['last_watered'] != null
          ? DateTime.parse(json['last_watered'])
          : null,
      isHealthy: json['is_healthy'] ?? true,
      healthStatus: _parseHealthStatus(json['health_status']),
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      imageUrl:
          json['image_url'] ?? 'https://via.placeholder.com/150?text=Plant',
      // Extract sensor data from the first associated device, if available
      currentMoisture: _extractSensorValue(json, 'moisture').round(),
      currentTemperature: _extractSensorValue(json, 'temperature'),
      currentLight: _extractSensorValue(json, 'light').round(),
    );
  }
  final String id;
  final int userId;
  final int plantTypeId;
  final String name;
  final String location;
  final DateTime plantingDate;
  final DateTime? lastWatered;
  final bool isHealthy;
  final HealthStatus healthStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String imageUrl;
  int currentMoisture;
  double currentTemperature;
  int currentLight;

  static double _extractSensorValue(Map<String, dynamic> json, String type) {
    if (json['devices'] is List && (json['devices'] as List).isNotEmpty) {
      final device = json['devices'].first;
      if (device['sensors'] is List) {
        final sensor = (device['sensors'] as List).firstWhere(
            (s) => s['sensor_type']?['type_name'] == type,
            orElse: () => null);
        return (sensor?['latest_value'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }

  static HealthStatus _parseHealthStatus(dynamic status) {
    if (status == null) return HealthStatus.good;
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('excellent')) return HealthStatus.excellent;
    if (statusStr.contains('warning') || statusStr.contains('care'))
      return HealthStatus.warning;
    if (statusStr.contains('critical') || statusStr.contains('danger'))
      return HealthStatus.critical;
    return HealthStatus.good;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plant_type_id': plantTypeId,
        'plant_name': name,
        'location': location,
        'planting_date': plantingDate.toIso8601String(),
        'last_watered': lastWatered?.toIso8601String(),
        'is_healthy': isHealthy,
        'health_status': healthStatus.displayName,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'image_url': imageUrl,
        'current_moisture': currentMoisture,
        'current_temperature': currentTemperature,
        'current_light': currentLight,
      };

  void updateMoisture(int newMoisture) {
    currentMoisture = newMoisture.clamp(0, 100);
  }

  void updateTemperature(double newTemperature) {
    currentTemperature = newTemperature;
  }

  void updateLight(int newLight) {
    currentLight = newLight.clamp(0, 100);
  }

  Plant copyWith({
    String? id,
    int? userId,
    int? plantTypeId,
    String? name,
    String? location,
    DateTime? plantingDate,
    DateTime? lastWatered,
    bool? isHealthy,
    HealthStatus? healthStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    int? currentMoisture,
    double? currentTemperature,
    int? currentLight,
  }) =>
      Plant(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        plantTypeId: plantTypeId ?? this.plantTypeId,
        name: name ?? this.name,
        location: location ?? this.location,
        plantingDate: plantingDate ?? this.plantingDate,
        lastWatered: lastWatered ?? this.lastWatered,
        isHealthy: isHealthy ?? this.isHealthy,
        healthStatus: healthStatus ?? this.healthStatus,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        imageUrl: imageUrl ?? this.imageUrl,
        currentMoisture: currentMoisture ?? this.currentMoisture,
        currentTemperature: currentTemperature ?? this.currentTemperature,
        currentLight: currentLight ?? this.currentLight,
      );
}
