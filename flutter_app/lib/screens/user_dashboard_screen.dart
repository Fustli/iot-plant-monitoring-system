import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/device_model.dart';
import '../models/plant_model.dart';
import '../models/plant_type_model.dart';
import '../widgets/plant_card.dart';
import '../widgets/alert_banner.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';
import '../services/plant_provider.dart';
import '../services/alert_provider.dart';
import '../services/auth_provider.dart';
import '../services/localization_service.dart';
import 'plant_detail_screen.dart';
import 'history_screen.dart';

/// Consumer/User dashboard with plants, devices, alerts, and settings
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
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
    final localization = context.watch<LocalizationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(localization)),
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
          _HomeView(),
          _PlantsView(),
          _DevicesView(),
          _AlertsView(),
          _SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: localization.tr('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_florist),
            label: localization.tr('nav_plants'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.devices),
            label: localization.tr('nav_devices'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.warning_amber),
            label: localization.tr('nav_alerts'),
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
        return localization.tr('nav_home');
      case 1:
        return localization.tr('plants_title');
      case 2:
        return localization.tr('devices_title');
      case 3:
        return localization.tr('alerts_title');
      case 4:
        return localization.tr('settings_title');
      default:
        return localization.tr('app_name');
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
    await Future.wait([
      context.read<PlantProvider>().refresh(),
      context.read<AlertProvider>().refresh(),
    ]);
  }
}

// =============================================================================
// HOME VIEW
// =============================================================================

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.username ?? 'User';

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
              '${localization.tr('home_hello')}, $username!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
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

            // Quick stats
            Text(
              localization.tr('home_quick_stats'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Consumer2<PlantProvider, AlertProvider>(
              builder: (context, plantProvider, alertProvider, child) {
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_florist,
                        title: localization.tr('home_total_plants'),
                        value: plantProvider.totalPlants.toString(),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.devices,
                        title: localization.tr('home_total_devices'),
                        value: '0', // TODO: Get from device provider
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.warning,
                        title: localization.tr('home_active_alerts'),
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

            // Plants needing attention
            Consumer<PlantProvider>(
              builder: (context, plantProvider, child) {
                final needsAttention = plantProvider.plantsNeedingAttention;

                if (needsAttention.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.tr('home_recent_alerts'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 12),
                      ...needsAttention.take(2).map((plant) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PlantCard(
                              plant: plant,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PlantDetailScreen(plantId: plant.id),
                                ),
                              ),
                              onWaterSuccess: (plantId) {
                                context
                                    .read<PlantProvider>()
                                    .loadPlantDetails(plantId);
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

            // History/Analytics card
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.info.withOpacity(0.1),
                  child: Icon(Icons.analytics, color: AppColors.info),
                ),
                title: Text(localization.tr('common_view_details')),
                subtitle: const Text('Plant History & Analytics'),
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
}

// =============================================================================
// PLANTS VIEW
// =============================================================================

class _PlantsView extends StatefulWidget {
  const _PlantsView();

  @override
  State<_PlantsView> createState() => _PlantsViewState();
}

class _PlantsViewState extends State<_PlantsView> {
  @override
  void initState() {
    super.initState();
    // Load plant types for the add dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantProvider>().loadPlantTypes();
    });
  }

  Future<void> _showAddPlantDialog(BuildContext context) async {
    final plantProvider = context.read<PlantProvider>();
    final localization = context.read<LocalizationProvider>();

    if (plantProvider.plantTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.tr('plants_no_types'))),
      );
      return;
    }

    PlantType? selectedType;
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(localization.tr('plants_add')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localization.tr('plants_select_type'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<PlantType>(
                  value: selectedType,
                  hint: Text(localization.tr('plants_select_type_hint')),
                  isExpanded: true,
                  items: plantProvider.plantTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text('${type.plantName} (${type.scientificName})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value;
                      if (value != null && nameController.text.isEmpty) {
                        nameController.text = value.plantName;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: localization.tr('plants_name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: localization.tr('plants_location'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: localization.tr('plants_notes'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(localization.tr('common_cancel')),
            ),
            ElevatedButton(
              onPressed: selectedType == null || nameController.text.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(localization.tr('common_add')),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedType != null && mounted) {
      final request = PlantFromDatabaseRequest(
        name: nameController.text,
        scientificName: selectedType!.scientificName,
        location:
            locationController.text.isNotEmpty ? locationController.text : null,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
      );

      final success = await plantProvider.createPlantFromDatabase(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? localization.tr('plants_added_success')
                : localization.tr('plants_added_error')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePlant(
      BuildContext context, String plantId, String plantName) async {
    final localization = context.read<LocalizationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('plants_delete')),
        content: Text(localization
            .tr('plants_delete_confirm')
            .replaceAll('{name}', plantName)),
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
      final plantProvider = context.read<PlantProvider>();
      final success = await plantProvider.deletePlant(int.parse(plantId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? localization.tr('plants_deleted_success')
                : localization.tr('plants_deleted_error')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    return Stack(
      children: [
        Consumer<PlantProvider>(
          builder: (context, plantProvider, child) {
            if (plantProvider.isLoading) {
              return Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (plantProvider.plants.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_florist,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(localization.tr('plants_empty')),
                    const SizedBox(height: 8),
                    Text(localization.tr('plants_add_first'),
                        style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPlantDialog(context),
                      icon: const Icon(Icons.add),
                      label: Text(localization.tr('plants_add')),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: plantProvider.refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plantProvider.plants.length,
                itemBuilder: (context, index) {
                  final plant = plantProvider.plants[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: Key(plant.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        await _confirmDeletePlant(
                            context, plant.id, plant.name);
                        return false; // We handle deletion ourselves
                      },
                      child: PlantCard(
                        plant: plant,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  PlantDetailScreen(plantId: plant.id),
                            ),
                          );
                        },
                        onWaterSuccess: (plantId) {
                          plantProvider.loadPlantDetails(plantId);
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        // FAB for adding plants
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddPlantDialog(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DEVICES VIEW
// =============================================================================

class _DevicesView extends StatefulWidget {
  const _DevicesView();

  @override
  State<_DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<_DevicesView> {
  final ApiService _apiService = ApiService();
  List<Device> _devices = [];
  List<Map<String, dynamic>> _deviceTypes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devices = await _apiService.getMyDevices();
      final deviceTypes = await _apiService.listAvailableDeviceTypes();
      setState(() {
        _devices = devices;
        _deviceTypes = deviceTypes;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.messageHu;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devices';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddDeviceDialog(BuildContext context) async {
    final localization = context.read<LocalizationProvider>();
    final plantProvider = context.read<PlantProvider>();

    if (_deviceTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.tr('devices_no_types'))),
      );
      return;
    }

    Map<String, dynamic>? selectedType;
    Plant? selectedPlant;
    final uniqueIdController = TextEditingController();
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(localization.tr('devices_add')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedType,
                  hint: Text(localization.tr('devices_select_type')),
                  isExpanded: true,
                  items: _deviceTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Plant>(
                  value: selectedPlant,
                  hint: Text(localization.tr('devices_select_plant')),
                  isExpanded: true,
                  items: plantProvider.plants.map((plant) {
                    return DropdownMenuItem(
                      value: plant,
                      child: Text(plant.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPlant = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uniqueIdController,
                  decoration: InputDecoration(
                    labelText: localization.tr('devices_unique_id'),
                    border: const OutlineInputBorder(),
                    hintText: 'e.g., SENSOR-001',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: localization.tr('devices_name'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: localization.tr('devices_location'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(localization.tr('common_cancel')),
            ),
            ElevatedButton(
              onPressed: selectedType == null ||
                      selectedPlant == null ||
                      uniqueIdController.text.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(localization.tr('common_add')),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        selectedType != null &&
        selectedPlant != null &&
        mounted) {
      try {
        await _apiService.registerDevice({
          'device_type_name': selectedType!['name'],
          'plant_id': int.parse(selectedPlant!.id),
          'unique_identifier': uniqueIdController.text,
          'device_name': nameController.text.isNotEmpty
              ? nameController.text
              : '${selectedType!['name']} Device',
          'is_active': true,
          'location_description': locationController.text.isNotEmpty
              ? locationController.text
              : null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('devices_added_success')),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
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

  Future<void> _confirmDeleteDevice(BuildContext context, Device device) async {
    final localization = context.read<LocalizationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('devices_delete')),
        content: Text(localization
            .tr('devices_delete_confirm')
            .replaceAll('{name}', device.deviceName)),
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
        await _apiService.removeDevice(device.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('devices_deleted_success')),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
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

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(localization.tr('common_retry')),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(localization.tr('devices_empty')),
            const SizedBox(height: 8),
            Text(localization.tr('devices_add_first'),
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddDeviceDialog(context),
              icon: const Icon(Icons.add),
              label: Text(localization.tr('devices_add')),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: device.isOnline
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    child: Icon(
                      Icons.sensors,
                      color: device.isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                  title: Text(
                    device.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device ID: ${device.uniqueIdentifier}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            device.isOnline ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: device.isOnline ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            device.isOnline
                                ? localization.tr('devices_online')
                                : localization.tr('devices_offline'),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  device.isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          if (device.batteryLevel != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.battery_std,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Text(
                              '${device.batteryLevel}%',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDeleteDevice(context, device),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: () => _showAddDeviceDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ALERTS VIEW
// =============================================================================

class _AlertsView extends StatelessWidget {
  const _AlertsView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    return Consumer<AlertProvider>(
      builder: (context, alertProvider, child) {
        if (alertProvider.isLoading) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (alertProvider.alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(localization.tr('alerts_none')),
                const SizedBox(height: 8),
                Text(localization.tr('home_no_alerts'),
                    style: TextStyle(color: Colors.grey[600])),
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

// =============================================================================
// SETTINGS VIEW
// =============================================================================

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final role = authProvider.currentRole;
    final username = authProvider.username ?? 'User';

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
                  backgroundColor: AppColors.primary,
                  radius: 28,
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 28),
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
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role?.displayNameHu ?? localization.tr('consumer'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
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
          child: Column(
            children: [
              ListTile(
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
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(localization.tr('settings_notifications')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localization.tr('common_loading'))),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // About
        _buildSectionTitle(localization.tr('settings_about')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(localization.tr('settings_about')),
                subtitle: Text('${localization.tr('version')} 1.0.0'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: localization.tr('app_name'),
                    applicationVersion: '1.0.0',
                    applicationLegalese:
                        '(c) 2025 ${localization.tr('app_subtitle')}',
                  );
                },
              ),
            ],
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
