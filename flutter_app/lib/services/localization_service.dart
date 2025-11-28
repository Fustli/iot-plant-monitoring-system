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
    'plants_health': 'Plant Health',
    'plants_last_watered': 'Last Watered',
    'plants_type': 'Plant Type',
    'plants_location': 'Location',
    'plants_empty': 'No plants yet',
    'plants_add_first': 'Add your first plant',
    'plants_water': 'Water Plant',
    'plants_watering': 'Watering...',
    'plants_watered_success': 'watered successfully!',

    // Devices
    'devices_title': 'My Devices',
    'devices_add': 'Add Device',
    'devices_edit': 'Edit Device',
    'devices_delete': 'Delete Device',
    'devices_status': 'Device Status',
    'devices_battery': 'Battery Level',
    'devices_signal': 'Signal Strength',
    'devices_last_seen': 'Last Seen',
    'devices_online': 'Online',
    'devices_offline': 'Offline',
    'devices_empty': 'No devices yet',
    'devices_add_first': 'Register your first device',

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
    'plants_health': 'Növény Állapota',
    'plants_last_watered': 'Utolsó Öntözés',
    'plants_type': 'Növény Típus',
    'plants_location': 'Hely',
    'plants_empty': 'Még nincsenek növények',
    'plants_add_first': 'Add hozzá az első növényed',
    'plants_water': 'Öntözés',
    'plants_watering': 'Öntözés...',
    'plants_watered_success': 'sikeresen megöntözve!',

    // Devices
    'devices_title': 'Eszközeim',
    'devices_add': 'Eszköz Hozzáadása',
    'devices_edit': 'Eszköz Szerkesztése',
    'devices_delete': 'Eszköz Törlése',
    'devices_status': 'Eszköz Állapota',
    'devices_battery': 'Akkumulátor Szint',
    'devices_signal': 'Jelerősség',
    'devices_last_seen': 'Utoljára Látva',
    'devices_online': 'Online',
    'devices_offline': 'Offline',
    'devices_empty': 'Még nincsenek eszközök',
    'devices_add_first': 'Regisztráld az első eszközöd',

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
  };
}

/// Extension for easy access to translations
extension LocalizationExtension on String {
  String tr(LocalizationProvider provider) => provider.tr(this);
}
