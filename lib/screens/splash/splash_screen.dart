import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _startTransition = false;
  String? _nextRoute;

  @override
  void initState() {
    super.initState();
    // Faster easeInOut duration to complete the mask quickly
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeInOut)), 
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 100.0).chain(CurveTween(curve: Curves.easeInExpo)), 
        weight: 70,
      ),
    ]).animate(_controller);

    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/welcome_bg.jpg'), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final loggedIn = await auth.tryAutoLogin();

    if (!mounted) return;
    
    setState(() {
      _nextRoute = loggedIn ? '/home' : '/welcome';
      _startTransition = true;
    });

    await _controller.forward();
    
    if (!mounted) return;
    
    if (_nextRoute == '/welcome') {
      context.go('/welcome?animate=1');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Screen Behind the Mask
          if (_nextRoute == '/welcome')
            Image.asset(
              'assets/images/welcome_bg.jpg',
              fit: BoxFit.cover,
            )
          else if (_nextRoute == '/home')
            const HomeScreen() // Render Home Screen passively to show through the hole 
          else
            Container(color: AppColors.background(context)),

          // 2. The Animated Mask Layer
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (!_startTransition) {
                return Container(
                  color: AppColors.background(context),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: 80,
                      color: AppColors.primary,
                    ).animate().fadeIn(duration: 600.ms),
                  ),
                );
              }

              return ColorFiltered(
                colorFilter: ColorFilter.mode(
                  AppColors.background(context), 
                  BlendMode.srcOut,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.transparent,
                    ),
                    Center(
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 80,
                          color: Colors.black, 
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
