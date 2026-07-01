import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';
import '../../providers/favorites_provider.dart';
import '../common/appwrite_image.dart';

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

    final imageContent = recipe.imageUrl != null
        ? AppwriteImage(
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
          );

    final imageLayer = Material(
      type: MaterialType.transparency,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Sharp base image
            imageContent,
            
            // 2. Pre-rendered soft-edge blur behind the title area.
            //    Positioned with negative offsets extends the blurred image
            //    BEYOND the card edges so the blur kernel has full pixel data
            //    at borders — no fade-out at sides/bottom. The parent's
            //    Clip.hardEdge hides the bleed. ShaderMask fades only the top.
            Positioned(
              left: -40,
              right: -40,
              top: 0,
              bottom: -25,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.6, 0.82, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 35.0, sigmaY: 20.0),
                  child: imageContent,
                ),
              ),
            ),

            // 3. Dark gradient scrim for text readability over the blur
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: isLandscape ? 110.0 : 150.0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
                createRectTween: (begin, end) =>
                    RectTween(begin: begin, end: end),
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
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: isLandscape ? 8 : 12,
                        right: isLandscape ? 8 : 12,
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
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
                                              fontSize: isLandscape ? 18 : 24,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                              letterSpacing: -0.5,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black45,
                                                  blurRadius: 4.0,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
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
                                            color: Colors.white,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 3.0,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${recipe.cookTimeMinutes} min',
                                            style: textTheme.labelSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black45,
                                                  blurRadius: 3.0,
                                                ),
                                              ],
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
                                            color: Colors.white,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 3.0,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            recipe.difficulty.toUpperCase(),
                                            style: textTheme.labelSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black45,
                                                  blurRadius: 3.0,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // V1.0: PREMIUM badge hidden — restore for V1.1.
                            /* if (recipe.isPremium) ...[
                              const SizedBox(width: 8),
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
                            ], // end if (recipe.isPremium)
                            */
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
      return 'Traditional';
    case 'main':
      return 'Main Course';
    case 'soup':
      return 'Soup';
    case 'drink':
      return 'Drink';
    case 'dessert':
      return 'Dessert';
    case 'snack':
      return 'Appetizer';
    case 'salad':
      return 'Salad';
    case 'breakfast':
      return 'Breakfast';
    case 'pastry':
      return 'Pastry';
    default:
      return categoryId.toUpperCase();
  }
}
}
