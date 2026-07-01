import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/common/appwrite_image.dart';
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
  bool _queuedPremiumPrompt = false;
  bool _buttonsVisible = false;
  /// Resolved HTTP headers for the recipe image (Appwrite session / Wikimedia UA).
  /// Initialised synchronously from cache, then refreshed async.
  Map<String, String> _imageHeaders = const {};

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
      // Resolve headers synchronously from cache for instant hero image
      if (_recipe!.imageUrl != null) {
        _imageHeaders = AppwriteImage.resolveHeadersSync(_recipe!.imageUrl!);
      }
    }
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.animation != null) {
      route.animation!.addStatusListener(_onAnimationStatusChanged);
      if (route.animation!.status == AnimationStatus.completed) {
        if (!_buttonsVisible) {
          _buttonsVisible = true;
        }
      }
    } else {
      if (!_buttonsVisible) {
        _buttonsVisible = true;
      }
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && !_buttonsVisible) {
        setState(() => _buttonsVisible = true);
      }
    } else if (status == AnimationStatus.reverse) {
      if (mounted && _buttonsVisible) {
        setState(() => _buttonsVisible = false);
      }
    }
  }

  @override
  void dispose() {
    final route = ModalRoute.of(context);
    route?.animation?.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final rp = context.read<RecipeProvider>();
    final favProv = context.read<FavoritesProvider>();
    final auth = context.read<AuthProvider>();

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

    // Async-resolve image headers (covers cases where sync cache was empty)
    final recipe = _recipe;
    if (recipe?.imageUrl != null && mounted) {
      final headers = await AppwriteImage.resolveHeadersFor(recipe!.imageUrl!);
      if (mounted && headers.isNotEmpty && _imageHeaders.isEmpty) {
        setState(() => _imageHeaders = headers);
      }
    }

    final canAccessPremium = auth.hasPremium;
    if (recipe != null && (!recipe.isPremium || canAccessPremium)) {
      favProv.addRecentlyViewed(widget.recipeId);
    }
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
    final hasPremium = context.watch<AuthProvider>().hasPremium;
    final fav = context.watch<FavoritesProvider>();
    final isFav = fav.isFavorite(recipe.id);

    if (recipe.isPremium && !hasPremium) {
      _queuePremiumDialog();
      return _buildPremiumLockedState();
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ── Hero image header ──
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: AnimatedOpacity(
              opacity: _buttonsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: _headerButton(
                  Icons.arrow_back_ios_new_rounded,
                  () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              AnimatedOpacity(
                opacity: _buttonsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
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
                          tag: '${widget.heroPrefix}recipe_image_${recipe.id}',
                          createRectTween: (begin, end) =>
                              RectTween(begin: begin, end: end),
                          flightShuttleBuilder: (
                            flightContext,
                            animation,
                            flightDirection,
                            fromHeroContext,
                            toHeroContext,
                          ) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    24 * (1 - animation.value),
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: recipe.imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: recipe.imageUrl!,
                                            cacheManager: AmttaiCacheManager(),
                                            httpHeaders: _imageHeaders.isEmpty ? null : _imageHeaders,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            fadeInDuration: Duration.zero,
                                            fadeOutDuration: Duration.zero,
                                            useOldImageOnUrlChange: true,
                                          )
                                        : Container(
                                            color: AppColors.surfaceVariant(
                                                context),
                                          ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Material(
                            type: MaterialType.transparency,
                            child: recipe.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: recipe.imageUrl!,
                                    cacheManager: AmttaiCacheManager(),
                                    httpHeaders: _imageHeaders.isEmpty ? null : _imageHeaders,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    useOldImageOnUrlChange: true,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Ingredients',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.remove_circle_outline_rounded,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Serves ${recipe.servings}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.textSecondary(context),
                  ),
                  const Spacer(),
                  Text(
                    'US / METRIC',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary(context),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

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
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.primaries[i % Colors.primaries.length]
                              .withValues(alpha: 0.2), // Light background color for ingredient
                        ),
                        // Replace with an actua CachedNetworkImage if you have ingredient images
                      ),
                      const SizedBox(width: 16),
                      // Amount
                      SizedBox(
                        width: 48,
                        child: Text(
                          ing.amount,
                          style: textTheme.titleMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ing.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textPrimary(context).withValues(alpha: 0.5),
                              ),
                            ),
                            if (ing.unit != null && ing.unit!.isNotEmpty)
                              Text(
                                ing.unit!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary(context),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary(context),
                        size: 20,
                      ),
                    ],
                  ),
                );
              }, childCount: recipe.ingredients.length),
            ),

          // ── Nutrition section ──
          if (recipe.nutrition != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nutrition Per Serving',
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'VIEW ALL',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary(context),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _nutritionItem(
                      '${recipe.nutrition!.calories}',
                      'CALORIES',
                      context,
                    ),
                    _verticalDivider(context),
                    _nutritionItem(
                      '${recipe.nutrition!.fat.toStringAsFixed(1)} g',
                      'FAT',
                      context,
                    ),
                    _verticalDivider(context),
                    _nutritionItem(
                      '${recipe.nutrition!.protein.toStringAsFixed(1)} g',
                      'PROTEIN',
                      context,
                    ),
                    _verticalDivider(context),
                    _nutritionItem(
                      '${recipe.nutrition!.carbs.toStringAsFixed(1)} g',
                      'CARBS',
                      context,
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Divider(
                color: AppColors.surfaceVariant(context),
                height: 1,
                thickness: 8,
              ),
            ),
          ],

          // ── Directions section ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Directions',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'HIDE IMAGES',
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/recipe/${recipe.id}/steps', extra: recipe);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('STEP BY STEP MODE'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  side: BorderSide(color: AppColors.textPrimary(context).withValues(alpha: 0.2)),
                  foregroundColor: AppColors.textPrimary(context),
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
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${step.order}',
                        style: textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                        ),
                      ),
                      if ((step.timerSeconds ?? 0) > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Таймер: ${step.timerSeconds} сек',
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if ((step.imageUrl ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: step.imageUrl!.trim(),
                                  cacheManager: AmttaiCacheManager(),
                                  httpHeaders: AppwriteImage.resolveHeadersSync(step.imageUrl!.trim()).isEmpty
                                      ? null
                                      : AppwriteImage.resolveHeadersSync(step.imageUrl!.trim()),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      ShimmerLoader.card(height: 160),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.surfaceVariant(
                                      context,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.textSecondary(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.background(context).withValues(alpha: 0.8),
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: AppColors.primary,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }, childCount: recipe.steps.length),
            ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _queuePremiumDialog() {
    if (_queuedPremiumPrompt) {
      return;
    }

    _queuedPremiumPrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final shouldUpgrade = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Premium шаардлагатай'),
            content: const Text(
              'Энэ жорыг үзэхийн тулд Premium төлөвлөгөөнд нэгдэх шаардлагатай.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Буцах'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Premium авах'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (shouldUpgrade == true) {
        context.go('/premium');
        return;
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    });
  }

  Widget _buildPremiumLockedState() {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 68,
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Энэ бол Premium жор',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Premium авахад бүх premium жор нээгдэнэ.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push('/premium'),
                child: const Text('Premium авах'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback onTap) => _headerIconButton(
    icon: Icon(icon, color: Colors.white, size: 20),
    onTap: onTap,
  );

  Widget _headerIconButton({
    required Widget icon,
    required VoidCallback onTap,
  }) => GestureDetector(
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
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: Theme.of(
          ctx,
        ).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary(ctx),
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _verticalDivider(BuildContext ctx) => Container(
    width: 1,
    height: 32,
    color: AppColors.textSecondary(ctx).withValues(alpha: 0.3),
  );
}
