import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import 'appwrite_service.dart';

/// Handles email / phone authentication via Appwrite.
class AuthService {
  Account get _account => AppwriteService.instance.account;
  static const String _sessionStorageKey = 'appwrite_session_id';

  // ── Email Auth ──────────────────────────────────────────
  Future<models.User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    return _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
  }

  Future<models.Session> loginWithEmail({
    required String email,
    required String password,
  }) async {
    // Ensure no stale in-memory session header survives between auth attempts.
    AppwriteService.instance.reset();

    final session = await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );

    await _applySession(session.$id);
    await _persistSessionId(session.$id);

    return session;
  }

  Future<models.Session> loginWithOAuth({
    required OAuthProvider provider,
  }) async {
    // Ensure no stale in-memory session header survives between auth attempts.
    AppwriteService.instance.reset();
    await _clearPersistedSessionId();

    await _account.createOAuth2Session(provider: provider);

    AppwriteException? lastAppwriteError;

    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final session = await _account.getSession(sessionId: 'current');
        await _applySession(session.$id);
        await _persistSessionId(session.$id);
        return session;
      } on AppwriteException catch (e) {
        lastAppwriteError = e;
        final normalized = (e.message ?? '').toLowerCase();

        if (_isOAuthCancelled(normalized)) {
          rethrow;
        }

        final shouldRetry =
            e.code == 401 ||
            e.code == 404 ||
            normalized.contains('missing_scopes') ||
            normalized.contains('session') ||
            normalized.contains('not found');

        if (!shouldRetry || attempt == 4) {
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 280 * (attempt + 1)));
      }
    }

    if (lastAppwriteError != null) {
      throw lastAppwriteError;
    }

    throw Exception('Google login could not be verified. Please try again.');
  }

  // ── Phone / OTP Auth ────────────────────────────────────
  Future<models.Token> sendOtp({required String phone}) async {
    return _account.createPhoneToken(userId: ID.unique(), phone: phone);
  }

  Future<models.Session> verifyOtp({
    required String userId,
    required String otp,
  }) async {
    // Ensure no stale in-memory session header survives between auth attempts.
    AppwriteService.instance.reset();

    final session = await _account.updatePhoneSession(
      userId: userId,
      secret: otp,
    );

    await _applySession(session.$id);
    await _persistSessionId(session.$id);

    return session;
  }

  // ── Password Reset ─────────────────────────────────────
  Future<models.Token> resetPassword({required String email}) async {
    return _account.createRecovery(
      email: email,
      url: 'https://amttai.com/reset', // deep-link placeholder
    );
  }

  // ── Session ────────────────────────────────────────────
  Future<models.User> getCurrentUser() async {
    await _restoreSessionFromStorage();

    try {
      return await _account.get();
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        await _clearPersistedSessionId();
        AppwriteService.instance.reset();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final storedSessionId = await _readPersistedSessionId();

    Future<void> bestEffort(Future<void> Function() action) async {
      try {
        await action();
      } on AppwriteException catch (e) {
        // Ignore already-invalid or already-removed session errors.
        if (e.code != 401 && e.code != 404) {
          // Keep local logout flow reliable even when remote cleanup fails.
        }
      } catch (_) {
        // Keep local logout flow reliable even when remote cleanup fails.
      }
    }

    try {
      if (storedSessionId != null && storedSessionId.trim().isNotEmpty) {
        final scopedAccount = _createScopedAccount(sessionId: storedSessionId);
        await bestEffort(
          () => scopedAccount.deleteSession(sessionId: storedSessionId),
        );
        await bestEffort(
          () => scopedAccount.deleteSession(sessionId: 'current'),
        );
      }

      await bestEffort(() => _account.deleteSession(sessionId: 'current'));
    } finally {
      await _clearPersistedSessionId();
      AppwriteService.instance.reset();
    }
  }

  /// Permanently delete the user account by calling the server-side
  /// Appwrite Function `delete-account`. The function uses a Server API key
  /// to delete all user data, storage files, and the auth user.
  Future<void> deleteAccount(String userId) async {
    final functions = Functions(AppwriteService.instance.client);
    final execution = await functions.createExecution(
      functionId: AppConfig.deleteAccountFunctionId,
      body: jsonEncode({'userId': userId}),
      method: ExecutionMethod.pOST,
    );

    // Parse the function response
    final response = jsonDecode(execution.responseBody);
    if (response['ok'] != true) {
      throw Exception(response['message'] ?? 'Account deletion failed');
    }
  }

  Future<models.User> updateName(String name) async {
    return _account.updateName(name: name);
  }

  Future<models.User> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return _account.updatePassword(
      password: newPassword,
      oldPassword: oldPassword,
    );
  }

  Future<models.User> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    return _account.updateEmail(email: newEmail, password: password);
  }

  Future<void> _persistSessionId(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, sessionId);
  }

  Future<void> _clearPersistedSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
  }

  Future<String?> _readPersistedSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sessionStorageKey);
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Future<void> _restoreSessionFromStorage() async {
    final storedSessionId = await _readPersistedSessionId();
    if (storedSessionId == null) {
      return;
    }

    await _applySession(storedSessionId);
  }

  Account _createScopedAccount({required String sessionId}) {
    final normalized = sessionId.trim();
    final client = Client()
      ..setEndpoint(AppConfig.appwriteEndpoint)
      ..setProject(AppConfig.appwriteProjectId)
      ..setSelfSigned(status: true)
      ..setSession(normalized);

    return Account(client);
  }

  Future<void> _applySession(String sessionId) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) {
      return;
    }

    AppwriteService.instance.client.setSession(normalized);
  }

  bool _isOAuthCancelled(String normalizedMessage) {
    return normalizedMessage.contains('cancel') ||
        normalizedMessage.contains('cancelled') ||
        normalizedMessage.contains('user canceled') ||
        normalizedMessage.contains('user closed') ||
        normalizedMessage.contains('aborted');
  }

  /// Returns the currently persisted Appwrite session ID without making
  /// any network calls. Useful for attaching the session to image requests.
  Future<String?> getCurrentSessionId() => _readPersistedSessionId();
}
