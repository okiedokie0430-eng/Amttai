import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/user.dart';
import 'appwrite_service.dart';

/// Manages the app-level user profile document in the `users` collection.
class UserService {
  final Databases _db = AppwriteService.instance.databases;

  /// Create or update user profile document.
  Future<AppUser> upsertProfile(AppUser user) async {
    try {
      await _db.getDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.usersCollection,
        documentId: user.id,
      );
      // Document exists — update.
      final doc = await _db.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.usersCollection,
        documentId: user.id,
        data: user.toJson(),
      );
      return AppUser.fromJson(doc.data);
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Create.
        final doc = await _db.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.usersCollection,
          documentId: user.id,
          data: user.toJson(),
        );
        return AppUser.fromJson(doc.data);
      }
      rethrow;
    }
  }

  /// Fetch the user profile document.
  Future<AppUser> getProfile(String userId) async {
    final doc = await _db.getDocument(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.usersCollection,
      documentId: userId,
    );
    return AppUser.fromJson(doc.data);
  }

  /// Toggle a recipe in the user's favorites list.
  Future<AppUser> toggleFavorite(String userId, String recipeId) async {
    final profile = await getProfile(userId);
    final favorites = List<String>.from(profile.favoriteRecipeIds);
    if (favorites.contains(recipeId)) {
      favorites.remove(recipeId);
    } else {
      favorites.add(recipeId);
    }
    return upsertProfile(profile.copyWith(favoriteRecipeIds: favorites));
  }

  /// Delete all user data across all collections.
  Future<void> deleteAllUserData(String userId) async {
    // Collections to clean up user documents from
    final collections = [
      AppConfig.usersCollection,
      AppConfig.ratingsCollection,
      AppConfig.paymentsCollection,
      AppConfig.supportMessagesCollection,
    ];

    for (final col in collections) {
      try {
        final docs = await _db.listDocuments(
          databaseId: AppConfig.databaseId,
          collectionId: col,
          queries: [
            if (col == AppConfig.usersCollection)
              // users collection uses documentId = userId
              Query.equal('\$id', userId)
            else
              Query.equal('user_id', userId),
            Query.limit(500),
          ],
        );
        for (final doc in docs.documents) {
          try {
            await _db.deleteDocument(
              databaseId: AppConfig.databaseId,
              collectionId: col,
              documentId: doc.$id,
            );
          } catch (e) {
            debugPrint('[UserService] Failed to delete doc ${doc.$id} from $col: $e');
          }
        }
        debugPrint('[UserService] Cleaned $col: ${docs.documents.length} docs');
      } catch (e) {
        debugPrint('[UserService] Error cleaning collection $col: $e');
      }
    }

    // Try to delete profile photos
    try {
      final storage = AppwriteService.instance.storage;
      final files = await storage.listFiles(
        bucketId: AppConfig.profilePhotosBucket,
        queries: [Query.limit(100)],
      );
      for (final file in files.files) {
        // Profile photos may be named with userId
        if (file.$id.contains(userId) || file.name.contains(userId)) {
          try {
            await storage.deleteFile(
              bucketId: AppConfig.profilePhotosBucket,
              fileId: file.$id,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[UserService] Error cleaning storage: $e');
    }
  }
}
