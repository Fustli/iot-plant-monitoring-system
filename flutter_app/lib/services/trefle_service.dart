import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for fetching plant images from Trefle API
/// https://trefle.io/
class TrefleService {
  // Singleton pattern
  static final TrefleService _instance = TrefleService._internal();
  factory TrefleService() => _instance;
  TrefleService._internal();

  // Trefle API configuration
  // Note: Get your free API token from https://trefle.io/
  static const String _baseUrl = 'https://trefle.io/api/v1';

  // API token - should be stored securely in production
  // For now, we'll use environment variable or fallback
  String? _apiToken;

  // Cache for plant images to avoid repeated API calls
  final Map<String, String?> _imageCache = {};

  /// Set the Trefle API token
  void setToken(String token) {
    _apiToken = token;
  }

  /// Search for a plant by name and get its image URL
  /// Returns null if no image found or API unavailable
  Future<String?> getPlantImage(String plantName) async {
    // Check cache first
    final cacheKey = plantName.toLowerCase().trim();
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }

    // If no token, return null (will use placeholder)
    if (_apiToken == null || _apiToken!.isEmpty) {
      debugPrint('Trefle: No API token configured');
      return null;
    }

    try {
      // Search for the plant
      final searchUrl = Uri.parse(
        '$_baseUrl/plants/search?token=$_apiToken&q=${Uri.encodeComponent(plantName)}',
      );

      final response = await http.get(searchUrl).timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('Timeout', 408),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final plants = data['data'] as List?;

        if (plants != null && plants.isNotEmpty) {
          // Get the first matching plant
          final plant = plants.first;
          final imageUrl = plant['image_url'] as String?;

          // Cache the result
          _imageCache[cacheKey] = imageUrl;
          return imageUrl;
        }
      } else if (response.statusCode == 401) {
        debugPrint('Trefle: Invalid API token');
      } else if (response.statusCode == 429) {
        debugPrint('Trefle: Rate limit exceeded');
      } else {
        debugPrint('Trefle: API error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Trefle: Error fetching plant image: $e');
    }

    // Cache null result to avoid repeated failed requests
    _imageCache[cacheKey] = null;
    return null;
  }

  /// Search for plants and get multiple results with images
  Future<List<TreflePlant>> searchPlants(String query, {int limit = 10}) async {
    if (_apiToken == null || _apiToken!.isEmpty) {
      return [];
    }

    try {
      final searchUrl = Uri.parse(
        '$_baseUrl/plants/search?token=$_apiToken&q=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final response = await http.get(searchUrl).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final plants = data['data'] as List?;

        if (plants != null) {
          return plants.map((p) => TreflePlant.fromJson(p)).toList();
        }
      }
    } catch (e) {
      debugPrint('Trefle: Error searching plants: $e');
    }

    return [];
  }

  /// Get detailed plant information by Trefle ID
  Future<TreflePlantDetails?> getPlantDetails(int trefleId) async {
    if (_apiToken == null || _apiToken!.isEmpty) {
      return null;
    }

    try {
      final url = Uri.parse('$_baseUrl/plants/$trefleId?token=$_apiToken');
      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TreflePlantDetails.fromJson(data['data']);
      }
    } catch (e) {
      debugPrint('Trefle: Error fetching plant details: $e');
    }

    return null;
  }

  /// Clear the image cache
  void clearCache() {
    _imageCache.clear();
  }

  /// Check if the service is configured with a valid token
  bool get isConfigured => _apiToken != null && _apiToken!.isNotEmpty;
}

/// Simple plant data from Trefle search results
class TreflePlant {
  final int id;
  final String commonName;
  final String scientificName;
  final String? imageUrl;
  final String? family;
  final String? genus;

  const TreflePlant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.imageUrl,
    this.family,
    this.genus,
  });

  factory TreflePlant.fromJson(Map<String, dynamic> json) {
    return TreflePlant(
      id: json['id'] as int,
      commonName: json['common_name'] as String? ??
          json['scientific_name'] as String? ??
          'Unknown',
      scientificName: json['scientific_name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      family: json['family'] as String?,
      genus: json['genus'] as String?,
    );
  }
}

/// Detailed plant data from Trefle
class TreflePlantDetails {
  final int id;
  final String commonName;
  final String scientificName;
  final String? imageUrl;
  final List<String> images;
  final String? family;
  final String? genus;
  final int? minimumTemperature;
  final int? maximumTemperature;
  final int? light;
  final int? atmosphericHumidity;
  final String? soilHumidity;
  final String? growthHabit;

  const TreflePlantDetails({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.imageUrl,
    this.images = const [],
    this.family,
    this.genus,
    this.minimumTemperature,
    this.maximumTemperature,
    this.light,
    this.atmosphericHumidity,
    this.soilHumidity,
    this.growthHabit,
  });

  factory TreflePlantDetails.fromJson(Map<String, dynamic> json) {
    // Extract all image URLs
    final imagesList = <String>[];
    if (json['image_url'] != null) {
      imagesList.add(json['image_url'] as String);
    }
    if (json['images'] != null) {
      final imagesData = json['images'] as Map<String, dynamic>?;
      imagesData?.forEach((key, value) {
        if (value is List) {
          for (final img in value) {
            if (img is Map && img['image_url'] != null) {
              imagesList.add(img['image_url'] as String);
            }
          }
        }
      });
    }

    // Extract growth requirements
    final growth = json['growth'] as Map<String, dynamic>?;

    return TreflePlantDetails(
      id: json['id'] as int,
      commonName: json['common_name'] as String? ??
          json['scientific_name'] as String? ??
          'Unknown',
      scientificName: json['scientific_name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      images: imagesList,
      family: json['family'] as String?,
      genus: json['genus'] as String?,
      minimumTemperature: growth?['minimum_temperature']?['deg_c'] as int?,
      maximumTemperature: growth?['maximum_temperature']?['deg_c'] as int?,
      light: growth?['light'] as int?,
      atmosphericHumidity: growth?['atmospheric_humidity'] as int?,
      soilHumidity: growth?['soil_humidity'] as String?,
      growthHabit: json['specifications']?['growth_habit'] as String?,
    );
  }
}
