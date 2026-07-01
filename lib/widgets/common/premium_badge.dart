import 'package:flutter/material.dart';

// V1.0: Imports unused while PremiumBadge is hidden — restore for V1.1.
// import '../../core/constants/app_dimens.dart';
// import '../../core/theme/app_colors.dart';

/// A small badge that signals premium-only content.
class PremiumBadge extends StatelessWidget {
  final double fontSize;

  const PremiumBadge({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    // V1.0: PremiumBadge hidden for Google Play review — restore for V1.1.
    return const SizedBox.shrink();
    /* V1.0 — original badge widget preserved below
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: fontSize + 2, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            'Premium',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    */
  }
}
