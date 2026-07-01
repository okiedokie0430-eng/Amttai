import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}
class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _letterAnimations;
  static const String _title = 'AMTTAI';
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
    // Start the animation shortly after entering the screen
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // Force Dark Mode context for this screen
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) {
          // Now AppColors.background(context) will correctly resolve to the dark mode color
          final bgColor = AppColors.background(context);
          // Ensure status bar icons are light
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
          );
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: _buildTitle(context)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 64.0),
                    child: Image.asset(
                      'assets/icons/brand.png',
                      width: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
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
      },
    );
  }
}
