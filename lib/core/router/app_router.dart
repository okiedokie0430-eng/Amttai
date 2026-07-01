import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../models/recipe.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/pantry/pantry_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/premium/premium_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/payment/payment_screen.dart';
import '../../screens/profile/profile_edit_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/recipe/recipe_detail_screen.dart';
import '../../screens/recipe/step_by_step_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/settings/about_screen.dart';
import '../../screens/settings/account_settings_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/splash/cinematic_splash_screen.dart';
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

  static CustomTransitionPage _fadeZoom(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 1200),
      reverseTransitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (_, animation, __, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 1.08, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  /// Faster fade + zoom for screens where the background should appear immediately.
  static CustomTransitionPage _fastFadeZoom(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 800),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, animation, __, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 1.05, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
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
        pageBuilder: (_, state) => _fade(const CinematicSplashScreen(), state),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) {
          final shouldAnimate = state.uri.queryParameters['animate'] == '1';
          return _fadeZoom(WelcomeScreen(shouldAnimate: shouldAnimate), state);
        },
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fastFadeZoom(const LoginScreen(), state),
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
                pageBuilder: (_, state) => _fadeZoom(const HomeScreen(), state),
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
          return CustomTransitionPage(
            key: state.pageKey,
            child: RecipeDetailScreen(
              recipeId: state.pathParameters['id']!,
              heroPrefix: heroPrefix,
            ),
            transitionDuration: const Duration(milliseconds: 350),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final fadeIn = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                    reverseCurve: Curves.easeIn,
                  );
                  return FadeTransition(opacity: fadeIn, child: child);
                },
          );
        },
        routes: [
          GoRoute(
            path: 'steps',
            pageBuilder: (context, state) {
              final recipe = state.extra as Recipe;
              return _slide(StepByStepScreen(recipe: recipe), state);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/premium',
        pageBuilder: (_, state) => _slide(const PremiumScreen(), state),
      ),
      GoRoute(
        path: '/payment',
        pageBuilder: (_, state) => _slide(const PaymentScreen(), state),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, state) =>
            CupertinoPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/account-settings',
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: const AccountSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (_, state) =>
            CupertinoPage(key: state.pageKey, child: const SupportChatScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (_, state) =>
            CupertinoPage(key: state.pageKey, child: const AboutScreen()),
      ),
      GoRoute(
        path: '/profile-edit',
        pageBuilder: (_, state) => _slide(const ProfileEditScreen(), state),
      ),
    ],
  );
}
