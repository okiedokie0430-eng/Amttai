import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/common/empty_state_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;

  final List<Map<String, dynamic>> _meals = [
    {
      'name': 'Өглөөний цай',
      'emoji': '🍳',
      'color': const Color(0xFFFFF0D4),
      'accent': const Color(0xFFFFD280),
    },
    {
      'name': 'Бранч',
      'emoji': '🥞',
      'color': const Color(0xFFFFE4E1),
      'accent': const Color(0xFFFFB3B3),
    },
    {
      'name': 'Өдрийн хоол',
      'emoji': '🥗',
      'color': const Color(0xFFE8F5E9),
      'accent': const Color(0xFFA5D6A7),
    },
    {
      'name': 'Оройн хоол',
      'emoji': '🥘',
      'color': const Color(0xFFE3F2FD),
      'accent': const Color(0xFF90CAF9),
    },
    {
      'name': 'Хөнгөн зууш',
      'emoji': '🥪',
      'color': const Color(0xFFFFF3E0),
      'accent': const Color(0xFFB3E5FC),
    },
    {
      'name': 'Амттан',
      'emoji': '🍰',
      'color': const Color(0xFFF3E5F5),
      'accent': const Color(0xFFCE93D8),
    },
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    context.read<RecipeProvider>().search(q);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RecipeProvider>();
    final textTheme = Theme.of(context).textTheme;
    final isSearching = _ctrl.text.isNotEmpty || _isFocused;

    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _ctrl.clear();
          _onChanged('');
          _focusNode.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: isSearching ? 40 : 0,
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              _onChanged('');
                              _focusNode.unfocus();
                            },
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textPrimary(context),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          onChanged: _onChanged,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _isFocused
                                ? AppColors.background(context)
                                : AppColors.surfaceVariant(
                                    context,
                                  ).withValues(alpha: 0.6),
                            hintText: 'Хайх...',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary(context),
                              fontSize: 16,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                left: 12.0,
                                right: 4.0,
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                color: _isFocused
                                    ? AppColors.primary
                                    : AppColors.textPrimary(context),
                                size: 22,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            suffixIcon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _ctrl.text.isNotEmpty
                                  ? GestureDetector(
                                      key: const ValueKey('clear_icon'),
                                      onTap: () {
                                        _ctrl.clear();
                                        _onChanged('');
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                          8,
                                          14,
                                          16,
                                          14,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.textTertiary(
                                            context,
                                          ).withValues(alpha: 0.2),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.black54,
                                          size: 14,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty_icon'),
                                    ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide(
                                color: AppColors.textTertiary(
                                  context,
                                ).withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: textTheme.bodyLarge,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {},
                      child: Icon(
                        Icons.tune_rounded,
                        color: AppColors.textPrimary(context),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                  child: isSearching
                      ? _searchResultsList(rp, textTheme)
                      : _exploreContent(textTheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exploreContent(TextTheme textTheme) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'Хоолны төрлөөр хайх',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              final meal = _meals[index];
              return Material(
                color: meal['color'],
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    _ctrl.text = meal['name'];
                    _onChanged(meal['name']);
                    _focusNode.unfocus();
                  },
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: meal['accent'],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Text(
                          meal['emoji'],
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          meal['name'],
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _searchResultsList(RecipeProvider rp, TextTheme textTheme) {
    if (rp.isLoading) {
      return Center(
        child: SizedBox(
          width: 140,
          height: 140,
          child: Lottie.asset(
            'assets/images/processing order.json',
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    if (rp.searchResults.isEmpty && _ctrl.text.isNotEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: S.noResults,
      );
    }
    if (_ctrl.text.isEmpty && rp.searchResults.isEmpty) {
      return Center(
        child: Text(
          'Түлхүүр үгээ оруулна уу',
          style: TextStyle(color: AppColors.textTertiary(context)),
        ),
      );
    }
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
      itemCount: rp.searchResults.length,
      itemBuilder: (_, i) {
        final recipe = rp.searchResults[i];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: AppColors.surfaceVariant(context),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/recipe/${recipe.id}?hero=search_'),
            child: SizedBox(
              height: 140,
              child: Row(
                children: [
                  Hero(
                    tag: 'search_recipe_image_${recipe.id}',
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
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '2 хүн',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.grey.withValues(
                                      alpha: 0.5,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: 12,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Монгол тогооч',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary(context),
                                      ),
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
                                  padding: const EdgeInsets.all(12),
                                  onPressed: () => fp.toggleFavorite(recipe.id),
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
    );
  }
}
