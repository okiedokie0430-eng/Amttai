import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/premium_recipe_access.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/common/appwrite_image.dart';
import 'widgets/add_ingredient_sheet.dart';

class _RecipeMatchResult {
  final Recipe recipe;
  final List<String> matchedIngredients;
  final List<String> missingIngredients;

  const _RecipeMatchResult({
    required this.recipe,
    required this.matchedIngredients,
    required this.missingIngredients,
  });

  int get matchedCount => matchedIngredients.length;
  int get totalCount => matchedIngredients.length + missingIngredients.length;
  int get missingCount => missingIngredients.length;
  bool get canCook => totalCount > 0 && missingIngredients.isEmpty;
  double get coverage => totalCount == 0 ? 0 : matchedCount / totalCount;
}

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<IngredientItem> _myIngredients = [];
  final Map<String, List<_RecipeMatchResult>> _matchesCache = {};

  static const Map<String, String> _ingredientAliases = {
    // Mongolian aliases for recipe ingredient matching
    'үхрийн мах': 'beef',
    'үхрийн': 'beef',
    'beef': 'beef',

    'хонины мах': 'mutton',
    'бүтэн хонь': 'mutton',
    'mutton': 'mutton',
    'lamb': 'mutton',

    'тахианы мах': 'chicken',
    'chicken': 'chicken',

    'гахайн мах': 'pork',
    'pork': 'pork',

    'сонгино': 'onion',
    'onion': 'onion',
    'сармис': 'garlic',
    'garlic': 'garlic',

    'гурил': 'flour',
    'flour': 'flour',
    'давс': 'salt',
    'salt': 'salt',
    'элсэн чихэр': 'sugar',
    'чихэр': 'sugar',
    'sugar': 'sugar',

    'сүү': 'milk',
    'milk': 'milk',
    'өндөг': 'egg',
    'egg': 'egg',
    'бяслаг': 'cheese',
    'cheese': 'cheese',

    'улаан лооль': 'tomato',
    'tomato': 'tomato',
    'лууван': 'carrot',
    'carrot': 'carrot',
    'брокколи': 'broccoli',
    'broccoli': 'broccoli',
    'төмс': 'potato',
    'potato': 'potato',
    'байцаа': 'cabbage',
    'cabbage': 'cabbage',
    'өргөст хэмх': 'cucumber',
    'cucumber': 'cucumber',

    'ус': 'water',
    'water': 'water',
    'хар цай': 'tea',
    'цай': 'tea',
    'tea leaves': 'tea',
    'tea': 'tea',

    'чидун тос': 'olive oil',
    'оливын тос': 'olive oil',
    'olive oil': 'olive oil',
    'луулин тос': 'oil',
    'тос шарахад': 'oil',
    'тос': 'oil',
    'oil': 'oil',

    'цөцгийн тос': 'butter',
    'шар тос': 'butter',
    'butter': 'butter',

    'хүнсний ногоо': 'vegetables',
    'ногоо': 'vegetables',
    'vegetables': 'vegetables',

    'халуун чулуу': 'hot stones',
    'hot stones': 'hot stones',
  };

  static const List<String> _stopWords = [
    'cup', 'cups', 'tbsp', 'tsp', 'tablespoon', 'teaspoon',
    'piece', 'pieces', 'slice', 'slices', 'small', 'large', 'medium',
    'fresh', 'dried', 'can', 'package', 'oz', 'lb', 'gram', 'kg',
    'мл', 'г', 'кг', 'ш', 'шүүс', 'хутга', 'хутганы', 'хутгатай',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final recipeProvider = context.read<RecipeProvider>();
      if (!recipeProvider.isLoading && recipeProvider.recipes.isEmpty) {
        recipeProvider.loadRecipes();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddIngredients() async {
    final result = await Navigator.of(context, rootNavigator: false)
        .push<List<IngredientItem>>(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AddIngredientScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final tween = Tween(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );

    if (result != null && result.isNotEmpty) {
      setState(() {
        for (final item in result) {
          if (!_myIngredients.any((e) => e.id == item.id)) {
            _myIngredients.add(item);
          }
        }
      });
    }
  }

  String _normalizeIngredient(String raw) {
    var value = raw.toLowerCase().trim();
    value = value.replaceAll(RegExp(r'[\(\)\[\],./:_-]'), ' ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove stop words
    for (final stopWord in _stopWords) {
      value = value.replaceAll(RegExp('\\b$stopWord\\b'), ' ');
    }
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  String _canonicalIngredient(String raw) {
    final normalized = _normalizeIngredient(raw);
    if (normalized.isEmpty) {
      return normalized;
    }

    for (final entry in _ingredientAliases.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return normalized;
  }

  Set<String> _tokenizeIngredient(String raw) {
    final canonical = _canonicalIngredient(raw);
    if (canonical.isEmpty) return {};
    
    // Keep multi-word phrases intact (e.g., "chicken breast")
    final phrases = <String>{};
    final parts = canonical.split(' ').where((part) => part.length >= 2).toList();
    
    // Add 2-word phrases
    for (int i = 0; i < parts.length - 1; i++) {
      final phrase = '${parts[i]} ${parts[i + 1]}';
      if (phrase.length >= 4) {
        phrases.add(phrase);
      }
    }
    // Add single words
    phrases.addAll(parts);
    
    return phrases;
  }

  bool _isIngredientCovered({
    required String requiredIngredient,
    required Set<String> pantryNormalized,
    required Set<String> pantryTokens,
  }) {
    final required = _canonicalIngredient(requiredIngredient);
    if (required.isEmpty) {
      return false;
    }
  
    // Exact match is always best
    if (pantryNormalized.contains(required)) {
      return true;
    }
  
    // Check for substring matches (only if both are long enough to avoid false positives)
    for (final pantryValue in pantryNormalized) {
      if (pantryValue.isEmpty) {
        continue;
      }
      final isSubstringMatch = pantryValue.contains(required) || required.contains(pantryValue);
      if (isSubstringMatch && required.length >= 4 && pantryValue.length >= 4) {
        // Avoid false matches like "egg" matching "vegetable"
        if (required.length <= 3 || pantryValue.length <= 3) {
          continue;
        }
        return true;
      }
    }
  
    // Token-based matching
    final requiredTokens = _tokenizeIngredient(required);
    if (requiredTokens.isEmpty) {
      return false;
    }
  
    // Special cases
    if (requiredTokens.contains('oil') && pantryTokens.contains('oil')) {
      return true;
    }
  
    // For short ingredients (1-2 tokens), require at least one token match
    if (requiredTokens.length <= 2) {
      return requiredTokens.any((token) => pantryTokens.contains(token));
    }
  
    // For longer ingredients, require at least 2 token matches
    final overlapCount = requiredTokens.where(pantryTokens.contains).length;
    return overlapCount >= 2;
  }

  List<_RecipeMatchResult> _buildRecipeMatches(List<Recipe> recipes) {
    if (_myIngredients.isEmpty || recipes.isEmpty) {
      return const [];
    }
  
    final pantryNormalized = _myIngredients
        .map((item) => _canonicalIngredient(item.name))
        .where((name) => name.isNotEmpty)
        .toSet();

    final pantryTokens = pantryNormalized
        .expand((name) => _tokenizeIngredient(name))
        .toSet();

    final results = <_RecipeMatchResult>[];

    for (final recipe in recipes) {
      if (recipe.ingredients.isEmpty) {
        continue;
      }

      final matched = <String>[];
      final missing = <String>[];

      for (final ingredient in recipe.ingredients) {
        final ingredientName = ingredient.name.trim();
        if (ingredientName.isEmpty) {
          continue;
        }

        final covered = _isIngredientCovered(
          requiredIngredient: ingredientName,
          pantryNormalized: pantryNormalized,
          pantryTokens: pantryTokens,
        );

        if (covered) {
          matched.add(ingredientName);
        } else {
          missing.add(ingredientName);
        }
      }

      final consideredCount = matched.length + missing.length;
      if (consideredCount == 0) {
        continue;
      }

      results.add(
        _RecipeMatchResult(
          recipe: recipe,
          matchedIngredients: matched,
          missingIngredients: missing,
        ),
      );
    }

    // Generate cache key
    final cacheKey = '${_myIngredients.map((i) => i.name).join('|')}||${recipes.map((r) => r.id).join('|')}';

    // Return cached result if available
    if (_matchesCache.containsKey(cacheKey)) {
      return _matchesCache[cacheKey]!;
    }

    // Cache the result
    _matchesCache[cacheKey] = results;
    return results;
  }

  Widget _buildRecipeIdeasTab({
    required RecipeProvider recipeProvider,
    required List<_RecipeMatchResult> readyMatches,
    required List<_RecipeMatchResult> nearMatches,
    required Color textPrimary,
    required Color textSecondary,
    required double bottomPadding,
  }) {
    if (_myIngredients.isEmpty) {
      return _buildEmptyState(
        context,
        textPrimary,
        textSecondary,
        'assets/images/Recipes book animation.json',
        bottomPadding: bottomPadding,
        title: 'Add ingredients to your pantry first.',
        description:
            'After adding your ingredients, recipes you can make will appear here.',
      );
    }

    if (recipeProvider.isLoading && recipeProvider.recipes.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (readyMatches.isEmpty && nearMatches.isEmpty) {
      return _buildEmptyState(
        context,
        textPrimary,
        textSecondary,
        'assets/images/Recipes book animation.json',
        bottomPadding: bottomPadding,
        title: 'No matching recipes found.',
        description: 'Try adding more ingredients to get more recipe suggestions.',
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      children: [
        if (readyMatches.isNotEmpty) ...[
          Text(
            'Recipes you can make right now',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${readyMatches.length} recipes fully matched',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...readyMatches.map(
            (match) => _buildRecipeMatchCard(
              match: match,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ),
        ] else ...[
          Text(
            'No recipes you can make right now.',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'But there are some close matches. Pick one below and add the missing ingredients.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (nearMatches.isNotEmpty) ...[
          if (readyMatches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Almost ready recipes',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          ...nearMatches
              .take(10)
              .map(
                (match) => _buildRecipeMatchCard(
                  match: match,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildRecipeMatchCard({
    required _RecipeMatchResult match,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final recipe = match.recipe;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: match.canCook
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border(context),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openRecipeWithPremiumGuard(
            context: context,
            recipe: recipe,
            heroPrefix: 'pantry_',
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child:
                        recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                        ? AppwriteImage(
                            imageUrl: recipe.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.surface(context),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${match.matchedCount}/${match.totalCount} ingredients matched',
                        style: TextStyle(
                          color: match.canCook
                              ? AppColors.primary
                              : textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!match.canCook) ...[
                        const SizedBox(height: 4),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final allMissing = match.missingIngredients.join(', ');
                            final textSpan = TextSpan(
                              text: 'Missing: ',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: allMissing,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                            final textPainter = TextPainter(
                              text: textSpan,
                              maxLines: 1,
                              textDirection: TextDirection.ltr,
                            )..layout();
                            if (textPainter.width <= constraints.maxWidth) {
                              return Text.rich(
                                textSpan,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            } else {
                              return SizedBox(
                                height: 20,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: match.missingIngredients.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                                  itemBuilder: (context, index) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        match.missingIngredients[index],
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.background(context)
        : Colors.white;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scale = (screenWidth / 375.0).clamp(0.85, 1.15).toDouble();
    final bottomNavClearance = (56.0 + 20.0 + 8.0) * scale + 16.0;
    final recipeProvider = context.watch<RecipeProvider>();

    final allMatches = _buildRecipeMatches(recipeProvider.recipes);
    final readyMatches = allMatches.where((match) => match.canCook).toList()
      ..sort((a, b) {
        final byIngredients = b.totalCount.compareTo(a.totalCount);
        if (byIngredients != 0) {
          return byIngredients;
        }
        return a.recipe.title.compareTo(b.recipe.title);
      });

    final nearMatches =
        allMatches
            .where((match) => !match.canCook && match.matchedCount > 0)
            .toList()
          ..sort((a, b) {
            final byCoverage = b.coverage.compareTo(a.coverage);
            if (byCoverage != 0) {
              return byCoverage > 0 ? 1 : -1;
            }

            final byMissing = a.missingCount.compareTo(b.missingCount);
            if (byMissing != 0) {
              return byMissing;
            }

            return a.recipe.title.compareTo(b.recipe.title);
          });

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: EdgeInsets.only(bottom: bottomNavClearance),
            child: FloatingActionButton(
              heroTag: 'addIngredient',
              onPressed: _openAddIngredients,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded, size: 32),
            ),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Pantry',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabController,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: textPrimary,
                unselectedLabelColor: textSecondary,
                labelPadding: EdgeInsets.zero,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('My Ingredients'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_myIngredients.length}',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Recipe Ideas'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${readyMatches.length}',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(
              color: AppColors.border(context).withValues(alpha: 0.2),
              height: 1,
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _myIngredients.isEmpty
                      ? _buildEmptyState(
                          context,
                          textPrimary,
                          textSecondary,
                          'assets/images/Food animation.json',
                          bottomPadding: bottomNavClearance,
                        )
                      : _buildIngredientsList(
                          textPrimary,
                          bottomPadding: bottomNavClearance,
                        ),
                  _buildRecipeIdeasTab(
                    recipeProvider: recipeProvider,
                    readyMatches: readyMatches,
                    nearMatches: nearMatches,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    bottomPadding: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsList(Color textPrimary, {required double bottomPadding}) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _myIngredients.length,
      itemBuilder: (context, index) {
        final item = _myIngredients[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.surfaceVariant(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          item.imageEmoji,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _myIngredients.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    String lottieAsset, {
    double bottomPadding = 0,
    String title = 'Your pantry is empty.',
    String description =
        'Add your first ingredient or quickly add commonly used ingredients to get started.',
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        children: [
          const SizedBox(height: 40),
          SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Lottie.asset(
                lottieAsset,
                fit: BoxFit.contain,
                repeat: false,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
