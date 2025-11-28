import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/plant_model.dart';

/// A service class for handling all API interactions with the backend.
class ApiService {
  // Base URL - use localhost for web, would need platform check for mobile
  static const String _baseUrl = 'http://localhost:8000/api';

  /// Fetches all plants associated with a given user ID.
  ///
  /// This corresponds to the backend endpoint that returns a list of plants,
  /// including their nested device and sensor information.
  Future<List<Plant>> fetchUserPlants(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/plants'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Plant.fromJson(json)).toList();
      } else {
        // Handle non-200 responses
        print('Failed to load plants with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load plants from API');
      }
    } on SocketException catch (e) {
      print('Network error fetching plants: $e');
      throw Exception(
          'Could not connect to the server. Please check your network connection.');
    } on http.ClientException catch (e) {
      print('Client error fetching plants: $e');
      throw Exception(
          'Could not connect to the server. Is the backend running?');
    } catch (e) {
      print('An unexpected error occurred while fetching plants: $e');
      throw Exception('An unexpected error occurred.');
    }
  }

  // Future methods for fetchPlantSensors, etc., can be added here.
}
