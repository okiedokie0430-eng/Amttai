import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/recipe_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = AppColors.background(context);
    final primaryColor = AppColors.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          bottom: false,
          child: NestedScrollView(
            physics: const ClampingScrollPhysics(),
            headerSliverBuilder: (context, _) {
              return [
                SliverToBoxAdapter(
                  child: Container(
                    color: bgColor,
                    child: _buildHeader(
                      context,
                      auth,
                      isDark,
                      primaryColor,
                      bgColor,
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      indicatorColor: primaryColor,
                      indicatorWeight: 3,
                      labelColor: AppColors.textPrimary(context),
                      unselectedLabelColor: AppColors.textSecondary(context),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dividerColor: AppColors.border(
                        context,
                      ).withValues(alpha: 0.2),
                      tabs: const [
                        Tab(text: 'Хадгалсан'),
                        Tab(text: 'Сүүлд үзсэн'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _RecipeList(
                  bgColor: bgColor,
                  heroPrefix: 'profile_',
                  emptyMessage: 'Та хараахан жор хадгалаагүй байна.',
                  emptyIcon: Icons.favorite_rounded,
                  recipesBuilder: (context) {
                    final rp = context.watch<RecipeProvider>();
                    return context.watch<FavoritesProvider>().getFavorites(
                      rp.recipes,
                    );
                  },
                ),
                _RecipeList(
                  bgColor: bgColor,
                  heroPrefix: 'profile_recent_',
                  emptyMessage: 'Сүүлд үзсэн жор байхгүй байна.',
                  emptyIcon: Icons.history_rounded,
                  recipesBuilder: (context) {
                    final rp = context.watch<RecipeProvider>();
                    return context.watch<FavoritesProvider>().getRecentlyViewed(
                      rp.recipes,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthProvider auth,
    bool isDark,
    Color primaryColor,
    Color bgColor,
  ) {
    final user = auth.user;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
                onPressed: () => context.push('/profile-edit'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
                onPressed: () => context.push('/settings'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(user?.photoUrl, user?.name, primaryColor, context),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name.isNotEmpty == true ? user!.name : 'Очирсүх',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user?.isPremium == true
                            ? primaryColor
                            : AppColors.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user?.isPremium == true ? 'PREMIUM' : 'FREE',
                        style: TextStyle(
                          color: user?.isPremium == true
                              ? Colors.white
                              : AppColors.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String? name, Color primaryColor, BuildContext context) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.endsWith('.json')) {
        return Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceVariant(context),
            border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          ),
          clipBehavior: Clip.antiAlias,
          child: Transform.scale(
            scale: 1.5,
            child: Lottie.asset(photoUrl, fit: BoxFit.cover),
          )
        );
      }
      return CircleAvatar(
        radius: 46,
        backgroundColor: AppColors.surfaceVariant(context),
        backgroundImage: CachedNetworkImageProvider(photoUrl),
      );
    }
    
    return CircleAvatar(
      radius: 46,
      backgroundColor: AppColors.surfaceVariant(context),
      child: Text(
        name?.isNotEmpty == true ? name![0].toUpperCase() : 'О',
        style: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  final Color bgColor;
  final String heroPrefix;
  final String emptyMessage;
  final IconData emptyIcon;
  final List<dynamic> Function(BuildContext) recipesBuilder;

  const _RecipeList({
    required this.bgColor,
    required this.heroPrefix,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.recipesBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final recipes = recipesBuilder(context);
    final textTheme = Theme.of(context).textTheme;

    if (recipes.isEmpty) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(emptyIcon, size: 80, color: AppColors.textTertiary(context)),
            const SizedBox(height: 24),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: bgColor,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 120,
        ),
        itemCount: recipes.length,
        itemBuilder: (_, i) {
          final recipe = recipes[i];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: AppColors.surfaceVariant(context),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  context.push('/recipe/${recipe.id}?hero=$heroPrefix'),
              child: SizedBox(
                height: 140,
                child: Row(
                  children: [
                    Hero(
                      tag: '${heroPrefix}recipe_image_${recipe.id}',
                      child: SizedBox(
                        width: 140,
                        height: double.infinity,
                        child: recipe.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: recipe.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.withValues(alpha: 0.2),
                                child: const Icon(Icons.restaurant_rounded),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Орц: ${recipe.category}...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary(context),
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${recipe.cookTimeMinutes} мин',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned(
                              bottom: -10,
                              right: -10,
                              child: Consumer<FavoritesProvider>(
                                builder: (context, fp, _) {
                                  final isFav = fp.isFavorite(recipe.id);
                                  return IconButton(
                                    icon: Icon(
                                      Icons.favorite_rounded,
                                      size: 24,
                                      color: isFav
                                          ? Colors.redAccent
                                          : AppColors.textTertiary(context),
                                    ),
                                    onPressed: () =>
                                        fp.toggleFavorite(recipe.id),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background(context), child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
