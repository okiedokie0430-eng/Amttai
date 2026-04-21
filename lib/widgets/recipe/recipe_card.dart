import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';
import '../../providers/favorites_provider.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final bool isLandscape;
  final double uiOpacity;
  final String heroPrefix;
  final bool enableHero;
  final int imageMemCacheHeight;
  final FilterQuality imageFilterQuality;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.isLandscape = false,
    this.uiOpacity = 1.0,
    this.heroPrefix = '',
    this.enableHero = true,
    this.imageMemCacheHeight = 800,
    this.imageFilterQuality = FilterQuality.low,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showOverlay = uiOpacity > 0.0;
    final isFavorite = showOverlay
        ? context.select<FavoritesProvider, bool>(
            (fp) => fp.isFavorite(recipe.id),
          )
        : false;

    final imageLayer = Material(
      type: MaterialType.transparency,
      child: RepaintBoundary(
        child: recipe.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: recipe.imageUrl!,
                fit: BoxFit.cover,
                memCacheHeight: imageMemCacheHeight,
                filterQuality: imageFilterQuality,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) =>
                    Container(color: AppColors.surfaceVariant(context)),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceVariant(context),
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.textTertiary(context),
                    size: 40,
                  ),
                ),
              )
            : Container(
                color: AppColors.surfaceVariant(context),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.textTertiary(context),
                  size: 40,
                ),
              ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.surfaceVariant(context),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (enableHero)
              Hero(
                tag: '${heroPrefix}recipe_image_${recipe.id}',
                createRectTween: (begin, end) => RectTween(begin: begin, end: end),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: imageLayer,
                ),
              )
            else
              imageLayer,

            if (showOverlay)
              Opacity(
                opacity: uiOpacity,
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.4, 0.7, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        top: isLandscape ? 12 : 16,
                        left: isLandscape ? 12 : 16,
                        right: isLandscape ? 12 : 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isLandscape ? 8 : 10,
                                vertical: isLandscape ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                _getCategoryName(recipe.category),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isLandscape ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (recipe.isPremium)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isLandscape ? 8 : 10,
                                  vertical: isLandscape ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.premiumGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      size: isLandscape ? 12 : 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PREMIUM',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isLandscape ? 9 : 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: isLandscape ? 8 : 12,
                        right: recipe.isPremium
                            ? (isLandscape ? 85 : 100)
                            : (isLandscape ? 8 : 12),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            context.read<FavoritesProvider>().toggleFavorite(
                              recipe.id,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(isLandscape ? 8 : 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: isLandscape ? 18 : 22,
                              color: isFavorite
                                  ? Colors.redAccent
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: isLandscape ? 12 : 16,
                        left: isLandscape ? 12 : 16,
                        right: isLandscape ? 12 : 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (isLandscape
                                          ? textTheme.titleMedium
                                          : textTheme.titleLarge)
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                        letterSpacing: -0.5,
                                      ),
                            ),
                            SizedBox(height: isLandscape ? 4 : 8),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: isLandscape ? 14 : 16,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${recipe.cookTimeMinutes} мин',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isLandscape ? 11 : 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: isLandscape ? 8 : 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: isLandscape ? 14 : 16,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      recipe.difficulty.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isLandscape ? 11 : 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String categoryId) {
    switch (categoryId) {
      case 'traditional':
        return 'Уламжлалт';
      case 'main':
        return 'Үндсэн хоол';
      case 'soup':
        return 'Шөл';
      case 'drink':
        return 'Уух зүйл';
      case 'dessert':
        return 'Амттан';
      case 'snack':
        return 'Зууш';
      case 'salad':
        return 'Салад';
      case 'breakfast':
        return 'Өглөөний цай';
      case 'pastry':
        return 'Нарийн боов';
      default:
        return categoryId.toUpperCase();
    }
  }
}
