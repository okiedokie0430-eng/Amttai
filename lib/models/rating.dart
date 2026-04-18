/// Rating model mapping to the Appwrite `ratings` collection.
class Rating {
  final String id;
  final String recipeId;
  final String userId;
  final String userName;
  final double score;
  final String? comment;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userName,
    required this.score,
    this.comment,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
        id: json['\$id'] as String? ?? json['id'] as String,
        recipeId: json['recipe_id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        score: (json['score'] as num).toDouble(),
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'user_id': userId,
        'user_name': userName,
        'score': score,
        'comment': comment,
        'created_at': createdAt.toIso8601String(),
      };
}
