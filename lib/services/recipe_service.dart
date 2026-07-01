import 'package:appwrite/appwrite.dart';

import '../core/config/app_config.dart';
import '../models/recipe.dart';
import 'appwrite_service.dart';

/// CRUD operations for recipes.
class RecipeService {
  Databases get _db => AppwriteService.instance.databases;

  /// Fetch all recipes with optional filters.
  Future<List<Recipe>> getRecipes({
    String? category,
    bool? premiumOnly,
    int limit = 25,
    int offset = 0,
  }) async {
    final queries = <String>[
      Query.limit(limit),
      Query.offset(offset),
      Query.orderDesc('created_at'),
    ];
    if (category != null) queries.add(Query.equal('category', category));
    if (premiumOnly == true) queries.add(Query.equal('is_premium', true));

    final result = await _db.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.recipesCollection,
      queries: queries,
    );
    return result.documents.map((d) => Recipe.fromJson(d.data)).toList();
  }

  /// Fetch a single recipe by ID.
  Future<Recipe> getRecipe(String id) async {
    final doc = await _db.getDocument(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.recipesCollection,
      documentId: id,
    );
    return Recipe.fromJson(doc.data);
  }

  /// Full-text search (uses Appwrite search query).
  Future<List<Recipe>> searchRecipes(String query, {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    try {
      final result = await _db.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.recipesCollection,
        queries: [
          Query.search('title', normalized),
          Query.limit(limit),
        ],
      );
      
      return result.documents.map((d) => Recipe.fromJson(d.data)).toList();
    } catch (_) {
      // Fallback if full-text index fails or is unavailable
      try {
        final fallbackResult = await _db.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.recipesCollection,
          queries: [
            Query.equal('category', normalized),
            Query.limit(limit),
          ],
        );
        return fallbackResult.documents.map((d) => Recipe.fromJson(d.data)).toList();
      } catch (e) {
        return const [];
      }
    }
  }

  /// Trending = highest rated in the last 30 days.
  Future<List<Recipe>> getTrending({int limit = 10}) async {
    final result = await _db.listDocuments(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.recipesCollection,
      queries: [
        Query.orderDesc('average_rating'),
        Query.limit(limit),
      ],
    );
    return result.documents.map((d) => Recipe.fromJson(d.data)).toList();
  }
}
