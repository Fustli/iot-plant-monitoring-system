/// PlantType model for the plant species catalog
/// Managed by Super Admin role (merged Admin + Plant Database Manager)
/// Matches backend NewPlantType and plant type API responses

class PlantType {
  final int id;
  final String plantName;
  final String scientificName;
  final double reqBrightness; // Required light level (0-100 lux percentage)
  final double reqHumidity; // Required humidity (0-100%)
  final double reqTemperature; // Required temperature (Celsius)
  final int reqMoisture; // Required soil moisture (0-100%)
  final String? description;
  final String? careInstructions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlantType({
    required this.id,
    required this.plantName,
    required this.scientificName,
    required this.reqBrightness,
    required this.reqHumidity,
    required this.reqTemperature,
    required this.reqMoisture,
    this.description,
    this.careInstructions,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse from backend JSON response
  factory PlantType.fromJson(Map<String, dynamic> json) {
    return PlantType(
      id: json['id'] as int? ?? 0,
      plantName:
          json['plant_name'] as String? ?? json['name'] as String? ?? 'Unknown',
      scientificName: json['scientific_name'] as String? ?? '',
      reqBrightness: (json['req_brightness'] as num?)?.toDouble() ?? 50.0,
      reqHumidity: (json['req_humidity'] as num?)?.toDouble() ?? 50.0,
      reqTemperature: (json['req_temperature'] as num?)?.toDouble() ?? 22.0,
      reqMoisture: (json['req_moisture'] as num?)?.toInt() ?? 50,
      description: json['description'] as String?,
      careInstructions: json['care_instructions'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for API requests (matches NewPlantType schema)
  Map<String, dynamic> toJson() => {
        'plant_name': plantName,
        'scientific_name': scientificName,
        'req_brightness': reqBrightness,
        'req_humidity': reqHumidity,
        'req_temperature': reqTemperature,
        'req_moisture': reqMoisture,
        if (description != null) 'description': description,
        if (careInstructions != null) 'care_instructions': careInstructions,
      };

  /// Create a copy with modified fields
  PlantType copyWith({
    int? id,
    String? plantName,
    String? scientificName,
    double? reqBrightness,
    double? reqHumidity,
    double? reqTemperature,
    int? reqMoisture,
    String? description,
    String? careInstructions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlantType(
      id: id ?? this.id,
      plantName: plantName ?? this.plantName,
      scientificName: scientificName ?? this.scientificName,
      reqBrightness: reqBrightness ?? this.reqBrightness,
      reqHumidity: reqHumidity ?? this.reqHumidity,
      reqTemperature: reqTemperature ?? this.reqTemperature,
      reqMoisture: reqMoisture ?? this.reqMoisture,
      description: description ?? this.description,
      careInstructions: careInstructions ?? this.careInstructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted requirements string for display
  String get requirementsSummary =>
      '🌡️ ${reqTemperature.toStringAsFixed(1)}°C | 💧 $reqMoisture% | ☀️ ${reqBrightness.toStringAsFixed(0)}%';

  /// Get formatted requirements in Hungarian
  String get requirementsSummaryHu =>
      'Hőmérséklet: ${reqTemperature.toStringAsFixed(1)}°C\n'
      'Talajnedvesség: $reqMoisture%\n'
      'Fényigény: ${reqBrightness.toStringAsFixed(0)}%\n'
      'Páratartalom: ${reqHumidity.toStringAsFixed(0)}%';

  @override
  String toString() => 'PlantType($plantName - $scientificName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlantType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Request model for creating a plant from an existing PlantType
class PlantFromDatabaseRequest {
  final String name;
  final String scientificName;
  final bool isHealthy;
  final String? location;
  final String? healthStatus;
  final String? notes;

  const PlantFromDatabaseRequest({
    required this.name,
    required this.scientificName,
    this.isHealthy = true,
    this.location,
    this.healthStatus,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'scientific_name': scientificName,
        'is_healthy': isHealthy,
        if (location != null) 'location': location,
        if (healthStatus != null) 'health_status': healthStatus,
        if (notes != null) 'notes': notes,
      };
}

/// Request model for creating a custom plant with full requirements
class PlantFromScratchRequest {
  final String name;
  final String scientificName;
  final double reqBrightness;
  final double reqHumidity;
  final double reqTemperature;
  final int reqMoisture;
  final String? description;
  final String? careInstructions;
  final String? location;
  final bool isHealthy;
  final String? healthStatus;
  final String? notes;

  const PlantFromScratchRequest({
    required this.name,
    required this.scientificName,
    required this.reqBrightness,
    required this.reqHumidity,
    required this.reqTemperature,
    required this.reqMoisture,
    this.description,
    this.careInstructions,
    this.location,
    this.isHealthy = true,
    this.healthStatus,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'scientific_name': scientificName,
        'req_brightness': reqBrightness,
        'req_humidity': reqHumidity,
        'req_temperature': reqTemperature,
        'req_moisture': reqMoisture,
        if (description != null) 'description': description,
        if (careInstructions != null) 'care_instructions': careInstructions,
        if (location != null) 'location': location,
        'is_healthy': isHealthy,
        if (healthStatus != null) 'health_status': healthStatus,
        if (notes != null) 'notes': notes,
      };
}
