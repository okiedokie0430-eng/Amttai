

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/bridge_config.dart';
import '../../core/logging/bridge_logger.dart';
import '../../core/security/device_binding.dart';
import '../../core/security/hmac_signer.dart';
import '../../core/security/nonce_manager.dart';
import 'appwrite_client.dart';

/// Handles matching parsed SMS transactions to pending payments
/// and approving premium subscriptions.
class PaymentApprover {
  static const _tag = 'PaymentApprover';

  final AppwriteClient _client;

  PaymentApprover(this._client);

  /// Process a verified SMS transaction.
  ///
  /// 1. Find matching pending payment by transaction_code
  /// 2. Validate amount matches plan
  /// 3. Approve payment
  /// 4. Activate user's premium
  /// 5. Create audit record
  ///
  /// Returns true if payment was approved, false otherwise.
  Future<PaymentApprovalResult> approvePayment({
    String? transactionCode,
    String? directUserId,
    required int amount,
    required String smsHash,
    required String sender,
    String? plan,
    DateTime? receivedAt,
  }) async {
    BridgeLogger.info(
        _tag, 'Approving payment: code=$transactionCode, userId=$directUserId, amount=$amount');

    try {
      String? paymentId;
      String? userId = directUserId;
      String? paymentPlan = plan ?? 'oneMonth'; // Default fallback plan if not matched

      // Step 1: Find matching pending payment if we don't have a direct user ID
      if (userId == null && transactionCode != null) {
      final paymentsResult = await _client.listDocuments(
        collectionId: BridgeConfig.paymentsCollection,
        queries: [
          'equal("transaction_code", ["$transactionCode"])',
          'equal("status", ["pending"])',
          'limit(1)',
        ],
      );

      final docs = paymentsResult['documents'] as List<dynamic>? ?? [];
      if (docs.isEmpty) {
        BridgeLogger.warn(
            _tag, 'No pending payment found for code: $transactionCode');
        return PaymentApprovalResult(
          success: false,
          error: 'No pending payment found',
        );
      }

      final payment = docs.first as Map<String, dynamic>;
      paymentId = payment['\$id'] as String;
      userId = payment['user_id'] as String;
      paymentPlan = payment['plan'] as String;
      final paymentAmount = payment['amount'] as int;

      // Step 2: Validate amount matches (with tolerance)
      final amountDiff = (amount - paymentAmount).abs();
      if (amountDiff > BridgeConfig.amountTolerance) {
        BridgeLogger.warn(_tag,
            'Amount mismatch: SMS=$amount, Payment=$paymentAmount '
            '(diff=$amountDiff, tolerance=${BridgeConfig.amountTolerance})');
        return PaymentApprovalResult(
          success: false,
          error: 'Amount mismatch: expected $paymentAmount, got $amount',
          paymentId: paymentId,
          userId: userId,
        );
      }
      } else if (userId == null) {
        return const PaymentApprovalResult(
          success: false,
          error: 'No userId or transactionCode provided',
        );
      }

      // Step 3: Approve the payment (if we have a payment document)
      final now = DateTime.now().toIso8601String();
      
      if (paymentId != null) {
        await _client.updateDocument(
          collectionId: BridgeConfig.paymentsCollection,
          documentId: paymentId,
          data: {
            'status': 'approved',
            'verified_at': now,
          },
        );
        BridgeLogger.info(
            _tag, 'Payment approved: $paymentId for user $userId');
      } else {
        // Direct premium bypass: optionally create an approved payment record
        paymentId = const Uuid().v4();
        await _client.createDocument(
          collectionId: BridgeConfig.paymentsCollection,
          documentId: paymentId,
          data: {
            'user_id': userId,
            'amount': amount,
            'plan': paymentPlan,
            'status': 'approved',
            'transaction_code': directUserId ?? transactionCode ?? 'DIRECT',
            'created_at': now,
            'verified_at': now,
          },
        );
        BridgeLogger.info(
            _tag, 'Direct payment record created: $paymentId for user $userId');
      }

      // Step 4: Activate premium for the user
      await _activatePremium(userId, paymentPlan);

      // Step 5: Create audit record in sms_transactions collection
      await _createAuditRecord(
        transactionCode: transactionCode ?? directUserId ?? 'DIRECT',
        amount: amount,
        smsHash: smsHash,
        sender: sender,
        paymentId: paymentId,
        userId: userId,
      );

      return PaymentApprovalResult(
        success: true,
        paymentId: paymentId,
        userId: userId,
        plan: paymentPlan,
      );
    } on DioException catch (e) {
      final message = e.response?.data?.toString() ?? e.message ?? 'Unknown';
      BridgeLogger.error(_tag, 'Appwrite error during approval',
          error: e, metadata: message);
      return PaymentApprovalResult(
        success: false,
        error: 'Appwrite error: $message',
        isRetryable: _isRetryable(e),
      );
    } catch (e, st) {
      BridgeLogger.error(_tag, 'Unexpected error during approval',
          error: e, stackTrace: st);
      return PaymentApprovalResult(
        success: false,
        error: 'Unexpected: $e',
        isRetryable: true,
      );
    }
  }

  /// Activate premium subscription for a user.
  Future<void> _activatePremium(String userId, String planName) async {
    // Calculate expiry based on plan
    final months = _planMonths(planName);
    final expiresAt =
        DateTime.now().add(Duration(days: months * 30)).toIso8601String();

    try {
      await _client.updateDocument(
        collectionId: BridgeConfig.usersCollection,
        documentId: userId,
        data: {
          'is_premium': true,
          'premium_expires_at': expiresAt,
        },
      );
      BridgeLogger.info(
          _tag, 'Premium activated: user=$userId, plan=$planName, '
          'expires=$expiresAt');
    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to activate premium for $userId',
          error: e);
      // Payment is already approved — premium activation failure is logged
      // but doesn't roll back the payment approval
    }
  }

  /// Create an audit record in the sms_transactions collection.
  Future<void> _createAuditRecord({
    required String transactionCode,
    required int amount,
    required String smsHash,
    required String sender,
    required String paymentId,
    required String userId,
  }) async {
    try {
      final deviceId = await DeviceBinding.getDeviceId();
      final nonce = NonceManager.generate();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final signature = HmacSigner.sign(
        deviceId: deviceId,
        transactionCode: transactionCode,
        amount: amount,
        timestamp: timestamp,
        nonce: nonce,
      );

      await _client.createDocument(
        collectionId: BridgeConfig.smsTransactionsCollection,
        documentId: const Uuid().v4(),
        data: {
          'device_id': deviceId,
          'sms_hash': smsHash,
          'sender': sender,
          'amount': amount,
          'transaction_code': transactionCode,
          'matched_payment_id': paymentId,
          'matched_user_id': userId,
          'status': 'approved',
          'processed_at': DateTime.now().toIso8601String(),
          'hmac_signature': signature,
          'nonce': nonce,
        },
      );
    } catch (e) {
      BridgeLogger.error(_tag, 'Failed to create audit record', error: e);
      // Non-critical — payment is already approved
    }
  }

  int _planMonths(String planName) {
    switch (planName) {
      case 'oneMonth':
        return 1;
      case 'threeMonth':
        return 3;
      case 'sixMonth':
        return 6;
      case 'oneYear':
        return 12;
      default:
        return 1;
    }
  }

  bool _isRetryable(DioException e) {
    final code = e.response?.statusCode;
    if (code == null) return true; // Network error
    return code >= 500 || code == 429; // Server error or rate limit
  }
}

/// Result of a payment approval attempt.
class PaymentApprovalResult {
  final bool success;
  final String? error;
  final String? paymentId;
  final String? userId;
  final String? plan;
  final bool isRetryable;

  const PaymentApprovalResult({
    required this.success,
    this.error,
    this.paymentId,
    this.userId,
    this.plan,
    this.isRetryable = false,
  });

  @override
  String toString() =>
      'PaymentApprovalResult(success=$success, payment=$paymentId, '
      'user=$userId, error=$error)';
}
