/// Chat message for customer service.
class SupportMessage {
  final String id;
  final String userId;
  final String message;
  final bool isFromAdmin;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.userId,
    required this.message,
    this.isFromAdmin = false,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) =>
      SupportMessage(
        id: json['\$id'] as String? ?? json['id'] as String,
        userId: json['user_id'] as String,
        message: json['message'] as String,
        isFromAdmin: json['is_from_admin'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'message': message,
        'is_from_admin': isFromAdmin,
        'created_at': createdAt.toIso8601String(),
      };
}
