import 'package:flutter/services.dart';

class GestureExclusionService {
  GestureExclusionService._();

  static const _channel = MethodChannel('com.amttai.amttai/recommendation');

  /// Excludes a strip on the left edge from Android system gesture navigation.
  /// [widthDp] defaults to 30dp.
  static Future<void> setLeftEdgeExclusion({int widthDp = 30}) async {
    try {
      await _channel.invokeMethod('setGestureExclusion', {'widthDp': widthDp});
    } catch (_) {}
  }

  /// Clears all gesture exclusion rects.
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod('clearGestureExclusion');
    } catch (_) {}
  }
}
