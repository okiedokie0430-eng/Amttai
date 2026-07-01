import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// V1.0: Unused after premium gate bypass — restore for V1.1.
// import 'package:provider/provider.dart';

import '../../models/recipe.dart';
// V1.0: Unused after premium gate bypass — restore for V1.1.
// import '../../providers/auth_provider.dart';

Future<void> openRecipeWithPremiumGuard({
  required BuildContext context,
  required Recipe recipe,
  required String heroPrefix,
}) async {
  // V1.0 — Premium gate disabled for Google Play closed testing review.
  // All recipes are freely accessible. Restore the block below for V1.1.
  /*
  final auth = context.read<AuthProvider>();

  if (recipe.isPremium && !auth.hasPremium) {
    final shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Premium Recipe'),
          content: const Text(
            'This recipe is only available to Premium users. Would you like to upgrade?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Get Premium'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) {
      return;
    }

    if (shouldUpgrade == true) {
      context.push('/premium');
    }

    return;
  }
  */

  context.push('/recipe/${recipe.id}?hero=$heroPrefix');
}
