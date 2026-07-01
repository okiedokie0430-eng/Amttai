import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/premium_recipe_access.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/common/appwrite_image.dart';
import '../../widgets/common/dynamic_refresh_indicator.dart';
import '../../widgets/common/fade_slide_in.dart';
import '../../widgets/common/shimmer_loader.dart';
import '../../widgets/recipe/recipe_card.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  late PageController _trendingController;
  late PageController _newController;
  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _trendingController = PageController(viewportFraction: 0.9);
    _newController = PageController(viewportFraction: 0.9);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<RecipeProvider>().loadRecipes();
    });
  }
  @override
  void dispose() {
    _pageController.dispose();
    _trendingController.dispose();
    _newController.dispose();
    super.dispose();
  }
  Widget _buildGradientTitle(String text, TextStyle? style) {
    return Text(
      text,
      style: style?.copyWith(color: AppColors.textPrimary(context)),
    );
  }
  void _maybePrefetchFeaturedImages(List<Recipe> recipes) {
    // Warm the disk cache for featured recipe images so hero transitions
    // and card images render instantly. ImagePrefetcher resolves auth headers
    // per-URL (Appwrite session / Wikimedia User-Agent) and uses the same
    // AmttaiCacheManager, ensuring cache coherence with AppwriteImage widgets.
    ImagePrefetcher.prefetch(
      recipes.take(8).map((r) => r.imageUrl).toList(),
      count: 8,
    );
  }
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rp = context.watch<RecipeProvider>();
    _maybePrefetchFeaturedImages(rp.recipes);
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          S.appName,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            fontSize: 26,
            color: AppColors.primary,
          ),
        ),
      ),
      body: RepaintBoundary(
        child: DynamicRefreshIndicator(
          onRefresh: rp.loadRecipes,
          animationAsset: 'assets/images/food-bowl.json',
          offsetToArmed: 120,
          maxPullDistance: 60,
          indicatorSize: 42,
          child: rp.isLoading
              ? _buildLoadingShimmer()
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (rp.recipes.isNotEmpty) ...[
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 8.0,
                            ),
                            child: _buildGradientTitle(
                              'Today\'s Featured',
                              textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: SizedBox(
                            height: 480,
                            child: AnimatedBuilder(
                              animation: _pageController,
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(
                                  parent: PageScrollPhysics(),
                                ),
                                itemCount: rp.recipes.length > 5
                                    ? 5
                                    : rp.recipes.length,
                                itemBuilder: (_, __) => const SizedBox.expand(),
                              ),
                              builder: (context, pageViewChild) {
                                final page = _pageController.hasClients
                                    ? _pageController.page ?? 0.0
                                    : 0.0;
                                final itemCount = rp.recipes.length > 5
                                    ? 5
                                    : rp.recipes.length;
                                final screenWidth = MediaQuery.sizeOf(
                                  context,
                                ).width;
  
                                if (itemCount == 0) {
                                  return const SizedBox.shrink();
                                }
  
                                final activeIndex = page.round().clamp(
                                  0,
                                  itemCount - 1,
                                );
  
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    for (
                                      var index = itemCount - 1;
                                      index >= 0;
                                      index--
                                    )
                                      () {
                                        final recipe = rp.recipes[index];
                                        final progress = page - index;
                                        const rearFadeStart = -0.9;
                                        const rearFadeEnd = -1.75;
  
                                        // Drop deeply buried cards to cut per-frame composition cost,
                                        // but fade them out first to avoid sudden popping.
                                        if (progress >= 1.0 ||
                                            progress < rearFadeEnd) {
                                          return const SizedBox.shrink();
                                        }
  
                                        var cardVisibility = 1.0;
                                        if (progress <= rearFadeStart) {
                                          cardVisibility =
                                              ((progress - rearFadeEnd) /
                                                      (rearFadeStart -
                                                          rearFadeEnd))
                                                  .clamp(0.0, 1.0);
                                        }
  
                                        double scale = 1.0;
                                        double offset = 0.0;
                                        double rotation = 0.0;
                                        final absProgress = progress.abs();
                                        final isFocusedCard =
                                            index == activeIndex;
                                        final overlayOpacity =
                                            ((1.0 - (absProgress * 1.7)).clamp(
                                                      0.0,
                                                      1.0,
                                                    ) *
                                                    cardVisibility)
                                                .clamp(0.0, 1.0);
  
                                        if (progress > 0) {
                                          final easedProgress = Curves.easeIn
                                              .transform(
                                                progress.clamp(0.0, 1.0),
                                              );
                                          offset =
                                              -(easedProgress *
                                                  screenWidth *
                                                  1.02);
                                        } else {
                                          final easedBehind = Curves.easeInOut
                                              .transform(
                                                absProgress.clamp(0.0, 1.0),
                                              );
                                          scale = (1 - easedBehind * 0.085).clamp(
                                            0.0,
                                            1.0,
                                          );
                                          offset = easedBehind * 18.0;
                                          rotation = -easedBehind * 0.015;
                                        }
  
                                        final cardLayer = RepaintBoundary(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 8,
                                            ),
                                            child: RecipeCard(
                                              recipe: recipe,
                                              uiOpacity: overlayOpacity,
                                              enableHero: isFocusedCard,
                                              imageMemCacheHeight: 720,
                                              imageFilterQuality:
                                                  FilterQuality.medium,
                                              heroPrefix: 'home_',
                                              onTap: null,
                                            ),
                                          ),
                                        );
  
                                        final visibleCard =
                                            cardVisibility >= 0.999
                                            ? cardLayer
                                            : Opacity(
                                                opacity: cardVisibility,
                                                child: cardLayer,
                                              );
  
                                        return Transform.translate(
                                          offset: Offset(offset, 0),
                                          child: Transform.scale(
                                            scale: scale,
                                            alignment: Alignment.centerRight,
                                            child: Transform.rotate(
                                              angle: rotation,
                                              child: visibleCard,
                                            ),
                                          ),
                                        );
                                      }(),
                                    GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        final recipe = rp.recipes[activeIndex];
                                        openRecipeWithPremiumGuard(
                                          context: context,
                                          recipe: recipe,
                                          heroPrefix: 'home_',
                                        );
                                      },
                                      child: pageViewChild!,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (rp.recipes.length > 5) ...[
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 300),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildGradientTitle(
                                  'Trending Recipes',
                                  textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 400),
                          child: SizedBox(
                            height: 200,
                            child: PageView.builder(
                              controller: _trendingController,
                              physics: const ClampingScrollPhysics(),
                              itemCount: rp.recipes.length - 5,
                              itemBuilder: (context, index) {
                                final recipe = rp.recipes[index + 5];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: RecipeCard(
                                    recipe: recipe,
                                    isLandscape: true,
                                    heroPrefix: 'trending_',
                                    onTap: () => openRecipeWithPremiumGuard(
                                      context: context,
                                      recipe: recipe,
                                      heroPrefix: 'trending_',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 500),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildGradientTitle(
                                  'New Recipes',
                                  textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 600),
                          child: SizedBox(
                            height: 200,
                            child: PageView.builder(
                              controller: _newController,
                              physics: const ClampingScrollPhysics(),
                              itemCount: rp.recipes.length,
                              itemBuilder: (context, index) {
                                final recipe =
                                    rp.recipes[rp.recipes.length - 1 - index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: RecipeCard(
                                    recipe: recipe,
                                    isLandscape: true,
                                    heroPrefix: 'new_',
                                    onTap: () => openRecipeWithPremiumGuard(
                                      context: context,
                                      recipe: recipe,
                                      heroPrefix: 'new_',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 120), // Added bottom padding to clear nav bar
                    ],
                  ),
                ),
        ),
      ),
    );
  }
  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: ShimmerLoader.card(height: 32, width: 200),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 480,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ShimmerLoader.card(
                      height: 480,
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ShimmerLoader.card(height: 28, width: 150),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(child: ShimmerLoader.card(height: 200)),
                const SizedBox(width: 16),
                Expanded(child: ShimmerLoader.card(height: 200)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
