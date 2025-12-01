import 'package:flutter/foundation.dart';

import '../models/plant_model.dart';
import '../models/plant_type_model.dart';
import 'api_client.dart';
import 'api_exceptions.dart';

/// Plant state management provider
/// Handles plant data and API calls
class PlantProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Plant> _plants = [];
  List<PlantType> _plantTypes = [];
  bool _isLoading = false;
  String? _error;
  Plant? _selectedPlant;

  // Getters
  List<Plant> get plants => _plants;
  List<PlantType> get plantTypes => _plantTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Plant? get selectedPlant => _selectedPlant;

  // Statistics
  int get totalPlants => _plants.length;
  int get healthyPlants => _plants.where((plant) => plant.isHealthy).length;
  int get plantsNeedingCare =>
      _plants.where((plant) => !plant.isHealthy).length;

  /// Load all plants from the API
  Future<void> loadPlants() async {
    _setLoading(true);
    _error = null;

    try {
      _plants = await _apiService.getMyPlants();
    } on ServerUnreachableException catch (e) {
      _error = e.messageHu;
      debugPrint('Server unreachable: ${e.message}');
    } on UnauthorizedException catch (e) {
      _error = e.messageHu;
      _plants = [];
    } on ApiException catch (e) {
      _error = e.messageHu;
      debugPrint('API error loading plants: ${e.message}');
    } catch (e) {
      _error = 'Ismeretlen hiba tortent';
      debugPrint('Unexpected error loading plants: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load available plant types from catalog
  Future<void> loadPlantTypes() async {
    _setLoading(true);
    _error = null;

    try {
      _plantTypes = await _apiService.listPlantTypes();
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.messageHu;
      debugPrint('Failed to load plant types: ${e.message}');
      _plantTypes = [];
    } catch (e) {
      _error = 'Ismeretlen hiba tortent';
      debugPrint('Unexpected error loading plant types: $e');
      _plantTypes = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Search plant types by name
  Future<List<PlantType>> searchPlantTypes(String query) async {
    try {
      final results = await _apiService.searchPlantTypes(name: query);
      if (results is List) {
        return results.map((json) => PlantType.fromJson(json)).toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('Failed to search plant types: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Unexpected error searching plant types: $e');
      return [];
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
      final plant = await _apiService.getPlantDetails(int.parse(plantId));
      _selectedPlant = plant;
      // Update plant in the list as well
      final index = _plants.indexWhere((p) => p.id == plantId);
      if (index != -1) {
        _plants[index] = plant;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load plant details: $e');
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
      _error = 'Ismeretlen hiba tortent';
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
      _error = 'Ismeretlen hiba tortent';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing plant's details
  Future<bool> updatePlant(
      int plantId, PlantFromDatabaseRequest request) async {
    try {
      await _apiService.updatePlant(plantId, request);
      await loadPlants(); // Refresh plant list
      // Also refresh the selected plant if it's the one being edited
      if (_selectedPlant?.id == plantId.toString()) {
        await loadPlantDetails(plantId.toString());
      }
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Nem sikerult frissiteni a novenyt';
      notifyListeners();
      return false;
    }
  }

  /// Delete a plant
  Future<bool> deletePlant(int plantId) async {
    try {
      await _apiService.deletePlant(plantId);

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
      _error = 'Nem sikerult torolni a novenyt';
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
  Future<bool> waterPlant(String plantId, int deviceId) async {
    try {
      await _apiService.sendDeviceCommand(
        deviceId,
        metric: 'moisture',
        delta: 1.0,
      );

      // Optimistically update moisture
      final plantIndex = _plants.indexWhere((p) => p.id == plantId);
      if (plantIndex != -1) {
        final plant = _plants[plantIndex];
        final newMoisture = (plant.currentMoisture + 20).clamp(0, 100);
        plant.updateMoisture(newMoisture);

        if (_selectedPlant?.id == plantId) {
          _selectedPlant = plant;
        }
        notifyListeners();
      }

      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Failed to water plant: $e');
      return false;
    }
  }

  /// Control device (light, fan, etc.)
  Future<bool> controlDevice(
      String plantId, int deviceId, String metric, double value) async {
    try {
      await _apiService.sendDeviceCommand(
        deviceId,
        metric: metric,
        delta: value,
      );

      // Update plant data based on action
      final plantIndex = _plants.indexWhere((p) => p.id == plantId);
      if (plantIndex != -1) {
        final plant = _plants[plantIndex];

        switch (metric) {
          case 'brightness':
            plant.updateLight(value.round());
            break;
          case 'temperature':
            plant.updateTemperature(value);
            break;
          case 'humidity':
            plant.updateHumidity(value.round());
            break;
        }

        if (_selectedPlant?.id == plantId) {
          _selectedPlant = plant;
        }

        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Failed to control device: $e');
      return false;
    }
  }

  /// Get sensor history for charts
  Future<List<Map<String, dynamic>>> getSensorHistory(int deviceId) async {
    try {
      return await _apiService.getDeviceHistory(deviceId);
    } on ApiException catch (e) {
      debugPrint('Failed to get sensor history: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Unexpected error getting sensor history: $e');
      return [];
    }
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

  /// Get plants grouped by health status (using calculated status)
  Map<HealthStatus, List<Plant>> get plantsGroupedByHealth {
    final groups = <HealthStatus, List<Plant>>{};
    for (final status in HealthStatus.values) {
      groups[status] = _plants
          .where((plant) => plant.calculatedHealthStatus == status)
          .toList();
    }
    return groups;
  }

  /// Get plants that need attention (needsAttention or critical)
  List<Plant> get plantsNeedingAttention => _plants
      .where((plant) =>
          plant.calculatedHealthStatus == HealthStatus.needsAttention ||
          plant.calculatedHealthStatus == HealthStatus.critical)
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
      _error = 'Nem sikerult hozzaadni a novenyfajt';
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
      _error = 'Nem sikerult frissiteni a novenyfajt';
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
      _error = 'Nem sikerult torolni a novenyfajt';
      notifyListeners();
      return false;
    }
  }
}
