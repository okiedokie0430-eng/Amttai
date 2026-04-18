
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/common/shimmer_loader.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  final String heroPrefix;
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.heroPrefix = '',
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _loading = true;
  final Set<int> _checkedIngredients = {};

  @override
  void initState() {
    super.initState();
    // Try to load the local recipe synchronously
    final rp = context.read<RecipeProvider>();
    final allRecipes = [...rp.recipes, ...rp.trending, ...rp.searchResults];
    final local = allRecipes.where((r) => r.id == widget.recipeId).toList();
    if (local.isNotEmpty) {
      _recipe = local.first;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    final rp = context.read<RecipeProvider>();
    final favProv = context.read<FavoritesProvider>();

    if (_recipe == null && mounted) {
      setState(() => _loading = true);
    }

    try {
      final r = await rp.getRecipeDetail(widget.recipeId);
      if (mounted) setState(() => _recipe = r);
    } catch (_) {
      final local = rp.recipes.where((r) => r.id == widget.recipeId).toList();
      if (local.isNotEmpty && mounted) setState(() => _recipe = local.first);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    // Track as recently viewed
    favProv.addRecentlyViewed(widget.recipeId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(child: ShimmerLoader.card(height: 300)),
      );
    }
    if (_recipe == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(),
        body: const Center(child: Text(S.unknownError)),
      );
    }

    final recipe = _recipe!;
    final textTheme = Theme.of(context).textTheme;
    final fav = context.watch<FavoritesProvider>();
    final isFav = fav.isFavorite(recipe.id);

    final routeAnim = ModalRoute.of(context)?.animation;
    final delayedContentAnim = routeAnim != null
        ? CurvedAnimation(
            parent: routeAnim,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
            reverseCurve: const Interval(0.6, 0.9, curve: Curves.easeInCubic),
          )
        : const AlwaysStoppedAnimation(1.0);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: FadeTransition(
        opacity: delayedContentAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero image header ──
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: _headerButton(
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 4),
                  child: _headerIconButton(
                    icon: Icon(
                      Icons.favorite_rounded,
                      size: 22,
                      color: isFav ? Colors.redAccent : Colors.white70,
                    ),
                    onTap: () => fav.toggleFavorite(recipe.id),
                  ),
                ),
              ],
              flexibleSpace: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double minHeight =
                          MediaQuery.of(context).padding.top + kToolbarHeight;
                      final double currentHeight = constraints.maxHeight;

                      final double fadeStart = minHeight + 160.0;
                      final double fadeEnd = minHeight;

                      double progress = 0.0;
                      if (currentHeight <= fadeStart) {
                        progress =
                            1.0 -
                            ((currentHeight - fadeEnd) / (fadeStart - fadeEnd));
                        progress = progress.clamp(0.0, 1.0);
                      }

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag:
                                '${widget.heroPrefix}recipe_image_${recipe.id}',
                            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
                            flightShuttleBuilder:
                                (
                                  BuildContext flightContext,
                                  Animation<double> animation,
                                  HeroFlightDirection flightDirection,
                                  BuildContext fromHeroContext,
                                  BuildContext toHeroContext,
                                ) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      final isPush = flightDirection == HeroFlightDirection.push;
                                      final startRadius = isPush ? 24.0 : 0.0;
                                      final endRadius = isPush ? 0.0 : 24.0;
                                      final radius = startRadius + (endRadius - startRadius) * animation.value;

                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(radius),
                                        child: isPush ? toHeroContext.widget : fromHeroContext.widget,
                                      );
                                    },
                                  );
                                },
                            child: Material(
                              type: MaterialType.transparency,
                              child: recipe.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: recipe.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Container(
                                      color: AppColors.surfaceVariant(context),
                                    ),
                            ),
                          ),
                          if (progress > 0)
                            Positioned.fill(
                              child: Container(
                                color: AppColors.background(
                                  context,
                                ).withValues(alpha: progress),
                              ),
                            ),
                          if (progress > 0.5)
                            Positioned(
                              left: 64, // Space for leading button
                              right: 64, // Space for action button
                              bottom: 16,
                              child: Opacity(
                                opacity: ((progress - 0.5) * 2).clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - progress)),
                                  child: Text(
                                    recipe.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Title + meta info ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recipe.isPremium)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.premiumGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      recipe.title,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Meta chips row
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metaChip(
                          Icons.access_time_rounded,
                          '${recipe.totalTimeMinutes} мин',
                        ),
                        _metaChip(
                          Icons.people_outline_rounded,
                          '${recipe.servings} хүн',
                        ),
                        _metaChip(
                          Icons.signal_cellular_alt_rounded,
                          recipe.difficulty,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Text(
                      recipe.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Ingredients section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      S.ingredients,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${recipe.ingredients.length}',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addAllToCart(recipe),
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: const Text('Сагсанд нэмэх'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Ingredient list ──
            if (recipe.ingredients.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Орц нэмэгдээгүй')),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final ing = recipe.ingredients[i];
                  final checked = _checkedIngredients.contains(i);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (checked) {
                          _checkedIngredients.remove(i);
                        } else {
                          _checkedIngredients.add(i);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checked
                                  ? AppColors.primary
                                  : Colors.transparent,
                              border: Border.all(
                                color: checked
                                    ? AppColors.primary
                                    : AppColors.border(context),
                                width: 2,
                              ),
                            ),
                            child: checked
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              ing.name,
                              style: textTheme.bodyLarge?.copyWith(
                                decoration: checked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: checked
                                    ? AppColors.textTertiary(context)
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            '${ing.amount}${ing.unit != null ? ' ${ing.unit}' : ''}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: recipe.ingredients.length),
              ),

            // ── Steps section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Text(
                  S.steps,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            if (recipe.steps.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Алхам нэмэгдээгүй')),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final step = recipe.steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${step.order}',
                              style: textTheme.labelLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              step.description,
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }, childCount: recipe.steps.length),
              ),

            // ── Nutrition section ──
            if (recipe.nutrition != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text(
                    S.nutrition,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _nutritionItem(
                          '${recipe.nutrition!.calories}',
                          'ккал',
                          context,
                        ),
                        _nutritionItem(
                          '${recipe.nutrition!.protein.toStringAsFixed(1)}г',
                          'Уураг',
                          context,
                        ),
                        _nutritionItem(
                          '${recipe.nutrition!.carbs.toStringAsFixed(1)}г',
                          'Нүүрс ус',
                          context,
                        ),
                        _nutritionItem(
                          '${recipe.nutrition!.fat.toStringAsFixed(1)}г',
                          'Өөх тос',
                          context,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback onTap) => _headerIconButton(
    icon: Icon(icon, color: Colors.white, size: 20),
    onTap: onTap,
  );

  Widget _headerIconButton({required Widget icon, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Center(child: icon),
        ),
      );

  Widget _metaChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
        ),
      ),
    ],
  );

  Widget _nutritionItem(String value, String label, BuildContext ctx) => Column(
    children: [
      Text(
        value,
        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: Theme.of(
          ctx,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary(ctx)),
      ),
    ],
  );

  void _addAllToCart(Recipe recipe) {
    final cart = context.read<CartProvider>();
    cart.addItems(
      recipe.ingredients
          .map(
            (ing) => CartItem(
              name: ing.name,
              amount: ing.amount,
              unit: ing.unit,
              recipeName: recipe.title,
            ),
          )
          .toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${recipe.ingredients.length} орц сагсанд нэмэгдлээ'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

