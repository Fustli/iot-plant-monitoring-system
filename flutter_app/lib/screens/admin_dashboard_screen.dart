import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../services/auth_provider.dart';
import '../services/localization_service.dart';
import '../widgets/animated_stats.dart';
import '../widgets/shimmer_loading.dart';
import 'admin_users_screen.dart';
import 'admin_plant_catalog_screen.dart';

/// Administrator dashboard with full system management
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(localization)),
        backgroundColor: AppColors.adminPrimary,
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
          _DashboardView(),
          _UsersView(),
          _PlantCatalogView(),
          _SystemView(),
          _SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.adminPrimary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: localization.tr('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: localization.tr('admin_users'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.eco),
            label: localization.tr('admin_plant_catalog'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.monitor_heart),
            label: localization.tr('admin_system'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: localization.tr('nav_settings'),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle(LocalizationProvider localization) {
    switch (_selectedIndex) {
      case 0:
        return localization.tr('admin_title');
      case 1:
        return localization.tr('admin_users');
      case 2:
        return localization.tr('admin_plant_catalog');
      case 3:
        return localization.tr('admin_system');
      case 4:
        return localization.tr('settings_title');
      default:
        return localization.tr('admin_title');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRefresh() async {
    // TODO: Refresh admin data
  }
}

// =============================================================================
// DASHBOARD VIEW
// =============================================================================

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  int _usersCount = 0;
  int _plantsCount = 0;
  int _devicesCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Schedule the load after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthProvider>().apiClient;
      final status = await apiClient.getSystemStatus();

      if (!mounted) return;

      final stats = status['stats'] as Map<String, dynamic>?;

      if (stats != null) {
        setState(() {
          _usersCount = stats['users_total'] ?? 0;
          _plantsCount = stats['plants_count'] ?? 0;
          _devicesCount = stats['devices_count'] ?? 0;
          _isLoading = false;
        });
      } else {
        // Fallback: count from lists
        final users = status['users'] as List? ?? [];
        setState(() {
          _usersCount = users.length;
          _plantsCount = (status['plants'] as List? ?? []).length;
          _devicesCount = (status['devices'] as List? ?? []).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.username ?? 'Admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Text(
            '${localization.tr('home_hello')}, $username!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.adminPrimary,
                ),
          ),
          const SizedBox(height: 24),

          // Stats cards
          if (_isLoading)
            Row(
              children: const [
                Expanded(child: ShimmerStatCard()),
                SizedBox(width: 12),
                Expanded(child: ShimmerStatCard()),
                SizedBox(width: 12),
                Expanded(child: ShimmerStatCard()),
              ],
            )
          else if (_error != null)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${localization.tr('admin_error_loading_stats')}: $_error')),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadStats,
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AnimatedStatCard(
                    icon: Icons.people,
                    title: localization.tr('admin_total_users'),
                    value: _usersCount,
                    color: AppColors.adminPrimary,
                    animationDuration: const Duration(milliseconds: 1200),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStatCard(
                    icon: Icons.eco,
                    title: localization.tr('admin_total_plants'),
                    value: _plantsCount,
                    color: AppColors.success,
                    animationDuration: const Duration(milliseconds: 1500),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStatCard(
                    icon: Icons.devices,
                    title: localization.tr('admin_total_devices'),
                    value: _devicesCount,
                    color: AppColors.info,
                    animationDuration: const Duration(milliseconds: 1800),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Quick actions
          Text(
            localization.tr('admin_quick_actions'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.adminPrimary.withOpacity(0.1),
                child: Icon(Icons.people, color: AppColors.adminPrimary),
              ),
              title: Text(localization.tr('admin_users')),
              subtitle: Text(localization.tr('admin_users_desc')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to users tab (index 1)
                final state = context
                    .findAncestorStateOfType<_AdminDashboardScreenState>();
                if (state != null) {
                  state.setState(() {
                    state._selectedIndex = 1;
                  });
                  state._pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.success.withOpacity(0.1),
                child: Icon(Icons.eco, color: AppColors.success),
              ),
              title: Text(localization.tr('admin_plant_catalog')),
              subtitle: Text(localization.tr('admin_plant_catalog_desc')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to plant catalog tab (index 2)
                final state = context
                    .findAncestorStateOfType<_AdminDashboardScreenState>();
                if (state != null) {
                  state.setState(() {
                    state._selectedIndex = 2;
                  });
                  state._pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.info.withOpacity(0.1),
                child: Icon(Icons.monitor_heart, color: AppColors.info),
              ),
              title: Text(localization.tr('admin_system')),
              subtitle: Text(localization.tr('admin_system_desc')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to system tab
                final state = context
                    .findAncestorStateOfType<_AdminDashboardScreenState>();
                if (state != null) {
                  state.setState(() {
                    state._selectedIndex = 3;
                  });
                  state._pageController.animateToPage(
                    3,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// USERS VIEW - Embedded version
// =============================================================================

class _UsersView extends StatelessWidget {
  const _UsersView();

  @override
  Widget build(BuildContext context) {
    return const AdminUsersScreen(embedded: true);
  }
}

// =============================================================================
// PLANT CATALOG VIEW - Embedded version
// =============================================================================

class _PlantCatalogView extends StatelessWidget {
  const _PlantCatalogView();

  @override
  Widget build(BuildContext context) {
    return const AdminPlantCatalogScreen(embedded: true);
  }
}

// =============================================================================
// SYSTEM VIEW
// =============================================================================

class _SystemView extends StatelessWidget {
  const _SystemView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Server Status
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.cloud, color: Colors.green[600], size: 28),
                    const SizedBox(width: 12),
                    Text(
                      localization.tr('admin_server_status'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(localization.tr('admin_api_server')),
                subtitle: const Text('http://localhost:8000'),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    localization.tr('admin_online'),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              ListTile(
                title: Text(localization.tr('admin_database')),
                subtitle: Text(localization.tr('admin_postgresql')),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    localization.tr('admin_connected'),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              ListTile(
                title: Text(localization.tr('admin_mqtt_broker')),
                subtitle: Text(localization.tr('admin_hub_gateway')),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    localization.tr('admin_unknown'),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Resource Usage
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.memory, color: AppColors.info, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      localization.tr('admin_resource_usage'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text(localization.tr('admin_cpu')),
                trailing: const Text('--'),
              ),
              ListTile(
                title: Text(localization.tr('admin_memory')),
                trailing: const Text('--'),
              ),
              ListTile(
                title: Text(localization.tr('admin_storage')),
                trailing: const Text('--'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Actions
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.refresh, color: AppColors.info),
                title: Text(localization.tr('admin_check_status')),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localization.tr('common_loading'))),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.green),
                title: Text(localization.tr('admin_export_data')),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localization.tr('common_loading'))),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SETTINGS VIEW
// =============================================================================

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.username ?? 'Admin';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.adminPrimary,
                  radius: 28,
                  child: const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.adminPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          localization.tr('admin'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.adminPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Language settings
        _buildSectionTitle(localization.tr('settings_preferences')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(localization.tr('settings_language')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localization.currentLanguage.displayName,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: localization.currentLanguage == AppLanguage.hu,
                  onChanged: (value) {
                    localization.setLanguage(
                      value ? AppLanguage.hu : AppLanguage.en,
                    );
                  },
                  activeColor: AppColors.adminPrimary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // About
        _buildSectionTitle(localization.tr('settings_about')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(localization.tr('settings_about')),
            subtitle: Text('${localization.tr('version')} 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: localization.tr('app_name'),
                applicationVersion: '1.0.0',
                applicationLegalese:
                    '© 2025 ${localization.tr('app_subtitle')}',
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Logout button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(localization.tr('settings_logout')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
