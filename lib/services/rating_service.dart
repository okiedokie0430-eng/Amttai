import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'appwrite_service.dart';

/// Handles recipe ratings in the `ratings` collection.
class RatingService {
  Databases get _db => AppwriteService.instance.databases;

  /// Submit or update a rating for a recipe.
  /// Returns true on success.
  Future<bool> rateRecipe({
    required String userId,
    required String recipeId,
    required int rating,
  }) async {
    try {
      // Check if user already rated this recipe
      final existing = await _db.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ratingsCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('recipe_id', recipeId),
          Query.limit(1),
        ],
      );

      if (existing.documents.isNotEmpty) {
        // Update existing rating
        await _db.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.ratingsCollection,
          documentId: existing.documents.first.$id,
          data: {
            'rating': rating,
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      } else {
        // Create new rating
        await _db.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.ratingsCollection,
          documentId: ID.unique(),
          data: {
            'user_id': userId,
            'recipe_id': recipeId,
            'rating': rating,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }
      return true;
    } catch (e) {
      debugPrint('[RatingService] Error rating recipe: $e');
      return false;
    }
  }

  /// Get the user's rating for a recipe. Returns 0 if not rated.
  Future<int> getUserRating({
    required String userId,
    required String recipeId,
  }) async {
    try {
      final result = await _db.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.ratingsCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('recipe_id', recipeId),
          Query.limit(1),
        ],
      );
      if (result.documents.isNotEmpty) {
        return result.documents.first.data['rating'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('[RatingService] Error getting user rating: $e');
      return 0;
    }
  }
}
