import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/recommendation_service.dart';

class RecipeProvider extends ChangeNotifier {
  final RecipeService _recipeService = RecipeService();

  List<Recipe> _recipes = [];
  List<Recipe> _trending = [];
  List<Recipe> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  String? _activeCategory;

  List<Recipe> get recipes => _recipes;
  List<Recipe> get trending => _trending;
  List<Recipe> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get activeCategory => _activeCategory;

  Future<void> loadRecipes({String? category}) async {
    _setLoading(true);
    _activeCategory = category;
    try {
      var fetched = await _recipeService.getRecipes(category: category);
      if (fetched.isEmpty) throw Exception('empty');
      // Apply Native Recommendation Matrix Sort
      _recipes = await RecommendationService.rankRecipes(fetched);
      _error = null;
    } catch (e) {
      _recipes = [];
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTrending() async {
    try {
      _trending = await _recipeService.getTrending();
      if (_trending.isEmpty) throw Exception('empty');
      notifyListeners();
    } catch (e) {
      _trending = [];
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      _searchResults = await _recipeService.searchRecipes(query);
      if (_searchResults.isEmpty) throw Exception('empty');
      _error = null;
    } catch (e) {
      _searchResults = [];
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  Future<Recipe> getRecipeDetail(String id) async {
    try {
      final recipe = await _recipeService.getRecipe(id);
      // Track View Event for Recommendations
      RecommendationService.onRecipeViewed([
        recipe.category.toLowerCase(),
        recipe.difficulty.toLowerCase(),
      ]);
      return recipe;
    } catch (e) {
      rethrow;
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
