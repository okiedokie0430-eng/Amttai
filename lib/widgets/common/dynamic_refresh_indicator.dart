import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

class DynamicRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String animationAsset;
  final double offsetToArmed;
  final double maxPullDistance;
  final double indicatorSize;

  const DynamicRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.animationAsset = 'assets/images/food-bowl.json',
    this.offsetToArmed = 30,
    this.maxPullDistance = 90,
    this.indicatorSize = 46,
  });

  @override
  State<DynamicRefreshIndicator> createState() =>
      _DynamicRefreshIndicatorState();
}

class _DynamicRefreshIndicatorState extends State<DynamicRefreshIndicator>
    with SingleTickerProviderStateMixin {
  bool _armedHapticSent = false;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    // Default duration for Lottie looping speed
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      offsetToArmed: widget.offsetToArmed,
      onRefresh: widget.onRefresh,
      onStateChanged: (change) {
        if (change.didChange(to: IndicatorState.armed) && !_armedHapticSent) {
          _armedHapticSent = true;
          HapticFeedback.vibrate();
        }
        if (change.didChange(to: IndicatorState.idle)) {
          _armedHapticSent = false;
          _animController.stop();
        }
        if (change.didChange(to: IndicatorState.loading) ||
            change.didChange(to: IndicatorState.settling)) {
          if (!_animController.isAnimating) {
            _animController.repeat(min: 0.5, max: 1.0);
          }
        }
      },
      builder: (context, child, controller) {
        final pullProgress = controller.value.clamp(0.0, 1.0).toDouble();
        final isRefreshing =
            !controller.isDragging &&
            !controller.isArmed &&
            !controller.isIdle;

        if (!isRefreshing) {
          _animController.value = pullProgress * 0.5;
        }

        final refreshSpaceHeight = pullProgress * widget.maxPullDistance;
        final showIndicator = controller.value > 0.0 || !controller.isIdle;
        final indicatorOpacity = pullProgress;
        
        final indicatorTop =
            MediaQuery.of(context).padding.top +
            (refreshSpaceHeight * 0.5) -
            (widget.indicatorSize * 0.5);

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Stack(
          children: <Widget>[
            Transform.translate(
              offset: Offset(0.0, refreshSpaceHeight),
              child: child,
            ),
            if (showIndicator)
              Positioned(
                top: indicatorTop,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: indicatorOpacity,
                  child: Center(
                    child: SizedBox(
                      width: widget.indicatorSize,
                      height: widget.indicatorSize,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          isDarkMode ? Colors.white : Colors.transparent,
                          isDarkMode ? BlendMode.srcATop : BlendMode.dst,
                        ),
                        child: Lottie.asset(
                          widget.animationAsset,
                          fit: BoxFit.contain,
                          controller: _animController,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
