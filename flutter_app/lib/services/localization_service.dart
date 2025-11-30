import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages
enum AppLanguage {
  en('en', 'English', 'EN'),
  hu('hu', 'Magyar', 'HU');

  final String code;
  final String displayName;
  final String shortName;

  const AppLanguage(this.code, this.displayName, this.shortName);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.hu, // Default to Hungarian
    );
  }
}

/// Localization provider managing language state and translations
class LocalizationProvider with ChangeNotifier {
  static const String _languageKey = 'app_language';

  AppLanguage _currentLanguage = AppLanguage.hu;
  bool _isInitialized = false;

  AppLanguage get currentLanguage => _currentLanguage;
  bool get isInitialized => _isInitialized;
  String get languageCode => _currentLanguage.code;

  /// Initialize language from stored preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_languageKey);
      if (savedCode != null) {
        _currentLanguage = AppLanguage.fromCode(savedCode);
      }
    } catch (e) {
      debugPrint('Error loading language preference: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Change language and persist preference
  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;

    _currentLanguage = language;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language.code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  /// Toggle between EN and HU
  Future<void> toggleLanguage() async {
    final newLang =
        _currentLanguage == AppLanguage.en ? AppLanguage.hu : AppLanguage.en;
    await setLanguage(newLang);
  }

  /// Get localized string by key
  String tr(String key) {
    final translations =
        _currentLanguage == AppLanguage.en ? _translationsEn : _translationsHu;
    return translations[key] ?? key;
  }

  // ==========================================================================
  // Translation Dictionaries
  // ==========================================================================

  static const Map<String, String> _translationsEn = {
    // App
    'app_name': 'Plant Monitor',
    'app_subtitle': 'Houseplant life support system',
    'version': 'Version',

    // Navigation
    'nav_home': 'Home',
    'nav_plants': 'Plants',
    'nav_devices': 'Devices',
    'nav_alerts': 'Alerts',
    'nav_settings': 'Settings',

    // Login/Auth
    'login_title': 'Login',
    'login_email': 'Email address',
    'login_password': 'Password',
    'login_button': 'Login',
    'login_loading': 'Logging in...',
    'login_demo_mode': 'Demo Mode',
    'login_demo_info': 'Try the app without an account',
    'login_back_to_demo': 'Back to demo mode',
    'login_real_account': 'Login with real account',
    'login_no_account': "Don't have an account?",
    'login_register': 'Register',

    // Validation
    'validation_email_required': 'Please enter your email',
    'validation_email_invalid': 'Invalid email address',
    'validation_password_required': 'Please enter your password',
    'validation_password_short': 'Password too short',
    'validation_name_required': 'Please enter your name',
    'validation_confirm_password': 'Please confirm your password',
    'validation_passwords_mismatch': 'Passwords do not match',

    // Registration
    'register_title': 'Create Account',
    'register_name': 'Full name',
    'register_email': 'Email address',
    'register_password': 'Password',
    'register_confirm_password': 'Confirm password',
    'register_button': 'Register',
    'register_loading': 'Creating account...',
    'register_success': 'Account created successfully!',
    'register_have_account': 'Already have an account?',
    'register_login': 'Login',

    // Demo Mode
    'demo_title': 'Demo Mode',
    'demo_info': 'Try the app without an account',
    'demo_consumer': 'Consumer',
    'demo_consumer_desc': 'View plants, devices and manage your garden',
    'demo_manufacturer': 'Manufacturer',
    'demo_manufacturer_desc': 'Manage device types and products',
    'demo_admin': 'Administrator',
    'demo_admin_desc': 'Full system access and user management',
    'demo_loading': 'Loading...',

    // Dashboard - Home
    'home_hello': 'Hello',
    'home_quick_stats': 'Quick Stats',
    'home_recent_alerts': 'Recent Alerts',
    'home_total_plants': 'Total Plants',
    'home_total_devices': 'Total Devices',
    'home_active_alerts': 'Active Alerts',
    'home_no_alerts': 'No recent alerts',

    // Plants
    'plants_title': 'My Plants',
    'plants_add': 'Add Plant',
    'plants_edit': 'Edit Plant',
    'plants_delete': 'Delete Plant',
    'plants_delete_confirm': 'Are you sure you want to delete {name}?',
    'plants_health': 'Plant Health',
    'plants_last_watered': 'Last Watered',
    'plants_type': 'Plant Type',
    'plants_select_type': 'Select Plant Type',
    'plants_select_type_hint': 'Choose a plant type...',
    'plants_name': 'Plant Name',
    'plants_name_optional': 'Plant Name (optional)',
    'plants_location': 'Location',
    'plants_notes': 'Notes',
    'plants_empty': 'No plants yet',
    'plants_add_first': 'Add your first plant',
    'plants_water': 'Water Plant',
    'plants_watering': 'Watering...',
    'plants_watered_success': 'watered successfully!',
    'plants_added_success': 'Plant added successfully!',
    'plants_added_error': 'Failed to add plant',
    'plants_deleted_success': 'Plant deleted successfully!',
    'plants_deleted_error': 'Failed to delete plant',
    'plants_updated_success': 'Plant updated successfully!',
    'plants_updated_error': 'Failed to update plant',
    'plants_healthy': 'Healthy',
    'plants_health_status': 'Health Status',
    'plants_add_failed': 'Failed to add plant',
    'plants_delete_failed': 'Failed to delete plant',
    'plants_no_types': 'No plant types available',
    'plants_loading_types': 'Loading plant types...',

    // Devices
    'devices_title': 'My Devices',
    'devices_add': 'Add Device',
    'devices_edit': 'Edit Device',
    'devices_delete': 'Delete Device',
    'devices_delete_confirm': 'Are you sure you want to delete {name}?',
    'devices_status': 'Device Status',
    'devices_battery': 'Battery Level',
    'devices_signal': 'Signal Strength',
    'devices_last_seen': 'Last Seen',
    'devices_online': 'Online',
    'devices_offline': 'Offline',
    'devices_empty': 'No devices yet',
    'devices_add_first': 'Register your first device',
    'devices_select_type': 'Select Device Type',
    'devices_select_plant': 'Select Plant',
    'devices_select_hub': 'Select Hub (optional)',
    'devices_no_hub': 'No Hub',
    'devices_unique_id': 'Unique Identifier',
    'devices_name': 'Device Name',
    'devices_location': 'Location',
    'devices_no_types': 'No device types available',
    'devices_added_success': 'Device registered successfully!',
    'devices_deleted_success': 'Device removed successfully!',

    // Hubs
    'hubs_title': 'My Hubs',
    'hubs_add': 'Add Hub',
    'hubs_edit': 'Edit Hub',
    'hubs_delete': 'Delete Hub',
    'hubs_delete_confirm': 'Are you sure you want to delete this hub?',
    'hubs_name': 'Hub Name',
    'hubs_hub_id': 'Hub ID',
    'hubs_hub_link': 'Hub Link/URL',
    'hubs_location': 'Location',
    'hubs_online': 'Online',
    'hubs_offline': 'Offline',
    'hubs_empty': 'No hubs registered',
    'hubs_add_first': 'Add your first hub to connect devices',
    'hubs_added_success': 'Hub added successfully!',
    'hubs_updated_success': 'Hub updated successfully!',
    'hubs_deleted_success': 'Hub deleted successfully!',
    'hubs_assign_device': 'Assign Device to Hub',
    'hubs_select_device': 'Select a device to assign',

    // Alerts
    'alerts_title': 'My Alerts',
    'alerts_acknowledged': 'Acknowledged',
    'alerts_resolved': 'Resolved',
    'alerts_none': 'No alerts',
    'alerts_acknowledge': 'Acknowledge',
    'alerts_resolve': 'Resolve',
    'alerts_severity': 'Severity',
    'alerts_acknowledged_msg': 'Alert acknowledged',
    'alerts_dismissed_msg': 'Alert dismissed',

    // Settings
    'settings_title': 'Settings',
    'settings_profile': 'User Profile',
    'settings_preferences': 'Preferences',
    'settings_language': 'Language',
    'settings_notifications': 'Notifications',
    'settings_theme': 'Theme',
    'settings_about': 'About',
    'settings_help': 'Help',
    'settings_logout': 'Logout',
    'settings_logout_confirm': 'Are you sure you want to logout?',

    // Admin
    'admin_title': 'Administration',
    'admin_users': 'User Management',
    'admin_users_desc': 'Manage user accounts',
    'admin_plant_catalog': 'Plant Catalog',
    'admin_plant_catalog_desc': 'Manage plant species database',
    'admin_system': 'System Status',
    'admin_system_desc': 'Monitor system health',

    // Manufacturer
    'manufacturer_title': 'Manufacturer Dashboard',
    'manufacturer_device_types': 'Device Types',
    'manufacturer_device_types_desc': 'Manage your device types',
    'manufacturer_register_device': 'Register Device',
    'manufacturer_register_device_desc': 'Register new device instances',

    // Common
    'common_ok': 'OK',
    'common_cancel': 'Cancel',
    'common_save': 'Save',
    'common_delete': 'Delete',
    'common_edit': 'Edit',
    'common_add': 'Add',
    'common_create': 'Create',
    'common_loading': 'Loading...',
    'common_error': 'Error',
    'common_success': 'Success',
    'common_no_data': 'No data available',
    'common_retry': 'Retry',
    'common_refresh': 'Refresh',
    'common_search': 'Search',
    'common_filter': 'Filter',
    'common_sort': 'Sort',
    'common_view_details': 'View Details',
    'common_confirm': 'Confirm',
    'common_dismiss': 'Dismiss',

    // Errors
    'error_network': 'Network error. Check your connection.',
    'error_server': 'Server unreachable. Try again later.',
    'error_unauthorized': 'Session expired. Please login again.',
    'error_unknown': 'An unknown error occurred.',
    'error_load_users': 'Failed to load users',
    'error_no_permission': 'You do not have permission for this page',

    // Admin Users Screen
    'admin_delete_user': 'Delete User',
    'admin_delete_user_confirm':
        'Are you sure you want to delete {name}?\n\nThis action cannot be undone.',
    'admin_user_deleted': '{name} deleted',
    'admin_user_verified': '{name} verified',
    'admin_user_unverified': '{name} verification revoked',
    'admin_user_activated': '{name} activated',
    'admin_user_deactivated': '{name} deactivated',
    'admin_new_user': 'New User',
    'admin_user_created': '{name} created',
    'admin_role': 'Role *',
    'admin_username': 'Username *',
    'admin_email': 'Email *',
    'admin_password': 'Password *',
    'admin_first_name': 'First Name',
    'admin_last_name': 'Last Name',
    'admin_company_name': 'Company Name *',
    'admin_required_field': 'Required field',
    'admin_min_chars': 'At least {count} characters',
    'admin_invalid_email': 'Invalid email address',
    'admin_required_manufacturer': 'Required for manufacturers',
    'admin_verify': 'Verify',
    'admin_revoke_verify': 'Revoke Verification',
    'admin_activate': 'Activate',
    'admin_deactivate': 'Deactivate',
    'admin_inactive': 'Inactive',
    'admin_not_verified': 'Not Verified',
    'admin_no_users': 'No users',
    'admin_create': 'Create',

    // Admin Plant Catalog Screen
    'admin_plant_catalog_manage': 'Manage Plant Catalog',
    'admin_add_plant_type': 'Add Plant Species',
    'admin_edit_plant_type': 'Edit',
    'admin_delete_plant_type': 'Delete Plant Species',
    'admin_delete_plant_confirm': 'Are you sure you want to delete {name}?',
    'admin_empty_catalog': 'Empty Catalog',
    'admin_add_first_plant': 'Add the first plant species to the catalog',
    'admin_plant_requirements': 'Requirements:',
    'admin_temperature': 'Temperature',
    'admin_moisture': 'Soil Moisture',
    'admin_brightness': 'Light',
    'admin_humidity': 'Humidity',
    'admin_plant_name': 'Name *',
    'admin_scientific_name': 'Scientific Name *',
    'admin_description': 'Description',
    'admin_care_instructions': 'Care Instructions',
    'admin_plant_added': 'Plant species added',
    'admin_plant_updated': 'Plant species updated',
    'admin_plant_deleted': 'Plant species deleted',
    'admin_plant_add_failed': 'Failed to add plant species',
    'admin_plant_update_failed': 'Failed to update plant species',
    'admin_plant_delete_failed': 'Failed to delete plant species',
    'admin_no_permission': 'You do not have permission to access this page',
    'admin_new_plant_type': 'New Plant Species',
    'admin_plant_name_hint': 'e.g. Monstera deliciosa',
    'admin_brightness_lux': 'Light (lux) *',
    'admin_brightness_hint': 'e.g. 5000',
    'admin_brightness_helper':
        'Typical values: Shade: 500-2000, Medium: 2000-10000, Sunny: 10000+',
    'admin_brightness_error': 'Enter a valid positive number',
    'admin_action_irreversible': 'This action cannot be undone.',

    // Admin System View
    'admin_server_status': 'Server Status',
    'admin_api_server': 'API Server',
    'admin_online': 'Online',
    'admin_connected': 'Connected',
    'admin_unknown': 'Unknown',
    'admin_database': 'Database',
    'admin_postgresql': 'PostgreSQL',
    'admin_mqtt_broker': 'MQTT Broker',
    'admin_hub_gateway': 'Hub Gateway',
    'admin_resource_usage': 'Resource Usage',
    'admin_cpu': 'CPU',
    'admin_memory': 'Memory',
    'admin_storage': 'Storage',
    'admin_check_status': 'Check System Status',
    'admin_export_data': 'Export Data',
    'admin_quick_actions': 'Quick Actions',
    'admin_error_loading_stats': 'Error loading stats',

    // User Dashboard - Hubs
    'user_my_hubs': 'My Hubs',
    'user_hubs_configured': '{count} hub(s) configured',
    'user_no_hubs': 'No hubs configured',
    'user_add_hub': 'Add Hub',
    'user_edit_hub': 'Edit Hub',
    'user_delete_hub': 'Delete Hub',
    'user_delete_hub_confirm':
        'Are you sure you want to delete "{name}"? All devices assigned to this hub will be unassigned.',
    'user_hub_added': 'Hub added (local only - backend not connected)',
    'user_hub_updated': 'Hub updated (local only - backend not connected)',
    'user_hub_deleted': 'Hub deleted (local only - backend not connected)',
    'user_hub_id': 'Hub ID',
    'user_hub_id_mac': 'Hub ID (MAC/Serial)',
    'user_hub_link': 'Hub Link (MQTT URL)',
    'user_hub_name': 'Hub Name',
    'user_location': 'Location',
    'user_offline': 'Offline',
    'user_plant_history': 'Plant History & Analytics',

    // Plant Detail
    'plant_no_sensor_history': 'No sensor history available',
    'plant_no_water_pump': 'No water pump device assigned to this plant',
    'plant_watered_success': 'Plant watered successfully!',
    'plant_no_light_device': 'No light device assigned to this plant',
    'plant_light_adjusted': 'Light adjusted successfully!',
    'plant_no_temp_device': 'No temperature device assigned to this plant',
    'plant_temp_adjusted': 'Temperature adjusted successfully!',

    // History Screen
    'history_title': 'Plant History & Analytics',
    'history_charts': 'Charts',
    'history_logs': 'Logs',
    'history_insights': 'Insights',
    'history_select_plant': 'Select Plant:',
    'history_time_period': 'Time Period:',
    'history_no_plant': 'Select a plant to view its history',
    'history_current_status': 'Current Status',
    'history_moisture_chart': 'Soil Moisture',
    'history_temp_chart': 'Temperature',
    'history_light_chart': 'Light Level',
    'history_avg': 'Avg',
    'history_min': 'Min',
    'history_max': 'Max',
    'history_no_data': 'No sensor data available',
    'history_1d': '1 Day',
    'history_7d': '7 Days',
    'history_30d': '30 Days',
    // History Screen - Additional
    'history_error_load': 'Failed to load sensor history. Please try again.',
    'history_plant_not_found': 'Plant not found',
    'history_soil_moisture_trends': 'Soil Moisture Trends',
    'history_temperature_history': 'Temperature History',
    'history_light_level_changes': 'Light Level Changes',
    'history_chart_view': 'Chart View',
    'history_chart_install_hint':
        'Install fl_chart package for interactive charts',
    'history_data_summary': 'Data Summary',
    'history_total_data_points': 'Total data points',
    'history_avg_moisture': 'Average moisture',
    'history_avg_temp': 'Average temperature',
    'history_avg_light': 'Average light',
    'history_time_minutes_ago': '{n}m ago',
    'history_time_hours_ago': '{n}h ago',
    'history_time_days_ago': '{n}d ago',
    // History Screen - Logs
    'history_log_watered': 'Plant watered',
    'history_log_watered_desc': 'Manual watering completed',
    'history_log_light_adjusted': 'Light adjusted',
    'history_log_light_adjusted_desc': 'Grow light intensity increased to 80%',
    'history_log_health_check': 'Health check',
    'history_log_health_check_desc': 'Plant health assessment: Good condition',
    'history_log_moisture_alert': 'Moisture alert',
    'history_log_moisture_alert_desc': 'Low soil moisture detected - 25%',
    'history_log_temp_spike': 'Temperature spike',
    'history_log_temp_spike_desc': 'High temperature recorded - 28°C',
    // History Screen - Insights
    'history_insight_health_score': 'Health Score',
    'history_insight_excellent': 'Excellent',
    'history_insight_needs_attention': 'Needs Attention',
    'history_insight_health_good_desc':
        'Your plant is thriving! Keep up the great care routine.',
    'history_insight_health_bad_desc':
        'Your plant needs some attention. Check moisture levels and lighting.',
    'history_insight_watering': 'Watering Pattern',
    'history_insight_regular': 'Regular',
    'history_insight_watering_desc':
        'Your watering schedule appears consistent. Plants thrive on routine!',
    'history_insight_growth': 'Growth Trends',
    'history_insight_positive': 'Positive',
    'history_insight_growth_desc':
        'Based on sensor data, your plant shows healthy growth patterns.',
    'history_insight_environment': 'Environmental Conditions',
    'history_insight_optimal': 'Optimal',
    'history_insight_environment_desc':
        'Temperature and humidity levels are within ideal ranges for your plant.',
    'history_insight_recommendations': 'Care Recommendations',
    'history_insight_maintain': 'Maintain Current Routine',
    'history_insight_recommendations_desc':
        '• Continue current watering schedule\n• Monitor for any pest activity\n• Consider fertilizing next month',

    // Plant Detail Screen
    'plant_active_alerts': 'Active Alerts',
    'plant_info': 'Plant Information',
    'plant_current_readings': 'Current Readings',
    'plant_controls': 'Plant Controls',
    'plant_sensor_history': 'Sensor History (7 days)',
    'plant_care_instructions': 'Care Instructions',
    'plant_watering': 'Watering...',
    'plant_adjusting': 'Adjusting...',
    'plant_adjust': 'Adjust',
    'plant_water_action': 'Water',
    'plant_temp_action': 'Temp',
    'plant_light_action': 'Light',
    'plant_no_history': 'No sensor history available',
    'plant_chart_placeholder': 'Chart placeholder',
    'plant_location': 'Location',
    'plant_health_status': 'Health Status',
    'plant_last_watered': 'Last Watered',
    'plant_planted_date': 'Planted',
    'plant_notes': 'Notes',
    'plant_health_good': 'Good',
    'plant_health_attention': 'Needs attention',
    'plant_health_critical': 'Critical',

    // Manufacturer Screen
    'manufacturer_active': 'Active',
    'manufacturer_inactive': 'Inactive',
    'manufacturer_no_device_types': 'No device types yet',
    'manufacturer_add_first': 'Register your first device type',
    'manufacturer_device_name': 'Device Type Name *',
    'manufacturer_model_number': 'Model Number *',
    'manufacturer_firmware_version': 'Firmware Version',
    'manufacturer_status': 'Status',
    'manufacturer_sensors': 'Supported Sensors',
    'manufacturer_fill_required': 'Please fill all required fields',
    'manufacturer_type_added': 'Device type registered',
    'manufacturer_type_updated': 'Device type updated',
    'manufacturer_type_deleted': 'Device type deleted',
    'manufacturer_new_device_type': 'New Device Type',
    'manufacturer_edit_device_type': 'Edit Device Type',
    'manufacturer_delete_device_type': 'Delete Device Type',
    'manufacturer_delete_confirm': 'Are you sure you want to delete {name}?',
  };

  static const Map<String, String> _translationsHu = {
    // App
    'app_name': 'Növény Monitor',
    'app_subtitle': 'Szobanövény életben tartó keretrendszer',
    'version': 'Verzió',

    // Navigation
    'nav_home': 'Főoldal',
    'nav_plants': 'Növények',
    'nav_devices': 'Eszközök',
    'nav_alerts': 'Riasztások',
    'nav_settings': 'Beállítások',

    // Login/Auth
    'login_title': 'Bejelentkezés',
    'login_email': 'Email cím',
    'login_password': 'Jelszó',
    'login_button': 'Bejelentkezés',
    'login_loading': 'Bejelentkezés...',
    'login_demo_mode': 'Demó Mód',
    'login_demo_info': 'Próbáld ki az alkalmazást fiók nélkül',
    'login_back_to_demo': 'Vissza a demó módhoz',
    'login_real_account': 'Bejelentkezés valós fiókkal',
    'login_no_account': 'Nincs még fiókod?',
    'login_register': 'Regisztráció',

    // Validation
    'validation_email_required': 'Kérjük, adja meg az email címét',
    'validation_email_invalid': 'Érvénytelen email cím',
    'validation_password_required': 'Kérjük, adja meg a jelszavát',
    'validation_password_short': 'A jelszó túl rövid',
    'validation_name_required': 'Kérjük, adja meg a nevét',
    'validation_confirm_password': 'Kérjük, erősítse meg a jelszavát',
    'validation_passwords_mismatch': 'A jelszavak nem egyeznek',

    // Registration
    'register_title': 'Fiók Létrehozása',
    'register_name': 'Teljes név',
    'register_email': 'Email cím',
    'register_password': 'Jelszó',
    'register_confirm_password': 'Jelszó megerősítése',
    'register_button': 'Regisztráció',
    'register_loading': 'Fiók létrehozása...',
    'register_success': 'Fiók sikeresen létrehozva!',
    'register_have_account': 'Már van fiókod?',
    'register_login': 'Bejelentkezés',

    // Demo Mode
    'demo_title': 'Demó Mód',
    'demo_info': 'Próbáld ki az alkalmazást fiók nélkül',
    'demo_consumer': 'Felhasználó',
    'demo_consumer_desc': 'Növények, eszközök megtekintése és kert kezelése',
    'demo_manufacturer': 'Gyártó',
    'demo_manufacturer_desc': 'Eszköztípusok és termékek kezelése',
    'demo_admin': 'Adminisztrátor',
    'demo_admin_desc': 'Teljes rendszer-hozzáférés és felhasználó kezelés',
    'demo_loading': 'Betöltés...',

    // Dashboard - Home
    'home_hello': 'Szia',
    'home_quick_stats': 'Gyors Statisztikák',
    'home_recent_alerts': 'Legutóbbi Riasztások',
    'home_total_plants': 'Összes Növény',
    'home_total_devices': 'Összes Eszköz',
    'home_active_alerts': 'Aktív Riasztások',
    'home_no_alerts': 'Nincsenek legutóbbi riasztások',

    // Plants
    'plants_title': 'Növényeim',
    'plants_add': 'Növény Hozzáadása',
    'plants_edit': 'Növény Szerkesztése',
    'plants_delete': 'Növény Törlése',
    'plants_delete_confirm': 'Biztosan törölni szeretnéd: {name}?',
    'plants_health': 'Növény Állapota',
    'plants_last_watered': 'Utolsó Öntözés',
    'plants_type': 'Növény Típus',
    'plants_select_type': 'Válassz Növény Típust',
    'plants_select_type_hint': 'Válassz növénytípust...',
    'plants_name': 'Növény Neve',
    'plants_name_optional': 'Növény Neve (opcionális)',
    'plants_location': 'Hely',
    'plants_notes': 'Megjegyzések',
    'plants_empty': 'Még nincsenek növények',
    'plants_add_first': 'Add hozzá az első növényed',
    'plants_water': 'Öntözés',
    'plants_watering': 'Öntözés...',
    'plants_watered_success': 'sikeresen megöntözve!',
    'plants_added_success': 'Növény sikeresen hozzáadva!',
    'plants_added_error': 'Nem sikerült hozzáadni a növényt',
    'plants_deleted_success': 'Növény sikeresen törölve!',
    'plants_deleted_error': 'Nem sikerült törölni a növényt',
    'plants_updated_success': 'Növény sikeresen frissítve!',
    'plants_updated_error': 'Nem sikerült frissíteni a növényt',
    'plants_healthy': 'Egészséges',
    'plants_health_status': 'Egészségi Állapot',
    'plants_add_failed': 'Nem sikerült hozzáadni a növényt',
    'plants_delete_failed': 'Nem sikerült törölni a növényt',
    'plants_no_types': 'Nincsenek elérhető növénytípusok',
    'plants_loading_types': 'Növénytípusok betöltése...',

    // Devices
    'devices_title': 'Eszközeim',
    'devices_add': 'Eszköz Hozzáadása',
    'devices_edit': 'Eszköz Szerkesztése',
    'devices_delete': 'Eszköz Törlése',
    'devices_delete_confirm': 'Biztosan törölni szeretnéd: {name}?',
    'devices_status': 'Eszköz Állapota',
    'devices_battery': 'Akkumulátor Szint',
    'devices_signal': 'Jelerősség',
    'devices_last_seen': 'Utoljára Látva',
    'devices_online': 'Online',
    'devices_offline': 'Offline',
    'devices_empty': 'Még nincsenek eszközök',
    'devices_add_first': 'Regisztráld az első eszközöd',
    'devices_select_type': 'Válassz Eszköztípust',
    'devices_select_plant': 'Válassz Növényt',
    'devices_select_hub': 'Válassz Hubot (opcionális)',
    'devices_no_hub': 'Nincs Hub',
    'devices_unique_id': 'Egyedi Azonosító',
    'devices_name': 'Eszköz Neve',
    'devices_location': 'Hely',
    'devices_no_types': 'Nincsenek elérhető eszköztípusok',
    'devices_added_success': 'Eszköz sikeresen regisztrálva!',
    'devices_deleted_success': 'Eszköz sikeresen eltávolítva!',

    // Hubs
    'hubs_title': 'Hubjaim',
    'hubs_add': 'Hub Hozzáadása',
    'hubs_edit': 'Hub Szerkesztése',
    'hubs_delete': 'Hub Törlése',
    'hubs_delete_confirm': 'Biztosan törölni szeretnéd ezt a hubot?',
    'hubs_name': 'Hub Neve',
    'hubs_hub_id': 'Hub Azonosító',
    'hubs_hub_link': 'Hub Link/URL',
    'hubs_location': 'Hely',
    'hubs_online': 'Online',
    'hubs_offline': 'Offline',
    'hubs_empty': 'Nincsenek regisztrált hubok',
    'hubs_add_first': 'Adj hozzá egy hubot az eszközök csatlakoztatásához',
    'hubs_added_success': 'Hub sikeresen hozzáadva!',
    'hubs_updated_success': 'Hub sikeresen frissítve!',
    'hubs_deleted_success': 'Hub sikeresen törölve!',
    'hubs_assign_device': 'Eszköz Hozzárendelése Hubhoz',
    'hubs_select_device': 'Válassz egy eszközt a hozzárendeléshez',

    // Alerts
    'alerts_title': 'Riasztásaim',
    'alerts_acknowledged': 'Tudomásul Véve',
    'alerts_resolved': 'Megoldva',
    'alerts_none': 'Nincsenek riasztások',
    'alerts_acknowledge': 'Tudomásul Vesz',
    'alerts_resolve': 'Megold',
    'alerts_severity': 'Súlyosság',
    'alerts_acknowledged_msg': 'Riasztás tudomásul véve',
    'alerts_dismissed_msg': 'Riasztás elutasítva',

    // Settings
    'settings_title': 'Beállítások',
    'settings_profile': 'Felhasználói Profil',
    'settings_preferences': 'Preferenciák',
    'settings_language': 'Nyelv',
    'settings_notifications': 'Értesítések',
    'settings_theme': 'Téma',
    'settings_about': 'Az Alkalmazásról',
    'settings_help': 'Súgó',
    'settings_logout': 'Kijelentkezés',
    'settings_logout_confirm': 'Biztosan ki szeretne jelentkezni?',

    // Admin
    'admin_title': 'Adminisztráció',
    'admin_users': 'Felhasználó Kezelés',
    'admin_users_desc': 'Felhasználói fiókok kezelése',
    'admin_plant_catalog': 'Növény Katalógus',
    'admin_plant_catalog_desc': 'Növényfajok adatbázisának kezelése',
    'admin_system': 'Rendszer Állapot',
    'admin_system_desc': 'Rendszer egészség monitorozása',

    // Manufacturer
    'manufacturer_title': 'Gyártói Irányítópult',
    'manufacturer_device_types': 'Eszköz Típusok',
    'manufacturer_device_types_desc': 'Eszköztípusok kezelése',
    'manufacturer_register_device': 'Eszköz Regisztrálása',
    'manufacturer_register_device_desc': 'Új eszközpéldányok regisztrálása',

    // Common
    'common_ok': 'OK',
    'common_cancel': 'Mégse',
    'common_save': 'Mentés',
    'common_delete': 'Törlés',
    'common_edit': 'Szerkesztés',
    'common_add': 'Hozzáadás',
    'common_create': 'Létrehozás',
    'common_loading': 'Betöltés...',
    'common_error': 'Hiba',
    'common_success': 'Sikeres',
    'common_no_data': 'Nincs adat',
    'common_retry': 'Újra',
    'common_refresh': 'Frissítés',
    'common_search': 'Keresés',
    'common_filter': 'Szűrés',
    'common_sort': 'Rendezés',
    'common_view_details': 'Részletek',
    'common_confirm': 'Megerősítés',
    'common_dismiss': 'Elvetés',

    // Errors
    'error_network': 'Hálózati hiba. Ellenőrizze a kapcsolatot.',
    'error_server': 'A szerver nem elérhető. Próbálja később.',
    'error_unauthorized': 'Lejárt munkamenet. Kérjük, jelentkezzen be újra.',
    'error_unknown': 'Ismeretlen hiba történt.',
    'error_load_users': 'Nem sikerült betölteni a felhasználókat',
    'error_no_permission': 'Nincs jogosultsága ehhez az oldalhoz',

    // Admin Users Screen
    'admin_delete_user': 'Felhasználó Törlése',
    'admin_delete_user_confirm':
        'Biztosan törölni szeretné {name} felhasználót?\n\nEz a művelet nem visszavonható.',
    'admin_user_deleted': '{name} törölve',
    'admin_user_verified': '{name} hitelesítve',
    'admin_user_unverified': '{name} hitelesítése visszavonva',
    'admin_user_activated': '{name} aktiválva',
    'admin_user_deactivated': '{name} deaktiválva',
    'admin_new_user': 'Új Felhasználó',
    'admin_user_created': '{name} létrehozva',
    'admin_role': 'Szerepkör *',
    'admin_username': 'Felhasználónév *',
    'admin_email': 'Email *',
    'admin_password': 'Jelszó *',
    'admin_first_name': 'Keresztnév',
    'admin_last_name': 'Vezetéknév',
    'admin_company_name': 'Cég Neve *',
    'admin_required_field': 'Kötelező mező',
    'admin_min_chars': 'Legalább {count} karakter',
    'admin_invalid_email': 'Érvénytelen email cím',
    'admin_required_manufacturer': 'Kötelező gyártóknál',
    'admin_verify': 'Hitelesítés',
    'admin_revoke_verify': 'Hitelesítés Visszavonása',
    'admin_activate': 'Aktiválás',
    'admin_deactivate': 'Deaktiválás',
    'admin_inactive': 'Inaktív',
    'admin_not_verified': 'Nem Hitelesített',
    'admin_no_users': 'Nincsenek felhasználók',
    'admin_create': 'Létrehozás',

    // Admin Plant Catalog Screen
    'admin_plant_catalog_manage': 'Növénykatalógus Kezelése',
    'admin_add_plant_type': 'Növényfaj Hozzáadása',
    'admin_edit_plant_type': 'Szerkesztés',
    'admin_delete_plant_type': 'Növényfaj Törlése',
    'admin_delete_plant_confirm': 'Biztosan törölni szeretné: {name}?',
    'admin_empty_catalog': 'Üres Katalógus',
    'admin_add_first_plant': 'Adja hozzá az első növényfajt a katalógushoz',
    'admin_plant_requirements': 'Igények:',
    'admin_temperature': 'Hőmérséklet',
    'admin_moisture': 'Talajnedvesség',
    'admin_brightness': 'Fényerő',
    'admin_humidity': 'Páratartalom',
    'admin_plant_name': 'Név *',
    'admin_scientific_name': 'Tudományos Név *',
    'admin_description': 'Leírás',
    'admin_care_instructions': 'Gondozási Útmutató',
    'admin_plant_added': 'Növényfaj hozzáadva',
    'admin_plant_updated': 'Növényfaj frissítve',
    'admin_plant_deleted': 'Növényfaj törölve',
    'admin_plant_add_failed': 'Nem sikerült hozzáadni a növényfajt',
    'admin_plant_update_failed': 'Nem sikerült frissíteni a növényfajt',
    'admin_plant_delete_failed': 'Nem sikerült törölni a növényfajt',
    'admin_no_permission': 'Nincs jogosultsága ehhez az oldalhoz',
    'admin_new_plant_type': 'Új Növényfaj',
    'admin_plant_name_hint': 'pl. Monstera deliciosa',
    'admin_brightness_lux': 'Fényigény (lux) *',
    'admin_brightness_hint': 'pl. 5000',
    'admin_brightness_helper':
        'Tipikus értékek: Árnyékos: 500-2000, Közepes: 2000-10000, Napos: 10000+',
    'admin_brightness_error': 'Érvényes pozitív számot adjon meg',
    'admin_action_irreversible': 'Ez a művelet nem visszavonható.',

    // Admin System View
    'admin_server_status': 'Szerver Állapot',
    'admin_api_server': 'API Szerver',
    'admin_online': 'Online',
    'admin_database': 'Adatbázis',
    'admin_mqtt_broker': 'MQTT Bróker',
    'admin_hub_gateway': 'Hub Gateway',
    'admin_resource_usage': 'Erőforrás Használat',
    'admin_cpu': 'CPU',
    'admin_memory': 'Memória',
    'admin_storage': 'Tárhely',
    'admin_check_status': 'Rendszer Állapot Ellenőrzése',
    'admin_export_data': 'Adatok Exportálása',
    'admin_quick_actions': 'Gyors Műveletek',
    'admin_connected': 'Csatlakozva',
    'admin_unknown': 'Ismeretlen',
    'admin_postgresql': 'PostgreSQL',
    'admin_error_loading_stats': 'Hiba a statisztikák betöltésekor',

    // User Dashboard - Hubs
    'user_my_hubs': 'Hubok',
    'user_hubs_configured': '{count} hub konfigurálva',
    'user_no_hubs': 'Nincs hub konfigurálva',
    'user_add_hub': 'Hub Hozzáadása',
    'user_edit_hub': 'Hub Szerkesztése',
    'user_delete_hub': 'Hub Törlése',
    'user_delete_hub_confirm':
        'Biztosan törölni szeretné a(z) "{name}" hubot? Az ehhez a hubhoz tartozó eszközök hozzárendelése megszűnik.',
    'user_hub_added':
        'Hub hozzáadva (csak lokálisan - backend nincs csatlakoztatva)',
    'user_hub_updated':
        'Hub frissítve (csak lokálisan - backend nincs csatlakoztatva)',
    'user_hub_deleted':
        'Hub törölve (csak lokálisan - backend nincs csatlakoztatva)',
    'user_hub_id': 'Hub ID',
    'user_hub_id_mac': 'Hub ID (MAC/Sorozatszám)',
    'user_hub_link': 'Hub Link (MQTT URL)',
    'user_hub_name': 'Hub Név',
    'user_location': 'Hely',
    'user_offline': 'Offline',
    'user_plant_history': 'Növény Előzmények és Analitika',

    // Plant Detail
    'plant_no_sensor_history': 'Nincs szenzor előzmény',
    'plant_no_water_pump':
        'Nincs öntözőpumpa eszköz hozzárendelve ehhez a növényhez',
    'plant_watered_success': 'Növény sikeresen öntözve!',
    'plant_no_light_device':
        'Nincs világítás eszköz hozzárendelve ehhez a növényhez',
    'plant_light_adjusted': 'Világítás sikeresen beállítva!',
    'plant_no_temp_device':
        'Nincs hőmérséklet eszköz hozzárendelve ehhez a növényhez',
    'plant_temp_adjusted': 'Hőmérséklet sikeresen beállítva!',

    // History Screen
    'history_title': 'Növény Előzmények és Analitika',
    'history_charts': 'Grafikonok',
    'history_logs': 'Naplók',
    'history_insights': 'Betekintések',
    'history_select_plant': 'Válassz Növényt:',
    'history_time_period': 'Időszak:',
    'history_no_plant': 'Válassz egy növényt az előzmények megtekintéséhez',
    'history_current_status': 'Jelenlegi Állapot',
    'history_moisture_chart': 'Talajnedvesség',
    'history_temp_chart': 'Hőmérséklet',
    'history_light_chart': 'Fényerő',
    'history_avg': 'Átlag',
    'history_min': 'Min',
    'history_max': 'Max',
    'history_no_data': 'Nincs elérhető szenzor adat',
    'history_1d': '1 Nap',
    'history_7d': '7 Nap',
    'history_30d': '30 Nap',
    // History Screen - Additional
    'history_error_load':
        'Nem sikerült betölteni a szenzor előzményeket. Kérjük, próbálja újra.',
    'history_plant_not_found': 'Növény nem található',
    'history_soil_moisture_trends': 'Talajnedvesség Trendek',
    'history_temperature_history': 'Hőmérséklet Előzmények',
    'history_light_level_changes': 'Fényerő Változások',
    'history_chart_view': 'Grafikon Nézet',
    'history_chart_install_hint':
        'Telepítse az fl_chart csomagot az interaktív grafikonokhoz',
    'history_data_summary': 'Adat Összefoglaló',
    'history_total_data_points': 'Összes adatpont',
    'history_avg_moisture': 'Átlagos nedvesség',
    'history_avg_temp': 'Átlagos hőmérséklet',
    'history_avg_light': 'Átlagos fényerő',
    'history_time_minutes_ago': '{n} perce',
    'history_time_hours_ago': '{n} órája',
    'history_time_days_ago': '{n} napja',
    // History Screen - Logs
    'history_log_watered': 'Növény öntözve',
    'history_log_watered_desc': 'Kézi öntözés befejezve',
    'history_log_light_adjusted': 'Fény beállítva',
    'history_log_light_adjusted_desc': 'Növénylámpa intenzitás 80%-ra növelve',
    'history_log_health_check': 'Egészség ellenőrzés',
    'history_log_health_check_desc': 'Növény állapot felmérés: Jó állapot',
    'history_log_moisture_alert': 'Nedvesség riasztás',
    'history_log_moisture_alert_desc': 'Alacsony talajnedvesség észlelve - 25%',
    'history_log_temp_spike': 'Hőmérséklet kiugrás',
    'history_log_temp_spike_desc': 'Magas hőmérséklet rögzítve - 28°C',
    // History Screen - Insights
    'history_insight_health_score': 'Egészségi Pontszám',
    'history_insight_excellent': 'Kiváló',
    'history_insight_needs_attention': 'Figyelmet Igényel',
    'history_insight_health_good_desc':
        'A növényed virágzik! Folytasd a remek gondozást.',
    'history_insight_health_bad_desc':
        'A növényed odafigyelést igényel. Ellenőrizd a nedvességet és a fényt.',
    'history_insight_watering': 'Öntözési Minta',
    'history_insight_regular': 'Rendszeres',
    'history_insight_watering_desc':
        'Az öntözési ütemezésed következetesnek tűnik. A növények szeretik a rutint!',
    'history_insight_growth': 'Növekedési Trendek',
    'history_insight_positive': 'Pozitív',
    'history_insight_growth_desc':
        'A szenzor adatok alapján a növényed egészséges növekedési mintákat mutat.',
    'history_insight_environment': 'Környezeti Feltételek',
    'history_insight_optimal': 'Optimális',
    'history_insight_environment_desc':
        'A hőmérséklet és páratartalom szintek a növényed ideális tartományában vannak.',
    'history_insight_recommendations': 'Gondozási Javaslatok',
    'history_insight_maintain': 'Jelenlegi Rutin Fenntartása',
    'history_insight_recommendations_desc':
        '• Folytasd a jelenlegi öntözési ütemezést\n• Figyelj az esetleges kártevő tevékenységre\n• Fontold meg a trágyázást a következő hónapban',

    // Plant Detail Screen
    'plant_active_alerts': 'Aktív Riasztások',
    'plant_info': 'Növény Információ',
    'plant_current_readings': 'Jelenlegi Értékek',
    'plant_controls': 'Növény Vezérlés',
    'plant_sensor_history': 'Szenzor Előzmények (7 nap)',
    'plant_care_instructions': 'Gondozási Útmutató',
    'plant_watering': 'Öntözés...',
    'plant_adjusting': 'Beállítás...',
    'plant_adjust': 'Beállít',
    'plant_water_action': 'Öntöz',
    'plant_temp_action': 'Hőmérséklet',
    'plant_light_action': 'Fény',
    'plant_no_history': 'Nincs szenzor előzmény',
    'plant_chart_placeholder': 'Grafikon helyőrző',
    'plant_location': 'Hely',
    'plant_health_status': 'Egészségi Állapot',
    'plant_last_watered': 'Utoljára Öntözve',
    'plant_planted_date': 'Ültetve',
    'plant_notes': 'Megjegyzések',
    'plant_health_good': 'Jó',
    'plant_health_attention': 'Figyelmet igényel',
    'plant_health_critical': 'Kritikus',

    // Manufacturer Screen
    'manufacturer_active': 'Aktív',
    'manufacturer_inactive': 'Inaktív',
    'manufacturer_no_device_types': 'Még nincsenek eszköztípusok',
    'manufacturer_add_first': 'Regisztrálja az első eszköztípust',
    'manufacturer_device_name': 'Eszköztípus Neve *',
    'manufacturer_model_number': 'Modellszám *',
    'manufacturer_firmware_version': 'Firmware Verzió',
    'manufacturer_status': 'Állapot',
    'manufacturer_sensors': 'Támogatott Szenzorok',
    'manufacturer_fill_required': 'Kérjük töltse ki az összes kötelező mezőt',
    'manufacturer_type_added': 'Eszköztípus regisztrálva',
    'manufacturer_type_updated': 'Eszköztípus frissítve',
    'manufacturer_type_deleted': 'Eszköztípus törölve',
    'manufacturer_new_device_type': 'Új Eszköztípus',
    'manufacturer_edit_device_type': 'Eszköztípus Szerkesztése',
    'manufacturer_delete_device_type': 'Eszköztípus Törlése',
    'manufacturer_delete_confirm': 'Biztosan törölni szeretné: {name}?',
  };
}

/// Extension for easy access to translations
extension LocalizationExtension on String {
  String tr(LocalizationProvider provider) => provider.tr(this);
}
