import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';

/// Clean bottom nav with Lottie animated icons.
///
/// 4 tabs: Home, Search, Cart, Saved.
/// Tap triggers one-shot Lottie animation, then stays on last frame.
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
  late final List<AnimationController> _controllers;

  static const _items = <_NavItem>[
    _NavItem(lottieAsset: 'assets/icons/icons8-home.json', label: 'Нүүр'),
    _NavItem(
      lottieAsset: 'assets/icons/icons8-magnifying-glass.json',
      label: 'Хайх',
    ),
    _NavItem(lottieAsset: 'assets/icons/icons8-cart.json', label: 'Агуулах'),
    _NavItem(lottieAsset: 'assets/icons/icons8-profile.json', label: 'Профайл'),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _items.length,
      (_) => AnimationController(vsync: this),
    );
  }

  @override
  void didUpdateWidget(covariant AppBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _playAnimation(widget.currentIndex);
    }
  }

  void _playAnimation(int index) {
    final ctrl = _controllers[index];
    if (ctrl.isAnimating) return;
    ctrl.reset();
    ctrl.forward();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: BorderSide(color: AppColors.border(context), width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: List.generate(_items.length, (i) {
            final selected = i == widget.currentIndex;
            final item = _items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!selected) HapticFeedback.selectionClick();
                  widget.onTap(i);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        selected
                            ? AppColors.primary
                            : AppColors.textTertiary(context),
                        BlendMode.srcATop,
                      ),
                      child: Lottie.asset(
                        item.lottieAsset,
                        controller: _controllers[i],
                        width: 26,
                        height: 26,
                        onLoaded: (composition) {
                          _controllers[i].duration = composition.duration;
                          if (i == widget.currentIndex) {
                            _controllers[i].value = 1.0;
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final String lottieAsset;
  final String label;
  const _NavItem({required this.lottieAsset, required this.label});
}
