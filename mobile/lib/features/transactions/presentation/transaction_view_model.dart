import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../../wallet/domain/wallet.dart';
import '../domain/physical_transaction.dart';

const Duration _transactionsRefreshInterval = Duration(seconds: 10);

class TransactionViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<PhysicalTransaction> _transactions = [];
  PhysicalTransaction? _currentTransaction;
  List<Wallet> _wallets = [];
  bool _isLoading = false;
  bool _isLoadingWallets = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _hasLoadedTransactions = false;
  Timer? _pollTimer;
  Timer? _refreshTimer;
  Future<void>? _loadTransactionsFuture;
  Future<void>? _loadWalletsFuture;
  String? _sessionId;
  bool _isSessionActive = false;
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  TransactionViewModel(this._api, {bool autoStart = true}) {
    if (autoStart) {
      _startSession();
    }
  }

  List<PhysicalTransaction> get transactions => _transactions;
  PhysicalTransaction? get currentTransaction => _currentTransaction;
  List<Wallet> get wallets => _wallets;
  List<Wallet> get verifiedWallets =>
      _wallets.where((w) => w.isVerified).toList();
  bool get isLoading => _isLoading;
  bool get isLoadingWallets => _isLoadingWallets;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get isSessionActive => _isSessionActive;

  List<PhysicalTransaction> get activeTransactions =>
      _transactions.where((t) => t.isActive).toList();
  List<PhysicalTransaction> get completedTransactions =>
      _transactions.where((t) => !t.isActive).toList();

  /// Switches the cache to an authenticated user, invalidating all work and
  /// data associated with the previous user before loading the new session.
  void setSession(String? sessionId) {
    if (sessionId == null) {
      clearSession();
      return;
    }
    if (_isSessionActive && _sessionId == sessionId) return;
    _startSession(sessionId: sessionId);
  }

  /// Stops polling and removes every piece of user-scoped state immediately.
  void clearSession() {
    if (_isDisposed) return;
    _resetSessionState();
    _notifyListeners();
  }

  /// Starts background refresh of the transaction list for the active session.
  void startAutoRefresh() {
    if (!_isSessionActive || _refreshTimer != null || _isDisposed) return;
    _refreshTimer = Timer.periodic(
      _transactionsRefreshInterval,
      (_) => unawaited(loadTransactions()),
    );
  }

  /// Pauses transaction-list refresh without clearing cached session data.
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> loadTransactions() async {
    if (!_isSessionActive || _isDisposed) return;
    final inFlight = _loadTransactionsFuture;
    if (inFlight != null) return inFlight;

    final generation = _sessionGeneration;
    final future = _loadTransactionsInternal(generation);
    _loadTransactionsFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_loadTransactionsFuture, future)) {
          _loadTransactionsFuture = null;
        }
      }),
    );
    return future;
  }

  Future<void> _loadTransactionsInternal(int generation) async {
    _isLoading = !_hasLoadedTransactions && _transactions.isEmpty;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.getPhysicalTransactions();
      if (!_isCurrentSession(generation)) return;
      _transactions = data
          .map((e) => PhysicalTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_currentTransaction != null) {
        for (final txn in _transactions) {
          if (txn.id == _currentTransaction!.id) {
            _currentTransaction = txn;
            break;
          }
        }
      }
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentSession(generation)) {
        _hasLoadedTransactions = true;
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<void> loadWallets() async {
    if (!_isSessionActive || _isDisposed) return;
    final inFlight = _loadWalletsFuture;
    if (inFlight != null) return inFlight;

    final generation = _sessionGeneration;
    final future = _loadWalletsInternal(generation);
    _loadWalletsFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_loadWalletsFuture, future)) {
          _loadWalletsFuture = null;
        }
      }),
    );
    return future;
  }

  Future<void> _loadWalletsInternal(int generation) async {
    _isLoadingWallets = true;
    _notifyListeners();
    try {
      final data = await _api.getWallets();
      if (!_isCurrentSession(generation)) return;
      _wallets = data
          .map((e) => Wallet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentSession(generation)) {
        _isLoadingWallets = false;
        _notifyListeners();
      }
    }
  }

  Future<PhysicalTransaction?> createTransaction({
    required String agentId,
    required String transactionType,
    required String amount,
    required String network,
    required String walletId,
  }) async {
    if (!_isSessionActive || _isDisposed) return null;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.createPhysicalTransaction(
        agentId: agentId,
        transactionType: transactionType,
        amount: amount,
        network: network,
        walletId: walletId,
      );
      if (!_isCurrentSession(generation)) return null;
      final txn = PhysicalTransaction.fromJson(data);
      _currentTransaction = txn;
      _transactions.insert(0, txn);
      _notifyListeners();
      return txn;
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

  Future<void> loadTransactionDetail(String id) async {
    if (!_isSessionActive || _isDisposed) return;
    final generation = _sessionGeneration;
    _isLoading = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.getPhysicalTransactionDetail(id);
      if (!_isCurrentSession(generation)) return;
      if (data != null) {
        _currentTransaction = PhysicalTransaction.fromJson(data);
        _updateInList(_currentTransaction!);
        if (!_currentTransaction!.isActive) {
          stopPolling();
        }
      }
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentSession(generation)) {
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> acceptTransaction(
    String id, {
    required String meetingLatitude,
    required String meetingLongitude,
    String meetingDescription = '',
  }) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.acceptPhysicalTransaction(
        id,
        meetingLatitude: meetingLatitude,
        meetingLongitude: meetingLongitude,
        meetingDescription: meetingDescription,
      );
      if (!_isCurrentSession(generation)) return false;
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      _stopPollingForTerminalTransaction();
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

  Future<bool> rejectTransaction(String id, {String reason = ''}) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.rejectPhysicalTransaction(id, reason: reason);
      if (!_isCurrentSession(generation)) return false;
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      _stopPollingForTerminalTransaction();
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

  Future<bool> confirmTransaction(
    String id, {
    String verificationCode = '',
  }) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.confirmPhysicalTransaction(
        id,
        verificationCode: verificationCode,
      );
      if (!_isCurrentSession(generation)) return false;
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      _stopPollingForTerminalTransaction();
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

  Future<bool> cancelTransaction(String id, {String reason = ''}) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isSubmitting = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.cancelPhysicalTransaction(id, reason: reason);
      if (!_isCurrentSession(generation)) return false;
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      _stopPollingForTerminalTransaction();
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

  void startPolling(String transactionId) {
    if (!_isSessionActive || _isDisposed) return;
    stopPolling(resumeAutoRefresh: false);
    // A detail screen has a narrower data need than the list. Avoid running
    // competing list and detail pollers while it is active.
    stopAutoRefresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(loadTransactionDetail(transactionId));
    });
  }

  void stopPolling({bool resumeAutoRefresh = true}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (resumeAutoRefresh) startAutoRefresh();
  }

  void _stopPollingForTerminalTransaction() {
    if (_currentTransaction?.isActive == false) stopPolling();
  }

  void _updateInList(PhysicalTransaction updated) {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _transactions[idx] = updated;
    } else {
      _transactions.insert(0, updated);
    }
    if (_currentTransaction?.id == updated.id) {
      _currentTransaction = updated;
    }
  }

  void _startSession({String? sessionId}) {
    _resetSessionState();
    _sessionId = sessionId;
    _isSessionActive = true;
    startAutoRefresh();
    unawaited(loadTransactions());
  }

  void _resetSessionState() {
    stopPolling(resumeAutoRefresh: false);
    stopAutoRefresh();
    _sessionGeneration++;
    _sessionId = null;
    _isSessionActive = false;
    _loadTransactionsFuture = null;
    _loadWalletsFuture = null;
    _transactions = [];
    _currentTransaction = null;
    _wallets = [];
    _isLoading = false;
    _isLoadingWallets = false;
    _isSubmitting = false;
    _errorMessage = null;
    _hasLoadedTransactions = false;
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
