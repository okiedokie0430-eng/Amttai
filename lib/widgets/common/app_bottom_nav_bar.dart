import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';

class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with TickerProviderStateMixin {
  late final List<AnimationController> _lottieControllers;

  // Indices for the big pill
  static const _pillIndices = [0, 2, 3];

  static const _items = {
    0: {'asset': 'assets/icons/icons8-home.json', 'label': 'Нүүр'},
    1: {'asset': 'assets/icons/icons8-magnifying-glass.json', 'label': 'Хайх'},
    2: {'asset': 'assets/icons/icons8-cart.json', 'label': 'Агуулах'},
    3: {'asset': 'assets/icons/icons8-profile.json', 'label': 'Профайл'},
  };

  @override
  void initState() {
    super.initState();
    _lottieControllers = List.generate(
      4,
      (_) => AnimationController(vsync: this),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playAnimation(widget.currentIndex);
    });
  }

  @override
  void didUpdateWidget(covariant AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _playAnimation(widget.currentIndex);
    }
  }

  void _playAnimation(int index) {
    if (index >= 0 && index < _lottieControllers.length) {
      final ctrl = _lottieControllers[index];
      if (ctrl.isAnimating) return;
      ctrl.reset();
      ctrl.forward();
    }
  }

  @override
  void dispose() {
    for (final c in _lottieControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final pillBackgroundColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final highlightColor = AppColors.primary.withValues(alpha: 0.15);
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08);
    final outlineColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    int pillSelectedIndex = _pillIndices.indexOf(widget.currentIndex);
    if (pillSelectedIndex == -1) {
      pillSelectedIndex = 0; 
    }
    final isPillActive = _pillIndices.contains(widget.currentIndex);

    const double buttonWidth = 84.0;
    const double buttonHeight = 64.0;

    const double highlightWidth = buttonWidth - 12;
    const double highlightHeight = buttonHeight - 12;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // BIG PILL
            Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                color: pillBackgroundColor,
                borderRadius: BorderRadius.circular(buttonHeight / 2),
                border: Border.all(color: outlineColor, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: isPillActive ? (pillSelectedIndex * buttonWidth) + ((buttonWidth - highlightWidth) / 2) : ((buttonWidth - highlightWidth) / 2),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isPillActive ? 1.0 : 0.0,
                      child: Container(
                        width: highlightWidth,
                        height: highlightHeight,
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(highlightHeight / 2),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _pillIndices.map((idx) {
                      return _buildIcon(
                        index: idx,
                        width: buttonWidth,
                        height: buttonHeight,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // SEARCH BUTTON
            Container(
              width: buttonWidth,
              height: buttonHeight,
              decoration: BoxDecoration(
                color: pillBackgroundColor,
                borderRadius: BorderRadius.circular(buttonHeight / 2),
                border: Border.all(color: outlineColor, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: widget.currentIndex == 1 ? 1.0 : 0.0,
                    child: Container(
                      width: highlightWidth,
                      height: highlightHeight,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(highlightHeight / 2),
                      ),
                    ),
                  ),
                  _buildIcon(
                    index: 1,
                    width: buttonHeight,
                    height: buttonHeight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon({
    required int index,
    required double width,
    required double height,
  }) {
    final selected = index == widget.currentIndex;
    final item = _items[index]!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) {
          HapticFeedback.selectionClick();
        }
        widget.onTap(index);
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcATop,
              ),
              child: Lottie.asset(
                item['asset']!,
                controller: _lottieControllers[index],
                width: 26,
                height: 26,
                onLoaded: (composition) {
                  _lottieControllers[index].duration = composition.duration;
                  if (index == widget.currentIndex) {
                    _lottieControllers[index].value = 1.0;
                  }
                },
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item['label']!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textTertiary(context).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
