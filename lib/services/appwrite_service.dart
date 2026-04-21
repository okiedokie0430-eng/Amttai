import 'package:appwrite/appwrite.dart';

import '../core/config/app_config.dart';

/// Singleton wrapper around the Appwrite SDK.
///
/// All other services reference this to get [Client], [Account],
/// [Databases], [Storage], and [Realtime] instances.
class AppwriteService {
  AppwriteService._internal();
  static final AppwriteService _instance = AppwriteService._internal();
  static AppwriteService get instance => _instance;

  late Client client;
  late Account account;
  late Databases databases;
  late Storage storage;
  late Realtime realtime;

  bool _initialised = false;

  /// Call once from `main()` before `runApp`.
  void init() {
    if (_initialised) return;
    reset();
  }

  /// Rebuilds the Appwrite client and all service handles.
  ///
  /// This is used after logout to ensure stale auth headers/sessions are not
  /// carried into a fresh login attempt.
  void reset() {
    client = Client()
      ..setEndpoint(AppConfig.appwriteEndpoint)
      ..setProject(AppConfig.appwriteProjectId)
      ..setSelfSigned(status: true); // remove in production

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    realtime = Realtime(client);
    _initialised = true;
  }
}
