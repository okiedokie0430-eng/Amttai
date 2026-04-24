import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import 'appwrite_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.instance.ensureFirebaseReady();
}

// Backward-compatible alias for older callback handles persisted by
// firebase_messaging background isolate bootstrap.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await firebaseMessagingBackgroundHandler(message);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();
  static const String _targetIdStorageKey = 'appwrite_push_target_id';

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'amttai_high_importance_channel',
    'Amttai Notifications',
    description: 'Broadcast notifications and app updates.',
    importance: Importance.high,
  );

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  bool _initialMessageHandled = false;
  bool _loggedFirebaseConfigIssue = false;
  bool _loggedUnsupportedPlatform = false;
  String? _activeUserId;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  Timer? _tokenRetryTimer;
  String? _pendingRetryUserId;

  Future<bool> ensureFirebaseReady() async {
    if (!Platform.isAndroid) {
      _logUnsupportedPlatformOnce();
      return false;
    }

    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    final options = _firebaseOptionsForPlatform();

    try {
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      return true;
    } catch (e) {
      _logFirebaseConfigurationIssue(e);
      return false;
    }
  }

  void _logFirebaseConfigurationIssue(Object error) {
    if (_loggedFirebaseConfigIssue) {
      return;
    }

    _loggedFirebaseConfigIssue = true;
    debugPrint('[Push] Firebase initialization failed: $error');
    debugPrint(
      '[Push] Provide Firebase config using either native files '
      '(android/app/google-services.json) or dart defines '
      '(FIREBASE_API_KEY, FIREBASE_PROJECT_ID, '
      'FIREBASE_MESSAGING_SENDER_ID, FIREBASE_ANDROID_APP_ID).',
    );
  }

  void _logUnsupportedPlatformOnce() {
    if (_loggedUnsupportedPlatform) {
      return;
    }

    _loggedUnsupportedPlatform = true;
    debugPrint('[Push] Android-only mode enabled. Push setup skipped on this platform.');
  }

  void _scheduleTokenSyncRetry(String userId) {
    if (_pendingRetryUserId == userId && (_tokenRetryTimer?.isActive ?? false)) {
      return;
    }

    _pendingRetryUserId = userId;
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = Timer(const Duration(seconds: 20), () {
      _pendingRetryUserId = null;
      unawaited(syncForUser(userId));
    });
  }

  Future<void> ensureInitialized() async {
    if (!AppConfig.pushEnabled || _initialized) {
      return;
    }

    if (!Platform.isAndroid) {
      _logUnsupportedPlatformOnce();
      return;
    }

    final firebaseReady = await ensureFirebaseReady();
    if (!firebaseReady) {
      return;
    }

    _messaging ??= FirebaseMessaging.instance;
    final messaging = _messaging!;

    await messaging.setAutoInitEnabled(true);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final permissionSettings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (permissionSettings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Notification permissions are denied by the user.');
    }

    await _initializeLocalNotifications();
    await _requestAndroidNotificationPermission();

    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((token) async {
      final userId = _activeUserId;
      if (userId == null) {
        return;
      }

      await _syncAppwritePushTarget(userId: userId, token: token);
    });

    _foregroundMessageSubscription ??=
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    _messageOpenedSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    await _handleInitialMessage(messaging);

    _initialized = true;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(_androidChannel);

    _localNotificationsInitialized = true;
  }

  Future<void> _requestAndroidNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidNotifications?.requestNotificationsPermission();
  }

  Future<void> _handleInitialMessage(FirebaseMessaging messaging) async {
    if (_initialMessageHandled) {
      return;
    }

    _initialMessageHandled = true;
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage == null) {
      return;
    }

    _handleOpenedMessage(initialMessage);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!Platform.isAndroid) {
      return;
    }

    final title =
        message.notification?.title ??
      (message.data['title'] ?? 'Амттай').toString().trim();
    final body =
      message.notification?.body ??
      (message.data['body'] ?? '').toString().trim();

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final payload =
        message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: payload,
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    if (message.data.isEmpty) {
      return;
    }

    _navigateFromData(message.data);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _navigateFromData(decoded);
      } else if (decoded is Map) {
        final map = decoded.map((key, value) => MapEntry('$key', value));
        _navigateFromData(map);
      }
    } catch (e) {
      debugPrint('[Push] Failed to parse local notification payload: $e');
    }
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final route = _routeFromData(data);
    if (route == null || route.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final currentPath = AppRouter.router.routeInformationProvider.value.uri.path;
        if (currentPath != route) {
          AppRouter.router.go(route);
        }
      } catch (e) {
        debugPrint('[Push] Failed to open notification route: $e');
      }
    });
  }

  String? _routeFromData(Map<String, dynamic> data) {
    final rawRoute = (data['route'] ?? data['path'] ?? '').toString().trim();
    if (_isAllowedInAppRoute(rawRoute)) {
      return rawRoute;
    }

    final recipeId =
      (data['recipeId'] ?? data['recipe_id'] ?? '').toString().trim();
    if (recipeId.isNotEmpty) {
      return '/recipe/$recipeId';
    }

    final screen = (data['screen'] ?? '').toString().trim().toLowerCase();
    switch (screen) {
      case 'home':
        return '/home';
      case 'search':
        return '/search';
      case 'pantry':
        return '/pantry';
      case 'profile':
        return '/profile';
      case 'support':
        return '/support';
      case 'premium':
        return '/premium';
      case 'payment':
        return '/payment';
      default:
        return '/home';
    }
  }

  bool _isAllowedInAppRoute(String route) {
    final normalized = route.trim();
    if (!normalized.startsWith('/')) {
      return false;
    }

    final safeStaticRoutes = <String>{
      '/home',
      '/search',
      '/pantry',
      '/profile',
      '/support',
      '/premium',
      '/payment',
      '/settings',
    };

    if (safeStaticRoutes.contains(normalized)) {
      return true;
    }

    final recipeId = normalized.replaceFirst('/recipe/', '');
    if (recipeId.contains('..')) {
      return false;
    }

    final recipeRoute = RegExp(r'^/recipe/[A-Za-z0-9_-]{1,128}$');
    return recipeRoute.hasMatch(normalized);
  }

  Future<void> syncForUser(String userId) async {
    if (!Platform.isAndroid) {
      _logUnsupportedPlatformOnce();
      return;
    }

    try {
      await ensureInitialized();
      if (!_initialized) {
        _scheduleTokenSyncRetry(userId);
        return;
      }

      final messaging = _messaging;
      if (messaging == null) {
        _scheduleTokenSyncRetry(userId);
        return;
      }

      _activeUserId = userId;

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[Push] FCM token is not available yet. Retrying shortly.');
        _scheduleTokenSyncRetry(userId);
        return;
      }

      _tokenRetryTimer?.cancel();
      _pendingRetryUserId = null;
      await _syncAppwritePushTarget(userId: userId, token: token);
    } catch (e) {
      debugPrint('[Push] Failed to sync push token: $e');
      _scheduleTokenSyncRetry(userId);
    }
  }

  Future<void> detachUser(String userId) async {
    if (!Platform.isAndroid) {
      _activeUserId = null;
      return;
    }

    try {
      if (!_initialized) {
        _activeUserId = null;
        return;
      }

      final messaging = _messaging;
      if (messaging == null) {
        _activeUserId = null;
        return;
      }

      final targetId = await _readTargetId();
      if (targetId != null) {
        await AppwriteService.instance.account.deletePushTarget(targetId: targetId);
        debugPrint('[Push] Deleted Appwrite push target for user $userId.');
      }
    } on AppwriteException catch (e) {
      if (e.code != 404 && e.code != 401) {
        debugPrint('[Push] Failed to delete Appwrite push target: ${e.message}');
      }
    } catch (e) {
      debugPrint('[Push] Failed to remove push token: $e');
    } finally {
      if (_activeUserId == userId) {
        _activeUserId = null;
      }
    }
  }

  Future<void> _syncAppwritePushTarget({
    required String userId,
    required String token,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }

    final account = AppwriteService.instance.account;
    final targetId = await _getOrCreateTargetId();
    final providerId = AppConfig.appwritePushProviderIdOrNull;

    try {
      await account.createPushTarget(
        targetId: targetId,
        identifier: normalizedToken,
        providerId: providerId,
      );
      debugPrint('[Push] Appwrite push target created for user $userId.');
    } on AppwriteException catch (e) {
      final normalizedMessage = (e.message ?? '').toLowerCase();
      final alreadyExists =
          e.code == 409 ||
          normalizedMessage.contains('already exists') ||
          normalizedMessage.contains('target already exists');

      if (!alreadyExists) {
        rethrow;
      }

      await account.updatePushTarget(
        targetId: targetId,
        identifier: normalizedToken,
      );
      debugPrint('[Push] Appwrite push target updated for user $userId.');
    } catch (e) {
      debugPrint('[Push] Failed to sync Appwrite push target: $e');
      rethrow;
    }
  }

  Future<String?> _readTargetId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_targetIdStorageKey);
    if (stored == null) {
      return null;
    }

    final normalized = stored.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Future<String> _getOrCreateTargetId() async {
    final existing = await _readTargetId();
    if (existing != null) {
      return existing;
    }

    final targetId = ID.unique();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetIdStorageKey, targetId);
    return targetId;
  }

  FirebaseOptions? _firebaseOptionsForPlatform() {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    if (!AppConfig.hasFirebaseAndroidConfig) {
      return null;
    }

    return FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      appId: AppConfig.firebaseAndroidAppId,
      messagingSenderId: AppConfig.firebaseMessagingSenderId,
      projectId: AppConfig.firebaseProjectId,
    );
  }

  Future<void> dispose() async {
    _tokenRetryTimer?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _tokenRetryTimer = null;
    _pendingRetryUserId = null;
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _activeUserId = null;
  }
}
