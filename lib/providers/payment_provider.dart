import 'package:flutter/foundation.dart';

import '../models/payment.dart';
import '../services/payment_service.dart';

/// Manages the payment / premium purchase flow.
class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  PremiumPlan? _selectedPlan;
  String? _transactionCode;
  Payment? _latestPayment;
  bool _isLoading = false;
  String? _error;
  int _currentStep = 0; // 0 = select, 1 = pay, 2 = confirm

  PremiumPlan? get selectedPlan => _selectedPlan;
  String? get transactionCode => _transactionCode;
  Payment? get latestPayment => _latestPayment;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentStep => _currentStep;

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
    _currentStep = 1;
    notifyListeners();
  }

  // ── Submit ─────────────────────────────────────────────
  Future<void> submitPayment({
    required String userId,
    required String transactionId,
  }) async {
    if (_selectedPlan == null || _transactionCode == null) return;
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
    _selectedPlan = null;
    _transactionCode = null;
    _latestPayment = null;
    _currentStep = 0;
    _error = null;
    notifyListeners();
  }
}
