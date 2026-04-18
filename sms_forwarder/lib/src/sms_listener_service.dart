import 'package:telephony/telephony.dart';

import 'forwarder_engine.dart';

class SmsListenerService {
  SmsListenerService._();

  static final Telephony _telephony = Telephony.instance;
  static bool _started = false;

  static Future<bool> requestPermissions() async {
    final result = await _telephony.requestPhoneAndSmsPermissions;
    return result ?? false;
  }

  static Future<void> start() async {
    if (_started) return;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        ForwarderEngine.processSmsMessage(message, source: 'foreground');
      },
      onBackgroundMessage: smsBackgroundHandler,
      listenInBackground: true,
    );

    _started = true;
  }

  static Future<void> stop() async {
    if (!_started) return;
    _telephony.listenIncomingSms(
      onNewMessage: (_) {},
      onBackgroundMessage: smsBackgroundHandler,
      listenInBackground: false,
    );
    _started = false;
  }
}
