import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';
import '../services/hybrid_data_service.dart';
import '../services/mock_data.dart';

class AlertProvider with ChangeNotifier {
  final HybridDataService _dataService = HybridDataService();
  
  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Alert> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Filter alerts by status
  List<Alert> get activeAlerts => 
      _alerts.where((alert) => alert.status == AlertStatusEnum.active).toList();
  
  List<Alert> get acknowledgedAlerts => 
      _alerts.where((alert) => alert.status == AlertStatusEnum.acknowledged).toList();
  
  List<Alert> get resolvedAlerts => 
      _alerts.where((alert) => alert.status == AlertStatusEnum.resolved).toList();

  // Filter alerts by severity
  List<Alert> get criticalAlerts => 
      _alerts.where((alert) => alert.severity == AlertSeverityEnum.critical).toList();
  
  List<Alert> get warningAlerts => 
      _alerts.where((alert) => alert.severity == AlertSeverityEnum.warning).toList();
  
  List<Alert> get infoAlerts => 
      _alerts.where((alert) => alert.severity == AlertSeverityEnum.info).toList();

  // Statistics
  int get totalAlerts => _alerts.length;
  int get activeAlertsCount => activeAlerts.length;
  int get criticalAlertsCount => criticalAlerts.where((a) => a.status == AlertStatusEnum.active).length;

  /// Load all alerts from the data service
  Future<void> loadAlerts() async {
    _setLoading(true);
    _error = null;
    
    try {
      _alerts = await _dataService.getAlerts();
      // Sort by triggered time (newest first)
      _alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load alerts: $e';
      print(_error);
      // Fallback to direct mock data if service fails
      _alerts = MockData.alerts;
      _alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    } finally {
      _setLoading(false);
    }
  }

  /// Acknowledge an alert
  Future<bool> acknowledgeAlert(String alertId) async {
    try {
      final success = await _dataService.acknowledgeAlert(alertId);
      if (success) {
        // Update alert status locally
        final alertIndex = _alerts.indexWhere((alert) => alert.id == alertId);
        if (alertIndex != -1) {
          _alerts[alertIndex] = _alerts[alertIndex].copyWith(
            status: AlertStatusEnum.acknowledged,
            acknowledgedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          notifyListeners();
          
          // Also update mock data
          MockData.removeAlert(alertId);
          return true;
        }
      }
    } catch (e) {
      print('Failed to acknowledge alert: $e');
    }
    return false;
  }

  /// Dismiss (resolve) an alert
  Future<bool> dismissAlert(String alertId) async {
    try {
      // For demo purposes, treat dismiss as acknowledge
      final success = await acknowledgeAlert(alertId);
      if (success) {
        // Remove from local list for demo purposes
        _alerts.removeWhere((alert) => alert.id == alertId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Failed to dismiss alert: $e');
    }
    return false;
  }

  /// Get alerts for a specific plant
  List<Alert> getAlertsForPlant(String plantId) => _alerts.where((alert) => alert.plantId == plantId).toList();

  /// Get the most recent alert for a plant
  Alert? getMostRecentAlertForPlant(String plantId) {
    final plantAlerts = getAlertsForPlant(plantId);
    if (plantAlerts.isEmpty) return null;
    
    plantAlerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return plantAlerts.first;
  }

  /// Check if plant has active alerts
  bool hasActiveAlertsForPlant(String plantId) => _alerts.any((alert) => 
        alert.plantId == plantId && alert.status == AlertStatusEnum.active);

  /// Get count of active alerts for a plant
  int getActiveAlertsCountForPlant(String plantId) => _alerts.where((alert) => 
        alert.plantId == plantId && alert.status == AlertStatusEnum.active).length;

  /// Refresh alerts data
  Future<void> refresh() async {
    await loadAlerts();
  }

  /// Clear all alerts (for demo reset)
  void clearAllAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  /// Add a mock alert (for demo purposes)
  void addMockAlert(String plantId, String title, String message, 
      {AlertSeverityEnum severity = AlertSeverityEnum.info}) {
    final alert = Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 1,
      plantId: plantId,
      alertRuleId: 999, // Mock rule ID
      title: title,
      message: message,
      severity: severity,
      status: AlertStatusEnum.active,
      triggeredAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _alerts.insert(0, alert); // Add to beginning (most recent)
    notifyListeners();
  }

  /// Update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Get alerts grouped by severity
  Map<AlertSeverityEnum, List<Alert>> get alertsGroupedBySeverity {
    final groups = <AlertSeverityEnum, List<Alert>>{};
    for (final severity in AlertSeverityEnum.values) {
      groups[severity] = _alerts.where((alert) => alert.severity == severity).toList();
    }
    return groups;
  }

  /// Get recent alerts (last 24 hours)
  List<Alert> get recentAlerts {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _alerts.where((alert) => alert.triggeredAt.isAfter(yesterday)).toList();
  }

  /// Check if there are any unread (active) alerts
  bool get hasUnreadAlerts => activeAlerts.isNotEmpty;

  /// Get summary for dashboard
  String get alertsSummary {
    if (_alerts.isEmpty) return 'No alerts';
    final active = activeAlertsCount;
    final critical = criticalAlertsCount;
    
    if (critical > 0) {
      return '$critical critical alert${critical > 1 ? 's' : ''}';
    } else if (active > 0) {
      return '$active active alert${active > 1 ? 's' : ''}';
    } else {
      return 'All alerts resolved';
    }
  }
}