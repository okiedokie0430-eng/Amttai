import 'dart:async';

import '../../core/logging/bridge_logger.dart';
import '../../data/database/app_database.dart';
import '../sync/sync_engine.dart';
import 'foreground_service.dart';

/// Watchdog that monitors bridge health and triggers recovery.
class Watchdog {
  static const _tag = 'Watchdog';

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  Timer? _timer;

  Watchdog(this._db, this._syncEngine);

  /// Start the watchdog timer.
  void start({Duration interval = const Duration(minutes: 5)}) {
    stop();
    _timer = Timer.periodic(interval, (_) => _check());
    BridgeLogger.info(_tag, 'Watchdog started (interval: ${interval.inMinutes}m)');
  }

  /// Stop the watchdog timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Perform a health check.
  Future<HealthReport> check() async => _check();

  Future<HealthReport> _check() async {
    final report = HealthReport();

    try {
      // Check 1: Service running
      report.serviceRunning = await ForegroundServiceController.isRunning();
      if (!report.serviceRunning) {
        BridgeLogger.warn(_tag, 'Foreground service not running — restarting');
        await ForegroundServiceController.start();
      }

      // Check 2: Pending sync count
      report.pendingSyncCount = await _db.getPendingSyncCount();
      if (report.pendingSyncCount > 0 && !_syncEngine.isSyncing) {
        BridgeLogger.info(_tag,
            '${report.pendingSyncCount} items pending — triggering sync');
      }

      // Check 3: Battery optimization
      report.batteryExempted =
          await ForegroundServiceController.isBatteryExempted();

      // Check 4: Database health
      report.transactionCount = await _db.getTransactionCount();

      // Prune old data periodically
      await _db.pruneOldData();

      report.healthy = report.serviceRunning && report.batteryExempted;
      report.checkedAt = DateTime.now();

      BridgeLogger.debug(_tag, 'Health: $report');
    } catch (e) {
      BridgeLogger.error(_tag, 'Health check failed', error: e);
      report.healthy = false;
      report.error = e.toString();
    }

    return report;
  }

  bool get isRunning => _timer?.isActive ?? false;
}

class HealthReport {
  bool healthy = true;
  bool serviceRunning = false;
  bool batteryExempted = false;
  int pendingSyncCount = 0;
  int transactionCount = 0;
  DateTime? checkedAt;
  String? error;

  @override
  String toString() =>
      'HealthReport(healthy=$healthy, service=$serviceRunning, '
      'battery=$batteryExempted, pending=$pendingSyncCount, '
      'txns=$transactionCount)';
}
