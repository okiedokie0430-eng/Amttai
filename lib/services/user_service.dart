import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/utils/user_code_serializer.dart';
import '../models/user.dart';
import 'appwrite_service.dart';

/// Manages the app-level user profile document in the `users` collection.
class UserService {
  Databases get _db => AppwriteService.instance.databases;
  static const int _maxUserCodeAttempts = 12;
  static const List<String> _pushTokenFieldCandidates = <String>[
    'push_tokens',
    'pushTokens',
    'device_tokens',
  ];

  /// Create or update user profile document.
  Future<AppUser> upsertProfile(AppUser user) async {
    try {
      final existingDoc = await _db.getDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.usersCollection,
        documentId: user.id,
      );

      // Document exists — keep existing custom user code if present.
      final existingUser = _fromDocument(existingDoc);
      var toSave = user.copyWith(
        userCode: _pickPreferredUserCode(user.userCode, existingUser.userCode),
      );
      toSave = await _ensureUserCode(toSave);

      final doc = await _db.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.usersCollection,
        documentId: user.id,
        data: toSave.toJson(),
      );
      return _fromDocument(doc);
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        return _createProfileWithUniqueUserCode(user);
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

    var user = _fromDocument(doc);
    if (_hasUserCode(user.userCode)) {
      return user;
    }

    // Self-heal older profiles that were created before user code support.
    try {
      final fixed = await _ensureUserCode(user);
      final updated = await _db.updateDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.usersCollection,
        documentId: userId,
        data: {
          'user_code': fixed.userCode,
        },
      );
      user = _fromDocument(updated);
    } catch (e) {
      debugPrint('[UserService] Failed to backfill user_code for $userId: $e');
    }

    return user;
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

  Future<void> registerPushToken(String userId, String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    try {
      final snapshot = await _readPushTokens(userId);
      final tokens = List<String>.from(snapshot.tokens);
      if (tokens.contains(normalized)) {
        return;
      }

      tokens.add(normalized);
      await _updatePushTokens(userId: userId, tokens: tokens, preferredField: snapshot.fieldKey);
      debugPrint('[UserService] Push token registered in ${snapshot.fieldKey}.');
    } on AppwriteException catch (e) {
      if (_pushTokenFieldCandidates.any((field) => _isMissingAttributeError(e, field))) {
        debugPrint(
          '[UserService] No supported push token attribute found (${_pushTokenFieldCandidates.join(', ')}). '
          'Run provisioning script to add push_tokens.',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> removePushToken(String userId, String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }

    try {
      final snapshot = await _readPushTokens(userId);
      final tokens = List<String>.from(snapshot.tokens);
      final updated = tokens.where((item) => item != normalized).toList();

      if (updated.length == tokens.length) {
        return;
      }

      await _updatePushTokens(
        userId: userId,
        tokens: updated,
        preferredField: snapshot.fieldKey,
      );
    } on AppwriteException catch (e) {
      if (_pushTokenFieldCandidates.any((field) => _isMissingAttributeError(e, field))) {
        return;
      }
      rethrow;
    }
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

  Future<AppUser> _createProfileWithUniqueUserCode(AppUser user) async {
    for (var attempt = 0; attempt < _maxUserCodeAttempts; attempt++) {
      final preferred = attempt == 0 ? user.userCode : null;
      final candidate = _resolveCandidateCode(preferred);
      if (!_hasUserCode(candidate)) continue;

      final toCreate = user.copyWith(userCode: candidate);
      try {
        final doc = await _db.createDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.usersCollection,
          documentId: user.id,
          data: toCreate.toJson(),
        );
        return _fromDocument(doc);
      } on AppwriteException catch (e) {
        if (_isUniqueViolation(e)) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Could not generate unique user code after multiple attempts.');
  }

  Future<AppUser> _ensureUserCode(AppUser user) async {
    if (_hasUserCode(user.userCode)) {
      return user;
    }

    for (var attempt = 0; attempt < _maxUserCodeAttempts; attempt++) {
      final candidate = _resolveCandidateCode(null);
      if (!_hasUserCode(candidate)) continue;

      final available = await _isUserCodeAvailable(
        candidate!,
        currentUserId: user.id,
      );
      if (available) {
        return user.copyWith(userCode: candidate);
      }
    }

    throw Exception('Unable to allocate a unique user code.');
  }

  Future<bool> _isUserCodeAvailable(
    String userCode, {
    required String currentUserId,
  }) async {
    try {
      final result = await _db.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.usersCollection,
        queries: [
          Query.equal('user_code', userCode),
          Query.limit(1),
        ],
      );

      if (result.documents.isEmpty) return true;
      return result.documents.first.$id == currentUserId;
    } on AppwriteException catch (e) {
      if (_isMissingAttributeError(e, 'user_code') || e.code == 404) {
        return true;
      }
      rethrow;
    }
  }

  Future<({String fieldKey, List<String> tokens})> _readPushTokens(String userId) async {
    final profile = await _db.getDocument(
      databaseId: AppConfig.databaseId,
      collectionId: AppConfig.usersCollection,
      documentId: userId,
    );

    final data = profile.data;
    for (final fieldKey in _pushTokenFieldCandidates) {
      final dynamic raw = data[fieldKey];
      if (raw is List) {
        return (fieldKey: fieldKey, tokens: _normalizeTokenList(raw));
      }

      if (data.containsKey(fieldKey)) {
        return (fieldKey: fieldKey, tokens: <String>[]);
      }
    }

    return (fieldKey: _pushTokenFieldCandidates.first, tokens: <String>[]);
  }

  Future<void> _updatePushTokens({
    required String userId,
    required List<String> tokens,
    required String preferredField,
  }) async {
    final normalizedTokens = _normalizeTokenList(tokens);
    final fieldOrder = <String>[
      preferredField,
      ..._pushTokenFieldCandidates.where((field) => field != preferredField),
    ];

    AppwriteException? lastMissingAttributeError;

    for (final fieldKey in fieldOrder) {
      try {
        await _db.updateDocument(
          databaseId: AppConfig.databaseId,
          collectionId: AppConfig.usersCollection,
          documentId: userId,
          data: {fieldKey: normalizedTokens},
        );
        return;
      } on AppwriteException catch (e) {
        if (_isMissingAttributeError(e, fieldKey)) {
          lastMissingAttributeError = e;
          continue;
        }
        rethrow;
      }
    }

    if (lastMissingAttributeError != null) {
      throw lastMissingAttributeError;
    }
  }

  List<String> _normalizeTokenList(List<dynamic> rawTokens) {
    final deduped = <String>{};
    for (final token in rawTokens) {
      final normalized = '$token'.trim();
      if (normalized.isNotEmpty) {
        deduped.add(normalized);
      }
    }
    return deduped.toList();
  }

  AppUser _fromDocument(dynamic document) {
    final data = Map<String, dynamic>.from(document.data as Map);
    data['\$id'] = document.$id;

    if (data['push_tokens'] == null || data['push_tokens'] is! List) {
      for (final fieldKey in _pushTokenFieldCandidates.where((field) => field != 'push_tokens')) {
        final fallbackValue = data[fieldKey];
        if (fallbackValue is List) {
          data['push_tokens'] = fallbackValue;
          break;
        }
      }
    }

    return AppUser.fromJson(data);
  }

  String? _pickPreferredUserCode(String? preferred, String? fallback) {
    if (_hasUserCode(preferred)) return preferred;
    if (_hasUserCode(fallback)) return fallback;
    return null;
  }

  String? _resolveCandidateCode(String? preferred) {
    if (_hasUserCode(preferred) && UserCodeSerializer.isValid(preferred!)) {
      return preferred;
    }
    return UserCodeSerializer.generate();
  }

  bool _hasUserCode(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return UserCodeSerializer.isValid(value.trim());
  }

  bool _isUniqueViolation(AppwriteException error) {
    final type = (error.type ?? '').toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return (error.code == 409) ||
        type.contains('already_exists') ||
        type.contains('duplicate') ||
        message.contains('already exists') ||
        message.contains('duplicate');
  }

  bool _isMissingAttributeError(AppwriteException error, String key) {
    final message = (error.message ?? '').toLowerCase();
    final normalizedKey = key.toLowerCase();
    return (error.code == 400 || error.code == 404) &&
        (message.contains('attribute not found') || message.contains('unknown attribute')) &&
        message.contains(normalizedKey);
  }
}
