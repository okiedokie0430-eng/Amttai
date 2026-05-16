import 'package:workmanager/workmanager.dart';

import '../../core/config/bridge_config.dart';
import '../../core/logging/bridge_logger.dart';
import '../../data/database/app_database.dart';
import '../appwrite/appwrite_client.dart';
import '../appwrite/payment_approver.dart';
import '../sms/sms_listener.dart';
import 'sync_engine.dart';

/// WorkManager callback dispatcher — runs in a background isolate.
///
/// This is the entry point for all background tasks. It must be a
/// top-level function (not a method on a class).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      BridgeLogger.info('WorkManager', 'Executing task: $taskName');

      // Initialize services in the background isolate
      final db = AppDatabase();
      final client = AppwriteClient.instance;
      await client.init();
      final approver = PaymentApprover(client);

      switch (taskName) {
        case BridgeConfig.syncTaskName:
        case Workmanager.iOSBackgroundTask:
          // Process any queued SMS from SharedPreferences
          final listener = SmsListener(db);
          await listener.processQueuedSms();

          // Sync pending transactions to Appwrite
          final engine = SyncEngine(db, approver);
          await engine.syncAll();
          break;

        case BridgeConfig.heartbeatTaskName:
          // Simple health check — just log and prune old data
          BridgeLogger.info('Heartbeat', 'Bridge alive');
          await db.pruneOldData();
          break;

        case BridgeConfig.cleanupTaskName:
          await db.pruneOldData();
          BridgeLogger.info('Cleanup', 'Old data pruned');
          break;

        default:
          // Handle the one-off SMS processing task
          final listener = SmsListener(db);
          await listener.processQueuedSms();

          final engine = SyncEngine(db, approver);
          await engine.syncAll();
          break;
      }

      return true;
    } catch (e) {
      BridgeLogger.error(
          'WorkManager', 'Task $taskName failed', error: e);
      return false; // WorkManager will retry
    }
  });
}

/// Helper to register all WorkManager tasks.
class SyncWorker {
  static const _tag = 'SyncWorker';

  SyncWorker._();

  /// Initialize WorkManager with the callback dispatcher.
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    BridgeLogger.info(_tag, 'WorkManager initialized');
  }

  /// Register the periodic sync task (every 15 minutes).
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      BridgeConfig.syncTaskName,
      BridgeConfig.syncTaskName,
      frequency: const Duration(minutes: BridgeConfig.syncIntervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
    BridgeLogger.info(_tag, 'Periodic sync registered');
  }

  /// Register the heartbeat task.
  static Future<void> registerHeartbeat() async {
    await Workmanager().registerPeriodicTask(
      BridgeConfig.heartbeatTaskName,
      BridgeConfig.heartbeatTaskName,
      frequency:
          const Duration(minutes: BridgeConfig.heartbeatIntervalMinutes),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    BridgeLogger.info(_tag, 'Heartbeat registered');
  }

  /// Trigger an immediate one-off sync.
  static Future<void> triggerImmediateSync() async {
    await Workmanager().registerOneOffTask(
      '${BridgeConfig.syncTaskName}_${DateTime.now().millisecondsSinceEpoch}',
      BridgeConfig.syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      initialDelay: const Duration(seconds: 2),
    );
    BridgeLogger.info(_tag, 'Immediate sync triggered');
  }

  /// Cancel all WorkManager tasks.
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    BridgeLogger.info(_tag, 'All tasks cancelled');
  }
}
