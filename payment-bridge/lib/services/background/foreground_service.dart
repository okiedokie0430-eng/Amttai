import 'package:flutter/services.dart';

import '../../core/config/bridge_config.dart';
import '../../core/logging/bridge_logger.dart';

/// Controls the Android foreground service from Flutter.
class ForegroundServiceController {
  static const _tag = 'ForegroundService';
  static const _channel = MethodChannel(BridgeConfig.smsMethodChannel);

  ForegroundServiceController._();

  /// Start the foreground service.
  static Future<bool> start() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('startForegroundService');
      BridgeLogger.info(_tag, 'Service started: $result');
      return result ?? false;
    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to start service', error: e);
      return false;
    }
  }

  /// Stop the foreground service.
  static Future<bool> stop() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('stopForegroundService');
      BridgeLogger.info(_tag, 'Service stopped: $result');
      return result ?? false;
    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to stop service', error: e);
      return false;
    }
  }

  /// Check if the foreground service is running.
  static Future<bool> isRunning() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request battery optimization exemption.
  static Future<bool> requestBatteryExemption() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('requestBatteryOptimizationExemption');
      BridgeLogger.info(_tag, 'Battery exemption result: $result');
      return result ?? false;
    } catch (e) {
      BridgeLogger.error(
          _tag, 'Failed to request battery exemption', error: e);
      return false;
    }
  }

  /// Check if battery optimization is exempted.
  static Future<bool> isBatteryExempted() async {
    try {
      final result = await _channel
          .invokeMethod<bool>('isBatteryOptimizationExempted');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
