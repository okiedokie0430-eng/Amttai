import 'package:dio/dio.dart';

import '../../core/config/bridge_config.dart';
import '../../core/logging/bridge_logger.dart';
import '../../core/security/device_binding.dart';

/// Server-side Appwrite client using API Key authentication.
///
/// Unlike the main Amttai app which uses user sessions, this bridge
/// uses an API key for server-to-server communication. This allows
/// it to modify any user's data for payment approval.
class AppwriteClient {
  static const _tag = 'AppwriteClient';

  late final Dio _dio;
  bool _initialized = false;

  static final AppwriteClient _instance = AppwriteClient._internal();
  static AppwriteClient get instance => _instance;
  AppwriteClient._internal();

  Future<void> init() async {
    if (_initialized) return;

    // Get API key from secure storage, fall back to config
    String apiKey = BridgeConfig.appwriteApiKey;
    final storedKey = await DeviceBinding.getApiKey();
    if (storedKey != null && storedKey.isNotEmpty) {
      apiKey = storedKey;
    }

    _dio = Dio(BaseOptions(
      baseUrl: BridgeConfig.appwriteEndpoint,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': BridgeConfig.appwriteProjectId,
        'X-Appwrite-Key': apiKey,
      },
    ));

    _initialized = true;
    BridgeLogger.info(_tag, 'Appwrite client initialized');
  }

  /// List documents from a collection.
  Future<Map<String, dynamic>> listDocuments({
    required String collectionId,
    List<String>? queries,
    String databaseId = BridgeConfig.databaseId,
  }) async {
    await _ensureInit();
    final response = await _dio.get(
      '/databases/$databaseId/collections/$collectionId/documents',
      queryParameters: {
        'queries[]': ?queries,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get a single document.
  Future<Map<String, dynamic>> getDocument({
    required String collectionId,
    required String documentId,
    String databaseId = BridgeConfig.databaseId,
  }) async {
    await _ensureInit();
    final response = await _dio.get(
      '/databases/$databaseId/collections/$collectionId/documents/$documentId',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Create a document.
  Future<Map<String, dynamic>> createDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
    String databaseId = BridgeConfig.databaseId,
  }) async {
    await _ensureInit();
    final response = await _dio.post(
      '/databases/$databaseId/collections/$collectionId/documents',
      data: {
        'documentId': documentId,
        'data': data,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Update a document.
  Future<Map<String, dynamic>> updateDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
    String databaseId = BridgeConfig.databaseId,
  }) async {
    await _ensureInit();
    final response = await _dio.patch(
      '/databases/$databaseId/collections/$collectionId/documents/$documentId',
      data: {'data': data},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Execute an Appwrite function.
  Future<Map<String, dynamic>> executeFunction({
    required String functionId,
    Map<String, dynamic>? body,
  }) async {
    await _ensureInit();
    final response = await _dio.post(
      '/functions/$functionId/executions',
      data: {
        'body': ?body,
        'async': false,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }
}
