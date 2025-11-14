class Plant {
  final int id;
  final int userId;
  final int plantTypeId;
  final String plantName;
  final String location;
  final DateTime plantingDate;
  final DateTime? lastWatered;
  final bool isHealthy;
  final String healthStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Plant({
    required this.id,
    required this.userId,
    required this.plantTypeId,
    required this.plantName,
    required this.location,
    required this.plantingDate,
    this.lastWatered,
    required this.isHealthy,
    required this.healthStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      id: json['id'],
      userId: json['user_id'],
      plantTypeId: json['plant_type_id'],
      plantName: json['plant_name'],
      location: json['location'],
      plantingDate: DateTime.parse(json['planting_date']),
      lastWatered: json['last_watered'] != null ? DateTime.parse(json['last_watered']) : null,
      isHealthy: json['is_healthy'] ?? true,
      healthStatus: json['health_status'] ?? 'Healthy',
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'plant_type_id': plantTypeId,
    'plant_name': plantName,
    'location': location,
    'planting_date': plantingDate.toIso8601String(),
    'last_watered': lastWatered?.toIso8601String(),
    'is_healthy': isHealthy,
    'health_status': healthStatus,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
