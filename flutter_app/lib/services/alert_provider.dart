import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';
import 'api_client.dart';
import 'api_exceptions.dart';

class AlertProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _error;
  int? _userId;

  // Getters
  List<Alert> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Set the current user ID (needed for alert fetching)
  void setUserId(int userId) {
    _userId = userId;
  }

  // Filter alerts by status
  List<Alert> get activeAlerts =>
      _alerts.where((alert) => alert.status == AlertStatusEnum.active).toList();

  List<Alert> get acknowledgedAlerts => _alerts
      .where((alert) => alert.status == AlertStatusEnum.acknowledged)
      .toList();

  List<Alert> get resolvedAlerts => _alerts
      .where((alert) => alert.status == AlertStatusEnum.resolved)
      .toList();

  // Filter alerts by severity
  List<Alert> get criticalAlerts => _alerts
      .where((alert) => alert.severity == AlertSeverityEnum.critical)
      .toList();

  List<Alert> get warningAlerts => _alerts
      .where((alert) => alert.severity == AlertSeverityEnum.warning)
      .toList();

  List<Alert> get infoAlerts => _alerts
      .where((alert) => alert.severity == AlertSeverityEnum.info)
      .toList();

  // Statistics
  int get totalAlerts => _alerts.length;
  int get activeAlertsCount => activeAlerts.length;
  int get criticalAlertsCount =>
      criticalAlerts.where((a) => a.status == AlertStatusEnum.active).length;

  /// Load all alerts from the API
  Future<void> loadAlerts() async {
    if (_userId == null) {
      debugPrint('Cannot load alerts: userId not set');
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      _alerts = await _apiService.getAlerts(_userId!);
      // Sort by triggered time (newest first)
      _alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.messageHu;
      debugPrint('Failed to load alerts: ${e.message}');
    } catch (e) {
      _error = 'Failed to load alerts';
      debugPrint('Unexpected error loading alerts: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Acknowledge an alert
  Future<bool> acknowledgeAlert(String alertId) async {
    try {
      await _apiService.acknowledgeAlert(int.parse(alertId));

      // Update alert status locally
      final alertIndex = _alerts.indexWhere((alert) => alert.id == alertId);
      if (alertIndex != -1) {
        _alerts[alertIndex] = _alerts[alertIndex].copyWith(
          status: AlertStatusEnum.acknowledged,
          acknowledgedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      debugPrint('Failed to acknowledge alert: ${e.message}');
    } catch (e) {
      debugPrint('Failed to acknowledge alert: $e');
    }
    return false;
  }

  /// Resolve (dismiss) an alert
  Future<bool> resolveAlert(String alertId) async {
    try {
      await _apiService.resolveAlert(int.parse(alertId));

      // Update alert status locally
      final alertIndex = _alerts.indexWhere((alert) => alert.id == alertId);
      if (alertIndex != -1) {
        _alerts[alertIndex] = _alerts[alertIndex].copyWith(
          status: AlertStatusEnum.resolved,
          resolvedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _error = e.messageHu;
      notifyListeners();
      debugPrint('Failed to resolve alert: ${e.message}');
    } catch (e) {
      debugPrint('Failed to resolve alert: $e');
    }
    return false;
  }

  /// Dismiss an alert (alias for resolve)
  Future<bool> dismissAlert(String alertId) async {
    return resolveAlert(alertId);
  }

  /// Get alerts for a specific plant
  List<Alert> getAlertsForPlant(String plantId) =>
      _alerts.where((alert) => alert.plantId == plantId).toList();

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
  int getActiveAlertsCountForPlant(String plantId) => _alerts
      .where((alert) =>
          alert.plantId == plantId && alert.status == AlertStatusEnum.active)
      .length;

  /// Refresh alerts data
  Future<void> refresh() async {
    await loadAlerts();
  }

  /// Clear all alerts
  void clearAllAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _error = null;
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
      groups[severity] =
          _alerts.where((alert) => alert.severity == severity).toList();
    }
    return groups;
  }

  /// Get recent alerts (last 24 hours)
  List<Alert> get recentAlerts {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _alerts
        .where((alert) => alert.triggeredAt.isAfter(yesterday))
        .toList();
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
