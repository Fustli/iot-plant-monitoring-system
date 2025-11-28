import 'dart:math';
import '../models/plant_model.dart';
import '../models/alert_model.dart';
import 'hybrid_data_service.dart';

/// Mock data service for demo purposes
class MockData {
  static final Random _random = Random();

  // Mock plants data
  static final List<Plant> plants = [
    Plant(
      id: '1',
      userId: 1,
      plantTypeId: 1,
      name: 'Monstera Deliciosa',
      location: 'Living Room',
      plantingDate: DateTime.now().subtract(const Duration(days: 120)),
      lastWatered: DateTime.now().subtract(const Duration(hours: 8)),
      isHealthy: true,
      healthStatus: HealthStatus.excellent,
      notes: 'Growing beautifully',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=150',
      currentMoisture: 75,
      currentTemperature: 22.5,
      currentLight: 65,
    ),
    Plant(
      id: '2',
      userId: 1,
      plantTypeId: 2,
      name: 'Snake Plant',
      location: 'Bedroom',
      plantingDate: DateTime.now().subtract(const Duration(days: 80)),
      lastWatered: DateTime.now().subtract(const Duration(days: 3)),
      isHealthy: true,
      healthStatus: HealthStatus.good,
      notes: 'Very low maintenance',
      createdAt: DateTime.now().subtract(const Duration(days: 80)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      imageUrl: 'https://images.unsplash.com/photo-1595799133244-ae69a0e5ba02?w=150',
      currentMoisture: 45,
      currentTemperature: 21,
      currentLight: 40,
    ),
    Plant(
      id: '3',
      userId: 1,
      plantTypeId: 3,
      name: 'Fiddle Leaf Fig',
      location: 'Office',
      plantingDate: DateTime.now().subtract(const Duration(days: 200)),
      lastWatered: DateTime.now().subtract(const Duration(hours: 12)),
      isHealthy: false,
      healthStatus: HealthStatus.warning,
      notes: 'Needs more humidity',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      imageUrl: 'https://images.unsplash.com/photo-1512428813834-c702c7702b78?w=150',
      currentMoisture: 25,
      currentTemperature: 24,
      currentLight: 80,
    ),
    Plant(
      id: '4',
      userId: 1,
      plantTypeId: 4,
      name: 'Aloe Vera',
      location: 'Kitchen',
      plantingDate: DateTime.now().subtract(const Duration(days: 90)),
      lastWatered: DateTime.now().subtract(const Duration(days: 7)),
      isHealthy: false,
      healthStatus: HealthStatus.critical,
      notes: 'Overwatered recently',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      imageUrl: 'https://images.unsplash.com/photo-1509423350716-97f2360af177?w=150',
      currentMoisture: 85,
      currentTemperature: 26,
      currentLight: 90,
    ),
    Plant(
      id: '5',
      userId: 1,
      plantTypeId: 5,
      name: 'Pothos',
      location: 'Bathroom',
      plantingDate: DateTime.now().subtract(const Duration(days: 60)),
      lastWatered: DateTime.now().subtract(const Duration(hours: 24)),
      isHealthy: true,
      healthStatus: HealthStatus.excellent,
      notes: 'Thriving in humidity',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      imageUrl: 'https://images.unsplash.com/photo-1470058869958-2a77ade41c02?w=150',
      currentMoisture: 60,
      currentTemperature: 23,
      currentLight: 45,
    ),
    Plant(
      id: '6',
      userId: 1,
      plantTypeId: 6,
      name: 'Peace Lily',
      location: 'Dining Room',
      plantingDate: DateTime.now().subtract(const Duration(days: 150)),
      lastWatered: DateTime.now().subtract(const Duration(hours: 6)),
      isHealthy: true,
      healthStatus: HealthStatus.good,
      notes: 'Recently repotted',
      createdAt: DateTime.now().subtract(const Duration(days: 150)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      imageUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=150',
      currentMoisture: 70,
      currentTemperature: 22,
      currentLight: 55,
    ),
  ];

  // Mock alerts data
  static final List<Alert> alerts = [
    Alert(
      id: '1',
      userId: 1,
      plantId: '3',
      alertRuleId: 1,
      title: 'Low Soil Moisture',
      message: 'Fiddle Leaf Fig needs watering - moisture at 25%',
      severity: AlertSeverityEnum.warning,
      status: AlertStatusEnum.active,
      triggeredAt: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Alert(
      id: '2',
      userId: 1,
      plantId: '4',
      alertRuleId: 2,
      title: 'Overwatering Detected',
      message: 'Aloe Vera soil moisture is critically high at 85%',
      severity: AlertSeverityEnum.critical,
      status: AlertStatusEnum.active,
      triggeredAt: DateTime.now().subtract(const Duration(minutes: 30)),
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    Alert(
      id: '3',
      userId: 1,
      plantId: '1',
      alertRuleId: 3,
      title: 'Perfect Conditions',
      message: 'Monstera Deliciosa is thriving in current conditions',
      severity: AlertSeverityEnum.info,
      status: AlertStatusEnum.acknowledged,
      triggeredAt: DateTime.now().subtract(const Duration(hours: 6)),
      acknowledgedAt: DateTime.now().subtract(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  // Mock dashboard statistics
  static final DashboardStats dashboardStats = DashboardStats(
    totalPlants: plants.length,
    healthyPlants: plants.where((p) => p.isHealthy).length,
    activeAlerts: alerts.where((a) => a.status == AlertStatusEnum.active).length,
    onlineDevices: plants.length, // Assume all plants have devices
  );

  /// Generate mock sensor history for charts
  static List<SensorReading> generateSensorHistory(String plantId, int days) {
    final history = <SensorReading>[];
    final now = DateTime.now();
    final plant = plants.firstWhere((p) => p.id == plantId, orElse: () => plants.first);
    
    // Generate hourly readings for the specified number of days
    for (var day = days; day >= 0; day--) {
      for (var hour = 0; hour < 24; hour++) {
        final timestamp = now.subtract(Duration(days: day, hours: hour));
        
        // Generate realistic fluctuations around the plant's current values
        final moistureVariation = (_random.nextDouble() - 0.5) * 20; // ±10%
        final tempVariation = (_random.nextDouble() - 0.5) * 6; // ±3°C
        final lightVariation = _random.nextInt(40) - 20; // ±20%
        
        history.add(SensorReading(
          timestamp: timestamp,
          moisture: (plant.currentMoisture + moistureVariation).clamp(0, 100),
          temperature: plant.currentTemperature + tempVariation,
          light: (plant.currentLight + lightVariation).clamp(0, 100),
        ));
      }
    }
    
    // Sort by timestamp (oldest first)
    history.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return history;
  }

  /// Get plant by ID
  static Plant? getPlantById(String id) {
    try {
      return plants.firstWhere((plant) => plant.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Update plant moisture (for demo purposes)
  static void updatePlantMoisture(String plantId, int newMoisture) {
    final plant = plants.firstWhere((p) => p.id == plantId, orElse: () => plants.first);
    plant.updateMoisture(newMoisture);
    
    // Update health status based on moisture
    if (newMoisture < 20) {
      final updatedPlant = plant.copyWith(healthStatus: HealthStatus.critical, isHealthy: false);
      final index = plants.indexWhere((p) => p.id == plantId);
      if (index != -1) plants[index] = updatedPlant;
    } else if (newMoisture < 40) {
      final updatedPlant = plant.copyWith(healthStatus: HealthStatus.warning, isHealthy: false);
      final index = plants.indexWhere((p) => p.id == plantId);
      if (index != -1) plants[index] = updatedPlant;
    } else if (newMoisture >= 50) {
      final updatedPlant = plant.copyWith(healthStatus: HealthStatus.excellent, isHealthy: true);
      final index = plants.indexWhere((p) => p.id == plantId);
      if (index != -1) plants[index] = updatedPlant;
    }
  }

  /// Simulate watering effect
  static void simulateWatering(String plantId) {
    final plant = getPlantById(plantId);
    if (plant != null) {
      // Increase moisture by 15-25%
      final increase = 15 + _random.nextInt(10);
      updatePlantMoisture(plantId, (plant.currentMoisture + increase).clamp(0, 100));
    }
  }

  /// Remove an alert (for demo acknowledgment)
  static void removeAlert(String alertId) {
    alerts.removeWhere((alert) => alert.id == alertId);
  }
}