import 'package:flutter/foundation.dart';

import '../models/plant_model.dart';
import '../models/plant_type_model.dart';
import 'api_client.dart';
import 'api_exceptions.dart';
import 'mock_data.dart';
import 'hybrid_data_service.dart';

/// Plant state management provider
/// Handles plant data, API calls, and mock fallback
class PlantProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final HybridDataService _hybridService = HybridDataService();

  List<Plant> _plants = [];
  List<PlantType> _plantTypes = [];
  bool _isLoading = false;
  String? _error;
  Plant? _selectedPlant;
  bool _useMockData = true; // Fallback to mock when API fails

  // Getters
  List<Plant> get plants => _plants;
  List<PlantType> get plantTypes => _plantTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Plant? get selectedPlant => _selectedPlant;
  bool get useMockData => _useMockData;

  // Statistics
  int get totalPlants => _plants.length;
  int get healthyPlants => _plants.where((plant) => plant.isHealthy).length;
  int get plantsNeedingCare =>
      _plants.where((plant) => !plant.isHealthy).length;

  /// Load all plants from the API or mock data
  Future<void> loadPlants() async {
    _setLoading(true);
    _error = null;

    try {
      // Try API first
      _plants = await _apiService.getMyPlants();
      _useMockData = false;
    } on ServerUnreachableException catch (e) {
      debugPrint('Server unreachable, falling back to mock data: ${e.message}');
      _plants = MockData.plants;
      _useMockData = true;
    } on UnauthorizedException catch (e) {
      _error = e.messageHu;
      _plants = [];
    } on ApiException catch (e) {
      debugPrint('API error loading plants: ${e.message}');
      _plants = MockData.plants;
      _useMockData = true;
    } catch (e) {
      debugPrint('Unexpected error loading plants: $e');
      _plants = MockData.plants;
      _useMockData = true;
    } finally {
      _setLoading(false);
    }
  }

  /// Load available plant types from catalog
  Future<void> loadPlantTypes() async {
    try {
      _plantTypes = await _apiService.listPlantTypes();
    } on ApiException catch (e) {
      debugPrint('Failed to load plant types: ${e.message}');
      _plantTypes = [];
    } catch (e) {
      debugPrint('Unexpected error loading plant types: $e');
      _plantTypes = [];
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
      if (!_useMockData) {
        final plant = await _apiService.getPlantDetails(int.parse(plantId));
        _selectedPlant = plant;
        // Update plant in the list as well
        final index = _plants.indexWhere((p) => p.id == plantId);
        if (index != -1) {
          _plants[index] = plant;
        }
        notifyListeners();
      } else {
        // Use hybrid service for mock fallback
        final plant = await _hybridService.getPlant(plantId);
        if (plant != null) {
          _selectedPlant = plant;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to load plant details: $e');
      // Fallback to existing data
    }
  }

  /// Create a new plant from database (existing plant type)
  Future<bool> createPlantFromDatabase(PlantFromDatabaseRequest request) async {
    try {
      await _apiService.createPlantFromDatabase(request);
      await loadPlants(); // Refresh plant list
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ismeretlen hiba történt';
      notifyListeners();
      return false;
    }
  }

  /// Create a new plant from scratch (custom requirements)
  Future<bool> createPlantFromScratch(PlantFromScratchRequest request) async {
    try {
      await _apiService.createPlantFromScratch(request);
      await loadPlants(); // Refresh plant list
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ismeretlen hiba történt';
      notifyListeners();
      return false;
    }
  }

  /// Delete a plant
  Future<bool> deletePlant(int plantId) async {
    try {
      if (!_useMockData) {
        await _apiService.deletePlant(plantId);
      }

      // Remove from local list
      _plants.removeWhere((p) => p.id == plantId.toString());

      // Clear selection if it was deleted
      if (_selectedPlant?.id == plantId.toString()) {
        _selectedPlant = null;
      }

      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Nem sikerült törölni a növényt';
      notifyListeners();
      return false;
    }
  }

  /// Activate/deactivate plant care
  Future<bool> setPlantActivation(int? plantId, bool activate) async {
    try {
      await _apiService.setPlantActivation(
          plantId: plantId, activate: activate);
      await loadPlants(); // Refresh to get updated status
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Water a plant (send command to actuator)
  Future<bool> waterPlant(String plantId) async {
    try {
      final success = await _hybridService.waterPlant(plantId);
      if (success) {
        // Update plant moisture optimistically
        final plantIndex = _plants.indexWhere((p) => p.id == plantId);
        if (plantIndex != -1) {
          final plant = _plants[plantIndex];
          final newMoisture = (plant.currentMoisture + 20).clamp(0, 100);
          plant.updateMoisture(newMoisture);

          // Update health status if moisture improved
          if (newMoisture >= 50 &&
              plant.healthStatus != HealthStatus.excellent) {
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
      debugPrint('Failed to water plant: $e');
    }
    return false;
  }

  /// Control device (light, fan, etc.)
  Future<bool> controlDevice(
      String plantId, String action, dynamic value) async {
    try {
      final success =
          await _hybridService.controlDevice(plantId, action, value);
      if (success) {
        // Update plant data based on action
        final plantIndex = _plants.indexWhere((p) => p.id == plantId);
        if (plantIndex != -1) {
          final plant = _plants[plantIndex];

          switch (action) {
            case 'light':
              plant.updateLight(
                  value is int ? value : (value as double).round());
              break;
            case 'temperature':
              plant.updateTemperature(
                  value is double ? value : (value as int).toDouble());
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
      debugPrint('Failed to control device: $e');
    }
    return false;
  }

  /// Get sensor history for charts
  Future<List<SensorReading>> getSensorHistory(String plantId, int days) async {
    return await _hybridService.getSensorHistory(plantId, days);
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

  /// Clear error state
  void clearError() {
    _error = null;
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
      groups[status] =
          _plants.where((plant) => plant.healthStatus == status).toList();
    }
    return groups;
  }

  /// Get plants that need attention (warning or critical)
  List<Plant> get plantsNeedingAttention => _plants
      .where((plant) =>
          plant.healthStatus == HealthStatus.warning ||
          plant.healthStatus == HealthStatus.critical)
      .toList();

  /// Check if any plants need water (moisture < 30%)
  bool get hasThirstyPlants =>
      _plants.any((plant) => plant.currentMoisture < 30);

  /// Get count of plants by location
  Map<String, int> get plantsByLocation {
    final locationCounts = <String, int>{};
    for (final plant in _plants) {
      locationCounts[plant.location] =
          (locationCounts[plant.location] ?? 0) + 1;
    }
    return locationCounts;
  }

  // ===========================================================================
  // Admin-only: Plant Catalog Management
  // ===========================================================================

  /// Add a new plant type to the catalog (admin only)
  Future<bool> addPlantTypeToCatalog(PlantType plantType) async {
    try {
      await _apiService.addPlantType(plantType);
      await loadPlantTypes(); // Refresh catalog
      return true;
    } on ForbiddenException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Nem sikerült hozzáadni a növényfajt';
      notifyListeners();
      return false;
    }
  }

  /// Update a plant species in the catalog (admin only)
  Future<bool> updatePlantSpecies(int speciesId, PlantType plantType) async {
    try {
      await _apiService.updatePlantSpecies(speciesId, plantType);
      await loadPlantTypes(); // Refresh catalog
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Nem sikerült frissíteni a növényfajt';
      notifyListeners();
      return false;
    }
  }

  /// Delete a plant species from the catalog (admin only)
  Future<bool> deletePlantSpecies(int speciesId) async {
    try {
      await _apiService.deletePlantSpecies(speciesId);
      await loadPlantTypes(); // Refresh catalog
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Nem sikerült törölni a növényfajt';
      notifyListeners();
      return false;
    }
  }
}
