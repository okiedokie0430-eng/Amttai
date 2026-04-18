import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';
import 'widgets/add_ingredient_sheet.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<IngredientItem> _myIngredients = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddIngredients,
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Миний агуулах',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.textPrimary(context),
              dividerColor: AppColors.border(context).withValues(alpha: 0.2),
              tabs: const [
                Tab(text: 'Миний орцнууд'),
                Tab(text: 'Жорын санаанууд'),
              ],
            ),

            const SizedBox(height: 8),
            Divider(
              color: AppColors.border(context).withValues(alpha: 0.2),
              height: 1,
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _myIngredients.isEmpty
                      ? _buildEmptyState(
                          context,
                          textPrimary,
                          textSecondary,
                          'assets/images/Food animation.json',
                        )
                      : _buildIngredientsList(textPrimary),
                  _buildEmptyState(
                    context,
                    textPrimary,
                    textSecondary,
                    'assets/images/Recipes book animation.json',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsList(Color textPrimary) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
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
                  child: Center(
                    child: Text(
                      item.imageEmoji,
                      style: const TextStyle(fontSize: 48),
                    ),
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
    String lottieAsset,
  ) {
    return SingleChildScrollView(
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
            'Таны хүнсний агуулах хоосон байна.',
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
              'Эхний орцоо нэмээд эсвэл хамгийн түгээмэл хэрэглэгддэг орцуудыг нэмж хурдан эхлээрэй.',
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
