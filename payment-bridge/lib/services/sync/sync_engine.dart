import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/logging/bridge_logger.dart';
import '../../data/database/app_database.dart';

import '../appwrite/payment_approver.dart';
import 'retry_policy.dart';

/// Orchestrates syncing pending transactions to Appwrite.
///
/// Pulls items from the local SyncQueue, attempts to process each one
/// via PaymentApprover, and handles success/failure/retry.
class SyncEngine {
  static const _tag = 'SyncEngine';

  final AppDatabase _db;
  final PaymentApprover _approver;

  bool _isSyncing = false;

  SyncEngine(this._db, this._approver);

  bool get isSyncing => _isSyncing;

  /// Process all pending items in the sync queue.
  /// Returns the number of successfully processed items.
  Future<int> syncAll() async {
    if (_isSyncing) {
      BridgeLogger.debug(_tag, 'Sync already in progress, skipping');
      return 0;
    }

    _isSyncing = true;
    int successCount = 0;

    try {
      BridgeLogger.info(_tag, 'Starting sync cycle');

      final items = await _db.getPendingSyncItems();
      if (items.isEmpty) {
        BridgeLogger.debug(_tag, 'No pending items to sync');
        return 0;
      }

      BridgeLogger.info(_tag, 'Processing ${items.length} sync items');

      for (final item in items) {
        try {
          // Mark as in-progress
          await _db.updateSyncStatus(
              item.id, AppConstants.syncInProgress);

          // Parse payload
          final payload =
              jsonDecode(item.payload) as Map<String, dynamic>;

          final transactionCode =
              payload['transaction_code'] as String? ?? '';
          final directUserId = payload['direct_user_id'] as String?;
          final amount = payload['amount'] as int? ?? 0;
          final smsHash = payload['sms_hash'] as String? ?? '';
          final sender = payload['sender'] as String? ?? '';
          final plan = payload['plan'] as String?;

          if ((transactionCode.isEmpty && directUserId == null) || amount == 0) {
            BridgeLogger.warn(
                _tag, 'Invalid payload for sync item ${item.id}');
            await _db.updateSyncStatus(
                item.id, AppConstants.syncFailed,
                error: 'Invalid payload');
            continue;
          }

          // Attempt approval
          final result = await _approver.approvePayment(
            transactionCode: transactionCode.isEmpty ? null : transactionCode,
            directUserId: directUserId,
            amount: amount,
            smsHash: smsHash,
            sender: sender,
            plan: plan,
          );

          if (result.success) {
            // Success — mark sync done and update transaction
            await _db.updateSyncStatus(
                item.id, AppConstants.syncDone);
            await _db.updateTransactionStatus(
              item.transactionLocalId,
              AppConstants.statusSynced,
              paymentId: result.paymentId,
              userId: result.userId,
            );
            successCount++;
            BridgeLogger.info(_tag,
                'Sync success: ${result.paymentId} → ${result.plan}');
          } else if (result.isRetryable) {
            // Retryable failure — schedule retry
            final nextRetry =
                RetryPolicy.nextRetryAt(item.attempts);
            await _db.incrementSyncQueueAttempts(
                item.id, nextRetry, result.error);
            await _db.incrementSyncAttempts(
                item.transactionLocalId);
            BridgeLogger.warn(_tag,
                'Sync retry scheduled for item ${item.id}: '
                '${result.error}');
          } else {
            // Permanent failure
            await _db.updateSyncStatus(
                item.id, AppConstants.syncFailed,
                error: result.error);
            await _db.updateTransactionStatus(
              item.transactionLocalId,
              AppConstants.statusFailed,
              error: result.error,
            );
            BridgeLogger.error(_tag,
                'Sync permanent failure for item ${item.id}: '
                '${result.error}');
          }
        } catch (e, st) {
          BridgeLogger.error(_tag,
              'Error processing sync item ${item.id}',
              error: e, stackTrace: st);

          final nextRetry =
              RetryPolicy.nextRetryAt(item.attempts);
          await _db.incrementSyncQueueAttempts(
              item.id, nextRetry, e.toString());
        }
      }

      BridgeLogger.info(_tag,
          'Sync cycle complete: $successCount/${items.length} succeeded');
    } catch (e, st) {
      BridgeLogger.error(_tag, 'Sync cycle failed', error: e,
          stackTrace: st);
    } finally {
      _isSyncing = false;
    }

    return successCount;
  }

  /// Get current sync status for the UI.
  Future<SyncStatus> getStatus() async {
    final pendingCount = await _db.getPendingSyncCount();
    return SyncStatus(
      pendingCount: pendingCount,
      isSyncing: _isSyncing,
      lastSyncTime: DateTime.now()
    );
  }
}

class SyncStatus {
  final int pendingCount;
  final bool isSyncing;
  final DateTime lastSyncTime;

  const SyncStatus({
    required this.pendingCount,
    required this.isSyncing,
    required this.lastSyncTime,
  });
}
