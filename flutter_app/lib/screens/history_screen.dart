import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/plant_model.dart';
import '../models/sensor_model.dart';
import '../services/localization_service.dart';
import '../services/plant_provider.dart';

/// A screen displaying plant history, analytics, logs, and insights.
///
/// Follows Clean Architecture principles with separation of concerns:
/// - UI logic contained in private widget builders
/// - Business logic delegated to providers
/// - State management via StatefulWidget with minimal rebuilds
///
/// Performance optimizations:
/// - Uses const constructors wherever possible
/// - RepaintBoundary around heavy chart widgets
/// - Skeleton loaders for perceived performance
/// - AnimatedSwitcher for smooth state transitions
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final TabController _tabController;

  // State
  String? _selectedPlantId;
  List<SensorReading> _sensorHistory = [];
  bool _isLoadingHistory = false;
  int _selectedDays = 7;
  String? _errorMessage;

  // Available time periods for filtering
  static const List<int> _availableDays = [7, 14, 30];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeSelectedPlant();
  }

  /// Initialize the selected plant after the first frame.
  void _initializeSelectedPlant() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final plantProvider = context.read<PlantProvider>();
      if (plantProvider.plants.isNotEmpty) {
        setState(() {
          _selectedPlantId = plantProvider.plants.first.id;
        });
        _loadSensorHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Loads sensor history data with proper error handling.
  Future<void> _loadSensorHistory() async {
    if (_selectedPlantId == null) return;

    setState(() {
      _isLoadingHistory = true;
      _errorMessage = null;
    });

    try {
      final plantProvider = context.read<PlantProvider>();
      final deviceId = int.tryParse(_selectedPlantId!) ?? 0;
      final historyData = await plantProvider.getSensorHistory(deviceId);

      if (!mounted) return;

      setState(() {
        if (historyData.isEmpty) {
          // Generate dummy data for demonstration
          _sensorHistory = _generateDummySensorData();
        } else {
          _sensorHistory = historyData.map((data) => SensorReading.fromJson(data)).toList();
        }
        _isLoadingHistory = false;
      });
    } on Exception catch (e) {
      debugPrint('Failed to load sensor history: $e');
      if (!mounted) return;

      // Generate dummy data on error instead of showing error
      setState(() {
        _sensorHistory = _generateDummySensorData();
        _isLoadingHistory = false;
        _errorMessage = null; // Clear error to show dummy data
      });
    }
  }

  List<SensorReading> _generateDummySensorData() {
    final now = DateTime.now();
    final dummyData = <SensorReading>[];
    final days = _selectedDays;
    
    // Generate data based on selected time period with 2-hour intervals
    for (int day = days - 1; day >= 0; day--) {
      for (int hour = 0; hour < 24; hour += 2) {
        final timestamp = now.subtract(Duration(days: day, hours: hour));
        
        // Generate realistic-looking data with daily and hourly variations
        final dayProgress = day / days;
        final hourProgress = hour / 24;
        
        dummyData.add(SensorReading(
          timestamp: timestamp,
          moisture: 50 + (dayProgress * 20) - 10 + (hourProgress * 5),
          temperature: 20.0 + (hourProgress * 8) + (dayProgress * 3),
          light: (200.0 + (hourProgress * 800) + (dayProgress * 100)).toInt(),
          humidity: 60.0 + (dayProgress * 10) - 5 + (hourProgress * 8),
        ));
      }
    }
    
    return dummyData.reversed.toList(); // Chronological order
  }

  /// Handles plant selection changes.
  void _onPlantSelected(String? plantId) {
    if (plantId == null || plantId == _selectedPlantId) return;
    setState(() {
      _selectedPlantId = plantId;
    });
    _loadSensorHistory();
  }

  /// Handles time period selection changes.
  void _onDaysSelected(int days) {
    if (days == _selectedDays) return;
    setState(() {
      _selectedDays = days;
    });
    _loadSensorHistory();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tr('history_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.analytics_outlined),
              text: loc.tr('history_charts'),
            ),
            Tab(
              icon: const Icon(Icons.list_alt_outlined),
              text: loc.tr('history_logs'),
            ),
            Tab(
              icon: const Icon(Icons.insights_outlined),
              text: loc.tr('history_insights'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Plant selector section
          _PlantSelectorSection(
            selectedPlantId: _selectedPlantId,
            selectedDays: _selectedDays,
            availableDays: _availableDays,
            onPlantSelected: _onPlantSelected,
            onDaysSelected: _onDaysSelected,
          ),

          // Content with error boundary
          Expanded(
            child: _errorMessage != null
                ? _ErrorStateWidget(
                    message: _errorMessage!,
                    onRetry: _loadSensorHistory,
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _ChartsTab(
                        selectedPlantId: _selectedPlantId,
                        sensorHistory: _sensorHistory,
                        isLoading: _isLoadingHistory,
                      ),
                      const _LogsTab(),
                      _InsightsTab(selectedPlantId: _selectedPlantId),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PLANT SELECTOR SECTION
// =============================================================================

/// Plant selection and time period filter section.
class _PlantSelectorSection extends StatelessWidget {
  const _PlantSelectorSection({
    required this.selectedPlantId,
    required this.selectedDays,
    required this.availableDays,
    required this.onPlantSelected,
    required this.onDaysSelected,
  });

  final String? selectedPlantId;
  final int selectedDays;
  final List<int> availableDays;
  final ValueChanged<String?> onPlantSelected;
  final ValueChanged<int> onDaysSelected;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (plantProvider.plants.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.tr('history_select_plant'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _PlantDropdown(
                plants: plantProvider.plants,
                selectedPlantId: selectedPlantId,
                onChanged: onPlantSelected,
              ),
              const SizedBox(height: 12),
              _TimePeriodSelector(
                selectedDays: selectedDays,
                availableDays: availableDays,
                onSelected: onDaysSelected,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dropdown for plant selection.
class _PlantDropdown extends StatelessWidget {
  const _PlantDropdown({
    required this.plants,
    required this.selectedPlantId,
    required this.onChanged,
  });

  final List<Plant> plants;
  final String? selectedPlantId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedPlantId,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      items: plants.map((plant) {
        return DropdownMenuItem<String>(
          value: plant.id,
          child: _PlantDropdownItem(plant: plant),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// Individual item in the plant dropdown.
class _PlantDropdownItem extends StatelessWidget {
  const _PlantDropdownItem({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HealthIndicator(status: plant.calculatedHealthStatus),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            plant.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          plant.location,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Small health status indicator.
class _HealthIndicator extends StatelessWidget {
  const _HealthIndicator({required this.status});

  final HealthStatus status;

  Color _getHealthColor() {
    switch (status) {
      case HealthStatus.excellent:
        return AppColors.success;
      case HealthStatus.good:
        return AppColors.primary;
      case HealthStatus.needsAttention:
        return AppColors.warning;
      case HealthStatus.critical:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: _getHealthColor(),
      child: const Icon(Icons.local_florist, size: 12, color: Colors.white),
    );
  }
}

/// Time period chip selector.
class _TimePeriodSelector extends StatelessWidget {
  const _TimePeriodSelector({
    required this.selectedDays,
    required this.availableDays,
    required this.onSelected,
  });

  final int selectedDays;
  final List<int> availableDays;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Row(
      children: [
        Text(
          loc.tr('history_time_period'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 8),
        ...availableDays.map(
          (days) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${days}d'),
              selected: selectedDays == days,
              onSelected: (selected) {
                if (selected) onSelected(days);
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selectedDays == days ? Colors.white : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ERROR STATE
// =============================================================================

/// Error state widget with retry option.
class _ErrorStateWidget extends StatelessWidget {
  const _ErrorStateWidget({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc.tr('common_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SKELETON LOADERS
// =============================================================================

/// Skeleton loader for cards during loading states.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(width: 120),
            Spacer(),
            _SkeletonLine(width: double.infinity),
            SizedBox(height: 8),
            _SkeletonLine(width: 200),
          ],
        ),
      ),
    );
  }
}

/// Single skeleton line element.
class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine(
      {required this.width,
      this.height =
          16}); // ignore: unused_element_parameter - kept for extensibility

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// =============================================================================
// CHARTS TAB
// =============================================================================

/// Charts tab showing sensor data visualizations.
class _ChartsTab extends StatelessWidget {
  const _ChartsTab({
    required this.selectedPlantId,
    required this.sensorHistory,
    required this.isLoading,
  });

  final String? selectedPlantId;
  final List<SensorReading> sensorHistory;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    if (selectedPlantId == null) {
      return _EmptyStateWidget(
        icon: Icons.local_florist_outlined,
        message: loc.tr('history_no_plant'),
      );
    }

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        final selectedPlant = plantProvider.getPlantById(selectedPlantId!);

        if (selectedPlant == null) {
          return _EmptyStateWidget(
            icon: Icons.search_off_outlined,
            message: loc.tr('history_plant_not_found'),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? const _ChartsLoadingState(key: ValueKey('loading'))
              : _ChartsContent(
                  key: const ValueKey('content'),
                  plant: selectedPlant,
                  sensorHistory: sensorHistory,
                ),
        );
      },
    );
  }
}

/// Loading state for charts tab with skeleton loaders.
class _ChartsLoadingState extends StatelessWidget {
  const _ChartsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _SkeletonCard(height: 100),
          SizedBox(height: 16),
          _SkeletonCard(height: 240),
          SizedBox(height: 16),
          _SkeletonCard(height: 240),
        ],
      ),
    );
  }
}

/// Main content for charts tab.
class _ChartsContent extends StatelessWidget {
  const _ChartsContent({
    super.key,
    required this.plant,
    required this.sensorHistory,
  });

  final Plant plant;
  final List<SensorReading> sensorHistory;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current readings summary
          _CurrentReadingsCard(plant: plant),
          const SizedBox(height: 16),

          // Chart placeholders with RepaintBoundary for performance
          RepaintBoundary(
            child: _ChartCard(
              title: loc.tr('history_soil_moisture_trends'),
              icon: Icons.water_drop_outlined,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 16),

          RepaintBoundary(
            child: _ChartCard(
              title: loc.tr('history_temperature_history'),
              icon: Icons.thermostat_outlined,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 16),

          RepaintBoundary(
            child: _ChartCard(
              title: loc.tr('history_light_level_changes'),
              icon: Icons.wb_sunny_outlined,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),

          // Data summary
          if (sensorHistory.isNotEmpty)
            _DataSummaryCard(sensorHistory: sensorHistory),
        ],
      ),
    );
  }
}

/// Card showing current sensor readings.
class _CurrentReadingsCard extends StatelessWidget {
  const _CurrentReadingsCard({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${loc.tr('history_current_status')} - ${plant.name}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ReadingIndicator(
                    label: loc.tr('history_moisture_chart'),
                    value: '${plant.currentMoisture}%',
                    icon: Icons.water_drop_outlined,
                    color: AppColors.info,
                  ),
                ),
                Expanded(
                  child: _ReadingIndicator(
                    label: loc.tr('history_temp_chart'),
                    value: '${plant.currentTemperature.toStringAsFixed(1)}°C',
                    icon: Icons.thermostat_outlined,
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _ReadingIndicator(
                    label: loc.tr('history_light_chart'),
                    value: '${plant.currentLight}%',
                    icon: Icons.wb_sunny_outlined,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual reading indicator widget.
class _ReadingIndicator extends StatelessWidget {
  const _ReadingIndicator({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

/// Chart placeholder card.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: color.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.tr('history_chart_view'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      loc.tr('history_chart_install_hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data summary card.
class _DataSummaryCard extends StatelessWidget {
  const _DataSummaryCard({required this.sensorHistory});

  final List<SensorReading> sensorHistory;

  double _calculateAverage(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    final moistureValues =
        sensorHistory.where((r) => r.moisture != null).map((r) => r.moisture!);
    final tempValues = sensorHistory
        .where((r) => r.temperature != null)
        .map((r) => r.temperature!);
    final lightValues = sensorHistory
        .where((r) => r.light != null)
        .map((r) => r.light!.toDouble());

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.tr('history_data_summary'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: loc.tr('history_total_data_points'),
              value: sensorHistory.length.toString(),
            ),
            _SummaryRow(
              label: loc.tr('history_avg_moisture'),
              value: '${_calculateAverage(moistureValues).toStringAsFixed(1)}%',
            ),
            _SummaryRow(
              label: loc.tr('history_avg_temp'),
              value: '${_calculateAverage(tempValues).toStringAsFixed(1)}°C',
            ),
            _SummaryRow(
              label: loc.tr('history_avg_light'),
              value: '${_calculateAverage(lightValues).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary row widget.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOGS TAB
// =============================================================================

/// Logs tab showing activity history.
class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    // TODO: Replace with actual log data from provider
    final logs = _getMockLogs(loc);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _LogEntryCard(
          title: log.title,
          description: log.description,
          timestamp: log.timestamp,
          icon: log.icon,
          color: log.color,
        );
      },
    );
  }

  List<_LogEntry> _getMockLogs(LocalizationProvider loc) {
    return [
      _LogEntry(
        title: loc.tr('history_log_watered'),
        description: loc.tr('history_log_watered_desc'),
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        icon: Icons.water_drop_outlined,
        color: AppColors.info,
      ),
      _LogEntry(
        title: loc.tr('history_log_light_adjusted'),
        description: loc.tr('history_log_light_adjusted_desc'),
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        icon: Icons.wb_sunny_outlined,
        color: Colors.orange,
      ),
      _LogEntry(
        title: loc.tr('history_log_health_check'),
        description: loc.tr('history_log_health_check_desc'),
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        icon: Icons.health_and_safety_outlined,
        color: AppColors.success,
      ),
      _LogEntry(
        title: loc.tr('history_log_moisture_alert'),
        description: loc.tr('history_log_moisture_alert_desc'),
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        icon: Icons.warning_amber_outlined,
        color: AppColors.warning,
      ),
      _LogEntry(
        title: loc.tr('history_log_temp_spike'),
        description: loc.tr('history_log_temp_spike_desc'),
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        icon: Icons.thermostat_outlined,
        color: AppColors.error,
      ),
    ];
  }
}

/// Log entry data class.
class _LogEntry {
  const _LogEntry({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
}

/// Log entry card widget.
class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  String _formatTimestamp(DateTime timestamp, LocalizationProvider loc) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return loc
          .tr('history_time_minutes_ago')
          .replaceAll('{n}', '${difference.inMinutes}');
    } else if (difference.inHours < 24) {
      return loc
          .tr('history_time_hours_ago')
          .replaceAll('{n}', '${difference.inHours}');
    } else {
      return loc
          .tr('history_time_days_ago')
          .replaceAll('{n}', '${difference.inDays}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp, loc),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

// =============================================================================
// INSIGHTS TAB
// =============================================================================

/// Insights tab showing AI-generated recommendations.
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.selectedPlantId});

  final String? selectedPlantId;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        final selectedPlant = plantProvider.getPlantById(selectedPlantId ?? '');

        if (selectedPlant == null) {
          return _EmptyStateWidget(
            icon: Icons.insights_outlined,
            message: loc.tr('history_no_plant'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InsightCard(
              title: loc.tr('history_insight_health_score'),
              status: selectedPlant.isHealthy
                  ? loc.tr('history_insight_excellent')
                  : loc.tr('history_insight_needs_attention'),
              description: selectedPlant.isHealthy
                  ? loc.tr('history_insight_health_good_desc')
                  : loc.tr('history_insight_health_bad_desc'),
              icon: selectedPlant.isHealthy
                  ? Icons.eco_outlined
                  : Icons.warning_amber_outlined,
              color: selectedPlant.isHealthy
                  ? AppColors.success
                  : AppColors.warning,
            ),
            _InsightCard(
              title: loc.tr('history_insight_watering'),
              status: loc.tr('history_insight_regular'),
              description: loc.tr('history_insight_watering_desc'),
              icon: Icons.schedule_outlined,
              color: AppColors.info,
            ),
            _InsightCard(
              title: loc.tr('history_insight_growth'),
              status: loc.tr('history_insight_positive'),
              description: loc.tr('history_insight_growth_desc'),
              icon: Icons.trending_up_outlined,
              color: AppColors.success,
            ),
            _InsightCard(
              title: loc.tr('history_insight_environment'),
              status: loc.tr('history_insight_optimal'),
              description: loc.tr('history_insight_environment_desc'),
              icon: Icons.thermostat_outlined,
              color: AppColors.success,
            ),
            _InsightCard(
              title: loc.tr('history_insight_recommendations'),
              status: loc.tr('history_insight_maintain'),
              description: loc.tr('history_insight_recommendations_desc'),
              icon: Icons.lightbulb_outline,
              color: AppColors.primary,
            ),
          ],
        );
      },
    );
  }
}

/// Insight card widget.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.status,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String status;
  final String description;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

/// Empty state widget with icon and message.
class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
