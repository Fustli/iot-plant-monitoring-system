import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plant_model.dart';
import '../services/plant_provider.dart';
import '../constants/app_colors.dart';

class PlantCard extends StatefulWidget {
  const PlantCard({
    Key? key,
    required this.plant,
    this.onTap,
    this.onWaterSuccess,
    this.deviceId,
  }) : super(key: key);
  final Plant plant;
  final VoidCallback? onTap;
  final Function(String)? onWaterSuccess;
  final int? deviceId;

  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard> with TickerProviderStateMixin {
  bool _isWatering = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with plant image and status
                      Row(
                        children: [
                          // Plant image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.plant.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.local_florist,
                                    color: Colors.green.shade600, size: 30),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Plant info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.plant.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.plant.location,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 6),

                                // Health status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getHealthColor(
                                        widget.plant.healthStatus),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.plant.healthStatus.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // Sensor readings row
                      Row(
                        children: [
                          // Moisture
                          Expanded(
                            child: _buildSensorTile(
                              icon: Icons.water_drop,
                              label: 'Moisture',
                              value: '${widget.plant.currentMoisture}%',
                              color: _getMoistureColor(
                                  widget.plant.currentMoisture),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Temperature
                          Expanded(
                            child: _buildSensorTile(
                              icon: Icons.thermostat,
                              label: 'Temp',
                              value:
                                  '${widget.plant.currentTemperature.toStringAsFixed(1)}°C',
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Light
                          Expanded(
                            child: _buildSensorTile(
                              icon: Icons.wb_sunny,
                              label: 'Light',
                              value: '${widget.plant.currentLight}%',
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Last watered info
                      if (widget.plant.lastWatered != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Last watered ${_formatTimeAgo(widget.plant.lastWatered!)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),

                      // Action buttons row
                      Row(
                        children: [
                          // Water button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isWatering ? null : _handleWaterPlant,
                              icon: _isWatering
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.water_drop, size: 18),
                              label: Text(
                                _isWatering ? 'Watering...' : 'Water',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getMoistureActionColor(),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Details button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onTap,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text(
                                'Details',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Widget _buildSensorTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Color _getHealthColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return AppColors.healthyGreen;
      case HealthStatus.good:
        return AppColors.success;
      case HealthStatus.warning:
        return AppColors.warningYellow;
      case HealthStatus.critical:
        return AppColors.criticalRed;
    }
  }

  Color _getMoistureColor(int moisture) {
    if (moisture >= 60) return AppColors.healthyGreen;
    if (moisture >= 40) return AppColors.warningYellow;
    if (moisture >= 20) return Colors.orange.shade600;
    return AppColors.criticalRed;
  }

  Color _getMoistureActionColor() {
    final moisture = widget.plant.currentMoisture;
    if (moisture < 30) return AppColors.criticalRed;
    if (moisture < 50) return AppColors.warningYellow;
    return AppColors.success;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _handleWaterPlant() async {
    if (_isWatering) return;

    // Need a device ID to water plant
    if (widget.deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No water pump device assigned to this plant'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isWatering = true;
    });

    // Start pulse animation
    _pulseController.repeat(reverse: true);

    try {
      final plantProvider = context.read<PlantProvider>();
      final success =
          await plantProvider.waterPlant(widget.plant.id, widget.deviceId!);

      if (success) {
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${widget.plant.name} watered successfully!'),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }

        // Call success callback if provided
        widget.onWaterSuccess?.call(widget.plant.id);

        // Brief celebration animation
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(plantProvider.error ?? 'Failed to water plant'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to water ${widget.plant.name}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _pulseController.stop();
      _pulseController.reset();

      if (mounted) {
        setState(() {
          _isWatering = false;
        });
      }
    }
  }
}
