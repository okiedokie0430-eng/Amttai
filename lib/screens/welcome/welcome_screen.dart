import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Welcome screen with animated background and Get Started button.
class WelcomeScreen extends StatelessWidget {
  final bool shouldAnimate;
  const WelcomeScreen({super.key, this.shouldAnimate = false});

  Future<void> _handleOAuthLogin(
    BuildContext context,
    Future<void> Function(AuthProvider auth) action,
  ) async {
    final auth = context.read<AuthProvider>();
    await action(auth);

    if (!context.mounted) {
      return;
    }

    if (auth.isLoggedIn) {
      context.go('/home');
      return;
    }

    final error = auth.error;
    if (error != null && error.trim().isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Edge-to-edge transparent bars
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Hero Image
          Image.asset(
            'assets/images/welcome_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black87,
              alignment: Alignment.center,
              child: const Icon(
                Icons.restaurant_menu,
                color: Colors.white24,
                size: 64,
              ),
            ),
          ),

          // 2. Dark Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(
                    alpha: 0.95,
                  ), // Very dark at bottom to read text
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 7),

                  // Logo + Title
                  Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.restaurant_menu_rounded,
                                size: 24,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'AMTTAI',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      )
                      .animate(target: shouldAnimate ? 1.0 : 0.0)
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 20),

                  // Catchy Subtitle
                  const Text(
                        'Cook with\nConfidence',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      )
                      .animate(target: shouldAnimate ? 1.0 : 0.0)
                      .fadeIn(delay: 80.ms, duration: 500.ms),

                  const Spacer(flex: 5),

                  // Primary login row
                  Row(
                        children: [
                          // Email sign-in button (reduced width)
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: () => context.push('/login'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 20,
                                  color: Colors.black,
                                ),
                                label: const Text(
                                  'LOGIN WITH EMAIL',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Circular Google bubble
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => _handleOAuthLogin(
                                      context,
                                      (provider) => provider.loginWithGoogle(),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A73E8),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate(target: shouldAnimate ? 1.0 : 0.0)
                      .fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 16),

                  const SizedBox(height: 28),

                  // Register link
                  GestureDetector(
                        onTap: () => context.push('/register'),
                        child: RichText(
                          text: const TextSpan(
                            text: 'New user? ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: 'Register',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate(target: shouldAnimate ? 1.0 : 0.0)
                      .fadeIn(delay: 300.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // Terms and Privacy Notes
                  Text.rich(
                        TextSpan(
                          text: 'By using the Amttai app, you agree to our ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: '\nand '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      )
                      .animate(target: shouldAnimate ? 1.0 : 0.0)
                      .fadeIn(delay: 400.ms, duration: 400.ms),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
