import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

/// Manages favorites locally on device using SharedPreferences.
class FavoritesProvider extends ChangeNotifier {
  static const _key = 'favorite_recipe_ids';
  static const _recentKey = 'recently_viewed_ids';

  final Set<String> _favoriteIds = {};
  final List<String> _recentlyViewedIds = [];

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<String> get recentlyViewedIds =>
      List.unmodifiable(_recentlyViewedIds);

  FavoritesProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key);
    if (ids != null) {
      _favoriteIds.addAll(ids);
    }
    final recent = prefs.getStringList(_recentKey);
    if (recent != null) {
      _recentlyViewedIds.addAll(recent);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favoriteIds.toList());
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recentlyViewedIds);
  }

  bool isFavorite(String recipeId) => _favoriteIds.contains(recipeId);

  Future<void> toggleFavorite(String recipeId) async {
    if (_favoriteIds.contains(recipeId)) {
      _favoriteIds.remove(recipeId);
    } else {
      _favoriteIds.add(recipeId);
    }
    notifyListeners();
    await _save();
  }

  /// Track a recipe as recently viewed. Max 20 items.
  Future<void> addRecentlyViewed(String recipeId) async {
    _recentlyViewedIds.remove(recipeId);
    _recentlyViewedIds.insert(0, recipeId);
    if (_recentlyViewedIds.length > 20) {
      _recentlyViewedIds.removeLast();
    }
    notifyListeners();
    await _saveRecent();
  }

  /// Get favorite recipes from a full recipe list.
  List<Recipe> getFavorites(List<Recipe> allRecipes) {
    return allRecipes
        .where((r) => _favoriteIds.contains(r.id))
        .toList();
  }

  /// Get recently viewed recipes from a full recipe list.
  List<Recipe> getRecentlyViewed(List<Recipe> allRecipes) {
    final result = <Recipe>[];
    for (final id in _recentlyViewedIds) {
      final match = allRecipes.where((r) => r.id == id);
      if (match.isNotEmpty) result.add(match.first);
    }
    return result;
  }
}
