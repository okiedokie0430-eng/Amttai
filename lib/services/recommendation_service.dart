import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../models/recipe.dart';

/// Dart Bridge to the Native Android Kotlin Recommendation Engine.
class RecommendationService {
  static const MethodChannel _channel = MethodChannel(
    'com.amttai.amttai/recommendation',
  );

  /// Initialize the engine with the current User ID
  static Future<void> initEngine(String userId) async {
    try {
      await _channel.invokeMethod('initEngine', {'userId': userId});
      // Optionally run decay when engine boots up
      await applyDecay();
    } on PlatformException {
      debugPrint('Failed to initialize Recommendation Engine: \${e.message}');
    }
  }

  /// Register when a user views a recipe (+0.1 weight)
  static Future<void> onRecipeViewed(List<String> tags) async {
    try {
      await _channel.invokeMethod('onRecipeViewed', {'tags': tags});
    } catch (_) {}
  }

  /// Register when a user cooks/completes a recipe (+0.5 weight)
  static Future<void> onRecipeCooked(List<String> tags) async {
    try {
      await _channel.invokeMethod('onRecipeCooked', {'tags': tags});
    } catch (_) {}
  }

  /// Register when a user bookmarks a recipe (+0.8 weight)
  static Future<void> onRecipeBookmarked(List<String> tags) async {
    try {
      await _channel.invokeMethod('onRecipeBookmarked', {'tags': tags});
    } catch (_) {}
  }

  /// Ask native engine to rank recipes using current preference weights
  static Future<List<Recipe>> rankRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) return recipes;

    try {
      // Convert Dart objects to Maps for MethodChannel
      final rawRecipes = recipes
          .map((r) => {'id': r.id, 'title': r.title, 'tags': _extractTags(r)})
          .toList();

      final List<dynamic>? rankedIds = await _channel.invokeMethod(
        'rankRecipes',
        {'recipes': rawRecipes},
      );

      if (rankedIds == null || rankedIds.isEmpty) return recipes;

      // Reorder the original list based on the returned ranked IDs
      final idMap = {for (var r in recipes) r.id: r};
      return rankedIds
          .map((id) => idMap[id.toString()])
          .whereType<Recipe>()
          .toList();
    } catch (e) {
      debugPrint('Ranking fallback: \${e.toString()}');
      return recipes; // Fallback to original order if channel fails
    }
  }

  /// Internal helper to pull tags/categories out of the Recipe model
  static List<String> _extractTags(Recipe recipe) {
    // Collect standard fields that act as tags
    final tags = <String>[];
    if (recipe.category.isNotEmpty) tags.add(recipe.category.toLowerCase());
    if (recipe.difficulty.isNotEmpty) tags.add(recipe.difficulty.toLowerCase());
    // If the Recipe model has actual 'tags', add them here.
    return tags;
  }

  static Future<void> applyDecay() async {
    try {
      await _channel.invokeMethod('applyDecay');
    } catch (_) {}
  }

  /// Opens the native Offline Sync Settings Compose Screen
  static Future<void> openOfflineSettings() async {
    try {
      await _channel.invokeMethod('openOfflineSettings');
    } catch (e) {
      debugPrint('Failed to open offline settings: $e');
    }
  }
}
