import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../domain/loan.dart';

const Duration _loansRefreshInterval = Duration(seconds: 10);

class LoanViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<Loan> _loans = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _hasLoadedLoans = false;
  Timer? _refreshTimer;
  Future<void>? _loadLoansFuture;

  LoanViewModel(this._api) {
    loadLoans();
    _refreshTimer = Timer.periodic(_loansRefreshInterval, (_) => loadLoans());
  }

  List<Loan> get loans => _loans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSubmitting => _isSubmitting;

  List<Loan> get ongoingLoans => _loans.where((l) => l.isOngoing).toList();
  List<Loan> get historyLoans => _loans.where((l) => !l.isOngoing).toList();

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadLoans() async {
    final inFlight = _loadLoansFuture;
    if (inFlight != null) return inFlight;

    final future = _loadLoansInternal();
    _loadLoansFuture = future;
    future.whenComplete(() => _loadLoansFuture = null);
    return future;
  }

  Future<void> _loadLoansInternal() async {
    _isLoading = !_hasLoadedLoans && _loans.isEmpty;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getLoans();
      _loans = data
          .map((e) => Loan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _hasLoadedLoans = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Loan?> requestLoan({
    required String agentId,
    required String amount,
    required String walletId,
    required String network,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.requestLoan(
        agentId: agentId,
        amount: amount,
        walletId: walletId,
        network: network,
      );
      final loan = Loan.fromJson(data);
      await loadLoans();
      return loan;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> acceptLoan(
    String loanId, {
    required String agentWalletId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.acceptLoan(loanId, agentWalletId: agentWalletId);
      await loadLoans();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> rejectLoan(String loanId, {String reason = ''}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.rejectLoan(loanId, reason: reason);
      await loadLoans();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> disburseLoan(String loanId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.disburseLoan(loanId);
      await loadLoans();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> repayLoan(String loanId, {String? amount}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.repayLoan(loanId, amount: amount);
      await loadLoans();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> cancelLoan(String loanId, {String reason = ''}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.cancelLoan(loanId, reason: reason);
      await loadLoans();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<Loan?> getLoanDetail(String loanId) async {
    try {
      final data = await _api.getLoanDetail(loanId);
      if (data == null) return null;
      final loan = Loan.fromJson(data);
      _updateInList(loan);
      notifyListeners();
      return loan;
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _updateInList(Loan updated) {
    final index = _loans.indexWhere((loan) => loan.id == updated.id);
    if (index >= 0) {
      _loans[index] = updated;
    } else {
      _loans.insert(0, updated);
    }
  }
}
