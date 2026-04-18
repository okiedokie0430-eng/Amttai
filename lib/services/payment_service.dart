import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';

import '../core/config/app_config.dart';
import '../models/payment.dart';
import 'appwrite_service.dart';

class SocialPayCheckoutSession {
  final String deeplink;
  final String description;
  final String? providerReference;

  const SocialPayCheckoutSession({
    required this.deeplink,
    required this.description,
    this.providerReference,
  });
}

/// Handles premium payment submissions and status checks.
class PaymentService {
  final Databases _db = AppwriteService.instance.databases;
  final Functions _functions = Functions(AppwriteService.instance.client);

  /// Generate a unique transaction code: USERNAME-PLAN-TIMESTAMP
  String generateTransactionCode(
    String userName,
    PremiumPlan plan, {
    String prefix = 'AMTTAI',
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final clean = userName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    return '$prefix-$clean-${plan.name.toUpperCase()}-$ts';
  }

  String generateSocialPayDescription(String transactionCode) {
    return '${AppConfig.socialPayDescriptionPrefix}$transactionCode';
  }

  /// Request a provider-signed SocialPay checkout payload from backend.
  Future<SocialPayCheckoutSession> createSocialPayCheckout({
    required String userId,
    required String userName,
    required PremiumPlan plan,
    required int amountMnt,
    required String transactionCode,
    required String description,
  }) async {
    final execution = await _functions.createExecution(
      functionId: AppConfig.socialPayCheckoutFunctionId,
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'plan': plan.name,
        'amount': amountMnt,
        'transactionCode': transactionCode,
        'description': description,
      }),
      method: ExecutionMethod.pOST,
    );

    final rawResponse = execution.responseBody;
    dynamic decoded;
    try {
      decoded = jsonDecode(rawResponse);
    } catch (_) {
      throw Exception('Invalid checkout function response: $rawResponse');
    }
    final response = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    if (response['ok'] == false) {
      throw Exception(
        response['message'] ??
            data['message'] ??
            'SocialPay checkout request failed.',
      );
    }

    String? firstNonEmpty(List<dynamic> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final deeplink = firstNonEmpty([
      data['deeplink'],
      data['deepLink'],
      data['checkoutUrl'],
      data['paymentUrl'],
      response['deeplink'],
      response['deepLink'],
    ]);

    String resolvedDeeplink;
    if (deeplink != null) {
      resolvedDeeplink = deeplink;
    } else {
      final qrPayload = firstNonEmpty([
        data['qPay_QRcode'],
        data['qpay_qrcode'],
        data['qPayQrCode'],
        data['qr'],
        data['qrPayload'],
        response['qPay_QRcode'],
        response['qPayQrCode'],
        response['qr'],
      ]);
      final keyPayload = firstNonEmpty([
        data['key'],
        data['encryptedKey'],
        response['key'],
        response['encryptedKey'],
      ]);

      if (qrPayload != null) {
        resolvedDeeplink =
            'socialpay-payment://q?qPay_QRcode=${Uri.encodeComponent(qrPayload)}';
      } else if (keyPayload != null) {
        resolvedDeeplink =
            'socialpay-payment://key=${Uri.encodeComponent(keyPayload)}';
      } else {
        throw Exception(
          'SocialPay checkout did not return a deeplink or signed payload.',
        );
      }
    }

    final providerReference = firstNonEmpty([
      data['providerReference'],
      data['reference'],
      data['paymentId'],
      response['providerReference'],
      response['reference'],
    ]);

    return SocialPayCheckoutSession(
      deeplink: resolvedDeeplink,
      description: description,
      providerReference: providerReference,
    );
  }

  /// Submit a payment record.
  Future<Payment> submitPayment({
    required String userId,
    required PremiumPlan plan,
    required String transactionCode,
    required String transactionId,
  }) async {
    final doc = await _db.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.paymentsCollection,
      documentId: ID.unique(),
      data: {
        'user_id': userId,
        'plan': plan.name,
        'amount': plan.priceMNT,
        'transaction_code': transactionCode,
        'transaction_id': transactionId,
        'status': PaymentStatus.pending.name,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
    return Payment.fromJson(doc.data);
  }

  /// Create a pending payment record started by SocialPay deeplink flow.
  Future<Payment> createPendingSocialPayPayment({
    required String userId,
    required PremiumPlan plan,
    required String transactionCode,
  }) async {
    final doc = await _db.createDocument(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.paymentsCollection,
      documentId: ID.unique(),
      data: {
        'user_id': userId,
        'plan': plan.name,
        'amount': plan.priceMNT,
        'transaction_code': transactionCode,
        'transaction_id': 'SOCIALPAY_PENDING',
        'status': PaymentStatus.pending.name,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
    return Payment.fromJson(doc.data);
  }

  /// Get the latest payment for a user (to check status).
  Future<Payment?> getLatestPayment(String userId) async {
    final result = await _db.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.paymentsCollection,
      queries: [
        Query.equal('user_id', userId),
        Query.orderDesc('created_at'),
        Query.limit(1),
      ],
    );
    if (result.documents.isEmpty) return null;
    return Payment.fromJson(result.documents.first.data);
  }

  /// Get a payment by user and transaction code.
  Future<Payment?> getPaymentByTransactionCode({
    required String userId,
    required String transactionCode,
  }) async {
    final result = await _db.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.paymentsCollection,
      queries: [
        Query.equal('user_id', userId),
        Query.equal('transaction_code', transactionCode),
        Query.orderDesc('created_at'),
        Query.limit(1),
      ],
    );
    if (result.documents.isEmpty) return null;
    return Payment.fromJson(result.documents.first.data);
  }

  /// Get all payments for a user.
  Future<List<Payment>> getUserPayments(String userId) async {
    final result = await _db.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.paymentsCollection,
      queries: [Query.equal('user_id', userId), Query.orderDesc('created_at')],
    );
    return result.documents.map((d) => Payment.fromJson(d.data)).toList();
  }
}
