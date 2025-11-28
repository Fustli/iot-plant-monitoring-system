import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plant_model.dart';
import '../models/sensor_model.dart';
import '../services/plant_provider.dart';
import '../services/alert_provider.dart';
import '../constants/app_colors.dart';
import '../widgets/alert_banner.dart';

class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({
    Key? key,
    required this.plantId,
    this.deviceId,
  }) : super(key: key);
  final String plantId;
  final int? deviceId;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  bool _isWatering = false;
  bool _isControllingLight = false;
  List<SensorReading> _sensorHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadPlantData();
    _loadSensorHistory();
  }

  Future<void> _loadPlantData() async {
    await context.read<PlantProvider>().loadPlantDetails(widget.plantId);
  }

  Future<void> _loadSensorHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final deviceId = widget.deviceId ?? int.tryParse(widget.plantId) ?? 0;
      final plantProvider = context.read<PlantProvider>();
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
        body: Consumer<PlantProvider>(
          builder: (context, plantProvider, child) {
            final plant = plantProvider.getPlantById(widget.plantId);

            if (plant == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return CustomScrollView(
              slivers: [
                // App bar with plant image
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      plant.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          plant.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: AppColors.primary,
                            child: const Icon(
                              Icons.local_florist,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plant info card
                        _buildPlantInfoCard(plant),

                        const SizedBox(height: 16),

                        // Active alerts for this plant
                        Consumer<AlertProvider>(
                          builder: (context, alertProvider, child) {
                            final plantAlerts = alertProvider
                                .getAlertsForPlant(plant.id)
                                .where((alert) => alert.status.name == 'active')
                                .toList();

                            if (plantAlerts.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Alerts',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...plantAlerts.map((alert) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: AlertBanner(alert: alert),
                                      )),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Sensor readings
                        _buildSensorReadingsCard(plant),

                        const SizedBox(height: 16),

                        // Control actions
                        _buildControlActionsCard(plant),

                        const SizedBox(height: 16),

                        // Sensor history chart
                        _buildHistoryCard(),

                        const SizedBox(height: 16),

                        // Plant care info
                        _buildPlantCareCard(plant),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _buildPlantInfoCard(Plant plant) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Plant Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow(Icons.location_on, 'Location', plant.location),
              _buildInfoRow(
                  Icons.eco, 'Health Status', plant.healthStatus.displayName),
              if (plant.lastWatered != null)
                _buildInfoRow(Icons.water_drop, 'Last Watered',
                    _formatDateTime(plant.lastWatered!)),
              _buildInfoRow(Icons.calendar_today, 'Planted',
                  _formatDateTime(plant.plantingDate)),
              if (plant.notes != null && plant.notes!.isNotEmpty)
                _buildInfoRow(Icons.note, 'Notes', plant.notes!),
            ],
          ),
        ),
      );

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );

  Widget _buildSensorReadingsCard(Plant plant) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sensors, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Current Readings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSensorGauge(
                      'Soil Moisture',
                      '${plant.currentMoisture}%',
                      plant.currentMoisture / 100,
                      AppColors.info,
                      Icons.water_drop,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSensorGauge(
                      'Temperature',
                      '${plant.currentTemperature.toStringAsFixed(1)}°C',
                      (plant.currentTemperature - 15) /
                          15, // Scale 15-30°C to 0-1
                      Colors.orange,
                      Icons.thermostat,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSensorGauge(
                      'Light Level',
                      '${plant.currentLight}%',
                      plant.currentLight / 100,
                      Colors.amber,
                      Icons.wb_sunny,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildSensorGauge(String title, String value, double progress,
          Color color, IconData icon) =>
      Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
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

  Widget _buildControlActionsCard(Plant plant) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.control_camera, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Plant Controls',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isWatering ? null : _handleWaterPlant,
                      icon: _isWatering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.water_drop),
                      label: Text(_isWatering ? 'Watering...' : 'Water Plant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isControllingLight ? null : _handleToggleLight,
                      icon: _isControllingLight
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wb_sunny),
                      label: Text(_isControllingLight
                          ? 'Adjusting...'
                          : 'Adjust Light'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildHistoryCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Sensor History (7 days)',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _loadSensorHistory,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_sensorHistory.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Chart placeholder\n${_sensorHistory.length} data points available',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No sensor history available'),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildPlantCareCard(Plant plant) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.spa, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Care Instructions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCareInstruction(
                  Icons.water_drop, 'Water when soil moisture drops below 30%'),
              _buildCareInstruction(
                  Icons.wb_sunny, 'Provide bright, indirect sunlight'),
              _buildCareInstruction(
                  Icons.thermostat, 'Maintain temperature between 18-26°C'),
              _buildCareInstruction(
                  Icons.eco, 'Monitor for pests and diseases regularly'),
            ],
          ),
        ),
      );

  Widget _buildCareInstruction(IconData icon, String instruction) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                instruction,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year}';

  Future<void> _handleWaterPlant() async {
    if (widget.deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No water pump device assigned to this plant'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isWatering = true;
    });

    try {
      final success = await context
          .read<PlantProvider>()
          .waterPlant(widget.plantId, widget.deviceId!);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plant watered successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Reload alerts in case watering resolved any
        context.read<AlertProvider>().loadAlerts();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWatering = false;
        });
      }
    }
  }

  Future<void> _handleToggleLight() async {
    if (widget.deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No light device assigned to this plant'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isControllingLight = true;
    });

    try {
      final success = await context.read<PlantProvider>().controlDevice(
            widget.plantId,
            widget.deviceId!,
            'light',
            80.0, // Increase light to 80%
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Light adjusted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isControllingLight = false;
        });
      }
    }
  }
}
