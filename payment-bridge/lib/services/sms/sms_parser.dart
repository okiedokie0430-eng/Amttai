import '../../core/logging/bridge_logger.dart';
import 'sms_patterns.dart';

/// Result of parsing an SMS message.
class ParsedSms {
  final String sender;
  final String body;
  final DateTime receivedAt;
  final int? amount;
  final String? transactionCode;
  final String? directUserId;
  final String? plan;
  final bool isValid;
  final String parseMethod; // which regex/strategy matched
  final String? error;

  const ParsedSms({
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.amount,
    this.transactionCode,
    this.directUserId,
    this.plan,
    this.isValid = false,
    this.parseMethod = 'none',
    this.error,
  });

  @override
  String toString() =>
      'ParsedSms(valid=$isValid, amount=$amount, code=$transactionCode, '
      'userId=$directUserId, plan=$plan, method=$parseMethod)';
}

/// Multi-strategy SMS parser.
///
/// Attempts to parse SMS using multiple regex strategies in priority order.
/// Returns the best parse result with extracted payment details.
class SmsParser {
  static const _tag = 'SmsParser';

  SmsParser._();

  /// Plan amounts to name mapping (reverse lookup).
  static const Map<int, String> _amountToPlan = {
    9000: 'oneMonth',
    21000: 'threeMonth',
    36000: 'sixMonth',
    6000: 'oneMonth',
    15000: 'threeMonth',
    38000: 'oneYear',
  };

  /// Parse an SMS message and extract payment details.
  static ParsedSms parse({
    required String sender,
    required String body,
    required DateTime receivedAt,
    String? smsTemplate,
    List<RegExp>? customPatterns,
    int amountTolerance = 500,
  }) {
    BridgeLogger.debug(_tag, 'Parsing SMS from $sender (${body.length} chars)');

    // Strategy 0: Direct User ID Template parsing
    if (smsTemplate != null && smsTemplate.isNotEmpty) {
      final result = _tryTemplatePattern(smsTemplate, sender, body, receivedAt);
      if (result.isValid) return result;
    }

    // Strategy 1: Production transliterated format with duration+user id
    var result = _tryTransliteratedIncomingPattern(sender, body, receivedAt);
    if (result.isValid) return result;

    // Strategy 2: Golomt Bank specific pattern
    result = _tryGolomtPattern(sender, body, receivedAt);
    if (result.isValid) return result;

    // Strategy 3: AMTTAI reference pattern (any order)
    result = _tryAmttaiRefPattern(sender, body, receivedAt);
    if (result.isValid) return result;

    // Strategy 4: Generic incoming transfer + separate code extraction
    result = _tryGenericPattern(sender, body, receivedAt);
    if (result.isValid) return result;

    // Strategy 5: Custom patterns from settings
    if (customPatterns != null) {
      for (final pattern in customPatterns) {
        result = _tryCustomPattern(pattern, sender, body, receivedAt);
        if (result.isValid) return result;
      }
    }

    // Strategy 6: Fallback — just try to find amount + transaction code
    result = _tryFallback(sender, body, receivedAt);
    if (result.isValid) return result;

    BridgeLogger.debug(_tag, 'No payment pattern matched');
    return ParsedSms(
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      error: 'No payment pattern matched',
    );
  }

  static ParsedSms _tryTemplatePattern(
    String template,
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    try {
      // Convert all spaces into flexible whitespace tokens to handle bank spacing inconsistencies
      String regexString = RegExp.escape(template)
          .replaceAll(RegExp(r'\s+'), r'\s+')
          .replaceAll(r'\{AMOUNT\}', r'(?<amount>[\d,\.\s]+)')
          .replaceAll(r'\{USER_ID\}', r'(?<userId>[a-zA-Z0-9_\-]+)')
          .replaceAll(r'\{DATE\}', r'(?<date>.+?)')
          .replaceAll(r'\{DURATION\}', r'(?<duration>[a-zA-Z0-9_]+)')
          .replaceAll(r'\{BALANCE\}', r'(?<balance>[\d,\.\s]+)');

      final pattern = RegExp(regexString, caseSensitive: false);
      final match = pattern.firstMatch(body);

      if (match != null) {
        int? amount;
        String? userId;
        String? duration;

        try {
          amount = _parseAmount(match.namedGroup('amount'));
        } catch (_) {}

        try {
          userId = match.namedGroup('userId');
        } catch (_) {}

        try {
          duration = match.namedGroup('duration');
        } catch (_) {}

        if (amount != null && userId != null) {
          final upperDuration = (duration ?? '').toUpperCase();
          final txCode = upperDuration.isEmpty
              ? null
              : 'AMTTAI-$upperDuration-${userId.toUpperCase()}';

          BridgeLogger.info(
            _tag,
            'Template matched: $amount MNT, userId=$userId, duration=$duration',
          );
          return ParsedSms(
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            amount: amount,
            transactionCode: txCode,
            directUserId: userId,
            plan: _planFromDuration(duration) ?? _matchPlan(amount),
            isValid: true,
            parseMethod: 'template',
          );
        }
      }
    } catch (e) {
      BridgeLogger.error(
        _tag,
        'Failed to parse SMS using template: $template',
        error: e,
      );
    }
    return _invalid(sender, body, receivedAt);
  }

  static ParsedSms _tryGolomtPattern(
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    final match = SmsPatterns.golomtIncoming.firstMatch(body);
    if (match == null) return _invalid(sender, body, receivedAt);

    final amount = _parseAmount(match.group(1));
    final code = match.group(2);

    if (amount != null && code != null) {
      BridgeLogger.info(
        _tag,
        'Golomt pattern matched: $amount MNT, code=$code',
      );
      return ParsedSms(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
        amount: amount,
        transactionCode: code.toUpperCase(),
        plan: _matchPlan(amount),
        isValid: true,
        parseMethod: 'golomt_incoming',
      );
    }
    return _invalid(sender, body, receivedAt);
  }

  static ParsedSms _tryTransliteratedIncomingPattern(
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    final match = SmsPatterns.transliteratedIncoming.firstMatch(body);
    if (match == null) return _invalid(sender, body, receivedAt);

    final amount = _parseAmount(match.namedGroup('amount'));
    final durationRaw = match.namedGroup('duration');
    final userId = match.namedGroup('userId');

    if (amount == null || durationRaw == null || userId == null) {
      return _invalid(sender, body, receivedAt);
    }

    final duration = durationRaw.toUpperCase();
    final code = 'AMTTAI-$duration-${userId.toUpperCase()}';

    BridgeLogger.info(
      _tag,
      'Transliterated pattern matched: $amount MNT, duration=$duration, userId=$userId',
    );

    return ParsedSms(
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      amount: amount,
      transactionCode: code,
      directUserId: userId,
      plan: _planFromDuration(duration) ?? _matchPlan(amount),
      isValid: true,
      parseMethod: 'transliterated_incoming',
    );
  }

  static ParsedSms _tryAmttaiRefPattern(
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    final match = SmsPatterns.amttaiReference.firstMatch(body);
    if (match == null) return _invalid(sender, body, receivedAt);

    // Pattern has two alternatives, check which groups matched
    String? code;
    int? amount;

    if (match.group(1) != null && match.group(2) != null) {
      code = match.group(1);
      amount = _parseAmount(match.group(2));
    } else if (match.group(3) != null && match.group(4) != null) {
      amount = _parseAmount(match.group(3));
      code = match.group(4);
    }

    if (amount != null && code != null) {
      BridgeLogger.info(
        _tag,
        'AMTTAI ref pattern matched: $amount MNT, code=$code',
      );
      return ParsedSms(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
        amount: amount,
        transactionCode: code.toUpperCase(),
        plan: _matchPlan(amount),
        isValid: true,
        parseMethod: 'amttai_reference',
      );
    }
    return _invalid(sender, body, receivedAt);
  }

  static ParsedSms _tryGenericPattern(
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    final amountMatch = SmsPatterns.genericIncoming.firstMatch(body);
    if (amountMatch == null) return _invalid(sender, body, receivedAt);

    final amount = _parseAmount(amountMatch.group(1));
    if (amount == null) return _invalid(sender, body, receivedAt);

    // Try to find transaction code separately
    final codeMatch = SmsPatterns.transactionCode.firstMatch(body);
    final code = codeMatch?.group(0)?.toUpperCase();

    if (code != null) {
      BridgeLogger.info(
        _tag,
        'Generic pattern + code matched: $amount MNT, code=$code',
      );
      return ParsedSms(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
        amount: amount,
        transactionCode: code,
        plan: _matchPlan(amount),
        isValid: true,
        parseMethod: 'generic_with_code',
      );
    }

    // Valid payment but no transaction code — still capture it
    BridgeLogger.info(
      _tag,
      'Generic pattern (no code): $amount MNT from $sender',
    );
    return ParsedSms(
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      amount: amount,
      plan: _matchPlan(amount),
      isValid: true,
      parseMethod: 'generic_no_code',
    );
  }

  static ParsedSms _tryCustomPattern(
    RegExp pattern,
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    final match = pattern.firstMatch(body);
    if (match == null) return _invalid(sender, body, receivedAt);

    // Try to extract amount and code from named groups or positional groups
    int? amount;
    String? code;

    try {
      amount = _parseAmount(match.namedGroup('amount'));
    } catch (_) {
      if (match.groupCount >= 1) amount = _parseAmount(match.group(1));
    }

    try {
      code = match.namedGroup('code');
    } catch (_) {
      if (match.groupCount >= 2) code = match.group(2);
    }

    if (amount != null) {
      code ??= SmsPatterns.transactionCode.firstMatch(body)?.group(0);
      return ParsedSms(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
        amount: amount,
        transactionCode: code?.toUpperCase(),
        plan: _matchPlan(amount),
        isValid: true,
        parseMethod: 'custom',
      );
    }
    return _invalid(sender, body, receivedAt);
  }

  static ParsedSms _tryFallback(
    String sender,
    String body,
    DateTime receivedAt,
  ) {
    // Just find any amount and AMTTAI code
    final amountMatch = SmsPatterns.amountExtractor.firstMatch(body);
    final codeMatch = SmsPatterns.transactionCode.firstMatch(body);

    final amount = _parseAmount(amountMatch?.group(1));
    final code = codeMatch?.group(0)?.toUpperCase();

    if (amount != null && code != null) {
      BridgeLogger.info(
        _tag,
        'Fallback pattern matched: $amount MNT, code=$code',
      );
      return ParsedSms(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
        amount: amount,
        transactionCode: code,
        plan: _matchPlan(amount),
        isValid: true,
        parseMethod: 'fallback',
      );
    }
    return _invalid(sender, body, receivedAt);
  }

  /// Parse amount string to integer MNT.
  /// Handles: "9,000", "9 000", "9000", "6000.00", "21,000.50" → 6000, 21000
  static int? _parseAmount(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .replaceAll('\u00a0', ''); // non-breaking space
      final parsed = double.tryParse(cleaned);
      return parsed?.round();
    } catch (_) {
      return null;
    }
  }

  /// Match amount to a known plan (with tolerance).
  static String? _matchPlan(int? amount, {int tolerance = 500}) {
    if (amount == null) return null;
    for (final entry in _amountToPlan.entries) {
      if ((amount - entry.key).abs() <= tolerance) {
        return entry.value;
      }
    }
    return null;
  }

  static String? _planFromDuration(String? durationRaw) {
    if (durationRaw == null || durationRaw.trim().isEmpty) return null;

    final token = durationRaw.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    const oneMonth = {'onemonth', '1month', '1m', '1sar'};
    const threeMonth = {'threemonth', '3month', '3m', '3sar'};
    const sixMonth = {'sixmonth', '6month', '6m', '6sar'};
    const oneYear = {'oneyear', '1year', '12month', '12m'};

    if (oneMonth.contains(token)) return 'oneMonth';
    if (threeMonth.contains(token)) return 'threeMonth';
    if (sixMonth.contains(token)) return 'sixMonth';
    if (oneYear.contains(token)) return 'oneYear';

    return null;
  }

  static ParsedSms _invalid(String sender, String body, DateTime receivedAt) =>
      ParsedSms(sender: sender, body: body, receivedAt: receivedAt);
}
