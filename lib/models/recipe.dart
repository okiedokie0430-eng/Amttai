/// A single ingredient line inside a recipe.
class Ingredient {
  final String name;
  final String amount;
  final String? unit;

  const Ingredient({
    required this.name,
    required this.amount,
    this.unit,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String,
        amount: json['amount'] as String,
        unit: json['unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        if (unit != null) 'unit': unit,
      };

  Ingredient copyWith({String? name, String? amount, String? unit}) =>
      Ingredient(
        name: name ?? this.name,
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
      );
}

/// A single preparation / cooking step.
class RecipeStep {
  final int order;
  final String description;
  final String? imageUrl;
  final int? timerSeconds;

  const RecipeStep({
    required this.order,
    required this.description,
    this.imageUrl,
    this.timerSeconds,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        order: json['order'] as int,
        description: json['description'] as String,
        imageUrl: json['image_url'] as String?,
        timerSeconds: json['timer_seconds'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'order': order,
        'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        if (timerSeconds != null) 'timer_seconds': timerSeconds,
      };
}

/// Nutritional facts for one serving.
class NutritionalInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory NutritionalInfo.fromJson(Map<String, dynamic> json) =>
      NutritionalInfo(
        calories: json['calories'] as int,
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

/// Core recipe model mapping to the Appwrite `recipes` collection.
class Recipe {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? imageUrl;
  final String? videoUrl;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String difficulty; // easy | medium | hard
  final bool isPremium;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final NutritionalInfo? nutrition;
  final double averageRating;
  final int totalRatings;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl,
    this.videoUrl,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.difficulty,
    this.isPremium = false,
    this.ingredients = const [],
    this.steps = const [],
    this.nutrition,
    this.averageRating = 0,
    this.totalRatings = 0,
    required this.createdAt,
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['\$id'] as String? ?? json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      prepTimeMinutes: json['prep_time_minutes'] as int,
      cookTimeMinutes: json['cook_time_minutes'] as int,
      servings: json['servings'] as int,
      difficulty: json['difficulty'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nutrition: json['nutrition'] != null
          ? NutritionalInfo.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'prep_time_minutes': prepTimeMinutes,
        'cook_time_minutes': cookTimeMinutes,
        'servings': servings,
        'difficulty': difficulty,
        'is_premium': isPremium,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        if (nutrition != null) 'nutrition': nutrition!.toJson(),
        'average_rating': averageRating,
        'total_ratings': totalRatings,
        'created_at': createdAt.toIso8601String(),
      };

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    String? videoUrl,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? servings,
    String? difficulty,
    bool? isPremium,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    NutritionalInfo? nutrition,
    double? averageRating,
    int? totalRatings,
    DateTime? createdAt,
  }) =>
      Recipe(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        imageUrl: imageUrl ?? this.imageUrl,
        videoUrl: videoUrl ?? this.videoUrl,
        prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
        cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
        servings: servings ?? this.servings,
        difficulty: difficulty ?? this.difficulty,
        isPremium: isPremium ?? this.isPremium,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        nutrition: nutrition ?? this.nutrition,
        averageRating: averageRating ?? this.averageRating,
        totalRatings: totalRatings ?? this.totalRatings,
        createdAt: createdAt ?? this.createdAt,
      );
}
