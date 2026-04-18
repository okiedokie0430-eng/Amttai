import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/support_message.dart';
import 'appwrite_service.dart';

/// Customer-service chat backed by Appwrite Realtime.
class ChatService {
  final Databases _db = AppwriteService.instance.databases;
  final Realtime _realtime = AppwriteService.instance.realtime;

  /// Send a message from the user.
  /// Returns the created [SupportMessage] on success, null on error.
  Future<SupportMessage?> sendMessage({
    required String userId,
    required String message,
  }) async {
    try {
      final doc = await _db.createDocument(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.supportMessagesCollection,
        documentId: ID.unique(),
        data: {
          'user_id': userId,
          'message': message,
          'is_from_admin': false,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[ChatService] Message sent: ${doc.$id}');
      return SupportMessage.fromJson(doc.data);
    } on AppwriteException catch (e) {
      debugPrint('[ChatService] Appwrite error sending message: '
          'code=${e.code}, type=${e.type}, message=${e.message}');
      return null;
    } catch (e) {
      debugPrint('[ChatService] Error sending message: $e');
      return null;
    }
  }

  /// Load chat history.
  Future<List<SupportMessage>> getMessages(String userId) async {
    try {
      final result = await _db.listDocuments(
        databaseId: AppConfig.databaseId,
        collectionId: AppConfig.supportMessagesCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.orderAsc('created_at'),
          Query.limit(100),
        ],
      );
      debugPrint('[ChatService] Loaded ${result.documents.length} messages');
      return result.documents
          .map((d) => SupportMessage.fromJson(d.data))
          .toList();
    } on AppwriteException catch (e) {
      debugPrint('[ChatService] Appwrite error loading messages: '
          'code=${e.code}, type=${e.type}, message=${e.message}');
      return [];
    } catch (e) {
      debugPrint('[ChatService] Error loading messages: $e');
      return [];
    }
  }

  /// Subscribe to new messages via Appwrite Realtime.
  RealtimeSubscription subscribeToMessages(String userId) {
    return _realtime.subscribe([
      'databases.${AppConfig.databaseId}.collections.${AppConfig.supportMessagesCollection}.documents',
    ]);
  }
}
