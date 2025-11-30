/// App configuration constants
/// For production, these should come from environment variables or secure storage
class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  /// Trefle API token for plant images
  /// Get your free token at: https://trefle.io/
  /// Set to null or empty to disable Trefle integration
  static const String? trefleApiToken = String.fromEnvironment(
    'TREFLE_API_TOKEN',
    defaultValue: '',
  );

  /// Check if Trefle integration is enabled
  static bool get isTrefleEnabled =>
      trefleApiToken != null && trefleApiToken!.isNotEmpty;
}
