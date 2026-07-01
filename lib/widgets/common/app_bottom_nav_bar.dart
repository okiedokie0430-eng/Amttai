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
  // Indices grouped inside the main pill.
  static const _pillIndices = [0, 2, 3];
  static const _items = {
    0: {'asset': 'assets/icons/icons8-home.json', 'label': 'Home'},
    1: {
      'asset': 'assets/icons/icons8-magnifying-glass.json',
      'label': 'Search',
    },
    2: {'asset': 'assets/icons/icons8-cart.json', 'label': 'Pantry'},
    3: {'asset': 'assets/icons/icons8-profile.json', 'label': 'Profile'},
  };
  /// Tracks the last pill tab so the highlight stays put when Search is active.
  int _lastPillSelectedIndex = 0;
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
      final newPillIndex = _pillIndices.indexOf(widget.currentIndex);
      if (newPillIndex != -1) _lastPillSelectedIndex = newPillIndex;
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive scale: 375dp is iPhone reference.
    // Clamped so it never looks too tiny or bloated.
    final scale = (screenWidth / 375.0).clamp(0.85, 1.15).toDouble();
    final pillBackgroundColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF);
    final highlightColor = AppColors.primary.withValues(alpha: 0.14);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.07);
    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final inactiveIconColor = AppColors.textTertiary(context);
    int pillSelectedIndex = _pillIndices.indexOf(widget.currentIndex);
    if (pillSelectedIndex == -1) pillSelectedIndex = _lastPillSelectedIndex;
    final isPillActive = _pillIndices.contains(widget.currentIndex);
    final isSearchSelected = widget.currentIndex == 1;
    final double pillItemWidth =
        80.0 * scale; // Increased to make nav bar bigger
    final double pillHeight = 64.0 * scale; // Increased height
    final double searchWidth = pillHeight; // Perfect circle: width = height
    final double highlightWidth =
    pillItemWidth - 8.0 * scale; // Snug fit inside pill item
    final double highlightHeight = pillHeight - 8.0 * scale;
    final double iconSize = 28.0 * scale; // Increased icon size
    final double labelSize = 11.0 * scale; // Increased label size
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: 20.0 * scale, top: 8.0 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── MAIN PILL ───
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(pillHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 24 * scale,
                    offset: Offset(0, 8 * scale),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Container(
                height: pillHeight,
                decoration: BoxDecoration(
                  color: pillBackgroundColor,
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                  border: Border.all(color: outlineColor, width: 0.5),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Smooth sliding highlight – no overshoot physics.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      left:
                          (pillSelectedIndex * pillItemWidth) +
                          ((pillItemWidth - highlightWidth) / 2),
                      top: (pillHeight - highlightHeight) / 2,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        opacity: isPillActive ? 1.0 : 0.0,
                        child: Container(
                          width: highlightWidth,
                          height: highlightHeight,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(
                              highlightHeight / 2,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Icons row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _pillIndices.map((idx) {
                        return _buildNavItem(
                          index: idx,
                          width: pillItemWidth,
                          height: pillHeight,
                          iconSize: iconSize,
                          labelSize: labelSize,
                          inactiveColor: inactiveIconColor,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12 * scale),
            // ─── SEARCH BUBBLE ───
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(pillHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 24 * scale,
                    offset: Offset(0, 8 * scale),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                width: searchWidth,
                height: pillHeight,
                decoration: BoxDecoration(
                  color: isSearchSelected ? highlightColor : pillBackgroundColor,
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                  border: Border.all(
                    color: isSearchSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : outlineColor,
                    width: 0.5,
                  ),
                ),
                child: _buildNavItem(
                  index: 1,
                  width: searchWidth,
                  height: pillHeight,
                  iconSize: iconSize,
                  labelSize: labelSize,
                  inactiveColor: inactiveIconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildNavItem({
    required int index,
    required double width,
    required double height,
    required double iconSize,
    required double labelSize,
    required Color inactiveColor,
  }) {
    final selected = index == widget.currentIndex;
    final item = _items[index]!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!selected) {
          HapticFeedback.heavyImpact();
          widget.onTap(index);
        }
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              scale: selected ? 1.06 : 1.0,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  selected ? AppColors.primary : inactiveColor,
                  BlendMode.srcIn,
                ),
                child: Lottie.asset(
                  item['asset']!,
                  controller: _lottieControllers[index],
                  width: iconSize,
                  height: iconSize,
                  onLoaded: (composition) {
                    _lottieControllers[index].duration = composition.duration;
                    if (index == widget.currentIndex) {
                      _lottieControllers[index].value = 1.0;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item['label']!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: labelSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.primary
                    : inactiveColor.withValues(alpha: 0.7),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
