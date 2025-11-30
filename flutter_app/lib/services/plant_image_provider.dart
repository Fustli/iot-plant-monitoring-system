import 'package:flutter/foundation.dart';
import 'trefle_service.dart';

/// Provider for managing plant images from Trefle API
/// Handles fetching, caching, and providing plant images
class PlantImageProvider with ChangeNotifier {
  final TrefleService _trefleService = TrefleService();

  // Image cache: plantName -> imageUrl
  final Map<String, String?> _imageCache = {};

  // Loading state tracking
  final Set<String> _loadingPlants = {};

  /// Initialize the provider with Trefle API token
  void initialize(String? trefleToken) {
    if (trefleToken != null && trefleToken.isNotEmpty) {
      _trefleService.setToken(trefleToken);
      debugPrint('PlantImageProvider: Trefle service initialized');
    } else {
      debugPrint('PlantImageProvider: No Trefle token provided');
    }
  }

  /// Check if Trefle service is configured
  bool get isConfigured => _trefleService.isConfigured;

  /// Get image URL for a plant by name
  /// Returns cached image if available, otherwise fetches from Trefle
  String? getImageUrl(String plantName) {
    final key = plantName.toLowerCase().trim();
    return _imageCache[key];
  }

  /// Check if an image is currently being loaded
  bool isLoading(String plantName) {
    return _loadingPlants.contains(plantName.toLowerCase().trim());
  }

  /// Fetch image for a plant (async, notifies listeners when done)
  Future<String?> fetchImageUrl(String plantName) async {
    final key = plantName.toLowerCase().trim();

    // Return cached image if available
    if (_imageCache.containsKey(key)) {
      return _imageCache[key];
    }

    // Don't fetch if already loading
    if (_loadingPlants.contains(key)) {
      return null;
    }

    // Mark as loading
    _loadingPlants.add(key);
    notifyListeners();

    try {
      final imageUrl = await _trefleService.getPlantImage(plantName);
      _imageCache[key] = imageUrl;
      return imageUrl;
    } finally {
      _loadingPlants.remove(key);
      notifyListeners();
    }
  }

  /// Prefetch images for multiple plants
  Future<void> prefetchImages(List<String> plantNames) async {
    final futures = <Future<void>>[];

    for (final name in plantNames) {
      final key = name.toLowerCase().trim();
      if (!_imageCache.containsKey(key) && !_loadingPlants.contains(key)) {
        futures.add(fetchImageUrl(name).then((_) {}));
      }
    }

    // Fetch in parallel but limit concurrency
    await Future.wait(futures.take(5));
  }

  /// Search for plants with images
  Future<List<TreflePlant>> searchPlants(String query) async {
    return _trefleService.searchPlants(query);
  }

  /// Get detailed plant info including multiple images
  Future<TreflePlantDetails?> getPlantDetails(int trefleId) async {
    return _trefleService.getPlantDetails(trefleId);
  }

  /// Clear the image cache
  void clearCache() {
    _imageCache.clear();
    _trefleService.clearCache();
    notifyListeners();
  }

  /// Get the number of cached images
  int get cachedImageCount => _imageCache.length;
}
