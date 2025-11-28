class SensorData {
  SensorData({
    required this.id,
    required this.deviceId,
    required this.measurementValue,
    required this.measurementUnit,
    required this.dataQuality,
    required this.isAnomaly,
    required this.timestamp,
    this.rawData,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'],
      deviceId: json['device_id'],
      measurementValue: (json['measurement_value'] as num).toDouble(),
      measurementUnit: json['measurement_unit'],
      dataQuality: json['data_quality'] ?? 100,
      isAnomaly: json['is_anomaly'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      rawData: json['raw_data'],
    );
  }
  final int id;
  final int deviceId;
  final double measurementValue;
  final String measurementUnit;
  final int dataQuality;
  final bool isAnomaly;
  final DateTime timestamp;
  final String? rawData;

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceId,
        'measurement_value': measurementValue,
        'measurement_unit': measurementUnit,
        'data_quality': dataQuality,
        'is_anomaly': isAnomaly,
        'timestamp': timestamp.toIso8601String(),
        'raw_data': rawData,
      };
}

/// Aggregated sensor reading for history/charts
/// Used when displaying plant sensor data over time
class SensorReading {
  SensorReading({
    required this.timestamp,
    this.moisture,
    this.temperature,
    this.light,
    this.humidity,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      timestamp: json['timestamp'] is DateTime
          ? json['timestamp']
          : DateTime.parse(json['timestamp'].toString()),
      moisture: (json['moisture'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      light: (json['light'] as num?)?.toInt(),
      humidity: (json['humidity'] as num?)?.toDouble(),
    );
  }

  final DateTime timestamp;
  final double? moisture;
  final double? temperature;
  final int? light;
  final double? humidity;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'moisture': moisture,
        'temperature': temperature,
        'light': light,
        'humidity': humidity,
      };
}
