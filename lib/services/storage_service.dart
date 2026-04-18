import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';

import '../core/config/app_config.dart';
import 'appwrite_service.dart';

/// Upload / download helpers for Appwrite storage buckets.
class StorageService {
  final Storage _storage = AppwriteService.instance.storage;

  /// Upload a file and return the file ID.
  Future<String> uploadFile({
    required String bucketId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final file = await _storage.createFile(
      bucketId: bucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: fileName),
    );
    return file.$id;
  }

  /// Build a preview/download URL for a file.
  String getFileUrl({required String bucketId, required String fileId}) {
    return '${AppConfig.appwriteEndpoint}/storage/buckets/$bucketId/files/$fileId/view?project=${AppConfig.appwriteProjectId}';
  }

  /// Delete a file.
  Future<void> deleteFile({
    required String bucketId,
    required String fileId,
  }) async {
    await _storage.deleteFile(bucketId: bucketId, fileId: fileId);
  }
}
