import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// A choreographed splash screen that reveals the app title letter-by-letter
/// with staggered fade-in, shows a Lottie loading indicator, then zooms the
/// whole text and cross-fades to the next screen.
class CinematicSplashScreen extends StatefulWidget {
  const CinematicSplashScreen({super.key});

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // ── Per-letter fade animations ──
  late final List<Animation<double>> _letterAnimations;

  // ── Lottie fade-out ──
  late final Animation<double> _lottieFadeAnimation;

  // ── End-phase zoom & canvas fade ──
  late final Animation<double> _zoomAnimation;
  late final Animation<double> _fadeAnimation;

  bool _hasNavigated = false;
  bool? _isLoggedIn;
  bool _animationDone = false;

  static const String _title = 'AMTTAI';

  Timer? _navigateTimer;

  // Leisurely staggered intervals for a longer, more luxurious reveal
  static const List<(double, double)> _letterIntervals = [
    (0.00, 0.14), // A
    (0.08, 0.22), // M
    (0.16, 0.30), // T
    (0.24, 0.38), // T
    (0.32, 0.46), // A
    (0.40, 0.54), // I
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Phase 1: Letters fade in sequentially
    _letterAnimations = List.generate(_title.length, (i) {
      final (start, end) = _letterIntervals[i];
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    // Lottie fades out as letters start appearing
    _lottieFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.18, curve: Curves.easeIn),
    );

    // Phase 2: Cinematic zoom / fade-out (0.60 – 0.80)
    _zoomAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.80, curve: Curves.easeInOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.80, curve: Curves.easeIn),
    );

    _controller.addStatusListener(_onStatusChanged);
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Pre-cache the welcome background so WelcomeScreen shows instantly.
    precacheImage(const AssetImage('assets/images/welcome_bg.jpg'), context);

    _controller.forward();

    // Auth runs in parallel. _maybeNavigate fires only after BOTH
    // the animation finishes and the auth result are ready.
    context.read<AuthProvider>().tryAutoLogin().catchError((_) => false).then((
      loggedIn,
    ) {
      if (!mounted) return;
      _isLoggedIn = loggedIn;
      _maybeNavigate();
    });
  }

  /// Navigate 100 ms after the animation completes.
  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _navigateTimer == null) {
      _animationDone = true;
      _navigateTimer = Timer(const Duration(milliseconds: 100), () {
        _navigateTimer = null;
        _maybeNavigate();
      });
    }
  }

  /// Navigate via GoRouter only once, after animation + auth are both ready.
  void _maybeNavigate() {
    if (_hasNavigated || _isLoggedIn == null || !_animationDone) return;
    _hasNavigated = true;

    if (_isLoggedIn == true) {
      context.go('/home');
    } else {
      context.go('/welcome?animate=1');
    }
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final zoom = 1.0 + (_zoomAnimation.value * 0.15);
          final canvasOpacity = 1.0 - _fadeAnimation.value;

          return Opacity(
            opacity: canvasOpacity,
            child: Transform.scale(
              scale: zoom,
              alignment: Alignment.center,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Title at exact screen centre
                  Center(child: _buildTitle(context)),
                  // Lottie below centre so it never pushes the title
                  Align(
                    alignment: const Alignment(0, 0.35),
                    child: _buildLottie(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final letterStyle = textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -1.0,
      fontSize: 48,
      color: AppColors.primary,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_title.length, (index) {
        final anim = _letterAnimations[index];
        return Opacity(
          opacity: anim.value,
          child: Text(_title[index], style: letterStyle),
        );
      }),
    );
  }

  Widget _buildLottie(BuildContext context) {
    final lottieOpacity = 1.0 - _lottieFadeAnimation.value;
    // Always reserve the 100×100 slot so Column height never changes.
    return Opacity(
      opacity: lottieOpacity.clamp(0.0, 1.0),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Lottie.asset(
          'assets/images/processing order.json',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
