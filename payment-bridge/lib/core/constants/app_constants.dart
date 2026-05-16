/// Static constants that never change at runtime.
class AppConstants {
  AppConstants._();

  static const String appName = 'Amttai Payment Bridge';
  static const String appVersion = '1.0.0';

  // SMS queue states
  static const String statusRaw = 'raw';
  static const String statusParsed = 'parsed';
  static const String statusMatched = 'matched';
  static const String statusSynced = 'synced';
  static const String statusFailed = 'failed';
  static const String statusDuplicate = 'duplicate';
  static const String statusRejected = 'rejected';

  // Sync queue states
  static const String syncPending = 'pending';
  static const String syncInProgress = 'in_progress';
  static const String syncDone = 'done';
  static const String syncFailed = 'failed';
  static const String syncDead = 'dead';

  // Log levels
  static const String logDebug = 'debug';
  static const String logInfo = 'info';
  static const String logWarn = 'warn';
  static const String logError = 'error';

  // Payment status (matches main Amttai app)
  static const String paymentPending = 'pending';
  static const String paymentApproved = 'approved';
  static const String paymentRejected = 'rejected';
}
