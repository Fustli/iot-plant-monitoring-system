import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../widgets/plant_card.dart';
import '../widgets/alert_banner.dart';
import '../services/plant_provider.dart';
import '../services/alert_provider.dart';
import 'plant_detail_screen.dart';
import 'history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantProvider>().loadPlants();
      context.read<AlertProvider>().loadAlerts();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: const [
          _DashboardHomeView(),
          _PlantsGridView(),
          _AlertsListView(),
          _SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: AppStrings.plants,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber),
            label: AppStrings.alerts,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: AppStrings.settings,
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return AppStrings.home;
      case 1:
        return AppStrings.myPlants;
      case 2:
        return AppStrings.myAlerts;
      case 3:
        return AppStrings.settings;
      default:
        return AppStrings.appName;
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      context.read<PlantProvider>().refresh(),
      context.read<AlertProvider>().refresh(),
    ]);
  }
}

class _DashboardHomeView extends StatelessWidget {
  const _DashboardHomeView();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        context.read<PlantProvider>().refresh(),
        context.read<AlertProvider>().refresh(),
      ]),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            Text(
              '${AppStrings.hello}, Plant Parent! 🌱',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s how your plants are doing today',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 24),

            // Critical alerts banner
            Consumer<AlertProvider>(
              builder: (context, alertProvider, child) {
                final criticalAlerts = alertProvider.criticalAlerts
                    .where((alert) => alert.status.name == 'active')
                    .toList();
                
                if (criticalAlerts.isNotEmpty) {
                  return Column(
                    children: [
                      AlertBanner(alert: criticalAlerts.first),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Quick stats cards
            Consumer2<PlantProvider, AlertProvider>(
              builder: (context, plantProvider, alertProvider, child) {
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_florist,
                        title: AppStrings.totalPlants,
                        value: plantProvider.totalPlants.toString(),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite,
                        title: 'Healthy',
                        value: plantProvider.healthyPlants.toString(),
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.warning,
                        title: 'Alerts',
                        value: alertProvider.activeAlertsCount.toString(),
                        color: alertProvider.criticalAlertsCount > 0 
                            ? AppColors.error 
                            : AppColors.warning,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Recent plants needing attention
            Consumer<PlantProvider>(
              builder: (context, plantProvider, child) {
                final needsAttention = plantProvider.plantsNeedingAttention;
                
                if (needsAttention.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Needs Your Attention',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Switch to plants tab
                              final dashboardState = context.findAncestorStateOfType<_DashboardScreenState>();
                              dashboardState?._pageController.animateToPage(
                                1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...needsAttention.take(2).map((plant) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PlantCard(
                          plant: plant,
                          onTap: () => _navigateToPlantDetail(context, plant),
                          onWaterSuccess: (plantId) {
                            context.read<PlantProvider>().loadPlantDetails(plantId);
                          },
                        ),
                      )),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 16),

            // Recent activity / History button
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.info.withOpacity(0.1),
                  child: Icon(Icons.analytics, color: AppColors.info),
                ),
                title: const Text('Plant History & Analytics'),
                subtitle: const Text('View sensor data and growth trends'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _navigateToPlantDetail(BuildContext context, plant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlantDetailScreen(plantId: plant.id),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantsGridView extends StatelessWidget {
  const _PlantsGridView();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (plantProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (plantProvider.plants.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_florist, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No plants yet'),
                Text('Add your first plant to get started'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: plantProvider.refresh,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: plantProvider.plants.length,
            itemBuilder: (context, index) {
              final plant = plantProvider.plants[index];
              return PlantCard(
                plant: plant,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PlantDetailScreen(plantId: plant.id),
                    ),
                  );
                },
                onWaterSuccess: (plantId) {
                  plantProvider.loadPlantDetails(plantId);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _AlertsListView extends StatelessWidget {
  const _AlertsListView();

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertProvider>(
      builder: (context, alertProvider, child) {
        if (alertProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (alertProvider.alerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No alerts'),
                Text('Your plants are all doing well!'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: alertProvider.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alertProvider.alerts.length,
            itemBuilder: (context, index) {
              final alert = alertProvider.alerts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AlertBanner(alert: alert),
              );
            },
          ),
        );
      },
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.person),
          ),
          title: Text('Demo User'),
          subtitle: Text('demo@plantsystem.com'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('About'),
          subtitle: Text('Version ${AppStrings.appVersion}'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: AppStrings.appName,
              applicationVersion: AppStrings.appVersion,
              applicationLegalese: '© 2025 Plant Monitoring System',
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Reset Demo Data'),
          subtitle: const Text('Restore original demo data'),
          onTap: () {
            context.read<PlantProvider>().loadPlants();
            context.read<AlertProvider>().loadAlerts();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo data reset')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Exit Demo'),
          onTap: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}