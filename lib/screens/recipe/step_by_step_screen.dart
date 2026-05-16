import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';

class StepByStepScreen extends StatefulWidget {
  final Recipe recipe;

  const StepByStepScreen({
    super.key,
    required this.recipe,
  });

  @override
  State<StepByStepScreen> createState() => _StepByStepScreenState();
}

class _StepByStepScreenState extends State<StepByStepScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("mn-MN"); // Mongolian
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Play first step immediately if possible
    if (widget.recipe.steps.isNotEmpty) {
      _speak(widget.recipe.steps.first.description);
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    if (text.trim().isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _speak(widget.recipe.steps[index].description);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.recipe.steps;
    if (steps.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: const Text('Steps')),
        body: const Center(child: Text('No steps available')),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Step ${_currentIndex + 1} of ${steps.length}',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _currentIndex > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                onPressed: _currentIndex < steps.length - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / steps.length,
            backgroundColor: AppColors.surfaceVariant(context),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 2,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: steps.length,
        itemBuilder: (context, index) {
          final step = steps[index];
          return _buildStepPage(step, textTheme);
        },
      ),
    );
  }

  Widget _buildStepPage(RecipeStep step, TextTheme textTheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((step.imageUrl ?? '').trim().isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: step.imageUrl!.trim(),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceVariant(context),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: MediaQuery.of(context).size.width,
              color: AppColors.surfaceVariant(context),
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined, size: 48),
            ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              step.description,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),

          if (step.ingredients != null && step.ingredients!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...step.ingredients!.map((ing) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.2), // Toned down primary
                      ),
                      // Ideally image of ingredient goes here
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${ing.name}${ing.amount.isNotEmpty ? " (${ing.amount} ${ing.unit ?? ''})" : ""}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            // MOCK INGREDIENTS FOR VISUAL IF NOT AVAILABLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary(context),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No specific ingredients tied to this step yet.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
