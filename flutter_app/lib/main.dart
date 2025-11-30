import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'models/auth_models.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/user_dashboard_screen.dart';
import 'screens/manufacturer_dashboard_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'services/auth_provider.dart';
import 'services/plant_provider.dart';
import 'services/alert_provider.dart';
import 'services/localization_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          // Localization provider first
          ChangeNotifierProvider(create: (_) => LocalizationProvider()),
          // Auth provider should be second as other providers may depend on it
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => PlantProvider()),
          ChangeNotifierProvider(create: (_) => AlertProvider()),
        ],
        child: Consumer<LocalizationProvider>(
          builder: (context, localization, child) => MaterialApp(
            title: localization.tr('app_name'),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.neutral0,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegistrationScreen(),
              '/user-dashboard': (context) => const UserDashboardScreen(),
              '/manufacturer-dashboard': (context) =>
                  const ManufacturerDashboardScreen(),
              '/admin-dashboard': (context) => const AdminDashboardScreen(),
              '/history': (context) => const HistoryScreen(),
            },
          ),
        ),
      );
}

/// Wrapper widget that handles authentication state
/// Shows loading, login, or role-specific dashboard based on auth status
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth and localization on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalizationProvider>().initialize();
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while initializing
        if (!authProvider.isInitialized || !localization.isInitialized) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(localization.tr('common_loading')),
                ],
              ),
            ),
          );
        }

        // Route based on auth state
        switch (authProvider.authState.status) {
          case AuthStatus.authenticated:
            // Route to role-specific dashboard
            return _getRoleDashboard(authProvider.currentRole);
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
          case AuthStatus.initial:
          case AuthStatus.authenticating:
            return const LoginScreen();
        }
      },
    );
  }

  Widget _getRoleDashboard(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return const AdminDashboardScreen();
      case UserRole.manufacturer:
        return const ManufacturerDashboardScreen();
      case UserRole.consumer:
      default:
        return const UserDashboardScreen();
    }
  }
}
