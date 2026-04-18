import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../models/payment.dart';
import '../services/payment_service.dart';
import '../services/socialpay_service.dart';

/// Manages the payment / premium purchase flow.
class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService = PaymentService();
  final SocialPayService _socialPayService = const SocialPayService();

  PremiumPlan? _selectedPlan;
  String? _transactionCode;
  Payment? _latestPayment;
  String? _socialPayDeeplink;
  String? _socialPayDescription;
  bool _isSocialPayFlow = false;
  bool _isWatchdogActive = false;
  DateTime? _watchdogEndsAt;
  Timer? _watchdogTimer;
  bool _watchdogCheckRunning = false;
  bool _isLoading = false;
  String? _error;
  int _currentStep = 0; // 0 = select, 1 = pay, 2 = confirm

  PremiumPlan? get selectedPlan => _selectedPlan;
  String? get transactionCode => _transactionCode;
  Payment? get latestPayment => _latestPayment;
  String? get socialPayDeeplink => _socialPayDeeplink;
  String? get socialPayDescription => _socialPayDescription;
  bool get isSocialPayFlow => _isSocialPayFlow;
  bool get isWatchdogActive => _isWatchdogActive;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentStep => _currentStep;
  int get watchdogRemainingSeconds {
    final endsAt = _watchdogEndsAt;
    if (!_isWatchdogActive || endsAt == null) return 0;
    final seconds = endsAt.difference(DateTime.now()).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  // ── Step navigation ────────────────────────────────────
  void selectPlan(PremiumPlan plan) {
    _selectedPlan = plan;
    notifyListeners();
  }

  void goToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  /// Generate transaction code & advance to payment step.
  void preparePayment(String userName) {
    if (_selectedPlan == null) return;
    _transactionCode = _paymentService.generateTransactionCode(
      userName,
      _selectedPlan!,
    );
    _isSocialPayFlow = false;
    _socialPayDeeplink = null;
    _socialPayDescription = null;
    stopWatchdog(notify: false);
    _currentStep = 1;
    notifyListeners();
  }

  Future<void> startSocialPayCheckout({
    required String userId,
    required String userName,
  }) async {
    if (_selectedPlan == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final transactionCode = _paymentService.generateTransactionCode(
        userName,
        _selectedPlan!,
        prefix: 'SP',
      );
      final description = _paymentService.generateSocialPayDescription(
        transactionCode,
      );

      final pendingPayment = await _paymentService
          .createPendingSocialPayPayment(
            userId: userId,
            plan: _selectedPlan!,
            transactionCode: transactionCode,
          );

      final checkout = await _paymentService.createSocialPayCheckout(
        userId: userId,
        userName: userName,
        plan: _selectedPlan!,
        amountMnt: _selectedPlan!.priceMNT,
        transactionCode: transactionCode,
        description: description,
      );

      var payload = _socialPayService.buildFromDeeplink(
        deeplink: checkout.deeplink,
        description: checkout.description,
      );

      var launched = await _socialPayService.launch(payload.deeplink);
      if (!launched && AppConfig.socialPayAllowUnsafeDirectTemplate) {
        payload = _socialPayService.buildUnsafeTransferPayload(
          receiverAccount: AppConfig.bankAccountNumber,
          amountMnt: _selectedPlan!.priceMNT,
          description: description,
          transactionCode: transactionCode,
        );
        launched = await _socialPayService.launch(payload.deeplink);
      }

      if (!launched) {
        throw Exception(
          'SocialPay checkout нээгдсэнгүй. Merchant deeplink тохиргоогоо шалгана уу.',
        );
      }

      _transactionCode = transactionCode;
      _latestPayment = pendingPayment;
      _socialPayDescription = payload.description;
      _socialPayDeeplink = payload.deeplink.toString();
      _isSocialPayFlow = true;
      _currentStep = 1;
      _startWatchdog(userId: userId, transactionCode: transactionCode);
    } catch (e) {
      _error = _normalizeSocialPayError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _normalizeSocialPayError(Object error) {
    final message = error.toString();

    if (message.contains('did not return a deeplink or signed payload')) {
      return 'SocialPay-ийн гарын үсэгтэй payload буцаагдсангүй. Appwrite дээр socialpay-create-checkout function-оо шалгана уу.';
    }
    if (message.contains('Function with the requested ID could not be found')) {
      return 'Appwrite дээр socialpay-create-checkout function олдсонгүй. Function ID-гаа SOCIALPAY_CHECKOUT_FUNCTION_ID дээр тохируулна уу.';
    }
    if (message.contains('X-GOLOMT-CHECKSUM') ||
        message.contains('Invalid checksum')) {
      return 'SocialPay checksum буруу байна. Merchant API secret болон request body формат таарах ёстой.';
    }

    return message;
  }

  Future<bool> reopenSocialPay() async {
    final deeplink = _socialPayDeeplink;
    if (deeplink == null || deeplink.isEmpty) return false;
    final ok = await _socialPayService.launch(Uri.parse(deeplink));
    if (!ok) {
      _error = 'SocialPay апп нээгдсэнгүй.';
      notifyListeners();
    }
    return ok;
  }

  Future<void> checkSocialPayStatus(String userId) async {
    final txCode = _transactionCode;
    if (txCode == null || txCode.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _refreshSocialPayPayment(
        userId: userId,
        transactionCode: txCode,
        moveToConfirmation: true,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startWatchdog({
    required String userId,
    required String transactionCode,
  }) {
    stopWatchdog(notify: false);

    final timeoutSeconds = AppConfig.socialPayWatchdogTimeoutSeconds
        .clamp(30, 3600)
        .toInt();
    final pollSeconds = AppConfig.socialPayWatchdogPollSeconds
        .clamp(2, 60)
        .toInt();

    _isWatchdogActive = true;
    _watchdogEndsAt = DateTime.now().add(Duration(seconds: timeoutSeconds));
    _watchdogTimer = Timer.periodic(Duration(seconds: pollSeconds), (_) async {
      if (_watchdogCheckRunning) return;

      final endsAt = _watchdogEndsAt;
      if (endsAt != null && DateTime.now().isAfter(endsAt)) {
        _error =
            'Шилжүүлгийн автомат шалгалтын хугацаа дууслаа. Доорх "Одоо шалгах" товчийг дарна уу.';
        stopWatchdog(notify: false);
        notifyListeners();
        return;
      }

      _watchdogCheckRunning = true;
      try {
        await _refreshSocialPayPayment(
          userId: userId,
          transactionCode: transactionCode,
          moveToConfirmation: true,
        );
      } catch (_) {
        // Ignore temporary polling errors and continue watching.
      } finally {
        _watchdogCheckRunning = false;
        notifyListeners();
      }
    });
  }

  void stopWatchdog({bool notify = true}) {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _isWatchdogActive = false;
    _watchdogEndsAt = null;
    _watchdogCheckRunning = false;
    if (notify) notifyListeners();
  }

  Future<void> _refreshSocialPayPayment({
    required String userId,
    required String transactionCode,
    required bool moveToConfirmation,
  }) async {
    final payment = await _paymentService.getPaymentByTransactionCode(
      userId: userId,
      transactionCode: transactionCode,
    );

    if (payment == null) return;

    _latestPayment = payment;
    if (payment.status != PaymentStatus.pending) {
      stopWatchdog(notify: false);
      if (moveToConfirmation) {
        _currentStep = 2;
      }
    }
  }

  // ── Submit ─────────────────────────────────────────────
  Future<void> submitPayment({
    required String userId,
    required String transactionId,
  }) async {
    if (_selectedPlan == null || _transactionCode == null) return;
    stopWatchdog(notify: false);
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _latestPayment = await _paymentService.submitPayment(
        userId: userId,
        plan: _selectedPlan!,
        transactionCode: _transactionCode!,
        transactionId: transactionId,
      );
      _currentStep = 2;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Status check ───────────────────────────────────────
  Future<void> checkPaymentStatus(String userId) async {
    _latestPayment = await _paymentService.getLatestPayment(userId);
    notifyListeners();
  }

  // ── Reset ──────────────────────────────────────────────
  void reset() {
    stopWatchdog(notify: false);
    _selectedPlan = null;
    _transactionCode = null;
    _latestPayment = null;
    _socialPayDeeplink = null;
    _socialPayDescription = null;
    _isSocialPayFlow = false;
    _currentStep = 0;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopWatchdog(notify: false);
    super.dispose();
  }
}
