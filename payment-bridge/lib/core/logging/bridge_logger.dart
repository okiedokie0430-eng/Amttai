import 'package:flutter/foundation.dart';

/// Lightweight structured logger for the Payment Bridge.
///
/// Logs to both console (debug) and optionally to local database
/// via a provided callback. This avoids hard-coupling to the DB layer.
class BridgeLogger {
  BridgeLogger._();

  /// Callback to persist log entries. Set by the app initialization.
  static Future<void> Function(String level, String tag, String message,
      {String? metadata})? _persistCallback;

  static void setPersistCallback(
    Future<void> Function(String level, String tag, String message,
            {String? metadata})
        callback,
  ) {
    _persistCallback = callback;
  }

  static void debug(String tag, String message, {String? metadata}) {
    if (kDebugMode) debugPrint('[$tag] $message');
    _persistCallback?.call('debug', tag, message, metadata: metadata);
  }

  static void info(String tag, String message, {String? metadata}) {
    debugPrint('[$tag] ℹ️ $message');
    _persistCallback?.call('info', tag, message, metadata: metadata);
  }

  static void warn(String tag, String message, {String? metadata}) {
    debugPrint('[$tag] ⚠️ $message');
    _persistCallback?.call('warn', tag, message, metadata: metadata);
  }

  static void error(String tag, String message,
      {String? metadata, Object? error, StackTrace? stackTrace}) {
    debugPrint('[$tag] ❌ $message');
    if (error != null) debugPrint('  Error: $error');
    if (stackTrace != null && kDebugMode) debugPrint('  $stackTrace');

    final fullMeta = [
      ?metadata,
      if (error != null) 'error: $error',
    ].join('; ');

    _persistCallback?.call('error', tag, message,
        metadata: fullMeta.isNotEmpty ? fullMeta : null);
  }
}
