import 'package:appwrite/appwrite.dart';

import '../core/config/app_config.dart';
import '../models/payment.dart';
import 'appwrite_service.dart';

/// Handles premium payment submissions and status checks.
class PaymentService {
  Databases get _db => AppwriteService.instance.databases;

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
