import 'package:flutter/services.dart';

import '../../core/config/bridge_config.dart';
import '../../core/security/device_binding.dart';
import '../../settings/settings_manager.dart';

class NativeBridgeController {
  static const _channel = MethodChannel(BridgeConfig.smsMethodChannel);

  NativeBridgeController._();

  static Future<void> syncSettings(BridgeSettings settings) async {
    final deviceId = await DeviceBinding.getDeviceId();
    final apiKey = await DeviceBinding.getApiKey() ?? '';
    final hmacSecret =
        await DeviceBinding.getHmacSecret() ?? BridgeConfig.hmacSecret;
    await _channel.invokeMethod('updateNativeSettings', {
      'trustedSenders': settings.trustedSenders,
      'targetUserIds': settings.targetUserIds,
      'amountTolerance': settings.amountTolerance,
      'retryBaseDelayMs': settings.retryBaseDelayMs,
      'retryMaxDelayMs': settings.retryMaxDelayMs,
      'retryMaxAttempts': settings.retryMaxAttempts,
      'foregroundServiceEnabled': settings.foregroundServiceEnabled,
      'fallbackParsingEnabled': settings.fallbackParsingEnabled,
      'strictMode': settings.strictMode,
      'appwriteEndpoint': BridgeConfig.appwriteEndpoint,
      'appwriteProjectId': BridgeConfig.appwriteProjectId,
      'databaseId': BridgeConfig.databaseId,
      'paymentsCollection': BridgeConfig.paymentsCollection,
      'usersCollection': BridgeConfig.usersCollection,
      'smsTransactionsCollection': BridgeConfig.smsTransactionsCollection,
      'hmacSecret': hmacSecret,
      'deviceId': deviceId,
    });
    await _channel.invokeMethod('syncNativeCredentials', {
      'apiKey': apiKey,
      'hmacSecret': hmacSecret,
      'deviceId': deviceId,
    });
  }

  static Future<Map<String, dynamic>> testParsing(String rawSms) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'testSmsParsing',
      {'rawSms': rawSms},
    );
    return Map<String, dynamic>.from(result ?? const {});
  }
}
