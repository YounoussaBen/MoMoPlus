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
  String? _sessionId;
  bool _isSessionActive = false;
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  LoanViewModel(this._api, {bool autoStart = true}) {
    if (autoStart) {
      _startSession();
    }
  }

  List<Loan> get loans => _loans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSubmitting => _isSubmitting;
  bool get isSessionActive => _isSessionActive;

  List<Loan> get ongoingLoans => _loans.where((l) => l.isOngoing).toList();
  List<Loan> get historyLoans => _loans.where((l) => !l.isOngoing).toList();

  /// Switches this cache to [sessionId], clearing all data from the previous
  /// authenticated user before starting any requests for the new one.
  ///
  /// Passing `null` signs the view model out. Repeating the current non-null
  /// session is a no-op, which makes this safe to call from an auth listener.
  void setSession(String? sessionId) {
    if (sessionId == null) {
      clearSession();
      return;
    }
    if (_isSessionActive && _sessionId == sessionId) return;
    _startSession(sessionId: sessionId);
  }

  /// Stops requests and removes all user-scoped state immediately.
  ///
  /// The generation bump also invalidates requests that were already in
  /// flight, preventing a late response from restoring signed-out data.
  void clearSession() {
    if (_isDisposed) return;
    _resetSessionState();
    _notifyListeners();
  }

  /// Starts list refresh polling for the active session.
  void startAutoRefresh() {
    if (!_isSessionActive || _refreshTimer != null || _isDisposed) return;
    _refreshTimer = Timer.periodic(
      _loansRefreshInterval,
      (_) => unawaited(loadLoans()),
    );
  }

  /// Pauses list refresh polling without discarding the active session data.
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> loadLoans() async {
    if (!_isSessionActive || _isDisposed) return;
    final inFlight = _loadLoansFuture;
    if (inFlight != null) return inFlight;

    final generation = _sessionGeneration;
    final future = _loadLoansInternal(generation);
    _loadLoansFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_loadLoansFuture, future)) {
          _loadLoansFuture = null;
        }
      }),
    );
    return future;
  }

  Future<void> _loadLoansInternal(int generation) async {
    _isLoading = !_hasLoadedLoans && _loans.isEmpty;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.getLoans();
      if (!_isCurrentSession(generation)) return;
      _loans = data
          .map((e) => Loan.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentSession(generation)) {
        _hasLoadedLoans = true;
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<Loan?> requestLoan({
    required String agentId,
    required String amount,
    required String walletId,
    required String network,
  }) async {
    if (!_isSessionActive || _isDisposed) return null;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.requestLoan(
        agentId: agentId,
        amount: amount,
        walletId: walletId,
        network: network,
      );
      if (!_isCurrentSession(generation)) return null;
      final loan = Loan.fromJson(data);
      await loadLoans();
      if (!_isCurrentSession(generation)) return null;
      return loan;
    } catch (e) {
      if (!_isCurrentSession(generation)) return null;
      _errorMessage = friendlyErrorMessage(e);
      return null;
    } finally {
      if (_isCurrentSession(generation)) {
        _isSubmitting = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> acceptLoan(
    String loanId, {
    required String agentWalletId,
  }) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.acceptLoan(loanId, agentWalletId: agentWalletId);
      if (!_isCurrentSession(generation)) return false;
      await loadLoans();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isSubmitting = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> rejectLoan(String loanId, {String reason = ''}) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.rejectLoan(loanId, reason: reason);
      if (!_isCurrentSession(generation)) return false;
      await loadLoans();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isSubmitting = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> disburseLoan(String loanId) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.disburseLoan(loanId);
      if (!_isCurrentSession(generation)) return false;
      await loadLoans();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isSubmitting = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> repayLoan(String loanId, {String? amount}) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.repayLoan(loanId, amount: amount);
      if (!_isCurrentSession(generation)) return false;
      await loadLoans();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isSubmitting = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> cancelLoan(String loanId, {String reason = ''}) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.cancelLoan(loanId, reason: reason);
      if (!_isCurrentSession(generation)) return false;
      await loadLoans();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isSubmitting = false;
        _notifyListeners();
      }
    }
  }

  Future<Loan?> getLoanDetail(String loanId) async {
    if (!_isSessionActive || _isDisposed) return null;
    final generation = _sessionGeneration;
    _errorMessage = null;
    try {
      final data = await _api.getLoanDetail(loanId);
      if (!_isCurrentSession(generation) || data == null) return null;
      final loan = Loan.fromJson(data);
      _updateInList(loan);
      _notifyListeners();
      return loan;
    } catch (error) {
      if (!_isCurrentSession(generation)) return null;
      _errorMessage = friendlyErrorMessage(error);
      _notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    _notifyListeners();
  }

  void _updateInList(Loan updated) {
    final index = _loans.indexWhere((loan) => loan.id == updated.id);
    if (index >= 0) {
      _loans[index] = updated;
    } else {
      _loans.insert(0, updated);
    }
  }

  void _startSession({String? sessionId}) {
    _resetSessionState();
    _sessionId = sessionId;
    _isSessionActive = true;
    startAutoRefresh();
    unawaited(loadLoans());
  }

  void _resetSessionState() {
    stopAutoRefresh();
    _sessionGeneration++;
    _sessionId = null;
    _isSessionActive = false;
    _loadLoansFuture = null;
    _loans = [];
    _isLoading = false;
    _errorMessage = null;
    _isSubmitting = false;
    _hasLoadedLoans = false;
  }

  bool _isCurrentSession(int generation) =>
      !_isDisposed && _isSessionActive && generation == _sessionGeneration;

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _resetSessionState();
    _isDisposed = true;
    super.dispose();
  }
}
