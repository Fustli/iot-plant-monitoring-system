import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../services/auth_provider.dart';
import '../services/localization_service.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';
import '../widgets/empty_state.dart';

/// Manufacturer dashboard for device type management
class ManufacturerDashboardScreen extends StatefulWidget {
  const ManufacturerDashboardScreen({super.key});

  @override
  State<ManufacturerDashboardScreen> createState() =>
      _ManufacturerDashboardScreenState();
}

class _ManufacturerDashboardScreenState
    extends State<ManufacturerDashboardScreen> {
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
        backgroundColor: AppColors.manufacturerPrimary,
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
          _DeviceTypesView(),
          _SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.manufacturerPrimary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: localization.tr('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.category),
            label: localization.tr('manufacturer_device_types'),
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
        return localization.tr('manufacturer_title');
      case 1:
        return localization.tr('manufacturer_device_types');
      case 2:
        return localization.tr('settings_title');
      default:
        return localization.tr('manufacturer_title');
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
      case 1:
        // Device Types view
        final deviceTypesState = context.findAncestorStateOfType<_DeviceTypesViewState>();
        if (deviceTypesState != null) {
          await deviceTypesState._loadDeviceTypes();
        }
        break;
      default:
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
  final ApiService _apiService = ApiService();
  int _deviceTypesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final deviceTypes = await _apiService.listDeviceTypes();
      setState(() {
        _deviceTypesCount = deviceTypes.length;
      });
    } catch (e) {
      // Silently fail, show 0
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.username ?? 'Manufacturer';

    return RefreshIndicator(
      onRefresh: _loadStats,
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
                    color: AppColors.manufacturerPrimary,
                  ),
            ),
            const SizedBox(height: 24),

            // Stats card - only device types count
            _StatCard(
              icon: Icons.category,
              title: localization.tr('manufacturer_device_types'),
              value: _isLoading ? '...' : '$_deviceTypesCount',
              color: Colors.blue,
            ),

            const SizedBox(height: 24),

            // Quick actions
            Text(
              localization.tr('manufacturer_quick_actions'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.add_box, color: Colors.blue),
                ),
                title: Text(localization.tr('manufacturer_device_types')),
                subtitle:
                    Text(localization.tr('manufacturer_device_types_desc')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to device types tab
                  final state = context.findAncestorStateOfType<
                      _ManufacturerDashboardScreenState>();
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
// DEVICE TYPES VIEW
// =============================================================================

class _DeviceTypesView extends StatefulWidget {
  const _DeviceTypesView();

  @override
  State<_DeviceTypesView> createState() => _DeviceTypesViewState();
}

class _DeviceTypesViewState extends State<_DeviceTypesView> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _deviceTypes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceTypes();
  }

  Future<void> _loadDeviceTypes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _deviceTypes = await _apiService.listDeviceTypes();
    } on ApiException catch (e) {
      _error = e.messageHu;
    } catch (e) {
      _error = 'Failed to load device types';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
              onPressed: _loadDeviceTypes,
              child: Text(localization.tr('common_retry')),
            ),
          ],
        ),
      );
    }

    if (_deviceTypes.isEmpty) {
      return EmptyStateWidget(
        type: EmptyStateType.noData,
        title: localization.tr('manufacturer_no_device_types'),
        subtitle: localization.tr('manufacturer_add_first'),
        action: ElevatedButton.icon(
          onPressed: () => _showAddDeviceTypeDialog(context, localization),
          icon: const Icon(Icons.add),
          label: Text(localization.tr('common_add')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.manufacturerPrimary,
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadDeviceTypes,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _deviceTypes.length,
            itemBuilder: (context, index) {
              final deviceType = _deviceTypes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Icon(
                      _getDeviceIcon(deviceType['device_type'] ?? ''),
                      color: AppColors.manufacturerPrimary,
                    ),
                  ),
                  title: Text(
                    deviceType['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deviceType['device_type'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        deviceType['description'] ??
                            localization.tr('manufacturer_no_description'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (deviceType['is_active'] == true)
                              ? Colors.green.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (deviceType['is_active'] == true)
                              ? localization.tr('manufacturer_active')
                              : localization.tr('manufacturer_inactive'),
                          style: TextStyle(
                            fontSize: 12,
                            color: (deviceType['is_active'] == true)
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDeviceTypeDialog(
                                context, localization, deviceType);
                          } else if (value == 'delete') {
                            _confirmDeleteDeviceType(
                                context, localization, deviceType);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, size: 20),
                                const SizedBox(width: 8),
                                Text(localization.tr('common_edit')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  localization.tr('common_delete'),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
            onPressed: () => _showAddDeviceTypeDialog(context, localization),
            backgroundColor: AppColors.manufacturerPrimary,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'sensor':
        return Icons.sensors;
      case 'actuator':
        return Icons.settings_remote;
      case 'controller':
        return Icons.memory;
      default:
        return Icons.devices;
    }
  }

  Future<void> _showAddDeviceTypeDialog(
      BuildContext context, LocalizationProvider localization) async {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final descController = TextEditingController();
    final interfaceController = TextEditingController(text: 'MQTT');
    final functionsController = TextEditingController();
    final unitController = TextEditingController();
    final minController = TextEditingController(text: '0');
    final maxController = TextEditingController(text: '100');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localization.tr('manufacturer_device_types')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Type Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type (sensor/actuator/controller) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: interfaceController,
                decoration: const InputDecoration(
                  labelText: 'Communication Interface *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: functionsController,
                decoration: const InputDecoration(
                  labelText: 'Supported Capabilities (comma-separated) *',
                  border: OutlineInputBorder(),
                  hintText:
                      'temperature:read, humidity:write, light:read, moisture:write',
                  helperText: 'Format: metric:read or metric:write',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Data Unit *',
                  border: OutlineInputBorder(),
                  hintText: 'Celsius, %, etc.',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localization.tr('manufacturer_min_value'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localization.tr('manufacturer_max_value'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.manufacturerPrimary),
            child: Text(localization.tr('common_save')),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      if (nameController.text.isEmpty ||
          typeController.text.isEmpty ||
          functionsController.text.isEmpty ||
          unitController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('manufacturer_fill_required')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        await _apiService.registerDeviceType({
          'name': nameController.text,
          'device_type': typeController.text,
          'communication_interface': interfaceController.text,
          'supported_functions': functionsController.text,
          'data_unit': unitController.text,
          'min_value': double.tryParse(minController.text) ?? 0,
          'max_value': double.tryParse(maxController.text) ?? 100,
          'is_active': true,
          'description':
              descController.text.isNotEmpty ? descController.text : null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('manufacturer_device_registered')),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeviceTypes();
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

  Future<void> _showEditDeviceTypeDialog(
      BuildContext context,
      LocalizationProvider localization,
      Map<String, dynamic> deviceType) async {
    final nameController =
        TextEditingController(text: deviceType['name'] ?? '');
    final typeController =
        TextEditingController(text: deviceType['device_type'] ?? '');
    final descController =
        TextEditingController(text: deviceType['description'] ?? '');
    final interfaceController = TextEditingController(
        text: deviceType['communication_interface'] ?? 'MQTT');
    final functionsController =
        TextEditingController(text: deviceType['supported_functions'] ?? '');
    final unitController =
        TextEditingController(text: deviceType['data_unit'] ?? '');
    final minController =
        TextEditingController(text: (deviceType['min_value'] ?? 0).toString());
    final maxController = TextEditingController(
        text: (deviceType['max_value'] ?? 100).toString());
    bool isActive = deviceType['is_active'] ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(localization.tr('manufacturer_edit_device_type')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Device Type Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Type (sensor/actuator/controller) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interfaceController,
                  decoration: const InputDecoration(
                    labelText: 'Communication Interface *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: functionsController,
                  decoration: const InputDecoration(
                    labelText: 'Supported Capabilities (comma-separated) *',
                    border: OutlineInputBorder(),
                    hintText: 'temperature:read, humidity:write',
                    helperText: 'Format: metric:read or metric:write',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Data Unit *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: localization.tr('manufacturer_min_value'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: localization.tr('manufacturer_max_value'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(localization.tr('manufacturer_active')),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: localization.tr('admin_description'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.manufacturerPrimary),
              child: Text(localization.tr('common_save')),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      if (nameController.text.isEmpty ||
          typeController.text.isEmpty ||
          functionsController.text.isEmpty ||
          unitController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('manufacturer_fill_required')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        await _apiService.updateDeviceType(deviceType['id'], {
          'name': nameController.text,
          'device_type': typeController.text,
          'communication_interface': interfaceController.text,
          'supported_functions': functionsController.text,
          'data_unit': unitController.text,
          'min_value': double.tryParse(minController.text) ?? 0,
          'max_value': double.tryParse(maxController.text) ?? 100,
          'is_active': isActive,
          'description':
              descController.text.isNotEmpty ? descController.text : null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(localization.tr('manufacturer_device_type_updated')),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeviceTypes();
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

  Future<void> _confirmDeleteDeviceType(
      BuildContext context,
      LocalizationProvider localization,
      Map<String, dynamic> deviceType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('manufacturer_delete_device_type')),
        content: Text(localization
            .tr('manufacturer_delete_device_type_confirm')
            .replaceAll('{name}', deviceType['name'] ?? 'Unknown')),
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
        await _apiService.deleteDeviceType(deviceType['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(localization.tr('manufacturer_device_type_deleted')),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeviceTypes();
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
    final username = authProvider.username ?? 'Manufacturer';

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
                  backgroundColor: AppColors.manufacturerPrimary,
                  radius: 28,
                  child: const Icon(Icons.precision_manufacturing,
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
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          localization.tr('manufacturer'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.manufacturerPrimary,
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
                  activeColor: AppColors.manufacturerPrimary,
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
