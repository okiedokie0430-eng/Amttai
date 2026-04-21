import 'dart:math';

/// Generates and validates a serialized user code format:
/// YY + DDD + RRRRRR + C
/// - YY: last 2 digits of UTC year
/// - DDD: day-of-year (001-366)
/// - RRRRRR: random 6 digits
/// - C: checksum digit (mod 10)
class UserCodeSerializer {
  UserCodeSerializer._();

  static final Random _random = Random.secure();

  static final RegExp _pattern = RegExp(r'^\d{12}$');

  static String generate({DateTime? timestamp}) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final year = (now.year % 100).toString().padLeft(2, '0');

    final dayOfYear = now
            .difference(DateTime.utc(now.year, 1, 1))
            .inDays +
        1;
    final day = dayOfYear.toString().padLeft(3, '0');

    final randomPart = List.generate(6, (_) => _random.nextInt(10)).join();
    final core = '$year$day$randomPart';
    final checksum = _checksum(core);

    return '$core$checksum';
  }

  static bool isValid(String value) {
    if (!_pattern.hasMatch(value)) return false;

    final core = value.substring(0, 11);
    final expected = _checksum(core).toString();
    final actual = value.substring(11, 12);
    return expected == actual;
  }

  static DateTime? tryDecodeIssuedDateUtc(String value) {
    if (!isValid(value)) return null;

    final yearPart = int.parse(value.substring(0, 2));
    final dayPart = int.parse(value.substring(2, 5));
    final fullYear = 2000 + yearPart;

    if (dayPart < 1 || dayPart > 366) return null;
    return DateTime.utc(fullYear, 1, 1).add(Duration(days: dayPart - 1));
  }

  static int _checksum(String digits) {
    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      final digit = int.parse(digits[i]);
      final weight = i.isEven ? 3 : 7;
      sum += digit * weight;
    }
    return sum % 10;
  }
}
