enum HealthStatus {
  excellent,
  good,
  needsAttention,
  critical;

  String get displayName {
    switch (this) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.needsAttention:
        return 'Needs Attention';
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
    required this.currentHumidity,
    this.optimalTemperature,
    this.optimalHumidity,
    this.optimalLight,
    this.optimalMoisture,
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
      // Get sensor values directly from plant data, or extract from devices
      currentMoisture: _getSensorValue(json, 'current_moisture', 'moisture'),
      currentTemperature:
          _getSensorValueDouble(json, 'current_temperature', 'temperature'),
      currentLight: _getSensorValue(json, 'current_light', 'light'),
      currentHumidity: _getSensorValue(json, 'current_humidity', 'humidity'),
      // Optimal values from plant_type join
      optimalTemperature: (json['optimal_temperature'] as num?)?.toDouble(),
      optimalHumidity: (json['optimal_humidity'] as num?)?.toDouble(),
      optimalLight: (json['optimal_light'] as num?)?.toDouble(),
      optimalMoisture: (json['optimal_moisture'] as num?)?.toDouble(),
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
  int currentHumidity;
  // Optimal values from plant_type
  final double? optimalTemperature;
  final double? optimalHumidity;
  final double? optimalLight;
  final double? optimalMoisture;

  // ============== Health Range Configuration ==============
  // Each metric has specific tolerance ranges that make sense for plants

  /// Temperature tolerance: ±5°C around optimal (e.g., optimal 22°C → range 17-27°C)
  static const double _temperatureTolerance = 5.0;

  /// Humidity tolerance: ±15% around optimal (e.g., optimal 60% → range 45-75%)
  static const double _humidityTolerance = 15.0;

  /// Light tolerance: ±30% of optimal value (light varies more throughout day)
  static const double _lightTolerancePercent = 0.30;

  /// Moisture tolerance: ±20% around optimal (e.g., optimal 50% → range 30-70%)
  static const double _moistureTolerance = 20.0;

  // ============== Range Getters ==============

  /// Get acceptable temperature range [min, max]
  (double, double)? get temperatureRange {
    if (optimalTemperature == null) return null;
    return (
      optimalTemperature! - _temperatureTolerance,
      optimalTemperature! + _temperatureTolerance
    );
  }

  /// Get acceptable humidity range [min, max]
  (double, double)? get humidityRange {
    if (optimalHumidity == null) return null;
    return (
      (optimalHumidity! - _humidityTolerance).clamp(0, 100),
      (optimalHumidity! + _humidityTolerance).clamp(0, 100)
    );
  }

  /// Get acceptable light range [min, max]
  (double, double)? get lightRange {
    if (optimalLight == null) return null;
    return (
      (optimalLight! * (1 - _lightTolerancePercent)).clamp(0, double.infinity),
      optimalLight! * (1 + _lightTolerancePercent)
    );
  }

  /// Get acceptable moisture range [min, max]
  (double, double)? get moistureRange {
    if (optimalMoisture == null) return null;
    return (
      (optimalMoisture! - _moistureTolerance).clamp(0, 100),
      (optimalMoisture! + _moistureTolerance).clamp(0, 100)
    );
  }

  // ============== Health Calculation ==============

  /// Calculate health status based on current vs optimal ranges.
  /// Returns "Good" if all values are within their acceptable ranges,
  /// "Needs Attention" otherwise.
  HealthStatus get calculatedHealthStatus {
    // If we don't have optimal values, can't calculate - use stored status
    if (optimalTemperature == null ||
        optimalHumidity == null ||
        optimalLight == null ||
        optimalMoisture == null) {
      return healthStatus;
    }

    // Check if each sensor value is within its acceptable range
    final tempRange = temperatureRange!;
    final humRange = humidityRange!;
    final ligRange = lightRange!;
    final moiRange = moistureRange!;

    final tempOk = currentTemperature >= tempRange.$1 &&
        currentTemperature <= tempRange.$2;
    final humidityOk =
        currentHumidity >= humRange.$1 && currentHumidity <= humRange.$2;
    final lightOk = currentLight >= ligRange.$1 && currentLight <= ligRange.$2;
    final moistureOk =
        currentMoisture >= moiRange.$1 && currentMoisture <= moiRange.$2;

    // Debug: Print values to console
    print('Health Check for $name:');
    print(
        '  Temp: $currentTemperature in [${tempRange.$1}, ${tempRange.$2}] = $tempOk');
    print(
        '  Humidity: $currentHumidity in [${humRange.$1}, ${humRange.$2}] = $humidityOk');
    print(
        '  Light: $currentLight in [${ligRange.$1}, ${ligRange.$2}] = $lightOk');
    print(
        '  Moisture: $currentMoisture in [${moiRange.$1}, ${moiRange.$2}] = $moistureOk');

    // If any value is outside range, status is "Needs Attention"
    if (!tempOk || !humidityOk || !lightOk || !moistureOk) {
      print('  Result: Needs Attention');
      return HealthStatus.needsAttention;
    }

    // All values are within range, status is "Good"
    print('  Result: Good');
    return HealthStatus.good;
  }

  /// Check if a value is within the given range [min, max]
  static bool _isInRange(double value, (double, double) range) {
    return value >= range.$1 && value <= range.$2;
  }

  /// Get sensor value - first try direct field, then try nested device data
  static int _getSensorValue(
      Map<String, dynamic> json, String directField, String sensorType) {
    // First try direct field from plant data
    if (json[directField] != null) {
      return (json[directField] as num).round();
    }
    // Fallback to extracting from nested device data
    return _extractSensorValue(json, sensorType).round();
  }

  static double _getSensorValueDouble(
      Map<String, dynamic> json, String directField, String sensorType) {
    // First try direct field from plant data
    if (json[directField] != null) {
      return (json[directField] as num).toDouble();
    }
    // Fallback to extracting from nested device data
    return _extractSensorValue(json, sensorType);
  }

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
    if (statusStr.contains('attention') ||
        statusStr.contains('warning') ||
        statusStr.contains('care')) return HealthStatus.needsAttention;
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
        'current_humidity': currentHumidity,
        'optimal_temperature': optimalTemperature,
        'optimal_humidity': optimalHumidity,
        'optimal_light': optimalLight,
        'optimal_moisture': optimalMoisture,
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

  void updateHumidity(int newHumidity) {
    currentHumidity = newHumidity.clamp(0, 100);
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
    int? currentHumidity,
    double? optimalTemperature,
    double? optimalHumidity,
    double? optimalLight,
    double? optimalMoisture,
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
        currentHumidity: currentHumidity ?? this.currentHumidity,
        optimalTemperature: optimalTemperature ?? this.optimalTemperature,
        optimalHumidity: optimalHumidity ?? this.optimalHumidity,
        optimalLight: optimalLight ?? this.optimalLight,
        optimalMoisture: optimalMoisture ?? this.optimalMoisture,
      );
}
