import 'package:flutter/foundation.dart';

import '../data/dummy_data.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

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
      _recipes = await _recipeService.getRecipes(category: category);
      if (_recipes.isEmpty) throw Exception('empty');
      _error = null;
    } catch (_) {
      // Fallback to dummy data
      if (category != null) {
        _recipes = DummyData.byCategory(category);
      } else {
        _recipes = DummyData.recipes;
      }
      _error = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTrending() async {
    try {
      _trending = await _recipeService.getTrending();
      if (_trending.isEmpty) throw Exception('empty');
      notifyListeners();
    } catch (_) {
      _trending = DummyData.trending;
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
    } catch (_) {
      _searchResults = DummyData.search(query);
      _error = null;
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
      return await _recipeService.getRecipe(id);
    } catch (_) {
      return DummyData.recipes.firstWhere(
        (r) => r.id == id,
        orElse: () => DummyData.recipes.first,
      );
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
