import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;

import '../models/auth_models.dart';
import '../models/plant_model.dart';
import '../models/plant_type_model.dart';
import '../models/device_model.dart';
import '../models/alert_model.dart';
import '../models/user_model.dart';
import '../models/hub_model.dart';
import 'api_exceptions.dart';

/// Comprehensive API service for the IoT Plant Monitoring System
/// Handles all backend communication with proper authentication and error handling
class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Base URL configuration
  // - Production (Docker/Azure): Use relative URL, Nginx proxies to backend
  // - Development: Use localhost:8000
  static String get _baseUrl {
    if (kIsWeb) {
      // In release mode (Docker), use relative URL - Nginx will proxy
      if (kReleaseMode) {
        return '/api';
      }
      // Development mode - direct to backend
      return 'http://localhost:8000/api';
    }
    // For mobile, would need platform-specific check
    return 'http://localhost:8000/api';
  }

  // Request timeout duration
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _shortTimeout = Duration(seconds: 5);

  // Cached token for API calls
  String? _accessToken;
  UserRole? _currentRole;

  /// Set the access token for authenticated requests
  void setToken(String? token) {
    _accessToken = token;
  }

  /// Set the current user role
  void setRole(UserRole? role) {
    _currentRole = role;
  }

  /// Get current role
  UserRole? get currentRole => _currentRole;

  /// Clear authentication state
  void clearAuth() {
    _accessToken = null;
    _currentRole = null;
  }

  /// Build headers with optional authentication
  Map<String, String> _buildHeaders({bool requireAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  /// Handle HTTP response and convert errors to exceptions
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    }

    // Parse error response
    String? errorDetail;
    try {
      final errorBody = json.decode(response.body);
      errorDetail = errorBody['detail'] as String?;
    } catch (_) {
      errorDetail = response.body;
    }

    switch (statusCode) {
      case 401:
        throw UnauthorizedException(message: errorDetail ?? 'Unauthorized');
      case 403:
        throw ForbiddenException(message: errorDetail ?? 'Forbidden');
      case 404:
        throw NotFoundException(message: errorDetail ?? 'Not found');
      case 422:
        throw ValidationException(
            message: errorDetail ?? 'Validation error', details: errorDetail);
      case 500:
      case 502:
      case 503:
        throw ServerException(
            message: errorDetail ?? 'Server error', statusCode: statusCode);
      default:
        throw ApiException(
          message: errorDetail ?? 'Request failed',
          statusCode: statusCode,
        );
    }
  }

  /// Execute a GET request with error handling
  Future<dynamic> _get(String endpoint,
      {bool requireAuth = true, Duration? timeout}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _buildHeaders(requireAuth: requireAuth),
          )
          .timeout(timeout ?? _timeout);

      return _handleResponse(response);
    } on TimeoutException catch (e) {
      throw TimeoutException(originalError: e);
    } on http.ClientException catch (e) {
      throw ServerUnreachableException(originalError: e);
    } catch (e) {
      throw NetworkException(originalError: e);
    }
  }

  /// Execute a POST request with error handling
  Future<dynamic> _post(String endpoint,
      {Map<String, dynamic>? body, bool requireAuth = true}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _buildHeaders(requireAuth: requireAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on TimeoutException catch (e) {
      throw TimeoutException(originalError: e);
    } on http.ClientException catch (e) {
      throw ServerUnreachableException(originalError: e);
    } catch (e) {
      throw NetworkException(originalError: e);
    }
  }

  /// Execute a PUT request with error handling
  Future<dynamic> _put(String endpoint,
      {Map<String, dynamic>? body, bool requireAuth = true}) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _buildHeaders(requireAuth: requireAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on TimeoutException catch (e) {
      throw TimeoutException(originalError: e);
    } on http.ClientException catch (e) {
      throw ServerUnreachableException(originalError: e);
    } catch (e) {
      throw NetworkException(originalError: e);
    }
  }

  /// Execute a DELETE request with error handling
  Future<dynamic> _delete(String endpoint, {bool requireAuth = true}) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _buildHeaders(requireAuth: requireAuth),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on TimeoutException catch (e) {
      throw TimeoutException(originalError: e);
    } on http.ClientException catch (e) {
      throw ServerUnreachableException(originalError: e);
    } catch (e) {
      throw NetworkException(originalError: e);
    }
  }

  /// Execute a PATCH request with error handling
  Future<dynamic> _patch(String endpoint,
      {Map<String, dynamic>? body, bool requireAuth = true}) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl$endpoint'),
            headers: _buildHeaders(requireAuth: requireAuth),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on TimeoutException catch (e) {
      throw TimeoutException(originalError: e);
    } on http.ClientException catch (e) {
      throw ServerUnreachableException(originalError: e);
    } catch (e) {
      throw NetworkException(originalError: e);
    }
  }

  // ===========================================================================
  // 1. AUTHENTICATION
  // ===========================================================================

  /// Login with email and password
  /// Returns TokenResponse on success
  Future<TokenResponse> login(LoginRequest request) async {
    final response = await _post(
      '/auth/login',
      body: request.toJson(),
      requireAuth: false,
    );

    final tokenResponse = TokenResponse.fromJson(response);

    // Store token for subsequent requests
    setToken(tokenResponse.accessToken);
    setRole(tokenResponse.role);

    return tokenResponse;
  }

  /// Register a new consumer user (public endpoint - no auth required)
  Future<void> registerConsumer({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    await _post('/auth/register/consumer',
        body: {
          'username': username,
          'email': email,
          'password': password,
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
        },
        requireAuth: false);
  }

  /// Register a new user (admin only - for creating manufacturers/admins)
  Future<void> registerUser({
    required String username,
    required String email,
    required String password,
    required String role,
    String? firstName,
    String? lastName,
    String? companyName,
  }) async {
    await _post('/auth/register', body: {
      'username': username,
      'email': email,
      'password_hash':
          password, // Backend expects password_hash, it will hash it
      'role': role,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (companyName != null) 'company_name': companyName,
    });
  }

  /// Get current user profile
  Future<User> getUserProfile() async {
    final response = await _get('/user/profile');
    return User.fromJson(response);
  }

  /// Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    await _put('/user/profile', body: updates);
  }

  /// Change password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _post('/user/change-password', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  /// Initiate password reset flow (forgot password)
  Future<void> forgotPassword(String email) async {
    await _post('/auth/forgot-password',
        body: {
          'email': email,
        },
        requireAuth: false);
  }

  /// Reset password with token
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _post('/auth/reset-password',
        body: {
          'token': token,
          'new_password': newPassword,
        },
        requireAuth: false);
  }

  // ===========================================================================
  // 2. ADMIN - SYSTEM MANAGEMENT
  // ===========================================================================

  /// Get system status (admin only)
  Future<Map<String, dynamic>> getSystemStatus() async {
    final response = await _get('/admin/system/status');
    return response as Map<String, dynamic>;
  }

  /// List all users (admin only)
  Future<List<User>> listAllUsers() async {
    final response = await _get('/admin/users');
    return (response as List).map((json) => User.fromJson(json)).toList();
  }

  /// Delete a user (admin only)
  Future<void> deleteUser(int userId) async {
    await _delete('/admin/users/$userId');
  }

  /// Update user status (admin only) - for approving manufacturers, etc.
  Future<User> updateUser(
    int userId, {
    String? role,
    bool? isActive,
    bool? isVerified,
  }) async {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    if (isVerified != null) body['is_verified'] = isVerified;

    final response = await _patch('/admin/users/$userId', body: body);
    return User.fromJson(response);
  }

  /// Delete a manufacturer (admin only)
  Future<void> deleteManufacturer(int manufacturerId) async {
    await _delete('/admin/manufacturers/$manufacturerId');
  }

  /// List all devices in system (admin only)
  Future<List<Device>> listAllDevicesAdmin() async {
    final response = await _get('/admin/devices');
    return (response as List).map((json) => Device.fromJson(json)).toList();
  }

  /// List all device types in system (admin only)
  Future<List<Map<String, dynamic>>> listAllDeviceTypesAdmin() async {
    final response = await _get('/admin/device_types');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// List all plants in system (admin only)
  Future<List<Plant>> listAllPlantsAdmin() async {
    final response = await _get('/admin/plants');
    return (response as List).map((json) => Plant.fromJson(json)).toList();
  }

  // ===========================================================================
  // 3. MANUFACTURER - DEVICE TYPES
  // ===========================================================================

  /// Register a new device type (manufacturer/admin)
  Future<void> registerDeviceType(Map<String, dynamic> deviceTypeData) async {
    await _post('/manufacturer/device-types', body: deviceTypeData);
  }

  /// List device types (manufacturer/admin)
  Future<List<Map<String, dynamic>>> listDeviceTypes() async {
    final response = await _get('/manufacturer/device-types');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Update device type documentation (manufacturer/admin)
  Future<void> updateDeviceType(
      int deviceTypeId, Map<String, dynamic> updates) async {
    await _put('/manufacturer/device-types/$deviceTypeId', body: updates);
  }

  /// Delete device type (manufacturer/admin)
  Future<void> deleteDeviceType(int deviceTypeId) async {
    await _delete('/manufacturer/device-types/$deviceTypeId');
  }

  // NOTE: registerDeviceInstance is deferred - requires backend schema changes
  // for manufacturer device pre-registration table.
  // See docs/MISSING_API_REPORT.md for details.

  // ===========================================================================
  // 4. PLANT DATABASE (SPECIES CATALOG) - Admin Only
  // ===========================================================================

  /// Add new plant type to catalog (admin only)
  Future<void> addPlantType(PlantType plantType) async {
    await _post('/plant-type', body: plantType.toJson());
  }

  /// Update plant species in catalog (admin only)
  Future<void> updatePlantSpecies(int speciesId, PlantType plantType) async {
    await _put('/plant-types/$speciesId', body: plantType.toJson());
  }

  /// Delete plant species from catalog (admin only)
  Future<void> deletePlantSpecies(int speciesId) async {
    await _delete('/plant-type/$speciesId');
  }

  // ===========================================================================
  // 5. CONSUMER - PLANTS
  // ===========================================================================

  /// List available plant types from catalog
  Future<List<PlantType>> listPlantTypes() async {
    final response = await _get('/consumer/plant-types');
    return (response as List).map((json) => PlantType.fromJson(json)).toList();
  }

  /// Search plant types by name or scientific name
  Future<dynamic> searchPlantTypes(
      {String? name, String? scientificName}) async {
    final queryParams = <String, String>{};
    if (name != null && name.isNotEmpty) queryParams['name'] = name;
    if (scientificName != null && scientificName.isNotEmpty) {
      queryParams['scientific_name'] = scientificName;
    }

    final queryString = queryParams.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final endpoint = queryString.isEmpty
        ? '/consumer/plant-types/search'
        : '/consumer/plant-types/search?$queryString';

    return await _get(endpoint);
  }

  /// Get all plants for current user
  Future<List<Plant>> getMyPlants() async {
    final response = await _get('/consumer/my-plants');
    return (response as List).map((json) => Plant.fromJson(json)).toList();
  }

  /// Create plant from existing database type
  Future<void> createPlantFromDatabase(PlantFromDatabaseRequest request) async {
    await _post('/consumer/plant-from-database', body: request.toJson());
  }

  /// Create custom plant with full requirements
  Future<void> createPlantFromScratch(PlantFromScratchRequest request) async {
    await _post('/consumer/plant-from-scratch', body: request.toJson());
  }

  /// Get plant details
  Future<Plant> getPlantDetails(int plantId) async {
    final response = await _get('/consumer/my-plants/$plantId');
    return Plant.fromJson(response);
  }

  /// Activate/deactivate plant care
  Future<void> setPlantActivation(
      {int? plantId, required bool activate}) async {
    await _post('/consumer/my-plants/activation', body: {
      if (plantId != null) 'plant_id': plantId,
      'command': activate,
    });
  }

  /// Update plant details
  Future<void> updatePlant(
      int plantId, PlantFromDatabaseRequest request) async {
    await _put('/consumer/my-plants/$plantId', body: request.toJson());
  }

  /// Update plant health status (current sensor readings)
  /// healthStatus: [light_level, humidity, temperature, soil_moisture]
  Future<void> updatePlantHealthStatus(
      int plantId, List<int> healthStatus) async {
    await _patch('/consumer/my-plants/$plantId/health', body: {
      'health_status': healthStatus,
    });
  }

  /// Delete a plant
  Future<void> deletePlant(int plantId) async {
    await _delete('/consumer/my-plants/$plantId');
  }

  // ===========================================================================
  // 6. CONSUMER - DEVICES
  // ===========================================================================

  /// Register/claim a device by unique ID
  Future<void> registerDevice(Map<String, dynamic> deviceData) async {
    await _post('/consumer/devices/register', body: deviceData);
  }

  /// List available device types (for consumers to see compatible devices)
  Future<List<Map<String, dynamic>>> listAvailableDeviceTypes() async {
    final response = await _get('/consumer/device-types');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// List user's devices
  Future<List<Device>> getMyDevices() async {
    final response = await _get('/consumer/my-devices');
    return (response as List).map((json) => Device.fromJson(json)).toList();
  }

  /// Activate/deactivate device
  Future<void> setDeviceActivation(
      {int? deviceId, required bool activate}) async {
    await _post('/consumer/my-devices/activation', body: {
      if (deviceId != null) 'device_id': deviceId,
      'command': activate,
    });
  }

  /// Update device details (name, location)
  Future<void> updateDevice(int deviceId, Map<String, dynamic> updates) async {
    await _put('/consumer/my-devices/$deviceId', body: updates);
  }

  /// Remove a device from user account
  Future<void> removeDevice(int deviceId) async {
    await _delete('/consumer/my-devices/$deviceId');
  }

  // ===========================================================================
  // 7. CONSUMER - HUBS
  // ===========================================================================

  /// Get all hubs for current user
  Future<List<Hub>> getMyHubs() async {
    final response = await _get('/consumer/hubs');
    return (response as List).map((json) => Hub.fromJson(json)).toList();
  }

  /// Register/claim a hub by serial number
  /// The hub must be pre-provisioned by admin and activated by the physical device
  Future<Map<String, dynamic>> registerHub({required String serial}) async {
    final response = await _post('/consumer/hubs/register', body: {
      'serial': serial,
    });
    return response as Map<String, dynamic>;
  }

  // ===========================================================================
  // 8. ADMIN - HUBS
  // ===========================================================================

  /// List ALL hubs (admin only) - pre-provisioned, active, claimed, etc.
  Future<List<Hub>> adminListAllHubs() async {
    final response = await _get('/admin/hubs');
    return (response as List).map((json) => Hub.fromJson(json)).toList();
  }

  /// Pre-provision a hub (admin only)
  Future<Map<String, dynamic>> adminCreateHub({
    required String serial,
    String? name,
  }) async {
    final response = await _post('/admin/hubs', body: {
      'serial': serial,
      if (name != null) 'name': name,
    });
    return response as Map<String, dynamic>;
  }

  /// Delete a hub by ID (admin only)
  Future<void> adminDeleteHub(int hubId) async {
    await _delete('/admin/hubs/$hubId');
  }

  /// Delete a hub by serial (admin only)
  Future<void> adminDeleteHubBySerial(String serial) async {
    await _delete('/admin/hubs/serial/$serial');
  }

  // ===========================================================================
  // 9. HUB COMMANDS
  // ===========================================================================

  /// Send command to hub via Azure IoT Hub direct method
  Future<Map<String, dynamic>> sendHubCommand({
    int? hubId,
    String? hubSerial,
    required String topic,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _post('/hub/commands', body: {
      if (hubId != null) 'hub_id': hubId,
      if (hubSerial != null) 'hub_serial': hubSerial,
      'topic': topic,
      'payload': payload,
    });
    return response as Map<String, dynamic>;
  }

  // ===========================================================================
  // 10. MONITORING & CONTROL
  // ===========================================================================

  /// Get device sensor history for charts
  Future<List<Map<String, dynamic>>> getDeviceHistory(int deviceId) async {
    final response = await _get('/consumer/devices/$deviceId/history');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Send command to actuator (water, light, etc.)
  Future<void> sendDeviceCommand(int deviceId,
      {required String metric, required double delta}) async {
    print('[API_DEBUG] Sending device command: deviceId=$deviceId, metric=$metric, delta=$delta');
    print('[API_DEBUG] URL: $_baseUrl/consumer/devices/$deviceId/command');
    print('[API_DEBUG] Token exists: ${_accessToken != null}');
    
    final result = await _post('/consumer/devices/$deviceId/command', body: {
      'metric': metric,
      'delta': delta,
    });
    
    print('[API_DEBUG] Device command response: $result');
  }

  /// Get user alerts
  Future<List<Alert>> getAlerts(int userId) async {
    final response = await _get('/consumer/alerts/$userId');
    return (response as List).map((json) => Alert.fromJson(json)).toList();
  }

  /// Acknowledge an alert
  Future<void> acknowledgeAlert(int alertId) async {
    await _put('/consumer/alerts/$alertId/acknowledge');
  }

  /// Resolve an alert
  Future<void> resolveAlert(int alertId) async {
    await _put('/consumer/alerts/$alertId/resolve');
  }

  // ===========================================================================
  // HEALTH CHECK
  // ===========================================================================

  /// Quick connectivity check with short timeout
  Future<bool> checkConnectivity() async {
    try {
      await _get('/consumer/plant-types', timeout: _shortTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
