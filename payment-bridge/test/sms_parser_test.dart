import 'package:flutter_test/flutter_test.dart';
import 'package:payment_bridge/services/sms/sms_parser.dart';

void main() {
  group('SmsParser production transliterated format', () {
    test('parses amount, transaction code, user id, and plan', () {
      const body =
          '290*****08 dansand 9000 dungeer orlogiin guilgee hiigdlee. '
          'Ognoo: 2026-04-26 11:04, Utga:  AMTTAI-ONEMONTH-user_123 Uldegdel: 45000';

      final parsed = SmsParser.parse(
        sender: 'Golomt',
        body: body,
        receivedAt: DateTime(2026, 4, 26, 11, 5),
      );

      expect(parsed.isValid, isTrue);
      expect(parsed.amount, 9000);
      expect(parsed.transactionCode, 'AMTTAI-ONEMONTH-USER_123');
      expect(parsed.directUserId, 'user_123');
      expect(parsed.plan, 'oneMonth');
      expect(parsed.parseMethod, 'transliterated_incoming');
    });

    test('supports six-month duration token', () {
      const body =
          '290*****08 dansand 36000 dungeer orlogiin guilgee hiigdlee. '
          'Ognoo: 2026-04-26, Utga: AMTTAI-SIXMONTH-abc987 Uldegdel: 99000';

      final parsed = SmsParser.parse(
        sender: 'Golomt',
        body: body,
        receivedAt: DateTime(2026, 4, 26, 12, 0),
      );

      expect(parsed.isValid, isTrue);
      expect(parsed.amount, 36000);
      expect(parsed.transactionCode, 'AMTTAI-SIXMONTH-ABC987');
      expect(parsed.directUserId, 'abc987');
      expect(parsed.plan, 'sixMonth');
    });

    test('handles decimal amounts like 6000.00', () {
      const body =
          '290*****08 dansand 6000.00 dungeer orlogiin guilgee hiigdlee. '
          'Ognoo: 2026-04-26, Utga: AMTTAI-ONEMONTH-user_555 Uldegdel: 45000.50';

      final parsed = SmsParser.parse(
        sender: 'Golomt',
        body: body,
        receivedAt: DateTime(2026, 4, 26, 10, 30),
      );

      expect(parsed.isValid, isTrue);
      expect(parsed.amount, 6000); // 6000.00 rounds to 6000
      expect(parsed.transactionCode, 'AMTTAI-ONEMONTH-USER_555');
      expect(parsed.directUserId, 'user_555');
      expect(parsed.plan, 'oneMonth');
    });
  });
}
