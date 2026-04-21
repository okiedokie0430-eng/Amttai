import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final bool isPremium;
  final double size;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    required this.isPremium,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceVariant(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildAvatarContent(context),
          ),
          IgnorePointer(
            child: Image.asset(
              isPremium
                  ? 'assets/images/premium.png'
                  : 'assets/images/free.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    final normalized = photoUrl?.trim() ?? '';

    if (normalized.isNotEmpty) {
      if (normalized.endsWith('.json')) {
        return Transform.scale(
          scale: 1.45,
          child: Lottie.asset(normalized, fit: BoxFit.cover),
        );
      }

      if (normalized.startsWith('assets/')) {
        return Image.asset(
          normalized,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialFallback(context),
        );
      }

      return CachedNetworkImage(
        imageUrl: normalized,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildInitialFallback(context),
        errorWidget: (_, __, ___) => _buildInitialFallback(context),
      );
    }

    return _buildInitialFallback(context);
  }

  Widget _buildInitialFallback(BuildContext context) {
    final initial = (name ?? '').trim();
    final letter = initial.isNotEmpty ? initial[0].toUpperCase() : '?';

    return Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
