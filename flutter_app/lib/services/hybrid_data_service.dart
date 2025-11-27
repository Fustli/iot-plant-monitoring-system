import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/plant_model.dart';
import '../models/alert_model.dart';
import 'mock_data.dart';

class HybridDataService {
  static const Duration _timeout = Duration(seconds: 2);
  static const String _baseUrl = 'http://localhost:8000/api'; // Backend URL

  // Singleton pattern for consistent service usage
  static final HybridDataService _instance = HybridDataService._internal();
  factory HybridDataService() => _instance;
  HybridDataService._internal();

  /// Get all plants - tries real API, falls back to mock data
  Future<List<Plant>> getPlants() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/plants'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Plant.fromJson(json)).toList();
      }
    } catch (e) {
      print('API failed for getPlants, using mock data: $e');
    }
    
    // Instant fallback to mock data
    return MockData.plants;
  }

  /// Get plant details by ID
  Future<Plant?> getPlant(String plantId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/plants/$plantId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return Plant.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('API failed for getPlant, using mock data: $e');
    }
    
    // Fallback to mock data
    return MockData.plants.firstWhere(
      (plant) => plant.id == plantId,
      orElse: () => MockData.plants.first,
    );
  }

  /// Water a plant - tries real API, always shows success for demo
  Future<bool> waterPlant(String plantId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/plants/$plantId/water'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      print('API failed for waterPlant, simulating success: $e');
    }
    
    // Always simulate success for demo (with realistic delay)
    await Future.delayed(const Duration(milliseconds: 800));
    return true;
  }

  /// Control device (light, fan, etc.) - tries real API, simulates success
  Future<bool> controlDevice(String plantId, String action, dynamic value) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/plants/$plantId/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': action,
          'value': value,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(_timeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      print('API failed for controlDevice, simulating success: $e');
    }
    
    // Always simulate success for demo
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  /// Get sensor history for charts
  Future<List<SensorReading>> getSensorHistory(String plantId, int days) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/plants/$plantId/history?days=$days'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => SensorReading.fromJson(json)).toList();
      }
    } catch (e) {
      print('API failed for getSensorHistory, using mock data: $e');
    }
    
    // Fallback to generated mock history
    return MockData.generateSensorHistory(plantId, days);
  }

  /// Get active alerts
  Future<List<Alert>> getAlerts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/alerts'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Alert.fromJson(json)).toList();
      }
    } catch (e) {
      print('API failed for getAlerts, using mock data: $e');
    }
    
    return MockData.alerts;
  }

  /// Acknowledge an alert
  Future<bool> acknowledgeAlert(String alertId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/alerts/$alertId/acknowledge'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('API failed for acknowledgeAlert, simulating success: $e');
    }
    
    // Always simulate success
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  /// Get app statistics for dashboard
  Future<DashboardStats> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        return DashboardStats.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('API failed for getStats, using mock data: $e');
    }
    
    return MockData.dashboardStats;
  }
}

/// Sensor reading data structure for charts
class SensorReading {
  final DateTime timestamp;
  final double moisture;
  final double temperature;
  final int light;

  SensorReading({
    required this.timestamp,
    required this.moisture,
    required this.temperature,
    required this.light,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      timestamp: DateTime.parse(json['timestamp']),
      moisture: (json['moisture'] ?? 0.0).toDouble(),
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      light: json['light'] ?? 0,
    );
  }
}

/// Dashboard statistics
class DashboardStats {
  final int totalPlants;
  final int healthyPlants;
  final int activeAlerts;
  final int onlineDevices;

  DashboardStats({
    required this.totalPlants,
    required this.healthyPlants,
    required this.activeAlerts,
    required this.onlineDevices,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalPlants: json['total_plants'] ?? 0,
      healthyPlants: json['healthy_plants'] ?? 0,
      activeAlerts: json['active_alerts'] ?? 0,
      onlineDevices: json['online_devices'] ?? 0,
    );
  }
}