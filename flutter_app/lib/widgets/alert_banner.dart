import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert_model.dart';
import '../services/alert_provider.dart';
import '../constants/app_colors.dart';

class AlertBanner extends StatefulWidget {
  final Alert alert;
  final bool showDismissButton;

  const AlertBanner({
    Key? key,
    required this.alert,
    this.showDismissButton = true,
  }) : super(key: key);

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _getSeverityColor(widget.alert.severity),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _getSeverityColor(widget.alert.severity).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Severity icon
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                radius: 20,
                child: Icon(
                  _getSeverityIcon(widget.alert.severity),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Alert content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.alert.message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeAgo(widget.alert.triggeredAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.alert.severity.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              if (widget.showDismissButton && widget.alert.status == AlertStatusEnum.active)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _handleAcknowledge,
                      icon: const Icon(Icons.check, color: Colors.white),
                      tooltip: 'Acknowledge',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      onPressed: _handleDismiss,
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Dismiss',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(AlertSeverityEnum severity) {
    switch (severity) {
      case AlertSeverityEnum.info:
        return AppColors.info;
      case AlertSeverityEnum.warning:
        return AppColors.warning;
      case AlertSeverityEnum.critical:
        return AppColors.error;
    }
  }

  IconData _getSeverityIcon(AlertSeverityEnum severity) {
    switch (severity) {
      case AlertSeverityEnum.info:
        return Icons.info;
      case AlertSeverityEnum.warning:
        return Icons.warning;
      case AlertSeverityEnum.critical:
        return Icons.error;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _handleAcknowledge() async {
    final success = await context.read<AlertProvider>().acknowledgeAlert(widget.alert.id);
    if (success && mounted) {
      setState(() {
        _isDismissed = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Alert acknowledged'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleDismiss() async {
    // Animate out
    await _slideController.reverse();
    
    if (mounted) {
      final success = await context.read<AlertProvider>().dismissAlert(widget.alert.id);
      if (success) {
        setState(() {
          _isDismissed = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Alert dismissed'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Animate back in if dismiss failed
        _slideController.forward();
      }
    }
  }
}