import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';

Future<void> openRecipeWithPremiumGuard({
  required BuildContext context,
  required Recipe recipe,
  required String heroPrefix,
}) async {
  final auth = context.read<AuthProvider>();

  if (recipe.isPremium && !auth.hasPremium) {
    final shouldUpgrade = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Premium жор'),
          content: const Text(
            'Энэ жорыг зөвхөн Premium хэрэглэгч үзэх боломжтой. Premium авах уу?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Болих'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Premium авах'),
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

  context.push('/recipe/${recipe.id}?hero=$heroPrefix');
}
