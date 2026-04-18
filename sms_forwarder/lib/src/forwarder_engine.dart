import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

const String _enabledPrefKey = 'forwarder_enabled';
const String _logsPrefKey = 'forwarder_logs';

@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  await ForwarderEngine.processSmsMessage(message, source: 'background');
}

class ForwarderConfig {
  ForwarderConfig._();

  static const String endpoint = String.fromEnvironment(
    'FORWARDER_ENDPOINT',
    defaultValue: '',
  );

  static const String webhookSecret = String.fromEnvironment(
    'FORWARDER_WEBHOOK_SECRET',
    defaultValue: '',
  );

  static const String appwriteProjectId = String.fromEnvironment(
    'FORWARDER_APPWRITE_PROJECT_ID',
    defaultValue: '',
  );

  static const String xApiKey = String.fromEnvironment(
    'FORWARDER_X_API_KEY',
    defaultValue: '',
  );

  static const String authorization = String.fromEnvironment(
    'FORWARDER_AUTHORIZATION',
    defaultValue: '',
  );

  static const String senderAllowListRaw = String.fromEnvironment(
    'FORWARDER_ALLOWED_SENDERS',
    defaultValue: '',
  );

  static const String successKeywordsRaw = String.fromEnvironment(
    'FORWARDER_SUCCESS_KEYWORDS',
    defaultValue: 'success,successful,approved,completed,paid',
  );

  static const String failureKeywordsRaw = String.fromEnvironment(
    'FORWARDER_FAILURE_KEYWORDS',
    defaultValue: 'failed,rejected,declined,cancelled,canceled',
  );

  static const String transactionCodePattern = String.fromEnvironment(
    'FORWARDER_TX_CODE_REGEX',
    defaultValue: r'((?:SP|AMTTAI)-[A-Z0-9]+-[A-Z]+-\d+)',
  );

  static const bool allowNoTransactionCode = bool.fromEnvironment(
    'FORWARDER_ALLOW_NO_TX_CODE',
    defaultValue: false,
  );

  static const bool forwardUnclassified = bool.fromEnvironment(
    'FORWARDER_FORWARD_UNCLASSIFIED',
    defaultValue: false,
  );

  static const int requestTimeoutSeconds = int.fromEnvironment(
    'FORWARDER_REQUEST_TIMEOUT_SECONDS',
    defaultValue: 12,
  );

  static List<String> get senderAllowList => _splitCsv(senderAllowListRaw);
  static List<String> get successKeywords => _splitCsv(successKeywordsRaw);
  static List<String> get failureKeywords => _splitCsv(failureKeywordsRaw);

  static RegExp get transactionCodeRegex =>
      RegExp(transactionCodePattern, caseSensitive: false);

  static List<String> _splitCsv(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class ForwarderProcessOutcome {
  final bool matched;
  final bool forwarded;
  final int? statusCode;
  final String message;
  final String? transactionCode;
  final String? status;

  const ForwarderProcessOutcome({
    required this.matched,
    required this.forwarded,
    required this.message,
    this.statusCode,
    this.transactionCode,
    this.status,
  });

  String get summary {
    final tx = transactionCode == null ? '' : ' tx=$transactionCode';
    final st = status == null ? '' : ' status=$status';
    final code = statusCode == null ? '' : ' http=$statusCode';
    return '$message$st$tx$code';
  }
}

class _SmsClassification {
  final String status;
  final String transactionCode;

  const _SmsClassification({
    required this.status,
    required this.transactionCode,
  });
}

class ForwarderEngine {
  ForwarderEngine._();

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledPrefKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefKey, enabled);
    await _appendLog(enabled ? 'Forwarding enabled' : 'Forwarding paused');
  }

  static Future<List<String>> readLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.from(prefs.getStringList(_logsPrefKey) ?? const []);
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsPrefKey);
  }

  static Future<ForwarderProcessOutcome> processSmsMessage(
    SmsMessage message, {
    required String source,
  }) {
    return processRawMessage(
      body: message.body ?? '',
      sender: message.address ?? '',
      source: source,
    );
  }

  static Future<ForwarderProcessOutcome> processRawMessage({
    required String body,
    required String sender,
    required String source,
  }) async {
    final trimmedBody = body.trim();
    final trimmedSender = sender.trim();

    final enabled = await isEnabled();
    if (!enabled) {
      return const ForwarderProcessOutcome(
        matched: false,
        forwarded: false,
        message: 'Ignored: forwarding paused',
      );
    }

    if (trimmedBody.isEmpty) {
      return const ForwarderProcessOutcome(
        matched: false,
        forwarded: false,
        message: 'Ignored: empty SMS body',
      );
    }

    if (!_senderAllowed(trimmedSender)) {
      return ForwarderProcessOutcome(
        matched: false,
        forwarded: false,
        message: 'Ignored: sender not in allow list ($trimmedSender)',
      );
    }

    final classification = _classify(trimmedBody);
    if (classification == null) {
      return const ForwarderProcessOutcome(
        matched: false,
        forwarded: false,
        message: 'Ignored: not recognized as payment result',
      );
    }

    if (ForwarderConfig.endpoint.isEmpty) {
      return const ForwarderProcessOutcome(
        matched: true,
        forwarded: false,
        message: 'Blocked: FORWARDER_ENDPOINT is empty',
      );
    }

    final payload = <String, dynamic>{
      'status': classification.status,
      'transaction_code': classification.transactionCode,
      'reference': classification.transactionCode,
      'transaction_id': 'SMS-${DateTime.now().millisecondsSinceEpoch}',
      'source': 'sms_forwarder',
      'sender': trimmedSender,
      'message': trimmedBody,
      'received_at': DateTime.now().toIso8601String(),
      'channel': source,
    };

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (ForwarderConfig.webhookSecret.isNotEmpty) {
      headers['x-socialpay-signature'] = ForwarderConfig.webhookSecret;
    }
    if (ForwarderConfig.appwriteProjectId.isNotEmpty) {
      headers['X-Appwrite-Project'] = ForwarderConfig.appwriteProjectId;
    }
    if (ForwarderConfig.xApiKey.isNotEmpty) {
      headers['x-api-key'] = ForwarderConfig.xApiKey;
    }
    if (ForwarderConfig.authorization.isNotEmpty) {
      headers['Authorization'] =
          ForwarderConfig.authorization.startsWith('Bearer ')
          ? ForwarderConfig.authorization
          : 'Bearer ${ForwarderConfig.authorization}';
    }

    try {
      final uri = Uri.parse(ForwarderConfig.endpoint);
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(Duration(seconds: ForwarderConfig.requestTimeoutSeconds));

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      final outcome = ForwarderProcessOutcome(
        matched: true,
        forwarded: ok,
        statusCode: response.statusCode,
        transactionCode: classification.transactionCode,
        status: classification.status,
        message: ok
            ? 'Forwarded successfully'
            : 'Forward failed: ${response.body}',
      );

      await _appendLog(
        '[${DateTime.now().toIso8601String()}] ${outcome.summary}',
      );

      return outcome;
    } on TimeoutException {
      final outcome = ForwarderProcessOutcome(
        matched: true,
        forwarded: false,
        transactionCode: classification.transactionCode,
        status: classification.status,
        message: 'Forward failed: request timeout',
      );
      await _appendLog(
        '[${DateTime.now().toIso8601String()}] ${outcome.summary}',
      );
      return outcome;
    } catch (e) {
      final outcome = ForwarderProcessOutcome(
        matched: true,
        forwarded: false,
        transactionCode: classification.transactionCode,
        status: classification.status,
        message: 'Forward failed: $e',
      );
      await _appendLog(
        '[${DateTime.now().toIso8601String()}] ${outcome.summary}',
      );
      return outcome;
    }
  }

  static _SmsClassification? _classify(String body) {
    final lowerBody = body.toLowerCase();

    final successHit = ForwarderConfig.successKeywords.any(lowerBody.contains);
    final failureHit = ForwarderConfig.failureKeywords.any(lowerBody.contains);

    if (!successHit && !failureHit && !ForwarderConfig.forwardUnclassified) {
      return null;
    }

    final txMatch = ForwarderConfig.transactionCodeRegex.firstMatch(body);
    final txCode = txMatch?.group(1)?.trim() ?? txMatch?.group(0)?.trim() ?? '';

    if (txCode.isEmpty && !ForwarderConfig.allowNoTransactionCode) {
      return null;
    }

    final status = failureHit
        ? 'rejected'
        : successHit
        ? 'approved'
        : 'pending';

    return _SmsClassification(
      status: status,
      transactionCode: txCode.isEmpty
          ? 'SMS-${DateTime.now().millisecondsSinceEpoch}'
          : txCode,
    );
  }

  static bool _senderAllowed(String sender) {
    final allowList = ForwarderConfig.senderAllowList;
    if (allowList.isEmpty) return true;

    for (final allowed in allowList) {
      if (_senderMatches(sender, allowed)) {
        return true;
      }
    }

    return false;
  }

  static bool _senderMatches(String sender, String allowed) {
    final senderLower = sender.toLowerCase();
    if (senderLower.contains(allowed) || allowed.contains(senderLower)) {
      return true;
    }

    final senderDigits = sender.replaceAll(RegExp(r'\D'), '');
    final allowedDigits = allowed.replaceAll(RegExp(r'\D'), '');

    if (senderDigits.isEmpty || allowedDigits.isEmpty) return false;

    return senderDigits.endsWith(allowedDigits) ||
        allowedDigits.endsWith(senderDigits);
  }

  static Future<void> _appendLog(String line) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = List<String>.from(
      prefs.getStringList(_logsPrefKey) ?? const [],
    );
    existing.insert(0, line);
    final trimmed = existing.take(100).toList(growable: false);
    await prefs.setStringList(_logsPrefKey, trimmed);
  }
}
