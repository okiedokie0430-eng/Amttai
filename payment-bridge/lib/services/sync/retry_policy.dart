import 'dart:math';

import '../../core/config/bridge_config.dart';

/// Exponential backoff retry policy with jitter.
class RetryPolicy {
  RetryPolicy._();

  /// Calculate the next retry delay based on attempt count.
  ///
  /// Formula: min(base * 2^attempt + jitter, max)
  /// Default: 30s base, 30min max, ±20% jitter
  static Duration nextDelay(
    int attempt, {
    int baseMs = BridgeConfig.retryBaseDelayMs,
    int maxMs = BridgeConfig.retryMaxDelayMs,
    double jitterFactor = 0.2,
  }) {
    final baseDelay = baseMs * (1 << attempt.clamp(0, 15));
    final clamped = baseDelay.clamp(baseMs, maxMs);

    // Add jitter: ±jitterFactor of the delay
    final jitterRange = (clamped * jitterFactor).round();
    final jitter = Random().nextInt(jitterRange * 2 + 1) - jitterRange;

    return Duration(milliseconds: (clamped + jitter).clamp(1000, maxMs));
  }

  /// Calculate the DateTime for the next retry.
  static DateTime nextRetryAt(int attempt) {
    return DateTime.now().add(nextDelay(attempt));
  }

  /// Check if we should give up (move to dead-letter).
  static bool shouldGiveUp(int attempt,
      {int maxAttempts = BridgeConfig.retryMaxAttempts}) {
    return attempt >= maxAttempts;
  }
}
