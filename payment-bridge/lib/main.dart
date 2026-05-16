import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/bridge_logger.dart';
import 'core/security/device_binding.dart';
import 'data/database/app_database.dart';
import 'services/appwrite/appwrite_client.dart';
import 'services/appwrite/payment_approver.dart';
import 'services/background/foreground_service.dart';
import 'services/background/watchdog.dart';
import 'services/native/native_bridge_controller.dart';
import 'services/sms/sms_listener.dart';
import 'services/sync/sync_engine.dart';
import 'services/sync/sync_worker.dart';
import 'settings/settings_manager.dart';

import 'app.dart';

/// App Database Provider
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Settings Provider
final settingsProvider = Provider<SettingsManager>((ref) {
  final db = ref.watch(dbProvider);
  return SettingsManager(db);
});

/// Appwrite Client Provider
final appwriteClientProvider = Provider<AppwriteClient>((ref) {
  return AppwriteClient.instance;
});

/// Payment Approver Provider
final paymentApproverProvider = Provider<PaymentApprover>((ref) {
  final client = ref.watch(appwriteClientProvider);
  return PaymentApprover(client);
});

/// Sync Engine Provider
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(dbProvider);
  final approver = ref.watch(paymentApproverProvider);
  return SyncEngine(db, approver);
});

/// Watchdog Provider
final watchdogProvider = Provider<Watchdog>((ref) {
  final db = ref.watch(dbProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return Watchdog(db, syncEngine);
});

/// SMS Listener Provider
final smsListenerProvider = Provider<SmsListener>((ref) {
  final db = ref.watch(dbProvider);
  return SmsListener(db);
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Appwrite Client
  await AppwriteClient.instance.init();

  // Set up logging to persist to DB
  final tempDb = AppDatabase();
  BridgeLogger.setPersistCallback((level, tag, message, {metadata}) async {
    try {
      await tempDb.insertLog({
        'level': level,
        'tag': tag,
        'message': message,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Failed to persist log: $e');
    }
  });

  // Ensure device is bound (ID generated)
  await DeviceBinding.getDeviceId();

  // Initialize WorkManager
  await SyncWorker.initialize();
  await SyncWorker.registerPeriodicSync();
  await SyncWorker.registerHeartbeat();

  // Load initial settings
  final settingsManager = SettingsManager(tempDb);
  await settingsManager.load();
  await NativeBridgeController.syncSettings(settingsManager.current);

  // Close temp DB used for init
  await tempDb.close();

  // Optional: Start Foreground Service if enabled in settings
  if (settingsManager.current.foregroundServiceEnabled) {
    await ForegroundServiceController.start();
  }

  runApp(const ProviderScope(child: AmttaiBridgeApp()));
}
