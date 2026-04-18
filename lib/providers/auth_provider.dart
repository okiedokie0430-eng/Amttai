import 'package:flutter/foundation.dart';
import 'package:appwrite/models.dart' as models;

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Manages authentication state and the current user profile.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasPremium => _user?.hasPremiumAccess ?? false;

  // ── Lifecycle ──────────────────────────────────────────
  /// Attempts to restore the session (call from splash).
  Future<bool> tryAutoLogin() async {
    try {
      _setLoading(true);
      final accountUser = await _authService.getCurrentUser();
      await _loadProfile(accountUser);
      _isLoggedIn = true;
      return true;
    } catch (_) {
      _isLoggedIn = false;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Email Auth ─────────────────────────────────────────
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final accountUser =
          await _authService.register(email: email, password: password, name: name);
      // Auto-login after registration.
      await _authService.loginWithEmail(email: email, password: password);
      await _createProfile(accountUser);
      _isLoggedIn = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.loginWithEmail(email: email, password: password);
      final accountUser = await _authService.getCurrentUser();
      await _loadProfile(accountUser);
      _isLoggedIn = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Phone / OTP ────────────────────────────────────────
  String? _otpUserId;

  Future<void> sendOtp(String phone) async {
    _setLoading(true);
    _clearError();
    try {
      final token = await _authService.sendOtp(phone: phone);
      _otpUserId = token.userId;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyOtp(String code) async {
    if (_otpUserId == null) return;
    _setLoading(true);
    _clearError();
    try {
      await _authService.verifyOtp(userId: _otpUserId!, otp: code);
      final accountUser = await _authService.getCurrentUser();
      await _loadProfile(accountUser);
      _isLoggedIn = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // ── Delete Account ─────────────────────────────────────
  /// Calls the server-side Appwrite Function to permanently delete
  /// all user data, storage files, and the auth account.
  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    _setLoading(true);
    _clearError();
    try {
      final userId = _user!.id;
      // Call the server-side function that handles everything
      await _authService.deleteAccount(userId);
      _user = null;
      _isLoggedIn = false;
      return true;
    } catch (e) {
      _error = e.toString();
      // Even if server deletion fails, log out locally
      _user = null;
      _isLoggedIn = false;
      return true; // Return true so UI navigates away
    } finally {
      _setLoading(false);
    }
  }

  // ── Favorites ──────────────────────────────────────────
  Future<void> toggleFavorite(String recipeId) async {
    if (_user == null) return;
    _user = await _userService.toggleFavorite(_user!.id, recipeId);
    notifyListeners();
  }

  bool isFavorite(String recipeId) =>
      _user?.favoriteRecipeIds.contains(recipeId) ?? false;

  // ── Profile Refresh ────────────────────────────────────
  Future<void> refreshProfile() async {
    if (_user == null) return;
    _user = await _userService.getProfile(_user!.id);
    notifyListeners();
  }

  // ── Update Name ────────────────────────────────────────
  Future<void> updateName(String name) async {
    await _authService.updateName(name);
    if (_user != null) {
      _user = _user!.copyWith(name: name);
      await _userService.upsertProfile(_user!);
      notifyListeners();
    }
  }

  // ── Change Password ────────────────────────────────────
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  // ── Change Email ───────────────────────────────────────
  Future<void> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    await _authService.changeEmail(
      newEmail: newEmail,
      password: password,
    );
    if (_user != null) {
      _user = _user!.copyWith(email: newEmail);
      await _userService.upsertProfile(_user!);
      notifyListeners();
    }
  }

  // ── Update Photo URL ──────────────────────────────────
  Future<void> updatePhotoUrl(String url) async {
    if (_user != null) {
      _user = _user!.copyWith(photoUrl: url);
      await _userService.upsertProfile(_user!);
      notifyListeners();
    }
  }

  // ── Internal ───────────────────────────────────────────
  Future<void> _loadProfile(models.User accountUser) async {
    try {
      _user = await _userService.getProfile(accountUser.$id);
    } catch (_) {
      await _createProfile(accountUser);
    }
    notifyListeners();
  }

  Future<void> _createProfile(models.User accountUser) async {
    _user = await _userService.upsertProfile(AppUser(
      id: accountUser.$id,
      name: accountUser.name,
      email: accountUser.email,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
