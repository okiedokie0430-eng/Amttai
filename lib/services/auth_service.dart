import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:appwrite/models.dart' as models;

import '../core/config/app_config.dart';
import 'appwrite_service.dart';

/// Handles email / phone authentication via Appwrite.
class AuthService {
  final Account _account = AppwriteService.instance.account;

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
    return _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
  }

  // ── Phone / OTP Auth ────────────────────────────────────
  Future<models.Token> sendOtp({required String phone}) async {
    return _account.createPhoneToken(
      userId: ID.unique(),
      phone: phone,
    );
  }

  Future<models.Session> verifyOtp({
    required String userId,
    required String otp,
  }) async {
    return _account.updatePhoneSession(
      userId: userId,
      secret: otp,
    );
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
    return _account.get();
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
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
    return _account.updateEmail(
      email: newEmail,
      password: password,
    );
  }
}
