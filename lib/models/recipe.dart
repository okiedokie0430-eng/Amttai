import 'dart:convert';

/// A single ingredient line inside a recipe.
class Ingredient {
  final String name;
  final String amount;
  final String? unit;

  const Ingredient({required this.name, required this.amount, this.unit});

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
  final List<Ingredient>? ingredients;

  const RecipeStep({
    required this.order,
    required this.description,
    this.imageUrl,
    this.timerSeconds,
    this.ingredients,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    order: _asInt(json['order'] ?? json['step'] ?? json['index'], fallback: 1),
    description: _pickDescription(json),
    imageUrl: _pickOptionalString(json, const [
      'image_url',
      'imageUrl',
      'step_image_url',
      'stepImageUrl',
    ]),
    timerSeconds: _asNullableInt(
      json['timer_seconds'] ??
          json['timerSeconds'] ??
          json['duration_seconds'] ??
          json['durationSeconds'],
    ),
    ingredients: _parseStepIngredients(json['ingredients']),
  );

  Map<String, dynamic> toJson() => {
    'order': order,
    'description': description,
    if (imageUrl != null) 'image_url': imageUrl,
    if (timerSeconds != null) 'timer_seconds': timerSeconds,
    if (ingredients != null)
      'ingredients': ingredients!.map((i) => i.toJson()).toList(),
  };

  static List<Ingredient>? _parseStepIngredients(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String && value.isNotEmpty) {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
              .toList();
        }
      } else if (value is List) {
        return value
            .map((i) {
              if (i is String) {
                 final decoded = jsonDecode(i);
                 return Ingredient.fromJson(decoded as Map<String, dynamic>);
              } else if (i is Map<String, dynamic>) {
                 return Ingredient.fromJson(i);
              }
              return null;
            })
            .whereType<Ingredient>()
            .toList();
      }
    } catch (_) {}
    return null;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    final parsed = _asInt(value, fallback: -1);
    return parsed >= 0 ? parsed : null;
  }

  static String _pickDescription(Map<String, dynamic> json) {
    final value = _pickOptionalString(json, const [
      'description',
      'text',
      'instruction',
      'step',
    ]);
    return value ?? '';
  }

  static String? _pickOptionalString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = json[key];
      if (raw == null) {
        continue;
      }

      final value = '$raw'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }
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
  final List<String> englishKeywords;
  final String? searchText;
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
    this.englishKeywords = const [],
    this.searchText,
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
      id: (json['\$id'] ?? json['id'] ?? '').toString(),
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      englishKeywords: _parseEnglishKeywords(json),
      searchText: json['search_text'] as String?,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      prepTimeMinutes: _asInt(json['prep_time_minutes']),
      cookTimeMinutes: _asInt(json['cook_time_minutes']),
      servings: _asInt(json['servings'], fallback: 1),
      difficulty: json['difficulty'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      ingredients: _parseIngredients(json),
      steps: _parseSteps(json),
      nutrition: _parseNutrition(json),
      averageRating: _asDouble(json['average_rating']),
      totalRatings: _asInt(json['total_ratings']),
      createdAt: _parseDateTime(json['created_at'] ?? json['\$createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    final ingredientMaps = ingredients.map((e) => e.toJson()).toList();
    final stepMaps = steps.map((e) => e.toJson()).toList();
    final nutritionMap = nutrition?.toJson();

    return {
      'title': title,
      'description': description,
      'category': category,
      'english_keywords': englishKeywords,
      'search_text': _buildSearchText(
        title: title,
        category: category,
        description: description,
        englishKeywords: englishKeywords,
      ),
      'image_url': imageUrl,
      'video_url': videoUrl,
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'servings': servings,
      'difficulty': difficulty,
      'is_premium': isPremium,
      'ingredients': ingredientMaps,
      'steps': stepMaps,
      'nutrition': nutritionMap,
      // Schema-safe mirrors for Appwrite collections that use string attributes.
      'ingredients_json': jsonEncode(ingredientMaps),
      'steps_json': jsonEncode(stepMaps),
      'nutrition_json': nutritionMap == null ? null : jsonEncode(nutritionMap),
      'average_rating': averageRating,
      'total_ratings': totalRatings,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<Ingredient> _parseIngredients(Map<String, dynamic> json) {
    final raw = json['ingredients'];
    if (raw is List) {
      final mapped = raw
          .map(_parseIngredientEntry)
          .whereType<Ingredient>()
          .toList();
      if (mapped.isNotEmpty) return mapped;
    }

    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map(_parseIngredientEntry)
              .whereType<Ingredient>()
              .toList();
        }
      } catch (_) {
        final split = raw
            .split(RegExp(r'[,;\n]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .map((item) => Ingredient(name: item, amount: ''))
            .toList();
        if (split.isNotEmpty) {
          return split;
        }
      }
    }

    final rawJson = json['ingredients_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          return decoded
              .map(_parseIngredientEntry)
              .whereType<Ingredient>()
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  static Ingredient? _parseIngredientEntry(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);

      final name = _pickFirstNonEmptyString(map, const [
        'name',
        'ingredient',
        'ingredient_name',
        'title',
        'item',
      ]);
      if (name == null) {
        return null;
      }

      final amount =
          _pickFirstNonEmptyString(map, const ['amount', 'qty', 'quantity']) ??
          '';
      final unit = _pickFirstNonEmptyString(map, const [
        'unit',
        'measure',
        'uom',
      ]);

      return Ingredient(name: name, amount: amount, unit: unit);
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) {
        return null;
      }

      return Ingredient(name: text, amount: '');
    }

    return null;
  }

  static String? _pickFirstNonEmptyString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) {
        continue;
      }

      final normalized = '$value'.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  static List<RecipeStep> _parseSteps(Map<String, dynamic> json) {
    final raw = json['steps'];
    if (raw is List) {
      final mapped = raw
          .asMap()
          .entries
          .map((entry) => _parseStepEntry(entry.value, entry.key))
          .whereType<RecipeStep>()
          .toList();
      if (mapped.isNotEmpty) return mapped;
    }

    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .asMap()
              .entries
              .map((entry) => _parseStepEntry(entry.value, entry.key))
              .whereType<RecipeStep>()
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }

    final rawJson = json['steps_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          return decoded
              .asMap()
              .entries
              .map((entry) => _parseStepEntry(entry.value, entry.key))
              .whereType<RecipeStep>()
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  static RecipeStep? _parseStepEntry(dynamic raw, int index) {
    if (raw is Map) {
      final parsed = RecipeStep.fromJson(Map<String, dynamic>.from(raw));
      final description = parsed.description.trim();
      if (description.isEmpty) {
        return null;
      }

      final normalizedImage = parsed.imageUrl?.trim();
      return RecipeStep(
        order: parsed.order > 0 ? parsed.order : index + 1,
        description: description,
        imageUrl: (normalizedImage == null || normalizedImage.isEmpty)
            ? null
            : normalizedImage,
        timerSeconds: parsed.timerSeconds,
      );
    }

    if (raw is String) {
      final description = raw.trim();
      if (description.isEmpty) {
        return null;
      }

      return RecipeStep(order: index + 1, description: description);
    }

    return null;
  }

  static NutritionalInfo? _parseNutrition(Map<String, dynamic> json) {
    final raw = json['nutrition'];
    if (raw is Map) {
      return NutritionalInfo.fromJson(Map<String, dynamic>.from(raw));
    }

    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return NutritionalInfo.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return null;
      }
    }

    final rawJson = json['nutrition_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map) {
          return NutritionalInfo.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static List<String> _parseEnglishKeywords(Map<String, dynamic> json) {
    final raw = json['english_keywords'];
    if (raw is List) {
      return raw
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return const [];
  }

  static String _buildSearchText({
    required String title,
    required String category,
    required String description,
    required List<String> englishKeywords,
  }) {
    final parts = [title, category, description, ...englishKeywords]
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    return parts.join(' ');
  }

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    List<String>? englishKeywords,
    String? searchText,
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
  }) => Recipe(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    englishKeywords: englishKeywords ?? this.englishKeywords,
    searchText: searchText ?? this.searchText,
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
