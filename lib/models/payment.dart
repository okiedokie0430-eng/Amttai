/// Payment status enum.
enum PaymentStatus { pending, approved, rejected }

/// Premium plan duration.
enum PremiumPlan {
  oneMonth(1, 6000, '1 Сар'),
  threeMonth(3, 15000, '3 Сар'),
  oneYear(12, 38000, '1 Жил');

  final int months;
  final int priceMNT;
  final String label;
  const PremiumPlan(this.months, this.priceMNT, this.label);
}

/// Payment model mapping to the Appwrite `payments` collection.
class Payment {
  final String id;
  final String userId;
  final PremiumPlan plan;
  final int amount;
  final String transactionCode;
  final String? transactionId;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? verifiedAt;

  const Payment({
    required this.id,
    required this.userId,
    required this.plan,
    required this.amount,
    required this.transactionCode,
    this.transactionId,
    this.status = PaymentStatus.pending,
    required this.createdAt,
    this.verifiedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['\$id'] as String? ?? json['id'] as String,
        userId: json['user_id'] as String,
        plan: PremiumPlan.values.firstWhere(
          (p) => p.name == json['plan'],
          orElse: () => PremiumPlan.oneMonth,
        ),
        amount: json['amount'] as int,
        transactionCode: json['transaction_code'] as String,
        transactionId: json['transaction_id'] as String?,
        status: PaymentStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => PaymentStatus.pending,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'plan': plan.name,
        'amount': amount,
        'transaction_code': transactionCode,
        'transaction_id': transactionId,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
      };

  Payment copyWith({
    String? id,
    String? userId,
    PremiumPlan? plan,
    int? amount,
    String? transactionCode,
    String? transactionId,
    PaymentStatus? status,
    DateTime? createdAt,
    DateTime? verifiedAt,
  }) =>
      Payment(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        plan: plan ?? this.plan,
        amount: amount ?? this.amount,
        transactionCode: transactionCode ?? this.transactionCode,
        transactionId: transactionId ?? this.transactionId,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        verifiedAt: verifiedAt ?? this.verifiedAt,
      );
}
