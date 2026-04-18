import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/pantry/pantry_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/payment/payment_screen.dart';
import '../../screens/profile/profile_edit_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/recipe/recipe_detail_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/settings/account_settings_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/support/support_chat_screen.dart';
import '../../screens/welcome/welcome_screen.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static CustomTransitionPage _fade(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static CustomTransitionPage _slide(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => _fade(const SplashScreen(), state),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, state) => _fade(const WelcomeScreen(), state),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fade(const LoginScreen(), state),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => _fade(const RegisterScreen(), state),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) => _fade(const ForgotPasswordScreen(), state),
      ),
      StatefulShellRoute(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AnimatedBranchContainer(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, state) => _fade(const HomeScreen(), state),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                pageBuilder: (_, state) => _fade(const SearchScreen(), state),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pantry',
                pageBuilder: (_, state) => _fade(const PantryScreen(), state),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, state) => _fade(const ProfileScreen(), state),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/recipe/:id',
        pageBuilder: (context, state) {
          final heroPrefix = state.uri.queryParameters['hero'] ?? '';
          return _fade(
            RecipeDetailScreen(
              recipeId: state.pathParameters['id']!,
              heroPrefix: heroPrefix,
            ),
            state,
          );
        },
      ),
      GoRoute(
        path: '/payment',
        pageBuilder: (_, state) => _slide(const PaymentScreen(), state),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => _slide(const SettingsScreen(), state),
      ),
      GoRoute(
        path: '/account-settings',
        pageBuilder: (_, state) => _slide(const AccountSettingsScreen(), state),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (_, state) => _slide(const SupportChatScreen(), state),
      ),
      GoRoute(
        path: '/profile-edit',
        pageBuilder: (_, state) => _slide(const ProfileEditScreen(), state),
      ),
    ],
  );
}
