import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_colors.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 0;

  final List<Map<String, dynamic>> _plans = [
    {
      'title': '1 Сар',
      'price': '6,000 ₮',
      'sub': 'Сард',
    },
    {
      'title': '3 Сар',
      'price': '15,000 ₮',
      'sub': 'Улиралд',
    },
    {
      'title': '1 Жил',
      'price': '38,000 ₮',
      'sub': 'Жилд',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.background(context);
    final textColor = AppColors.textPrimary(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 16.0, bottom: 4.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, size: 26, color: textColor),
                  onPressed: () => context.pop(),
                ),
              ),
            ),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: textColor,
                      ),
                      children: [
                        TextSpan(
                          text: 'ПРЕМИУМ ',
                          style: TextStyle(color: AppColors.primary),
                        ),
                        const TextSpan(text: 'АВЧ,\n'),
                        const TextSpan(text: 'ХЯЗГААРГҮЙ ЖОРОО\n'),
                        const TextSpan(text: 'ИДЭВХЖҮҮЛЭЭРЭЙ'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // Middle Animation and Descriptive Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Lottie.asset(
                        'assets/images/Gradient Diamond.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Премиум эрхтэйгээр та бүх жор болон шинээр нэмэгдэх жоруудыг үзэх боломжтой. Цаашид премиумын олон шинэ боломжууд нэмэгдэнэ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Plan Selectors
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: List.generate(_plans.length, (index) {
                  final plan = _plans[index];
                  final isSelected = _selectedPlanIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPlanIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(
                          left: index == 0 ? 0 : 6,
                          right: index == _plans.length - 1 ? 0 : 6,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary.withValues(alpha: 0.05) 
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border(context),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              plan['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan['price'],
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? AppColors.primary : AppColors.textSecondary(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Main Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GestureDetector(
                onTap: () {
                  context.push('/payment');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Одоо идэвхжүүлэх',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Нийт  / ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
