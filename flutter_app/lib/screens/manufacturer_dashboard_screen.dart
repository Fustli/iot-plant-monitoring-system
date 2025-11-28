import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../services/localization_service.dart';

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
        backgroundColor: Colors.blue[700],
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
          _DeviceInstancesView(),
          _SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue[700],
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Devices',
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
        return localization.tr('manufacturer_register_device');
      case 3:
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
    // TODO: Refresh manufacturer data
  }
}

// =============================================================================
// DASHBOARD VIEW
// =============================================================================

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.username ?? 'Manufacturer';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Text(
            '${localization.tr('home_hello')}, $username! 🏭',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
          ),
          const SizedBox(height: 24),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.category,
                  title: localization.tr('manufacturer_device_types'),
                  value: '0',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.devices,
                  title: 'Registered',
                  value: '0',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  title: 'Claimed',
                  value: '0',
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick actions
          Text(
            'Quick Actions',
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
              subtitle: Text(localization.tr('manufacturer_device_types_desc')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to device types tab
                final state = context.findAncestorStateOfType<
                    _ManufacturerDashboardScreenState>();
                state?._pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.qr_code, color: Colors.green),
              ),
              title: Text(localization.tr('manufacturer_register_device')),
              subtitle:
                  Text(localization.tr('manufacturer_register_device_desc')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to device instances tab
                final state = context.findAncestorStateOfType<
                    _ManufacturerDashboardScreenState>();
                state?._pageController.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ],
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

class _DeviceTypesView extends StatelessWidget {
  const _DeviceTypesView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    // TODO: Implement device types list
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No device types yet'),
          const SizedBox(height: 8),
          Text(
            'Register your first device type',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showAddDeviceTypeDialog(context, localization);
            },
            icon: const Icon(Icons.add),
            label: Text(localization.tr('common_add')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceTypeDialog(
      BuildContext context, LocalizationProvider localization) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('manufacturer_device_types')),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Device Type Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localization.tr('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localization.tr('common_loading'))),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            child: Text(localization.tr('common_save')),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DEVICE INSTANCES VIEW
// =============================================================================

class _DeviceInstancesView extends StatelessWidget {
  const _DeviceInstancesView();

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    // TODO: Implement device instances list
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No device instances registered'),
          const SizedBox(height: 8),
          Text(
            'Register device instances for users to claim',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showAddDeviceInstanceDialog(context, localization);
            },
            icon: const Icon(Icons.add),
            label: Text(localization.tr('manufacturer_register_device')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDeviceInstanceDialog(
      BuildContext context, LocalizationProvider localization) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localization.tr('manufacturer_register_device')),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Serial Number / Unique ID',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Device Type',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localization.tr('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localization.tr('common_loading'))),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            child: Text(localization.tr('common_save')),
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
    final username = authProvider.username ?? 'Manufacturer';
    final isDemoMode = authProvider.isDemoMode;

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
                  backgroundColor: Colors.blue[700],
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
                          localization.tr('demo_manufacturer'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isDemoMode) ...[
                        const SizedBox(height: 4),
                        Text(
                          localization.tr('demo_title'),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
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
                  activeColor: Colors.blue[700],
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
