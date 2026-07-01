import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _maskScaleAnimation;
  late Animation<double> _bgScaleAnimation;
  late Animation<double> _bgOpacityAnimation;
  bool _startTransition = false;
  String? _nextRoute;

  @override
  void initState() {
    super.initState();

    // Fast Twitter-style duration.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    // ─── Mask Logo ───
    // 1. Hold    (~55ms)
    // 2. Shrink  (~132ms, easeInOutCubic)
    // 3. BOUNCE! (~132ms, easeOutBack — overshoots past original size)
    // 4. Explode (~231ms, easeInCubic)
    _maskScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.82,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 12.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 42,
      ),
    ]).animate(_controller);

    // ─── Background Zoom-Out ───
    _bgScaleAnimation = Tween<double>(
      begin: 1.04,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);

    // ─── Background Brightness ───
    _bgOpacityAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);

    _controller.addStatusListener(_onAnimationStatus);

    _init();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      if (_nextRoute == '/welcome') {
        context.go('/welcome?animate=1');
      } else if (_nextRoute == '/home') {
        context.go('/home');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/welcome_bg.jpg'), context);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Quick brand beat before the reveal.
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final loggedIn = await auth.tryAutoLogin();

    if (!mounted) return;

    setState(() {
      _nextRoute = loggedIn ? '/home' : '/welcome';
      _startTransition = true;
    });

    // Fire-and-forget; navigation happens instantly via status listener
    // the moment the animation completes.
    _controller.forward();
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── 1. Screen Behind the Mask ───
          if (_nextRoute == '/welcome')
            _buildWelcomeBackground()
          else if (_nextRoute == '/home')
            const HomeScreen()
          else
            Container(color: AppColors.background(context)),

          // ─── 2. Mask Overlay (always present; hole invisible when bg matches) ───
          _buildMaskOverlay(),

          // ─── 3. Orange Idle Icon — smoothly fades out when transition starts ───
          Center(
            child: AnimatedOpacity(
              opacity: _startTransition ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 80,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The welcome image with a simultaneous zoom-out + brightness fade.
  Widget _buildWelcomeBackground() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: Transform.scale(
            scale: _bgScaleAnimation.value,
            child: Opacity(opacity: _bgOpacityAnimation.value, child: child),
          ),
        );
      },
      child: Image.asset('assets/images/welcome_bg.jpg', fit: BoxFit.cover),
    );
  }

  /// Expanding-logo mask that punches a hole through the overlay.
  /// Uses a small saveLayer + BlendMode.dstOut instead of
  /// full-screen ColorFiltered to avoid the compositing bottleneck.
  Widget _buildMaskOverlay() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MaskHolePainter(
            scale: _maskScaleAnimation.value,
            overlayColor: AppColors.background(context),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Paints a full-screen overlay with an icon-shaped transparent hole.
/// The hole is created via a small saveLayer using BlendMode.dstOut,
/// so only the icon region is composited, not the entire screen.
class _MaskHolePainter extends CustomPainter {
  final double scale;
  final Color overlayColor;
  late final TextPainter _textPainter;

  _MaskHolePainter({required this.scale, required this.overlayColor}) {
    _textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.restaurant_menu_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.restaurant_menu_rounded.fontFamily,
          package: Icons.restaurant_menu_rounded.fontPackage,
          fontSize: 80,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    _textPainter.layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Full-screen overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = overlayColor,
    );

    // 2. Icon-shaped hole — saveLayer sized to the scaled icon only
    final holeWidth = _textPainter.width * scale;
    final holeHeight = _textPainter.height * scale;
    final holeRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: holeWidth,
      height: holeHeight,
    );

    canvas.saveLayer(holeRect, Paint()..blendMode = BlendMode.dstOut);

    // Scale around center and draw the pre-layout icon
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-_textPainter.width / 2, -_textPainter.height / 2);
    _textPainter.paint(canvas, Offset.zero);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaskHolePainter old) {
    return old.scale != scale || old.overlayColor != overlayColor;
  }
}
