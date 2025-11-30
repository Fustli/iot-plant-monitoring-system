import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'api_client.dart';
import 'api_exceptions.dart';

/// Authentication provider managing login state, token persistence, and role-based access
/// Uses Provider pattern with ChangeNotifier for state management
class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _usernameKey = 'username';
  static const String _tokenExpiryKey = 'token_expiry';

  // Current authentication state
  AuthState _authState = const AuthState.initial();
  bool _isInitialized = false;

  // Getters
  AuthState get authState => _authState;
  bool get isAuthenticated => _authState.isAuthenticated;
  bool get isInitialized => _isInitialized;
  UserRole? get currentRole => _authState.role;
  String? get username => _authState.username;
  String? get accessToken => _authState.accessToken;

  /// Expose API service for direct API calls
  ApiService get apiClient => _apiService;

  // Role-based access helpers
  bool get isAdmin => currentRole?.isAdmin ?? false;
  bool get isConsumer => currentRole == UserRole.consumer;
  bool get isManufacturer => currentRole == UserRole.manufacturer;
  bool get canManagePlants => currentRole?.canManagePlants ?? false;
  bool get canManageDeviceTypes => currentRole?.canManageDeviceTypes ?? false;
  bool get canManagePlantCatalog => currentRole?.canManagePlantCatalog ?? false;
  bool get canManageUsers => currentRole?.canManageUsers ?? false;

  /// Initialize authentication from stored credentials
  /// Call this on app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString(_tokenKey);
      final roleStr = prefs.getString(_roleKey);
      final username = prefs.getString(_usernameKey);
      final expiryStr = prefs.getString(_tokenExpiryKey);

      if (token != null && roleStr != null && username != null) {
        // Check if token is expired
        DateTime? expiry;
        if (expiryStr != null) {
          expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            // Token expired, clear storage
            await _clearStorage();
            _authState = const AuthState.unauthenticated();
            _isInitialized = true;
            notifyListeners();
            return;
          }
        }

        // Restore authentication state
        final tokenResponse = TokenResponse(
          accessToken: token,
          role: UserRole.fromString(roleStr),
          username: username,
        );

        _authState = AuthState.authenticated(tokenResponse, expiry: expiry);
        _apiService.setToken(token);
        _apiService.setRole(tokenResponse.role);
      } else {
        _authState = const AuthState.unauthenticated();
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      _authState = const AuthState.unauthenticated();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    _authState = const AuthState.authenticating();
    notifyListeners();

    try {
      final request = LoginRequest(email: email, password: password);
      final tokenResponse = await _apiService.login(request);

      // Calculate token expiry (assuming 24h validity - adjust based on backend)
      final expiry = DateTime.now().add(const Duration(hours: 24));

      // Store credentials
      await _storeCredentials(tokenResponse, expiry);

      // Set token in API service for authenticated requests
      _apiService.setToken(tokenResponse.accessToken);
      _apiService.setRole(tokenResponse.role);

      _authState = AuthState.authenticated(tokenResponse, expiry: expiry);
      notifyListeners();
      return true;
    } on UnauthorizedException catch (e) {
      _authState = AuthState.error(e.messageHu);
      notifyListeners();
      return false;
    } on ServerUnreachableException catch (e) {
      _authState = AuthState.error(e.messageHu);
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      _authState = AuthState.error(e.messageHu);
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _authState = AuthState.error(e.messageHu);
      notifyListeners();
      return false;
    } catch (e) {
      _authState = AuthState.error('Ismeretlen hiba történt: $e');
      notifyListeners();
      return false;
    }
  }

  /// Logout and clear all stored credentials
  Future<void> logout() async {
    await _clearStorage();
    _apiService.clearAuth();
    _authState = const AuthState.unauthenticated();
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    if (_authState.status == AuthStatus.error) {
      _authState = const AuthState.unauthenticated();
      notifyListeners();
    }
  }

  /// Store credentials to persistent storage
  Future<void> _storeCredentials(
      TokenResponse tokenResponse, DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, tokenResponse.accessToken);
    await prefs.setString(_roleKey, tokenResponse.role.name);
    await prefs.setString(_usernameKey, tokenResponse.username);
    await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
  }

  /// Clear stored credentials
  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenExpiryKey);
  }

  /// Check if token needs refresh (call periodically)
  Future<void> checkTokenValidity() async {
    if (!isAuthenticated) return;

    if (_authState.isTokenExpired) {
      // Token expired, logout
      await logout();
    }
  }

  /// Handle unauthorized response (401) from any API call
  void handleUnauthorized() {
    logout();
  }

  /// Get authorization header for API calls
  String? get authorizationHeader => _authState.authorizationHeader;
}
