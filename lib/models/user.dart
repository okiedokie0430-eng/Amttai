/// App user model mapping to the Appwrite `users` collection.
class AppUser {
  final String id;
  final String? userCode;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final List<String> pushTokens;
  final bool isPremium;
  final DateTime? premiumExpiresAt;
  final List<String> favoriteRecipeIds;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.userCode,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.pushTokens = const [],
    this.isPremium = false,
    this.premiumExpiresAt,
    this.favoriteRecipeIds = const [],
    required this.createdAt,
  });

  bool get hasPremiumAccess {
    if (!isPremium) return false;
    // If no expiry is set, premium is permanent
    if (premiumExpiresAt == null) return true;
    return premiumExpiresAt!.isAfter(DateTime.now());
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['\$id'] as String? ?? json['id'] as String,
        userCode: json['user_code'] as String?,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        photoUrl: json['photo_url'] as String?,
        pushTokens:
            (json['push_tokens'] as List<dynamic>?)?.map((e) => '$e').toList() ??
                const [],
        isPremium: json['is_premium'] as bool? ?? false,
        premiumExpiresAt: json['premium_expires_at'] != null
            ? DateTime.parse(json['premium_expires_at'] as String)
            : null,
        favoriteRecipeIds:
            (json['favorite_recipe_ids'] as List<dynamic>?)?.cast<String>() ??
                [],
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_code': userCode,
        'name': name,
        'email': email,
        'phone': phone,
        'photo_url': photoUrl,
        'is_premium': isPremium,
        'premium_expires_at': premiumExpiresAt?.toIso8601String(),
        'favorite_recipe_ids': favoriteRecipeIds,
        'created_at': createdAt.toIso8601String(),
      };

  AppUser copyWith({
    String? id,
    String? userCode,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    List<String>? pushTokens,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    List<String>? favoriteRecipeIds,
    DateTime? createdAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        userCode: userCode ?? this.userCode,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        pushTokens: pushTokens ?? this.pushTokens,
        isPremium: isPremium ?? this.isPremium,
        premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
        favoriteRecipeIds: favoriteRecipeIds ?? this.favoriteRecipeIds,
        createdAt: createdAt ?? this.createdAt,
      );
}
