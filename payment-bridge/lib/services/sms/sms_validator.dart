import '../../core/logging/bridge_logger.dart';
import 'sms_patterns.dart';

/// Validates SMS messages before processing.
///
/// Checks sender whitelist, content validity, and suspicious patterns.
class SmsValidator {
  static const _tag = 'SmsValidator';

  SmsValidator._();

  /// Validate an incoming SMS for processing eligibility.
  static ValidationResult validate({
    required String sender,
    required String body,
    List<String>? trustedSenders,
    bool strictMode = false,
  }) {
    final senders = trustedSenders ?? SmsPatterns.defaultTrustedSenders;

    // Check 1: Sender whitelist
    if (!_isTrustedSender(sender, senders)) {
      BridgeLogger.debug(_tag, 'Untrusted sender: $sender');
      return ValidationResult(
        isValid: false,
        reason: 'Sender not in trusted list: $sender',
      );
    }

    // Check 2: Message not empty
    if (body.trim().isEmpty) {
      return ValidationResult(isValid: false, reason: 'Empty message body');
    }

    // Check 3: Message length sanity (SMS should be < 1600 chars for multi-part)
    if (body.length > 2000) {
      return ValidationResult(
        isValid: false,
        reason: 'Message too long (${body.length} chars)',
      );
    }

    // Check 4: Contains at least one payment-related keyword
    if (!_hasPaymentKeyword(body)) {
      BridgeLogger.debug(_tag, 'No payment keywords found in SMS');
      if (strictMode) {
        return ValidationResult(
          isValid: false,
          reason: 'No payment keywords in message',
        );
      }
    }

    // Check 5: Anti-spoof — reject if message contains suspicious patterns
    if (_isSuspicious(body)) {
      BridgeLogger.warn(_tag, 'Suspicious SMS content detected');
      return ValidationResult(
        isValid: false,
        reason: 'Suspicious message content',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Check if sender matches any trusted sender pattern.
  static bool _isTrustedSender(String sender, List<String> trusted) {
    final normalized = sender.toLowerCase().replaceAll(RegExp(r'[\s\-+]'), '');
    return trusted.any((t) {
      final normalizedTrusted = t.toLowerCase().replaceAll(
        RegExp(r'[\s\-+]'),
        '',
      );
      return normalized.contains(normalizedTrusted) ||
          normalizedTrusted.contains(normalized);
    });
  }

  /// Check for payment-related keywords in the message.
  static bool _hasPaymentKeyword(String body) {
    final lower = body.toLowerCase();
    const keywords = [
      'mnt',
      '₮',
      'төгрөг',
      'орлого',
      'орсон',
      'шилжүүлэг',
      'шилжүүлсэн',
      'хүлээн ав',
      'credit',
      'received',
      'transfer',
      'dansand',
      'dungeer',
      'orlogiin',
      'guilgee',
      'hiigdlee',
      'ognoo',
      'utga',
      'uldegdel',
      'amttai',
      'гүйлгээ',
      'данс',
      'account',
    ];
    return keywords.any(lower.contains);
  }

  /// Check for suspicious patterns that might indicate spoofing.
  static bool _isSuspicious(String body) {
    final lower = body.toLowerCase();
    const suspicious = [
      'click here',
      'tap here',
      'verify your',
      'update your',
      'confirm your password',
      'http://', // HTTP (not HTTPS) links in bank SMS
      'bit.ly',
      'tinyurl',
      'urgent action',
    ];
    return suspicious.any(lower.contains);
  }
}

/// Result of SMS validation.
class ValidationResult {
  final bool isValid;
  final String? reason;

  const ValidationResult({required this.isValid, this.reason});

  @override
  String toString() => 'ValidationResult(valid=$isValid, reason=$reason)';
}
