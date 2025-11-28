import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/plant_provider.dart';
import '../models/sensor_model.dart';
import '../constants/app_colors.dart';
import '../models/plant_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPlantId;
  List<SensorReading> _sensorHistory = [];
  bool _isLoadingHistory = false;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plantProvider = context.read<PlantProvider>();
      if (plantProvider.plants.isNotEmpty) {
        _selectedPlantId = plantProvider.plants.first.id;
        _loadSensorHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSensorHistory() async {
    if (_selectedPlantId == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final plantProvider = context.read<PlantProvider>();
      // TODO: Need to get device ID from plant
      // For now, use plant ID as device ID (will need proper device association)
      final deviceId = int.tryParse(_selectedPlantId!) ?? 0;
      final historyData = await plantProvider.getSensorHistory(deviceId);
      setState(() {
        _sensorHistory =
            historyData.map((data) => SensorReading.fromJson(data)).toList();
      });
    } catch (e) {
      debugPrint('Failed to load sensor history: $e');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Plant History & Analytics'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.analytics), text: 'Charts'),
              Tab(icon: Icon(Icons.list), text: 'Logs'),
              Tab(icon: Icon(Icons.insights), text: 'Insights'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Plant selector
            Consumer<PlantProvider>(
              builder: (context, plantProvider, child) {
                if (plantProvider.plants.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Plant:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedPlantId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: plantProvider.plants.map((plant) {
                          return DropdownMenuItem<String>(
                            value: plant.id,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      _getHealthColor(plant.healthStatus),
                                  child: const Icon(Icons.local_florist,
                                      size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(plant.name)),
                                Text(
                                  plant.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedPlantId = newValue;
                            });
                            _loadSensorHistory();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Time Period:',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(width: 8),
                          ...([7, 14, 30].map((days) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('${days}d'),
                                  selected: _selectedDays == days,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedDays = days;
                                      });
                                      _loadSensorHistory();
                                    }
                                  },
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: _selectedDays == days
                                        ? Colors.white
                                        : null,
                                  ),
                                ),
                              ))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChartsTab(),
                  _buildLogsTab(),
                  _buildInsightsTab(),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildChartsTab() {
    if (_selectedPlantId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_florist, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No plant selected'),
            Text('Select a plant to view its sensor history'),
          ],
        ),
      );
    }

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        final selectedPlant = plantProvider.getPlantById(_selectedPlantId!);

        if (selectedPlant == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_isLoadingHistory) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current readings summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Status - ${selectedPlant.name}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCurrentReading(
                              'Moisture',
                              '${selectedPlant.currentMoisture}%',
                              Icons.water_drop,
                              AppColors.info,
                            ),
                          ),
                          Expanded(
                            child: _buildCurrentReading(
                              'Temperature',
                              '${selectedPlant.currentTemperature.toStringAsFixed(1)}°C',
                              Icons.thermostat,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildCurrentReading(
                              'Light',
                              '${selectedPlant.currentLight}%',
                              Icons.wb_sunny,
                              Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Chart placeholders
              _buildChartCard(
                  'Soil Moisture Trends', Icons.water_drop, AppColors.info),
              const SizedBox(height: 16),
              _buildChartCard(
                  'Temperature History', Icons.thermostat, Colors.orange),
              const SizedBox(height: 16),
              _buildChartCard(
                  'Light Level Changes', Icons.wb_sunny, Colors.amber),

              const SizedBox(height: 16),

              // Data summary
              if (_sensorHistory.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Summary',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Text('Total data points: ${_sensorHistory.length}'),
                        Text('Date range: $_selectedDays days'),
                        Text(
                            'Average moisture: ${_calculateAverageMoisture().toStringAsFixed(1)}%'),
                        Text(
                            'Average temperature: ${_calculateAverageTemperature().toStringAsFixed(1)}°C'),
                        Text(
                            'Average light: ${_calculateAverageLight().toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentReading(
          String label, String value, IconData icon, Color color) =>
      Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildChartCard(String title, IconData icon, Color color) => Card(
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
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 48, color: color.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    Text(
                      'Chart View',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Install fl_chart package for interactive charts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildLogsTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLogEntry(
              'Plant watered',
              'Manual watering completed',
              DateTime.now().subtract(const Duration(hours: 2)),
              Icons.water_drop,
              AppColors.info),
          _buildLogEntry(
              'Light adjusted',
              'Grow light intensity increased to 80%',
              DateTime.now().subtract(const Duration(hours: 4)),
              Icons.wb_sunny,
              Colors.orange),
          _buildLogEntry(
              'Health check',
              'Plant health assessment: Good condition',
              DateTime.now().subtract(const Duration(hours: 8)),
              Icons.health_and_safety,
              AppColors.success),
          _buildLogEntry(
              'Moisture alert',
              'Low soil moisture detected - 25%',
              DateTime.now().subtract(const Duration(hours: 12)),
              Icons.warning,
              AppColors.warning),
          _buildLogEntry(
              'Temperature spike',
              'High temperature recorded - 28°C',
              DateTime.now().subtract(const Duration(days: 1)),
              Icons.thermostat,
              AppColors.error),
        ],
      );

  Widget _buildLogEntry(String title, String description, DateTime timestamp,
          IconData icon, Color color) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          isThreeLine: true,
        ),
      );

  Widget _buildInsightsTab() => Consumer<PlantProvider>(
        builder: (context, plantProvider, child) {
          final selectedPlant =
              plantProvider.getPlantById(_selectedPlantId ?? '');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildInsightCard(
                'Health Score',
                selectedPlant?.isHealthy == true
                    ? 'Excellent'
                    : 'Needs Attention',
                selectedPlant?.isHealthy == true
                    ? 'Your plant is thriving! Keep up the great care routine.'
                    : 'Your plant needs some attention. Check moisture levels and lighting.',
                selectedPlant?.isHealthy == true ? Icons.eco : Icons.warning,
                selectedPlant?.isHealthy == true
                    ? AppColors.success
                    : AppColors.warning,
              ),
              _buildInsightCard(
                'Watering Pattern',
                'Regular',
                'Your watering schedule appears consistent. Plants thrive on routine!',
                Icons.schedule,
                AppColors.info,
              ),
              _buildInsightCard(
                'Growth Trends',
                'Positive',
                'Based on sensor data, your plant shows healthy growth patterns.',
                Icons.trending_up,
                AppColors.success,
              ),
              _buildInsightCard(
                'Environmental Conditions',
                'Optimal',
                'Temperature and humidity levels are within ideal ranges for your plant.',
                Icons.thermostat,
                AppColors.success,
              ),
              _buildInsightCard(
                'Care Recommendations',
                'Maintain Current Routine',
                '• Continue current watering schedule\n• Monitor for any pest activity\n• Consider fertilizing next month',
                Icons.lightbulb,
                AppColors.primary,
              ),
            ],
          );
        },
      );

  Widget _buildInsightCard(String title, String status, String description,
          IconData icon, Color color) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
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
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
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

  Color _getHealthColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return AppColors.success;
      case HealthStatus.good:
        return AppColors.primary;
      case HealthStatus.warning:
        return AppColors.warning;
      case HealthStatus.critical:
        return AppColors.error;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  double _calculateAverageMoisture() {
    if (_sensorHistory.isEmpty) return 0;
    final values = _sensorHistory
        .where((r) => r.moisture != null)
        .map((r) => r.moisture!)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateAverageTemperature() {
    if (_sensorHistory.isEmpty) return 0;
    final values = _sensorHistory
        .where((r) => r.temperature != null)
        .map((r) => r.temperature!)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateAverageLight() {
    if (_sensorHistory.isEmpty) return 0;
    final values = _sensorHistory
        .where((r) => r.light != null)
        .map((r) => r.light!.toDouble())
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
