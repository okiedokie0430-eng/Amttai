/// Amttai Payment Bridge — Configuration Constants
///
/// All configurable values are loaded from environment variables (--dart-define)
/// with sensible defaults. Values marked PLACEHOLDER must be customized.
class BridgeConfig {
  BridgeConfig._();

  // ── Appwrite ──────────────────────────────────────────────
  static const String appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://fra.cloud.appwrite.io/v1',
  );
  static const String appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: 'amttai',
  );
  static const String appwriteApiKey = String.fromEnvironment(
    'APPWRITE_API_KEY',
    defaultValue: 'standard_b6f4a1858f9e74d8225fa0d7f0b47dcfb8dc5a9ccc4aebbc1538d7bf0f845d12fcd482541f9b29b1b87d948950b8327f83f298a6407aaf37ec1a46788c3ab6947f838fd4b644ca12f80105d0ffefd814d6e841ac411b8837b1c6781f19d99a339a8d7025f9ca79c5051167b384fba61788b6e3e413efaba4a1fd8bd5898012db',
  );

  // ── Database IDs ──────────────────────────────────────────
  static const String databaseId = 'amttai_db';

  // Collections (existing in main Amttai app)
  static const String paymentsCollection = 'payments';
  static const String usersCollection = 'users';

  // Collections (new, created by bridge)
  static const String smsTransactionsCollection = 'sms_transactions';
  static const String bridgeSettingsCollection = 'bridge_settings';

  // ── Appwrite Function ─────────────────────────────────────
  static const String processSmsPaymentFunctionId = 'process-sms-payment';

  // ── Security ──────────────────────────────────────────────
  static const String hmacSecret = String.fromEnvironment(
    'HMAC_SECRET',
    defaultValue: 'amttai-bridge-hmac-secret-change-me', // PLACEHOLDER
  );

  // ── Payment Reference ─────────────────────────────────────
  static const String transactionCodePrefix = 'AMTTAI';

  // ── Premium Plans (MNT) ───────────────────────────────────
  static const Map<String, int> planPrices = {
    'oneMonth': 6000,
    'threeMonth': 15000,
    'oneYear': 38000,
  };

  // Amount tolerance for matching (±MNT)
  static const int amountTolerance = 500;

  // ── Bank Info ─────────────────────────────────────────────
  static const String bankName = 'Голомт банк';
  static const String bankAccountNumber = '480015002905262908';

  // ── Retry / Sync ──────────────────────────────────────────
  static const int retryBaseDelayMs = 30000; // 30 seconds
  static const int retryMaxDelayMs = 1800000; // 30 minutes
  static const int retryMaxAttempts = 10;
  static const int syncIntervalMinutes = 15;
  static const int heartbeatIntervalMinutes = 30;

  // ── Logging ───────────────────────────────────────────────
  static const int logRetentionDays = 7;
  static const int dedupRetentionDays = 30;
  static const int transactionRetentionDays = 90;

  // ── Feature Flags ─────────────────────────────────────────
  static const bool strictMode = false; // Reject ambiguous parses
  static const bool foregroundServiceEnabled = true;
  static const bool fallbackParsingEnabled = true;

  // ── Platform Channels ─────────────────────────────────────
  static const String smsMethodChannel = 'com.amttai.bridge/sms';
  static const String smsEventChannel = 'com.amttai.bridge/sms_events';

  // ── WorkManager Task Names ────────────────────────────────
  static const String syncTaskName = 'com.amttai.bridge.sync';
  static const String heartbeatTaskName = 'com.amttai.bridge.heartbeat';
  static const String cleanupTaskName = 'com.amttai.bridge.cleanup';
}
