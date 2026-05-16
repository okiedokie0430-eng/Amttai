import 'dart:convert';

import '../core/config/bridge_config.dart';
import '../core/logging/bridge_logger.dart';
import '../data/database/app_database.dart';
import '../services/sms/sms_patterns.dart';

/// Settings model for the bridge.
class BridgeSettings {
  final List<String> trustedSenders;
  final List<String> targetUserIds;
  final String smsTemplate;
  final List<String> customRegexPatterns;
  final Map<String, int> planPrices;
  final int amountTolerance;
  final int retryBaseDelayMs;
  final int retryMaxDelayMs;
  final int retryMaxAttempts;
  final int heartbeatIntervalMinutes;
  final int syncIntervalMinutes;
  final int logRetentionDays;
  final bool strictMode;
  final bool foregroundServiceEnabled;
  final bool fallbackParsingEnabled;

  const BridgeSettings({
    required this.trustedSenders,
    required this.targetUserIds,
    required this.smsTemplate,
    required this.customRegexPatterns,
    required this.planPrices,
    required this.amountTolerance,
    required this.retryBaseDelayMs,
    required this.retryMaxDelayMs,
    required this.retryMaxAttempts,
    required this.heartbeatIntervalMinutes,
    required this.syncIntervalMinutes,
    required this.logRetentionDays,
    required this.strictMode,
    required this.foregroundServiceEnabled,
    required this.fallbackParsingEnabled,
  });

  /// Default settings.
  factory BridgeSettings.defaults() => BridgeSettings(
    trustedSenders: List.from(SmsPatterns.defaultTrustedSenders),
    targetUserIds: const [],
    smsTemplate:
        '290*****08 dansand {AMOUNT} dungeer orlogiin guilgee hiigdlee. Ognoo: {DATE}, Utga:  AMTTAI-{DURATION}-{USER_ID} Uldegdel: {BALANCE}',
    customRegexPatterns: const [],
    planPrices: Map.from(BridgeConfig.planPrices),
    amountTolerance: BridgeConfig.amountTolerance,
    retryBaseDelayMs: BridgeConfig.retryBaseDelayMs,
    retryMaxDelayMs: BridgeConfig.retryMaxDelayMs,
    retryMaxAttempts: BridgeConfig.retryMaxAttempts,
    heartbeatIntervalMinutes: BridgeConfig.heartbeatIntervalMinutes,
    syncIntervalMinutes: BridgeConfig.syncIntervalMinutes,
    logRetentionDays: BridgeConfig.logRetentionDays,
    strictMode: BridgeConfig.strictMode,
    foregroundServiceEnabled: BridgeConfig.foregroundServiceEnabled,
    fallbackParsingEnabled: BridgeConfig.fallbackParsingEnabled,
  );

  BridgeSettings copyWith({
    List<String>? trustedSenders,
    List<String>? targetUserIds,
    String? smsTemplate,
    List<String>? customRegexPatterns,
    Map<String, int>? planPrices,
    int? amountTolerance,
    int? retryBaseDelayMs,
    int? retryMaxDelayMs,
    int? retryMaxAttempts,
    int? heartbeatIntervalMinutes,
    int? syncIntervalMinutes,
    int? logRetentionDays,
    bool? strictMode,
    bool? foregroundServiceEnabled,
    bool? fallbackParsingEnabled,
  }) => BridgeSettings(
    trustedSenders: trustedSenders ?? this.trustedSenders,
    targetUserIds: targetUserIds ?? this.targetUserIds,
    smsTemplate: smsTemplate ?? this.smsTemplate,
    customRegexPatterns: customRegexPatterns ?? this.customRegexPatterns,
    planPrices: planPrices ?? this.planPrices,
    amountTolerance: amountTolerance ?? this.amountTolerance,
    retryBaseDelayMs: retryBaseDelayMs ?? this.retryBaseDelayMs,
    retryMaxDelayMs: retryMaxDelayMs ?? this.retryMaxDelayMs,
    retryMaxAttempts: retryMaxAttempts ?? this.retryMaxAttempts,
    heartbeatIntervalMinutes:
        heartbeatIntervalMinutes ?? this.heartbeatIntervalMinutes,
    syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
    logRetentionDays: logRetentionDays ?? this.logRetentionDays,
    strictMode: strictMode ?? this.strictMode,
    foregroundServiceEnabled:
        foregroundServiceEnabled ?? this.foregroundServiceEnabled,
    fallbackParsingEnabled:
        fallbackParsingEnabled ?? this.fallbackParsingEnabled,
  );
}

/// Manages settings persistence (local SQLite + Appwrite remote config).
class SettingsManager {
  static const _tag = 'Settings';

  final AppDatabase _db;
  BridgeSettings _current;

  SettingsManager(this._db) : _current = BridgeSettings.defaults();

  BridgeSettings get current => _current;

  /// Load settings from local database, applying defaults for missing keys.
  Future<void> load() async {
    try {
      final stored = await _db.getAllSettings();
      if (stored.isEmpty) {
        BridgeLogger.info(_tag, 'No stored settings, using defaults');
        return;
      }

      _current = BridgeSettings(
        trustedSenders:
            _decodeList(stored['trusted_senders']) ?? _current.trustedSenders,
        targetUserIds:
            _decodeList(stored['target_user_ids']) ?? _current.targetUserIds,
        smsTemplate: stored['sms_template'] ?? _current.smsTemplate,
        customRegexPatterns:
            _decodeList(stored['custom_regex_patterns']) ??
            _current.customRegexPatterns,
        planPrices: _decodeMap(stored['plan_prices']) ?? _current.planPrices,
        amountTolerance:
            int.tryParse(stored['amount_tolerance'] ?? '') ??
            _current.amountTolerance,
        retryBaseDelayMs:
            int.tryParse(stored['retry_base_delay_ms'] ?? '') ??
            _current.retryBaseDelayMs,
        retryMaxDelayMs:
            int.tryParse(stored['retry_max_delay_ms'] ?? '') ??
            _current.retryMaxDelayMs,
        retryMaxAttempts:
            int.tryParse(stored['retry_max_attempts'] ?? '') ??
            _current.retryMaxAttempts,
        heartbeatIntervalMinutes:
            int.tryParse(stored['heartbeat_interval_minutes'] ?? '') ??
            _current.heartbeatIntervalMinutes,
        syncIntervalMinutes:
            int.tryParse(stored['sync_interval_minutes'] ?? '') ??
            _current.syncIntervalMinutes,
        logRetentionDays:
            int.tryParse(stored['log_retention_days'] ?? '') ??
            _current.logRetentionDays,
        strictMode: stored['strict_mode'] == 'true',
        foregroundServiceEnabled:
            stored['foreground_service_enabled'] != 'false',
        fallbackParsingEnabled: stored['fallback_parsing_enabled'] != 'false',
      );

      BridgeLogger.info(_tag, 'Settings loaded from database');
    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to load settings', error: e);
    }
  }

  /// Save current settings to local database.
  Future<void> save() async {
    try {
      await _db.setSetting(
        'trusted_senders',
        jsonEncode(_current.trustedSenders),
      );
      await _db.setSetting(
        'target_user_ids',
        jsonEncode(_current.targetUserIds),
      );
      await _db.setSetting('sms_template', _current.smsTemplate);
      await _db.setSetting(
        'custom_regex_patterns',
        jsonEncode(_current.customRegexPatterns),
      );
      await _db.setSetting('plan_prices', jsonEncode(_current.planPrices));
      await _db.setSetting(
        'amount_tolerance',
        _current.amountTolerance.toString(),
      );
      await _db.setSetting(
        'retry_base_delay_ms',
        _current.retryBaseDelayMs.toString(),
      );
      await _db.setSetting(
        'retry_max_delay_ms',
        _current.retryMaxDelayMs.toString(),
      );
      await _db.setSetting(
        'retry_max_attempts',
        _current.retryMaxAttempts.toString(),
      );
      await _db.setSetting(
        'heartbeat_interval_minutes',
        _current.heartbeatIntervalMinutes.toString(),
      );
      await _db.setSetting(
        'sync_interval_minutes',
        _current.syncIntervalMinutes.toString(),
      );
      await _db.setSetting(
        'log_retention_days',
        _current.logRetentionDays.toString(),
      );
      await _db.setSetting('strict_mode', _current.strictMode.toString());
      await _db.setSetting(
        'foreground_service_enabled',
        _current.foregroundServiceEnabled.toString(),
      );
      await _db.setSetting(
        'fallback_parsing_enabled',
        _current.fallbackParsingEnabled.toString(),
      );

      BridgeLogger.info(_tag, 'Settings saved');
    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to save settings', error: e);
    }
  }

  /// Update settings and save.
  Future<void> update(BridgeSettings newSettings) async {
    _current = newSettings;
    await save();
  }

  List<String>? _decodeList(String? json) {
    if (json == null) return null;
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  Map<String, int>? _decodeMap(String? json) {
    if (json == null) return null;
    try {
      return (jsonDecode(json) as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}
