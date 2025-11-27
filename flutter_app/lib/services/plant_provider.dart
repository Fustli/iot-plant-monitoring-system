import 'package:flutter/foundation.dart';
import '../models/plant_model.dart';
import '../services/hybrid_data_service.dart';
import '../services/mock_data.dart';

class PlantProvider with ChangeNotifier {
  final HybridDataService _dataService = HybridDataService();
  
  List<Plant> _plants = [];
  bool _isLoading = false;
  String? _error;
  Plant? _selectedPlant;

  // Getters
  List<Plant> get plants => _plants;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Plant? get selectedPlant => _selectedPlant;
  
  // Statistics
  int get totalPlants => _plants.length;
  int get healthyPlants => _plants.where((plant) => plant.isHealthy).length;
  int get plantsNeedingCare => _plants.where((plant) => !plant.isHealthy).length;

  /// Load all plants from the data service
  Future<void> loadPlants() async {
    _setLoading(true);
    _error = null;
    
    try {
      _plants = await _dataService.getPlants();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load plants: $e';
      print(_error);
      // Fallback to direct mock data if service fails
      _plants = MockData.plants;
    } finally {
      _setLoading(false);
    }
  }

  /// Select a plant for detailed view
  void selectPlant(Plant plant) {
    _selectedPlant = plant;
    notifyListeners();
  }

  /// Load detailed plant information
  Future<void> loadPlantDetails(String plantId) async {
    try {
      final plant = await _dataService.getPlant(plantId);
      if (plant != null) {
        _selectedPlant = plant;
        // Update plant in the list as well
        final index = _plants.indexWhere((p) => p.id == plantId);
        if (index != -1) {
          _plants[index] = plant;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Failed to load plant details: $e');
      // Fallback to existing data
    }
  }

  /// Water a plant
  Future<bool> waterPlant(String plantId) async {
    try {
      final success = await _dataService.waterPlant(plantId);
      if (success) {
        // Update plant moisture optimistically
        final plantIndex = _plants.indexWhere((p) => p.id == plantId);
        if (plantIndex != -1) {
          final plant = _plants[plantIndex];
          final newMoisture = (plant.currentMoisture + 20).clamp(0, 100);
          plant.updateMoisture(newMoisture);
          
          // Update health status if moisture improved
          if (newMoisture >= 50 && plant.healthStatus != HealthStatus.excellent) {
            _plants[plantIndex] = plant.copyWith(
              healthStatus: HealthStatus.excellent,
              isHealthy: true,
              lastWatered: DateTime.now(),
            );
          }
          
          // Update selected plant if it's the same
          if (_selectedPlant?.id == plantId) {
            _selectedPlant = _plants[plantIndex];
          }
          
          notifyListeners();
        }
        
        // Also update mock data for consistency
        MockData.simulateWatering(plantId);
        return true;
      }
    } catch (e) {
      print('Failed to water plant: $e');
    }
    return false;
  }

  /// Control device (light, fan, etc.)
  Future<bool> controlDevice(String plantId, String action, dynamic value) async {
    try {
      final success = await _dataService.controlDevice(plantId, action, value);
      if (success) {
        // Update plant data based on action
        final plantIndex = _plants.indexWhere((p) => p.id == plantId);
        if (plantIndex != -1) {
          final plant = _plants[plantIndex];
          
          switch (action) {
            case 'light':
              plant.updateLight(value is int ? value : (value as double).round());
              break;
            case 'temperature':
              plant.updateTemperature(value is double ? value : (value as int).toDouble());
              break;
          }
          
          if (_selectedPlant?.id == plantId) {
            _selectedPlant = plant;
          }
          
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      print('Failed to control device: $e');
    }
    return false;
  }

  /// Get plant by ID
  Plant? getPlantById(String id) {
    try {
      return _plants.firstWhere((plant) => plant.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Refresh plant data
  Future<void> refresh() async {
    await loadPlants();
  }

  /// Clear selected plant
  void clearSelection() {
    _selectedPlant = null;
    notifyListeners();
  }

  /// Update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Get plants grouped by health status
  Map<HealthStatus, List<Plant>> get plantsGroupedByHealth {
    final groups = <HealthStatus, List<Plant>>{};
    for (final status in HealthStatus.values) {
      groups[status] = _plants.where((plant) => plant.healthStatus == status).toList();
    }
    return groups;
  }

  /// Get plants that need attention (warning or critical)
  List<Plant> get plantsNeedingAttention {
    return _plants.where((plant) => 
      plant.healthStatus == HealthStatus.warning || 
      plant.healthStatus == HealthStatus.critical
    ).toList();
  }

  /// Check if any plants need water (moisture < 30%)
  bool get hasThirstyPlants {
    return _plants.any((plant) => plant.currentMoisture < 30);
  }

  /// Get count of plants by location
  Map<String, int> get plantsByLocation {
    final locationCounts = <String, int>{};
    for (final plant in _plants) {
      locationCounts[plant.location] = (locationCounts[plant.location] ?? 0) + 1;
    }
    return locationCounts;
  }
}