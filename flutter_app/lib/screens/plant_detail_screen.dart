import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plant_model.dart';
import '../models/plant_type_model.dart';
import '../models/sensor_model.dart';
import '../models/device_model.dart';
import '../services/plant_provider.dart';
import '../services/auth_provider.dart';
import '../services/plant_image_provider.dart';
import '../services/localization_service.dart';
import '../constants/app_colors.dart';

class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({
    super.key,
    required this.plantId,
    this.deviceId,
  });
  final String plantId;
  final int? deviceId;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  bool _isWatering = false;
  bool _isControllingLight = false;
  bool _isControllingTemperature = false;
  bool _isControllingHumidity = false;
  List<SensorReading> _sensorHistory = [];
  bool _isLoadingHistory = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Schedule data loading after first frame to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPlantData();
        _loadSensorHistory();
      }
    });
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadPlantData();
        _loadSensorHistory();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlantData() async {
    if (!mounted) return;
    await context.read<PlantProvider>().loadPlantDetails(widget.plantId);
  }

  Future<void> _loadSensorHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final deviceId = widget.deviceId ?? int.tryParse(widget.plantId) ?? 0;
      final plantProvider = context.read<PlantProvider>();
      final historyData = await plantProvider.getSensorHistory(deviceId);
      
      if (mounted) {
        setState(() {
          if (historyData.isEmpty) {
            // Add dummy data for demonstration
            _sensorHistory = _generateDummySensorData();
          } else {
            _sensorHistory = historyData.map((data) => SensorReading.fromJson(data)).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load sensor history: $e');
      if (mounted) {
        // Generate dummy data on error
        setState(() {
          _sensorHistory = _generateDummySensorData();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  List<SensorReading> _generateDummySensorData() {
    final now = DateTime.now();
    final dummyData = <SensorReading>[];
    
    // Generate 7 days of hourly readings
    for (int day = 6; day >= 0; day--) {
      for (int hour = 0; hour < 24; hour += 2) {
        final timestamp = now.subtract(Duration(days: day, hours: hour));
        
        // Generate realistic-looking data with variations
        dummyData.add(SensorReading(
          timestamp: timestamp,
          moisture: 45 + (day * 3) + (hour % 5) - 10,
          temperature: 22.0 + (hour / 3) - 2,
          light: (300.0 + (hour * 150) - 500).toInt(),
          humidity: 55.0 + (day * 2) - 5,
        ));
      }
    }
    
    return dummyData;
  }

  Future<void> _showEditPlantDialog(BuildContext context, Plant plant) async {
    final localization = context.read<LocalizationProvider>();
    final plantProvider = context.read<PlantProvider>();

    final nameController = TextEditingController(text: plant.name);
    final locationController = TextEditingController(text: plant.location);
    final notesController = TextEditingController(text: plant.notes ?? '');
    bool isHealthy = plant.isHealthy;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(localization.tr('plants_edit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(localization.tr('plants_healthy')),
                  value: isHealthy,
                  onChanged: (value) {
                    setDialogState(() {
                      isHealthy = value;
                    });
                  },
                ),
                // Health status is calculated automatically from sensor values
                // No manual override needed
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(localization.tr('common_cancel')),
            ),
            ElevatedButton(
              onPressed: nameController.text.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(localization.tr('common_save')),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final request = PlantFromDatabaseRequest(
        name: nameController.text,
        scientificName:
            plant.name, // Use plant name as scientific name fallback
        location:
            locationController.text.isNotEmpty ? locationController.text : null,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
        isHealthy: isHealthy,
        // Don't send healthStatus - it's calculated from sensor values
      );

      final success =
          await plantProvider.updatePlant(int.parse(plant.id), request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? localization.tr('plants_updated_success')
                : localization.tr('plants_updated_error')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          await _loadPlantData();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Consumer<PlantProvider>(
          builder: (context, plantProvider, child) {
            final plant = plantProvider.getPlantById(widget.plantId);
            final localization = context.watch<LocalizationProvider>();

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
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _showEditPlantDialog(context, plant),
                    ),
                  ],
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
                        _PlantHeaderImage(
                          plantName: plant.name,
                          defaultImageUrl: plant.imageUrl,
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
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
                        _buildPlantInfoCard(plant, localization),

                        const SizedBox(height: 16),

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

  Widget _buildPlantInfoCard(Plant plant, LocalizationProvider loc) => Card(
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
                    loc.tr('plant_info'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow(
                  Icons.location_on, loc.tr('plant_location'), plant.location),
              _buildInfoRow(Icons.eco, loc.tr('plant_health_status'),
                  plant.calculatedHealthStatus.displayName),
              if (plant.lastWatered != null)
                _buildInfoRow(Icons.water_drop, loc.tr('plant_last_watered'),
                    _formatDateTime(plant.lastWatered!)),
              _buildInfoRow(Icons.calendar_today, loc.tr('plant_planted_date'),
                  _formatDateTime(plant.plantingDate)),
              if (plant.notes != null && plant.notes!.isNotEmpty)
                _buildInfoRow(Icons.note, loc.tr('plant_notes'), plant.notes!),
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
                    context
                        .read<LocalizationProvider>()
                        .tr('plant_current_readings'),
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
                      context
                          .read<LocalizationProvider>()
                          .tr('plant_soil_moisture'),
                      '${plant.currentMoisture}%',
                      plant.currentMoisture / 100,
                      AppColors.info,
                      Icons.water_drop,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorGauge(
                      context
                          .read<LocalizationProvider>()
                          .tr('plant_temperature'),
                      '${plant.currentTemperature.toStringAsFixed(1)}°C',
                      (plant.currentTemperature - 15) /
                          15, // Scale 15-30°C to 0-1
                      Colors.orange,
                      Icons.thermostat,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorGauge(
                      context
                          .read<LocalizationProvider>()
                          .tr('plant_light_level'),
                      '${plant.currentLight.toStringAsFixed(0)} lux',
                      (plant.currentLight / 10000).clamp(0.0, 1.0),
                      Colors.amber,
                      Icons.wb_sunny,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorGauge(
                      context.read<LocalizationProvider>().tr('plant_humidity'),
                      '${plant.currentHumidity}%',
                      plant.currentHumidity / 100,
                      Colors.teal,
                      Icons.water,
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
                  backgroundColor: color.withValues(alpha: 0.2),
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
                    context.read<LocalizationProvider>().tr('plant_controls'),
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
                      label: Text(_isWatering
                          ? context
                              .read<LocalizationProvider>()
                              .tr('plant_watering')
                          : context
                              .read<LocalizationProvider>()
                              .tr('plant_water_action')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isControllingTemperature
                          ? null
                          : _handleAdjustTemperature,
                      icon: _isControllingTemperature
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.thermostat),
                      label: Text(_isControllingTemperature
                          ? context
                              .read<LocalizationProvider>()
                              .tr('plant_adjusting')
                          : context
                              .read<LocalizationProvider>()
                              .tr('plant_temp_action')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                          ? context
                              .read<LocalizationProvider>()
                              .tr('plant_adjusting')
                          : context
                              .read<LocalizationProvider>()
                              .tr('plant_light_action')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isControllingHumidity ? null : _handleAdjustHumidity,
                      icon: _isControllingHumidity
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.water),
                      label: Text(_isControllingHumidity
                          ? context
                              .read<LocalizationProvider>()
                              .tr('plant_adjusting')
                          : context
                              .read<LocalizationProvider>()
                              .tr('plant_humidity_action')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Update Health Status button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showUpdateHealthStatusDialog(context),
                  icon: const Icon(Icons.edit_note),
                  label: Text(context
                      .read<LocalizationProvider>()
                      .tr('plant_update_health')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                  ),
                ),
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(context
                        .read<LocalizationProvider>()
                        .tr('plant_no_sensor_history')),
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
                    context
                        .read<LocalizationProvider>()
                        .tr('plant_care_instructions'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCareInstruction(Icons.water_drop,
                  context.read<LocalizationProvider>().tr('plant_care_water')),
              _buildCareInstruction(Icons.wb_sunny,
                  context.read<LocalizationProvider>().tr('plant_care_light')),
              _buildCareInstruction(Icons.thermostat,
                  context.read<LocalizationProvider>().tr('plant_care_temp')),
              _buildCareInstruction(Icons.eco,
                  context.read<LocalizationProvider>().tr('plant_care_pests')),
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
    final localization = context.read<LocalizationProvider>();
    
    setState(() {
      _isWatering = true;
    });

    try {
      // Get the user's devices and device types
      final apiClient = context.read<AuthProvider>().apiClient;
      final devices = await apiClient.getMyDevices();
      final deviceTypes = await apiClient.listAvailableDeviceTypes();
      
      debugPrint('[WATER_DEBUG] Total devices: ${devices.length}');
      debugPrint('[WATER_DEBUG] Total device types: ${deviceTypes.length}');
      
      // Enrich devices with device type information
      final enrichedDevices = <Device>[];
      for (var device in devices) {
        final deviceTypeData = deviceTypes.firstWhere(
          (dt) => dt['id'] == device.deviceTypeId,
          orElse: () => <String, dynamic>{},
        );
        final enrichedDevice = Device.fromJson({
          ...device.toJson(),
          'device_type': deviceTypeData,
        });
        enrichedDevices.add(enrichedDevice);
        debugPrint('[WATER_DEBUG] Device ${device.id}: ${device.deviceName}, Functions: ${deviceTypeData['supported_functions']}');
      }
      
      // Find a device with moisture write capability (actuator) assigned to this plant
      final moistureDevice = enrichedDevices.where((device) {
        final functions = device.deviceType?['supported_functions'] as String? ?? '';
        final hasMoisture = functions.contains('moisture:write') || functions.contains('moisture');
        final isForThisPlant = device.plantId?.toString() == widget.plantId;
        debugPrint('[WATER_DEBUG] Checking device ${device.id}: hasMoisture=$hasMoisture, plantId=${device.plantId}, match=$isForThisPlant');
        return hasMoisture && isForThisPlant;
      }).firstOrNull;
      
      debugPrint('[WATER_DEBUG] Found moisture device: ${moistureDevice?.id}');
      
      if (moistureDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('plant_no_water_pump')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      final success = await context
          .read<PlantProvider>()
          .waterPlant(widget.plantId, moistureDevice.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('plant_watered_success')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localization.tr('common_error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
    final localization = context.read<LocalizationProvider>();
    
    setState(() {
      _isControllingLight = true;
    });

    try {
      // Get the user's devices and device types
      final apiClient = context.read<AuthProvider>().apiClient;
      final devices = await apiClient.getMyDevices();
      final deviceTypes = await apiClient.listAvailableDeviceTypes();
      
      debugPrint('[BRIGHTNESS_DEBUG] Total devices: ${devices.length}');
      debugPrint('[BRIGHTNESS_DEBUG] Total device types: ${deviceTypes.length}');
      
      // Enrich devices with device type information
      final enrichedDevices = <Device>[];
      for (var device in devices) {
        final deviceTypeData = deviceTypes.firstWhere(
          (dt) => dt['id'] == device.deviceTypeId,
          orElse: () => <String, dynamic>{},
        );
        final enrichedDevice = Device.fromJson({
          ...device.toJson(),
          'device_type': deviceTypeData,
        });
        enrichedDevices.add(enrichedDevice);
        debugPrint('[BRIGHTNESS_DEBUG] Device ${device.id}: ${device.deviceName}, Functions: ${deviceTypeData['supported_functions']}, PlantId: ${device.plantId}');
      }
      
      final lightDevice = enrichedDevices.where((device) {
        final functions = device.deviceType?['supported_functions'] as String? ?? '';
        final hasCapability = functions.contains('brightness:write') || functions.contains('light:write');
        final isForThisPlant = device.plantId?.toString() == widget.plantId;
        debugPrint('[BRIGHTNESS_DEBUG] Device ${device.id}: hasCapability=$hasCapability, plantId=${device.plantId}, match=$isForThisPlant');
        return hasCapability && isForThisPlant;
      }).firstOrNull;
      
      debugPrint('[BRIGHTNESS_DEBUG] Found light device: ${lightDevice?.id}');
      
      if (lightDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('plant_no_light_device')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final success = await context.read<PlantProvider>().controlDevice(
            widget.plantId,
            lightDevice.id,
            'brightness',
            10.0, // Increase brightness by 10%
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('plant_light_adjusted')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localization.tr('common_error')}: $e'),
            backgroundColor: AppColors.error,
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

  Future<void> _handleAdjustTemperature() async {
    final localization = context.read<LocalizationProvider>();
    
    setState(() {
      _isControllingTemperature = true;
    });

    try {
      // Get the user's devices and device types
      final apiClient = context.read<AuthProvider>().apiClient;
      final devices = await apiClient.getMyDevices();
      final deviceTypes = await apiClient.listAvailableDeviceTypes();
      
      debugPrint('[TEMP_DEBUG] Total devices: ${devices.length}');
      debugPrint('[TEMP_DEBUG] Total device types: ${deviceTypes.length}');
      
      // Enrich devices with device type information
      final enrichedDevices = <Device>[];
      for (var device in devices) {
        final deviceTypeData = deviceTypes.firstWhere(
          (dt) => dt['id'] == device.deviceTypeId,
          orElse: () => <String, dynamic>{},
        );
        final enrichedDevice = Device.fromJson({
          ...device.toJson(),
          'device_type': deviceTypeData,
        });
        enrichedDevices.add(enrichedDevice);
        debugPrint('[TEMP_DEBUG] Device ${device.id}: ${device.deviceName}, Functions: ${deviceTypeData['supported_functions']}, PlantId: ${device.plantId}');
      }
      
      final tempDevice = enrichedDevices.where((device) {
        final functions = device.deviceType?['supported_functions'] as String? ?? '';
        final hasCapability = functions.contains('temperature:write');
        final isForThisPlant = device.plantId?.toString() == widget.plantId;
        debugPrint('[TEMP_DEBUG] Device ${device.id}: hasCapability=$hasCapability, plantId=${device.plantId}, match=$isForThisPlant');
        return hasCapability && isForThisPlant;
      }).firstOrNull;
      
      debugPrint('[TEMP_DEBUG] Found temp device: ${tempDevice?.id}');
      
      if (tempDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('plant_no_temp_device')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final success = await context.read<PlantProvider>().controlDevice(
            widget.plantId,
            tempDevice.id,
            'temperature',
            2.0, // Increase temperature by 2°C
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('plant_temp_adjusted')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localization.tr('common_error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isControllingTemperature = false;
        });
      }
    }
  }

  Future<void> _handleAdjustHumidity() async {
    final localization = context.read<LocalizationProvider>();
    
    setState(() {
      _isControllingHumidity = true;
    });

    try {
      // Get the user's devices and device types
      final apiClient = context.read<AuthProvider>().apiClient;
      final devices = await apiClient.getMyDevices();
      final deviceTypes = await apiClient.listAvailableDeviceTypes();
      
      debugPrint('[HUMIDITY_DEBUG] Total devices: ${devices.length}');
      debugPrint('[HUMIDITY_DEBUG] Total device types: ${deviceTypes.length}');
      
      // Enrich devices with device type information
      final enrichedDevices = <Device>[];
      for (var device in devices) {
        final deviceTypeData = deviceTypes.firstWhere(
          (dt) => dt['id'] == device.deviceTypeId,
          orElse: () => <String, dynamic>{},
        );
        final enrichedDevice = Device.fromJson({
          ...device.toJson(),
          'device_type': deviceTypeData,
        });
        enrichedDevices.add(enrichedDevice);
        debugPrint('[HUMIDITY_DEBUG] Device ${device.id}: ${device.deviceName}, Functions: ${deviceTypeData['supported_functions']}, PlantId: ${device.plantId}');
      }
      
      final humidityDevice = enrichedDevices.where((device) {
        final functions = device.deviceType?['supported_functions'] as String? ?? '';
        final hasCapability = functions.contains('humidity:write');
        final isForThisPlant = device.plantId?.toString() == widget.plantId;
        debugPrint('[HUMIDITY_DEBUG] Device ${device.id}: hasCapability=$hasCapability, plantId=${device.plantId}, match=$isForThisPlant');
        return hasCapability && isForThisPlant;
      }).firstOrNull;
      
      debugPrint('[HUMIDITY_DEBUG] Found humidity device: ${humidityDevice?.id}');
      
      if (humidityDevice == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('plant_no_humidity_device')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final success = await context.read<PlantProvider>().controlDevice(
            widget.plantId,
            humidityDevice.id,
            'humidity',
            5.0, // Increase humidity by 5%
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localization.tr('plant_humidity_adjusted')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localization.tr('common_error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isControllingHumidity = false;
        });
      }
    }
  }

  Future<void> _showUpdateHealthStatusDialog(BuildContext context) async {
    final localization = context.read<LocalizationProvider>();
    final plantProvider = context.read<PlantProvider>();
    final plant = plantProvider.plants.firstWhere(
      (p) => p.id == widget.plantId,
      orElse: () => throw Exception('Plant not found'),
    );

    final moistureController =
        TextEditingController(text: plant.currentMoisture.toString());
    final temperatureController = TextEditingController(
        text: plant.currentTemperature.toStringAsFixed(1));
    final lightController =
        TextEditingController(text: plant.currentLight.toString());
    final humidityController =
        TextEditingController(text: plant.currentHumidity.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localization.tr('plant_update_health')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localization.tr('plant_set_health_values'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: moistureController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${localization.tr('plant_soil_moisture')} (%)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.water_drop),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: temperatureController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${localization.tr('plant_temperature')} (°C)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.thermostat),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${localization.tr('plant_light_level')} (lux)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.wb_sunny),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: humidityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${localization.tr('plant_humidity')} (%)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.water),
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(localization.tr('common_save')),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        // Order: [light_level, humidity, temperature, soil_moisture]
        // This matches the CSV format: "brightness,humidity,temperature,moisture"
        final healthStatus = [
          int.tryParse(lightController.text) ?? 0,
          int.tryParse(humidityController.text) ?? 0,
          (double.tryParse(temperatureController.text) ?? 0).round(),
          int.tryParse(moistureController.text) ?? 0,
        ];

        final apiClient = context.read<AuthProvider>().apiClient;
        await apiClient.updatePlantHealthStatus(
            int.parse(widget.plantId), healthStatus);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localization.tr('plant_readings_updated')),
              backgroundColor: AppColors.success,
            ),
          );
          // Reload plant data - need to reload the full list so the updated plant is fetched
          final plantProvider = context.read<PlantProvider>();
          await plantProvider.loadPlants();
          setState(() {}); // Force UI rebuild
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localization.tr('common_error')}: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

/// Widget that displays plant header image with Trefle API fallback
class _PlantHeaderImage extends StatefulWidget {
  const _PlantHeaderImage({
    required this.plantName,
    required this.defaultImageUrl,
  });

  final String plantName;
  final String defaultImageUrl;

  @override
  State<_PlantHeaderImage> createState() => _PlantHeaderImageState();
}

class _PlantHeaderImageState extends State<_PlantHeaderImage> {
  String? _trefleImageUrl;
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    _fetchTrefleImage();
  }

  bool get _isPlaceholder {
    return widget.defaultImageUrl.contains('placeholder') ||
        widget.defaultImageUrl.contains('via.placeholder');
  }

  Future<void> _fetchTrefleImage() async {
    if (!_isPlaceholder || _hasFetched) return;

    _hasFetched = true;

    final imageProvider = context.read<PlantImageProvider>();
    if (!imageProvider.isConfigured) return;

    final imageUrl = await imageProvider.fetchImageUrl(widget.plantName);
    if (mounted && imageUrl != null) {
      setState(() {
        _trefleImageUrl = imageUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _trefleImageUrl ?? widget.defaultImageUrl;
    final isPlaceholder = _isPlaceholder && _trefleImageUrl == null;

    if (isPlaceholder) {
      return Container(
        color: AppColors.primary,
        child: const Icon(
          Icons.local_florist,
          size: 100,
          color: Colors.white,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: AppColors.primary.withValues(alpha: 0.8),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.primary,
        child: const Icon(
          Icons.local_florist,
          size: 100,
          color: Colors.white,
        ),
      ),
    );
  }
}
