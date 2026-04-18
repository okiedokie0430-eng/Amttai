import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder/src/forwarder_engine.dart';

void main() {
  test('default classification regex exists', () {
    final regex = ForwarderConfig.transactionCodeRegex;
    final match = regex.firstMatch('Payment SP-USER-ONEMONTH-123456 success');
    expect(match, isNotNull);
  });
}
