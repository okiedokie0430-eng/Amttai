import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _txIdCtrl = TextEditingController();
  int _paymentMethod = 0; // 0 = bank transfer, 1 = social pay

  @override
  void dispose() {
    _txIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PaymentProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (pp.currentStep > 0 && pp.currentStep < 2) {
              pp.goToStep(pp.currentStep - 1);
            } else {
              pp.reset();
              Navigator.pop(context);
            }
          },
        ),
        title: Text(S.premiumTitle, style: textTheme.titleLarge),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: pp.currentStep,
          children: [
            _planSelection(pp, textTheme),
            _paymentInstructions(pp, textTheme),
            _confirmation(pp, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _planSelection(PaymentProvider pp, TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.premiumSubtitle,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          ...PremiumPlan.values.map((plan) => _planCard(plan, pp, textTheme)),
          const SizedBox(height: 16),

          // Payment method selector
          Text(
            'Төлбөрийн арга',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _methodChip(
                  icon: Icons.account_balance_outlined,
                  label: 'Банк шилжүүлэг',
                  selected: _paymentMethod == 0,
                  onTap: () => setState(() => _paymentMethod = 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _methodChip(
                  icon: Icons.phone_android_rounded,
                  label: 'SocialPay',
                  selected: _paymentMethod == 1,
                  onTap: () => setState(() => _paymentMethod = 1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pp.selectedPlan == null || pp.isLoading
                  ? null
                  : () async {
                      if (_paymentMethod == 1) {
                        await _startSocialPay(pp);
                      } else {
                        // Bank transfer
                        final name =
                            context.read<AuthProvider>().user?.name ?? 'USER';
                        pp.preparePayment(name);
                      }
                    },
              child: pp.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_paymentMethod == 1 ? 'SocialPay-ээр төлөх' : S.next),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceVariant(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border(context),
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary(context),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.primary
                    : AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSocialPay(PaymentProvider pp) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      _showSnack(S.authError);
      return;
    }

    await pp.startSocialPayCheckout(userId: user.id, userName: user.name);

    if (!mounted) return;
    final error = pp.error;
    if (error != null && error.isNotEmpty) {
      _showSnack(error.replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _planCard(PremiumPlan plan, PaymentProvider pp, TextTheme textTheme) {
    final selected = pp.selectedPlan == plan;
    return GestureDetector(
      onTap: () => pp.selectPlan(plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.07)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border(context),
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.label,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMNT(plan.priceMNT),
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textTertiary(context),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentInstructions(PaymentProvider pp, TextTheme textTheme) {
    final plan = pp.selectedPlan;
    if (plan == null) {
      return const Center(child: Text('Багц сонгоно уу'));
    }

    if (pp.isSocialPayFlow) {
      return _socialPayInstructions(pp, textTheme, plan);
    }

    return _bankTransferInstructions(pp, textTheme, plan);
  }

  Widget _bankTransferInstructions(
    PaymentProvider pp,
    TextTheme textTheme,
    PremiumPlan plan,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.paymentInstructions,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.paymentStep1,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow('Банк', AppConfig.bankName),
                _infoRow('Дансны дугаар', AppConfig.bankAccountNumber),
                _infoRow('Дансны нэр', AppConfig.bankAccountHolder),
                _infoRow('Дүн', _formatMNT(plan.priceMNT)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            S.paymentStep2,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pp.transactionCode ?? '',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: pp.transactionCode ?? ''),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(S.copied),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            S.paymentStep3,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _txIdCtrl,
            decoration: InputDecoration(
              hintText: S.transactionIdHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pp.isLoading
                  ? null
                  : () async {
                      final txId = _txIdCtrl.text.trim();
                      if (txId.isEmpty) {
                        _showSnack(S.requiredField);
                        return;
                      }

                      final userId =
                          context.read<AuthProvider>().user?.id ?? '';
                      await pp.submitPayment(
                        userId: userId,
                        transactionId: txId,
                      );

                      if (!mounted) return;
                      final error = pp.error;
                      if (error != null && error.isNotEmpty) {
                        _showSnack(error.replaceFirst('Exception: ', ''));
                      }
                    },
              child: pp.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(S.submitPayment),
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialPayInstructions(
    PaymentProvider pp,
    TextTheme textTheme,
    PremiumPlan plan,
  ) {
    final status = pp.latestPayment?.status ?? PaymentStatus.pending;
    final isApproved = status == PaymentStatus.approved;
    final isRejected = status == PaymentStatus.rejected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SocialPay төлбөр',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'SocialPay апп руу автоматаар шилжиж, мөнгөн дүн болон гүйлгээний утга бөглөгдөнө.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Банк', AppConfig.bankName),
                _infoRow('Дансны дугаар', AppConfig.bankAccountNumber),
                _infoRow('Дансны нэр', AppConfig.bankAccountHolder),
                _infoRow('Дүн', _formatMNT(plan.priceMNT)),
                _infoRow('Гүйлгээний утга', pp.socialPayDescription ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () async {
                final opened = await pp.reopenSocialPay();
                if (!mounted || opened) return;
                _showSnack('SocialPay апп нээгдсэнгүй.');
              },
              label: const Text('SocialPay нээх'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isApproved
                  ? AppColors.success.withValues(alpha: 0.12)
                  : isRejected
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApproved
                      ? 'Төлбөр амжилттай баталгаажсан'
                      : isRejected
                      ? 'Төлбөр татгалзсан байна'
                      : 'Төлбөрийн төлөв шалгаж байна',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isApproved
                        ? AppColors.success
                        : isRejected
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pp.isWatchdogActive
                      ? 'Автомат хяналт идэвхтэй: ${_watchdogLabel(pp.watchdogRemainingSeconds)}'
                      : 'Автомат хяналт зогссон. Доорх товчоор гараар шалгана уу.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (pp.error != null && pp.error!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              pp.error!.replaceFirst('Exception: ', ''),
              style: textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: pp.isLoading
                  ? null
                  : () async {
                      final userId = context.read<AuthProvider>().user?.id;
                      if (userId == null) {
                        _showSnack(S.authError);
                        return;
                      }

                      await pp.checkSocialPayStatus(userId);
                      if (!mounted) return;
                      final error = pp.error;
                      if (error != null && error.isNotEmpty) {
                        _showSnack(error.replaceFirst('Exception: ', ''));
                      }
                    },
              child: pp.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Одоо шалгах'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Код: ${pp.transactionCode ?? '-'}',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  String _watchdogLabel(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    final secStr = sec < 10 ? '0$sec' : '$sec';
    return '$min:$secStr';
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary(context),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _confirmation(PaymentProvider pp, TextTheme textTheme) {
    final status = pp.latestPayment?.status;
    final success = status == PaymentStatus.approved;
    final rejected = status == PaymentStatus.rejected;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : rejected
                  ? Icons.cancel_rounded
                  : Icons.hourglass_top_rounded,
              size: 72,
              color: success
                  ? AppColors.success
                  : rejected
                  ? AppColors.error
                  : AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              success
                  ? S.paymentSuccess
                  : rejected
                  ? S.paymentFailed
                  : S.paymentPending,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              success
                  ? 'Таны премиум эрх идэвхжлээ!'
                  : rejected
                  ? 'Төлбөрийн баталгаажуулалт амжилтгүй боллоо. Дахин оролдоно уу.'
                  : 'Таны төлбөр админ-аар баталгаажих болно. Та хэсэг хүлээнэ үү.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (success) {
                    try {
                      await context.read<AuthProvider>().refreshProfile();
                    } catch (_) {
                      // Payment is already approved; closing flow is still allowed.
                    }
                  }
                  if (!mounted) return;
                  pp.reset();
                  Navigator.pop(context);
                },
                child: const Text(S.done),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMNT(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
