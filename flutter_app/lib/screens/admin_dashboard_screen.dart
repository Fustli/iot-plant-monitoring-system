import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/hub_model.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';
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
    // Trigger refresh on the current page
    switch (_selectedIndex) {
      case 0:
        // Dashboard view
        final dashboardState = context.findAncestorStateOfType<_DashboardViewState>();
        if (dashboardState != null) {
          await dashboardState._loadStats();
        }
        break;
      case 3:
        // System view
        final systemState = context.findAncestorStateOfType<_SystemViewState>();
        if (systemState != null) {
          await systemState._handleRefresh();
        }
        break;
      default:
        // Other views handle their own refresh via RefreshIndicator
        break;
    }
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

class _SystemView extends StatefulWidget {
  const _SystemView();

  @override
  State<_SystemView> createState() => _SystemViewState();
}

class _SystemViewState extends State<_SystemView> {
  final ApiService _apiService = ApiService();
  List<Hub> _hubs = [];
  bool _isLoadingHubs = false;
  Map<String, dynamic>? _systemStatus;
  bool _isLoadingStatus = false;
  Timer? _refreshTimer;
  int _debugTapCount = 0;
  bool _showDebugView = false;

  @override
  void initState() {
    super.initState();
    _loadHubs();
    _loadSystemStatus();
    // Auto-refresh system status every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadSystemStatus();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHubs() async {
    setState(() => _isLoadingHubs = true);
    try {
      final hubs = await _apiService.adminListAllHubs();
      setState(() => _hubs = hubs);
    } catch (e) {
      // Silently handle - admin may not have hubs
    } finally {
      setState(() => _isLoadingHubs = false);
    }
  }

  Future<void> _loadSystemStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final status = await authProvider.apiClient.getSystemStatus();
      if (mounted) {
        setState(() => _systemStatus = status);
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  void _handleDebugTap() {
    setState(() {
      _debugTapCount++;
      if (_debugTapCount >= 5) {
        _showDebugView = true;
        _debugTapCount = 0;
      }
    });
    // Reset counter after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _debugTapCount < 5) {
        setState(() {
          _debugTapCount = 0;
        });
      }
    });
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadHubs(),
      _loadSystemStatus(),
    ]);
  }

  Future<void> _showPreProvisionHubDialog(BuildContext context) async {
    final localization = context.read<LocalizationProvider>();
    final serialController = TextEditingController();
    final nameController = TextEditingController();
    bool isCreating = false;
    String? errorMessage;
    String serialText = '';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(localization.tr('admin_preprovision_hub')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.tr('admin_preprovision_hub_info'),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serialController,
                  decoration: InputDecoration(
                    labelText: localization.tr('admin_hub_serial'),
                    border: const OutlineInputBorder(),
                    hintText: 'e.g., hub-serial-123',
                    errorText: errorMessage,
                  ),
                  enabled: !isCreating,
                  onChanged: (value) {
                    setDialogState(() {
                      serialText = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: localization.tr('admin_hub_name_optional'),
                    border: const OutlineInputBorder(),
                    hintText: 'e.g., Kitchen Hub',
                  ),
                  enabled: !isCreating,
                ),
                if (isCreating)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isCreating ? null : () => Navigator.pop(dialogContext, false),
              child: Text(localization.tr('common_cancel')),
            ),
            ElevatedButton(
              onPressed: isCreating || serialText.isEmpty
                  ? null
                  : () async {
                      setDialogState(() {
                        isCreating = true;
                        errorMessage = null;
                      });

                      try {
                        await _apiService.adminCreateHub(
                          serial: serialController.text.trim(),
                          name: nameController.text.isNotEmpty
                              ? nameController.text.trim()
                              : null,
                        );
                        if (context.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          errorMessage = e.messageHu;
                          isCreating = false;
                        });
                      } catch (e) {
                        setDialogState(() {
                          errorMessage = 'Failed to create hub';
                          isCreating = false;
                        });
                      }
                    },
              child: Text(localization.tr('common_create')),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadHubs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('admin_hub_created')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteHub(BuildContext context, Hub hub) async {
    final localization = context.read<LocalizationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('admin_delete_hub')),
        content: Text(localization
            .tr('admin_delete_hub_confirm')
            .replaceAll('{serial}', hub.serial)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localization.tr('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(localization.tr('common_delete')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _apiService.adminDeleteHub(hub.id);
        await _loadHubs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('admin_hub_deleted')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.messageHu),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSystemHealthCard(BuildContext context, LocalizationProvider localization) {
    final appStatus = _systemStatus?['application'] as String? ?? 'unknown';
    final dbStatus = _systemStatus?['database'] as String? ?? 'unknown';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _handleDebugTap,
              child: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red[400], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'System Health',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_debugTapCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '($_debugTapCount/5)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHealthIndicator(
                    context,
                    'Application',
                    appStatus,
                    Icons.cloud,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHealthIndicator(
                    context,
                    'Database',
                    dbStatus,
                    Icons.storage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(BuildContext context, String label, String status, IconData icon) {
    final isHealthy = status == 'ok' || status == 'running' || status == 'connected' || status == 'healthy';
    final color = isHealthy ? Colors.green : (status == 'error' ? Colors.red : Colors.grey);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context, LocalizationProvider localization) {
    final stats = _systemStatus?['stats'] as Map<String, dynamic>?;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.info, size: 24),
                const SizedBox(width: 12),
                Text(
                  'System Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip(
                  context,
                  'Users',
                  stats?['users_total']?.toString() ?? '0',
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatChip(
                  context,
                  'Consumers',
                  stats?['consumers_count']?.toString() ?? '0',
                  Icons.person,
                  Colors.green,
                ),
                _buildStatChip(
                  context,
                  'Manufacturers',
                  stats?['manufacturers_count']?.toString() ?? '0',
                  Icons.factory,
                  Colors.orange,
                ),
                _buildStatChip(
                  context,
                  'Admins',
                  stats?['admins_count']?.toString() ?? '0',
                  Icons.admin_panel_settings,
                  Colors.red,
                ),
                _buildStatChip(
                  context,
                  'Plants',
                  stats?['plants_count']?.toString() ?? '0',
                  Icons.eco,
                  Colors.lightGreen,
                ),
                _buildStatChip(
                  context,
                  'Devices',
                  stats?['devices_count']?.toString() ?? '0',
                  Icons.devices,
                  Colors.purple,
                ),
                _buildStatChip(
                  context,
                  'Device Types',
                  stats?['device_types_count']?.toString() ?? '0',
                  Icons.category,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, LocalizationProvider localization) {
    Color color;
    String text;
    
    switch (status.toLowerCase()) {
      case 'ok':
      case 'running':
      case 'connected':
      case 'healthy':
        color = Colors.green;
        text = localization.tr('admin_online');
        break;
      case 'error':
      case 'failed':
        color = Colors.red;
        text = 'Error';
        break;
      default:
        color = Colors.grey;
        text = localization.tr('admin_unknown');
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    if (_showDebugView) {
      return _buildDebugView(context, localization);
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // System Health Overview
          if (_systemStatus != null) ...[
            _buildSystemHealthCard(context, localization),
            const SizedBox(height: 16),
            _buildStatisticsCard(context, localization),
            const SizedBox(height: 16),
          ],

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
                  trailing: _buildStatusBadge(
                    _systemStatus != null ? (_systemStatus!['application'] as String? ?? 'unknown') : 'unknown',
                    localization,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(localization.tr('admin_database')),
                  subtitle: Text(localization.tr('admin_postgresql')),
                  trailing: _buildStatusBadge(
                    _systemStatus != null ? (_systemStatus!['database'] as String? ?? 'unknown') : 'unknown',
                    localization,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(localization.tr('admin_mqtt_broker')),
                  subtitle: Text(localization.tr('admin_hub_gateway')),
                  trailing: _buildStatusBadge('unknown', localization),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Hub Management
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.router, color: AppColors.adminPrimary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localization.tr('admin_hub_management'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      color: AppColors.adminPrimary,
                      onPressed: () => _showPreProvisionHubDialog(context),
                      tooltip: localization.tr('admin_preprovision_hub'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_isLoadingHubs)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hubs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.router_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          localization.tr('admin_no_hubs'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showPreProvisionHubDialog(context),
                          icon: const Icon(Icons.add),
                          label:
                              Text(localization.tr('admin_preprovision_hub')),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._hubs.map((hub) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hub.isActive
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        child: Icon(
                          Icons.router,
                          color: hub.isActive ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(hub.displayName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Serial: ${hub.serial}'),
                          Row(
                            children: [
                              Icon(
                                hub.isActive
                                    ? Icons.check_circle
                                    : Icons.pending,
                                size: 12,
                                color:
                                    hub.isActive ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hub.isActive
                                    ? localization.tr('admin_activated')
                                    : localization
                                        .tr('admin_pending_activation'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hub.isActive
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              if (hub.userId != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '• ${localization.tr('admin_claimed')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteHub(context, hub),
                      ),
                    )),
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
      ),
    );
  }

  Widget _buildDebugView(BuildContext context, LocalizationProvider localization) {
    if (_systemStatus == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(localization.tr('common_loading')),
          ],
        ),
      );
    }

    final users = _systemStatus!['users'] as List? ?? [];
    final plants = _systemStatus!['plants'] as List? ?? [];
    final devices = _systemStatus!['devices'] as List? ?? [];
    final deviceTypes = _systemStatus!['device_types'] as List? ?? [];
    final consumers = _systemStatus!['consumers'] as List? ?? [];
    final manufacturers = _systemStatus!['manufacturers'] as List? ?? [];
    final stats = _systemStatus!['stats'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug View - System Data'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _showDebugView = false;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSystemStatus,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSystemStatus,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Backend Developer Debug Mode - Full System State',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // System Status
            _buildDebugSection(
              context,
              'System Status',
              Icons.monitor_heart,
              Colors.red,
              [
                {'Application': _systemStatus!['application']},
                {'Database': _systemStatus!['database']},
              ],
            ),
            const SizedBox(height: 16),

            // Statistics
            _buildDebugSection(
              context,
              'Statistics Overview',
              Icons.analytics,
              Colors.blue,
              [
                {'Total Users': stats['users_total']},
                {'Consumers': stats['consumers_count']},
                {'Manufacturers': stats['manufacturers_count']},
                {'Admins': stats['admins_count']},
                {'Plants': stats['plants_count']},
                {'Devices': stats['devices_count']},
                {'Device Types': stats['device_types_count']},
              ],
            ),
            const SizedBox(height: 16),

            // Users
            _buildDebugListSection(
              context,
              'Users (${users.length})',
              Icons.people,
              Colors.purple,
              users,
              (user) => _buildUserDebugCard(user),
            ),
            const SizedBox(height: 16),

            // Plants
            _buildDebugListSection(
              context,
              'Plants (${plants.length})',
              Icons.eco,
              Colors.green,
              plants,
              (plant) => _buildPlantDebugCard(plant),
            ),
            const SizedBox(height: 16),

            // Devices
            _buildDebugListSection(
              context,
              'Devices (${devices.length})',
              Icons.devices,
              Colors.teal,
              devices,
              (device) => _buildDeviceDebugCard(device),
            ),
            const SizedBox(height: 16),

            // Device Types
            _buildDebugListSection(
              context,
              'Device Types (${deviceTypes.length})',
              Icons.category,
              Colors.orange,
              deviceTypes,
              (deviceType) => _buildDeviceTypeDebugCard(deviceType),
            ),
            const SizedBox(height: 16),

            // Runtime Consumers
            _buildDebugListSection(
              context,
              'Runtime Consumers (${consumers.length})',
              Icons.person,
              Colors.indigo,
              consumers,
              (consumer) => _buildConsumerDebugCard(consumer),
            ),
            const SizedBox(height: 16),

            // Runtime Manufacturers
            _buildDebugListSection(
              context,
              'Runtime Manufacturers (${manufacturers.length})',
              Icons.factory,
              Colors.deepOrange,
              manufacturers,
              (manufacturer) => _buildManufacturerDebugCard(manufacturer),
            ),
            const SizedBox(height: 24),

            // Raw JSON Data Section
            Card(
              color: Colors.grey[900],
              child: ExpansionTile(
                leading: const Icon(Icons.code, color: Colors.white),
                title: const Text(
                  'Raw API Response (JSON)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.black,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        _formatJson(_systemStatus!),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final jsonString = _formatJson(_systemStatus!);
                            await Clipboard.setData(ClipboardData(text: jsonString));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('JSON copied to clipboard!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy JSON'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  Widget _buildDebugSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> items,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...items.map((item) {
              final key = item.keys.first;
              final value = item[key];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$key:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      value?.toString() ?? 'null',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugListSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List items,
    Widget Function(dynamic) itemBuilder,
  ) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: items.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No data available'),
                )
              ]
            : items.map((item) => itemBuilder(item)).toList(),
      ),
    );
  }

  Widget _buildUserDebugCard(dynamic user) {
    final plants = _systemStatus!['plants'] as List? ?? [];
    final userPlants = plants.where((p) => p['user_id'] == user['id']).toList();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  user['role'] == 'admin' 
                    ? Icons.admin_panel_settings
                    : user['role'] == 'manufacturer'
                      ? Icons.factory
                      : Icons.person,
                  size: 20,
                  color: Colors.purple[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${user['username']} (ID: ${user['id']})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDebugRow('Email', user['email']),
            _buildDebugRow('Role', user['role']),
            _buildDebugRow('Active', user['is_active']?.toString() ?? 'null'),
            _buildDebugRow('Created', user['created_at'] ?? 'null'),
            
            // Show user's plants and their devices
            if (userPlants.isNotEmpty) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.eco, size: 16, color: Colors.green[800]),
                  const SizedBox(width: 6),
                  Text(
                    'Plants owned (${userPlants.length}):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...userPlants.map((plant) {
                final plantDevices = (plant['devices'] as List? ?? [])
                    .where((d) => d != null)
                    .toList();
                
                return Container(
                  margin: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_florist, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${plant['name']} (Plant ID: ${plant['id']})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (plant['scientific_name'] != null) ... [
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            'Scientific: ${plant['scientific_name']}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                      if (plantDevices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Row(
                            children: [
                              Icon(Icons.sensors, size: 12, color: Colors.teal[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Connected Devices (${plantDevices.length}):',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...plantDevices.map((device) => Padding(
                          padding: const EdgeInsets.only(left: 36, top: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.teal[600],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${device['name']} (ID: ${device['id']}, Type: ${device['device_type'] ?? 'N/A'})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ] else ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            'No devices connected',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ] else if (user['role'] == 'consumer') ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'No plants registered yet',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlantDebugCard(dynamic plant) {
    final devices = plant['devices'] as List? ?? [];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plant['name']} (ID: ${plant['id']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildDebugRow('Scientific Name', plant['scientific_name']),
            _buildDebugRow('Owner User ID', plant['user_id']?.toString()),
            _buildDebugRow('Light Preference', plant['light_preference']),
            _buildDebugRow('Water Needs', plant['water_needs']),
            _buildDebugRow('Devices Count', devices.length.toString()),
            if (devices.isNotEmpty) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.sensors, size: 16, color: Colors.teal[800]),
                  const SizedBox(width: 6),
                  Text(
                    'Connected Devices (${devices.length}):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...devices.map((d) => Container(
                    margin: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.device_hub, size: 14, color: Colors.teal[700]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${d['name']} (Device ID: ${d['id']})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Type: ${d['device_type'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                              ),
                              if (d['manufacturer_id'] != null)
                                Text(
                                  'Manufacturer ID: ${d['manufacturer_id']}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                ),
                              Text(
                                'Active: ${d['is_active']?.toString() ?? 'unknown'}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ] else ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'No devices connected yet',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDebugCard(dynamic device) {
    final plants = _systemStatus!['plants'] as List? ?? [];
    final connectedPlant = device['plant_id'] != null
        ? plants.firstWhere(
            (p) => p['id'] == device['plant_id'],
            orElse: () => null,
          )
        : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.teal[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.device_hub, size: 20, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${device['name']} (ID: ${device['id']})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDebugRow('Type', device['device_type']),
            _buildDebugRow('Manufacturer ID', device['manufacturer_id']?.toString()),
            _buildDebugRow('Active', device['is_active']?.toString() ?? 'null'),
            _buildDebugRow('Last Seen', device['last_seen'] ?? 'never'),
            
            if (connectedPlant != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.eco, size: 16, color: Colors.green[800]),
                  const SizedBox(width: 6),
                  Text(
                    'Connected to Plant:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_florist, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${connectedPlant['name']} (Plant ID: ${connectedPlant['id']})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (connectedPlant['scientific_name'] != null)
                            Text(
                              'Scientific: ${connectedPlant['scientific_name']}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            ),
                          Text(
                            'Owner User ID: ${connectedPlant['user_id']}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Not connected to any plant',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeDebugCard(dynamic deviceType) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${deviceType['name']} (ID: ${deviceType['id']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildDebugRow('Type', deviceType['device_type']),
            _buildDebugRow('Manufacturer ID', deviceType['manufacturer_id']?.toString()),
            _buildDebugRow(
              'Supported Functions',
              deviceType['supported_functions_formatted'] ?? deviceType['supported_functions'] ?? 'none',
            ),
            if (deviceType['description'] != null)
              _buildDebugRow('Description', deviceType['description']),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumerDebugCard(dynamic consumer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.indigo[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${consumer['username']} (ID: ${consumer['id']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildDebugRow('Runtime State', 'Active in SystemState'),
            _buildDebugRow(
              'Plants Count',
              (consumer['plants'] as List?)?.length.toString() ?? '0',
            ),
            if (consumer['email'] != null)
              _buildDebugRow('Email', consumer['email']),
          ],
        ),
      ),
    );
  }

  Widget _buildManufacturerDebugCard(dynamic manufacturer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.deepOrange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${manufacturer['username']} (ID: ${manufacturer['id']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildDebugRow('Runtime State', 'Active in SystemState'),
            if (manufacturer['email'] != null)
              _buildDebugRow('Email', manufacturer['email']),
            if (manufacturer['company_name'] != null)
              _buildDebugRow('Company', manufacturer['company_name']),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'null',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
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
