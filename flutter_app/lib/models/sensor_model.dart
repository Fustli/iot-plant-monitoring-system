class SensorData {
  final int id;
  final int deviceId;
  final double measurementValue;
  final String measurementUnit;
  final int dataQuality;
  final bool isAnomaly;
  final DateTime timestamp;
  final String? rawData;

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
