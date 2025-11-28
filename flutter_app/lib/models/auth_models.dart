/// Authentication-related models for the IoT Plant Monitoring System
/// These models match the backend Pydantic schemas in schemas.py

/// User roles matching backend Role type
enum UserRole {
  admin,
  consumer,
  manufacturer;

  /// Parse role from string (handles backend response)
  static UserRole fromString(String? role) {
    if (role == null) return UserRole.consumer;
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manufacturer':
        return UserRole.manufacturer;
      case 'consumer':
      default:
        return UserRole.consumer;
    }
  }

  /// Get display name in Hungarian
  String get displayNameHu {
    switch (this) {
      case UserRole.admin:
        return 'Rendszergazda';
      case UserRole.consumer:
        return 'Felhasználó';
      case UserRole.manufacturer:
        return 'Eszköz gyártó';
    }
  }

  /// Get display name in English (for debugging)
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Super Admin';
      case UserRole.consumer:
        return 'User';
      case UserRole.manufacturer:
        return 'Device Manufacturer';
    }
  }

  /// Check if role has admin privileges
  bool get isAdmin => this == UserRole.admin;

  /// Check if role can manage plants (consumer or admin)
  bool get canManagePlants =>
      this == UserRole.consumer || this == UserRole.admin;

  /// Check if role can manage devices (manufacturer or admin)
  bool get canManageDeviceTypes =>
      this == UserRole.manufacturer || this == UserRole.admin;

  /// Check if role can manage plant species catalog (admin only)
  bool get canManagePlantCatalog => this == UserRole.admin;

  /// Check if role can manage users (admin only)
  bool get canManageUsers => this == UserRole.admin;
}

/// Login request payload matching backend LoginRequest
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// Token response matching backend TokenResponse
class TokenResponse {
  final String accessToken;
  final String tokenType;
  final UserRole role;
  final String username;

  const TokenResponse({
    required this.accessToken,
    this.tokenType = 'bearer',
    required this.role,
    required this.username,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      role: UserRole.fromString(json['role'] as String?),
      username: json['username'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'role': role.name,
        'username': username,
      };
}

/// Authentication state for the app
enum AuthStatus {
  /// Initial state, checking stored credentials
  initial,

  /// Currently authenticating
  authenticating,

  /// Successfully authenticated
  authenticated,

  /// Not authenticated (no token or expired)
  unauthenticated,

  /// Authentication failed with error
  error,
}

/// Holds the current authentication state
class AuthState {
  final AuthStatus status;
  final TokenResponse? tokenResponse;
  final String? errorMessage;
  final DateTime? tokenExpiry;

  const AuthState({
    required this.status,
    this.tokenResponse,
    this.errorMessage,
    this.tokenExpiry,
  });

  /// Initial unauthenticated state
  const AuthState.initial()
      : status = AuthStatus.initial,
        tokenResponse = null,
        errorMessage = null,
        tokenExpiry = null;

  /// Authenticating state
  const AuthState.authenticating()
      : status = AuthStatus.authenticating,
        tokenResponse = null,
        errorMessage = null,
        tokenExpiry = null;

  /// Authenticated state with token
  AuthState.authenticated(TokenResponse token, {DateTime? expiry})
      : status = AuthStatus.authenticated,
        tokenResponse = token,
        errorMessage = null,
        tokenExpiry = expiry;

  /// Unauthenticated state (logged out)
  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        tokenResponse = null,
        errorMessage = null,
        tokenExpiry = null;

  /// Error state with message
  AuthState.error(String message)
      : status = AuthStatus.error,
        tokenResponse = null,
        errorMessage = message,
        tokenExpiry = null;

  /// Quick access to token
  String? get accessToken => tokenResponse?.accessToken;

  /// Quick access to role
  UserRole? get role => tokenResponse?.role;

  /// Quick access to username
  String? get username => tokenResponse?.username;

  /// Check if authenticated
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && tokenResponse != null;

  /// Check if token is expired
  bool get isTokenExpired {
    if (tokenExpiry == null) return false;
    return DateTime.now().isAfter(tokenExpiry!);
  }

  /// Authorization header for API calls
  String? get authorizationHeader {
    if (tokenResponse == null) return null;
    return '${tokenResponse!.tokenType} ${tokenResponse!.accessToken}';
  }
}
