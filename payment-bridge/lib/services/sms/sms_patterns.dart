/// SMS regex patterns for Mongolian bank transaction detection.
///
/// Patterns are ordered by specificity. Each pattern provides named groups
/// for extracting amount, transaction code, and sender info.
///
/// These can be overridden at runtime via the settings system.
class SmsPatterns {
  SmsPatterns._();

  /// Default trusted SMS senders (Mongolian banks).
  /// PLACEHOLDER: Add actual sender numbers/short codes for your bank.
  static const List<String> defaultTrustedSenders = [
    // Golomt Bank sender IDs — replace/add actual values
    'Golomt',
    'GOLOMT',
    'golomtbank',
    '1800',
    '7766',
    '77660101',
    // Khan Bank
    'KhanBank',
    'KHANBANK',
    // State Bank
    'StateBank',
    // TDB
    'TDB',
    'tdbm',
    // Generic short codes
    '900',
    '1900',
  ];

  /// Primary production format (Latin transliteration) from Golomt SMS.
  ///
  /// Example:
  /// 290*****08 dansand 9000 dungeer orlogiin guilgee hiigdlee.
  /// Ognoo: 2026-04-26 11:04, Utga: AMTTAI-ONEMONTH-user_123 Uldegdel: 45000
  static final RegExp transliteratedIncoming = RegExp(
    r'(?<maskedAccount>\d{2,8}\*{2,}\d{2,8})\s+dansand\s+(?<amount>\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)\s+dungeer\s+orlogiin\s+guilgee\s+hiigdlee\.\s*Ognoo:\s*(?<date>[^,]+),\s*Utga:\s*AMTTAI-(?<duration>[A-Z0-9_]+)-(?<userId>[A-Z0-9_-]+)\s+Uldegdel:\s*(?<balance>\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)',
    caseSensitive: false,
    dotAll: true,
  );

  /// Primary pattern: Golomt Bank specific incoming transfer with AMTTAI code.
  /// Matches: "9,000 MNT орлого AMTTAI-USERNAME-PLAN-12345"
  static final RegExp golomtIncoming = RegExp(
    r'(\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)\s*(?:MNT|₮|төгрөг).*?(?:орлого|орсон|хүлээн\s*ав).*?(AMTTAI-[\w]+-[\w]+-\w+)',
    caseSensitive: false,
    dotAll: true,
  );

  /// Secondary pattern: Amount + AMTTAI reference in any order.
  static final RegExp amttaiReference = RegExp(
    r'(AMTTAI-[\w]+-[\w]+-\w+).*?(\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)\s*(?:MNT|₮|թөгрөг)|(\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)\s*(?:MNT|₮|թөгрөг).*?(AMTTAI-[\w]+-[\w]+-\w+)',
    caseSensitive: false,
    dotAll: true,
  );

  /// Fallback: Generic incoming transfer pattern (any Mongolian bank).
  /// Extracts amount only — transaction code searched separately.
  static final RegExp genericIncoming = RegExp(
    r'(\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)\s*(?:MNT|₮|թөгрөг).*?(?:орлого|орсон|хүлээн\s*ав|шилжүүлэг|шилжүүлсэн|credit|credited|received)',
    caseSensitive: false,
    dotAll: true,
  );

  /// Extract AMTTAI transaction code from anywhere in text.
  /// Supports both formats:
  /// - AMTTAI-USERNAME-PLAN-12345
  /// - AMTTAI-DURATION-USER_ID
  static final RegExp transactionCode = RegExp(
    r'AMTTAI-(?:[A-Z0-9_]+-){1,2}[A-Z0-9_-]+',
    caseSensitive: false,
  );

  /// Extract any numeric amount.
  static final RegExp amountExtractor = RegExp(
    r'(\d+(?:[,\s]\d{3})*(?:\.\d{1,2})?)\s*(?:MNT|₮|թөгрөг)',
    caseSensitive: false,
  );

  /// Extract account number (for additional validation).
  static final RegExp accountNumber = RegExp(r'\b(\d{10,20})\b');

  /// All default patterns in priority order.
  static List<RegExp> get allPatterns => [
    transliteratedIncoming,
    golomtIncoming,
    amttaiReference,
    genericIncoming,
  ];
}
