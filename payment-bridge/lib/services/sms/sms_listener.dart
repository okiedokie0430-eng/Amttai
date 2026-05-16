import 'dart:async';
import 'dart:convert';


import 'package:flutter/services.dart';

import '../../core/config/bridge_config.dart';
import '../../core/logging/bridge_logger.dart';
import '../../core/security/hmac_signer.dart';
import '../../data/database/app_database.dart';
import '../../settings/settings_manager.dart';
import 'sms_parser.dart';
import 'sms_validator.dart';

/// Listens for incoming SMS via platform channel and processes them.
///
/// Two paths:
/// 1. Real-time: EventChannel streams SMS as they arrive (engine alive)
/// 2. Catch-up: MethodChannel polls SharedPreferences queue (after restart)
class SmsListener {
  static const _tag = 'SmsListener';

  final AppDatabase _db;
  final EventChannel _eventChannel;

  StreamSubscription? _eventSubscription;
  bool _isListening = false;

  /// Callback invoked after a new transaction is queued for sync.
  void Function()? onTransactionQueued;

  SmsListener(this._db)
      : _eventChannel = const EventChannel(BridgeConfig.smsEventChannel);

  /// Start listening for real-time SMS events.
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    BridgeLogger.info(_tag, 'Starting SMS listener');

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is String) {
          _processRawSms(data);
        }
      },
      onError: (Object error) {
        BridgeLogger.error(_tag, 'SMS event stream error', error: error);
      },
    );
  }

  /// Stop listening for SMS events.
  void stopListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _isListening = false;
    BridgeLogger.info(_tag, 'SMS listener stopped');
  }

  /// Process any unprocessed SMS from the native queue (catch-up after restart).
  Future<int> processQueuedSms() async {
    try {
      // Temporarily disable native polling to prevent MissingPluginException
      // final json = await _methodChannel.invokeMethod<String>('getUnprocessedSms');
      // if (json == null || json == '[]') return 0;
      return 0;

    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to process queued SMS', error: e);
      return 0;
    }
  }

  /// Process a single raw SMS JSON payload.
  Future<void> _processRawSms(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final sender = data['sender'] as String? ?? 'unknown';
      final body = data['body'] as String? ?? '';
      final timestamp = data['timestamp'] as int? ?? 0;
      final receivedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);

      BridgeLogger.info(_tag, 'Processing SMS from $sender');

      // Step 1: Validate sender + content
      final validation = SmsValidator.validate(
        sender: sender,
        body: body,
      );

      if (!validation.isValid) {
        BridgeLogger.debug(
            _tag, 'SMS rejected: ${validation.reason}');
        return;
      }

      // Load settings
      final settings = SettingsManager(_db);
      await settings.load();

      final customPatterns = settings.current.customRegexPatterns
          .map((p) {
            try {
              return RegExp(p, caseSensitive: false);
            } catch (_) {
              return null;
            }
          })
          .whereType<RegExp>()
          .toList();

      // Step 2: Check for duplicate
      final fingerprint =
          HmacSigner.fingerprint(sender, body, receivedAt);
      final isDup = await _db.isDuplicate(fingerprint);
      if (isDup) {
        BridgeLogger.info(_tag, 'Duplicate SMS detected, skipping');
        return;
      }

      // Step 3: Parse SMS
      final parsed = SmsParser.parse(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
        smsTemplate: settings.current.smsTemplate,
        customPatterns: customPatterns,
        amountTolerance: settings.current.amountTolerance,
      );

      if (!parsed.isValid) {
        BridgeLogger.debug(_tag, 'SMS did not match payment pattern');
        return;
      }

      // Step 4: Store transaction
      final smsHash = fingerprint.substring(0, 64);
      await _db.insertTransaction({
        'sms_hash': smsHash,
        'sender': sender,
        'body': body,
        'received_at': receivedAt.millisecondsSinceEpoch,
        'parsed_amount': parsed.amount,
        'parsed_transaction_code': parsed.transactionCode,
        'parsed_plan': parsed.plan,
        'status': parsed.transactionCode != null ? 'parsed' : 'raw',
      });

      // Step 5: Store dedup fingerprint
      await _db.insertDedup({
        'fingerprint': fingerprint,
        'sms_hash': smsHash,
        'expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      });

      // Step 6: Queue for sync if we have a transaction code or direct userId
      if ((parsed.transactionCode != null || parsed.directUserId != null) && parsed.amount != null) {
        final tx = await _db.getTransactionByHash(smsHash);
        if (tx != null) {
          final payload = jsonEncode({
            'sender': sender,
            'amount': parsed.amount,
            'transaction_code': parsed.transactionCode,
            'direct_user_id': parsed.directUserId,
            'plan': parsed.plan,
            'sms_hash': smsHash,
            'received_at': receivedAt.toIso8601String(),
            'parse_method': parsed.parseMethod,
          });

          await _db.insertSyncItem({
            'transaction_local_id': tx.id,
            'payload': payload,
            'priority': parsed.plan != null ? 10 : 5,
          });

          await _db.updateTransactionStatus(tx.id, 'matched');

          BridgeLogger.info(_tag,
              'Transaction queued: ${parsed.transactionCode ?? parsed.directUserId} '
              '(${parsed.amount} MNT, plan=${parsed.plan})');

          onTransactionQueued?.call();
        }
      }
    } catch (e, st) {
      BridgeLogger.error(_tag, 'Error processing SMS',
          error: e, stackTrace: st);
    }
  }

  bool get isListening => _isListening;
}
