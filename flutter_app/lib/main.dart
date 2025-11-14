import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'constants/app_strings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
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
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MainApp(),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PlantsScreen(),
    const DevicesScreen(),
    const AlertsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        elevation: 0,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: AppStrings.home),
          BottomNavigationBarItem(icon: Icon(Icons.local_florist), label: AppStrings.plants),
          BottomNavigationBarItem(icon: Icon(Icons.device_hub), label: AppStrings.devices),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: AppStrings.alerts),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: AppStrings.settings),
        ],
      ),
    );
  }
}

// Placeholder screens - to be implemented
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Home Screen'));
  }
}

class PlantsScreen extends StatelessWidget {
  const PlantsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Plants Screen'));
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Devices Screen'));
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Alerts Screen'));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings Screen'));
  }
}
