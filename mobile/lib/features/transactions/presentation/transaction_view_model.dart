import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../wallet/domain/wallet.dart';
import '../domain/physical_transaction.dart';

class TransactionViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<PhysicalTransaction> _transactions = [];
  PhysicalTransaction? _currentTransaction;
  List<Wallet> _wallets = [];
  bool _isLoading = false;
  bool _isLoadingWallets = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Timer? _pollTimer;

  TransactionViewModel(this._api);

  List<PhysicalTransaction> get transactions => _transactions;
  PhysicalTransaction? get currentTransaction => _currentTransaction;
  List<Wallet> get wallets => _wallets;
  List<Wallet> get verifiedWallets =>
      _wallets.where((w) => w.isVerified).toList();
  bool get isLoading => _isLoading;
  bool get isLoadingWallets => _isLoadingWallets;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  List<PhysicalTransaction> get activeTransactions =>
      _transactions.where((t) => t.isActive).toList();
  List<PhysicalTransaction> get completedTransactions =>
      _transactions.where((t) => !t.isActive).toList();

  Future<void> loadTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getPhysicalTransactions();
      _transactions = data
          .map((e) => PhysicalTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWallets() async {
    _isLoadingWallets = true;
    notifyListeners();
    try {
      final data = await _api.getWallets();
      _wallets = data
          .map((e) => Wallet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    _isLoadingWallets = false;
    notifyListeners();
  }

  Future<PhysicalTransaction?> createTransaction({
    required String agentId,
    required String transactionType,
    required String amount,
    required String network,
    required String walletId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.createPhysicalTransaction(
        agentId: agentId,
        transactionType: transactionType,
        amount: amount,
        network: network,
        walletId: walletId,
      );
      final txn = PhysicalTransaction.fromJson(data);
      _currentTransaction = txn;
      _transactions.insert(0, txn);
      notifyListeners();
      return txn;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactionDetail(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getPhysicalTransactionDetail(id);
      if (data != null) {
        _currentTransaction = PhysicalTransaction.fromJson(data);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> acceptTransaction(
    String id, {
    required String meetingLatitude,
    required String meetingLongitude,
    String meetingDescription = '',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.acceptPhysicalTransaction(
        id,
        meetingLatitude: meetingLatitude,
        meetingLongitude: meetingLongitude,
        meetingDescription: meetingDescription,
      );
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> rejectTransaction(String id, {String reason = ''}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.rejectPhysicalTransaction(id, reason: reason);
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> confirmTransaction(String id) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.confirmPhysicalTransaction(id);
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> cancelTransaction(String id, {String reason = ''}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.cancelPhysicalTransaction(id, reason: reason);
      _currentTransaction = PhysicalTransaction.fromJson(data);
      _updateInList(_currentTransaction!);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void startPolling(String transactionId) {
    stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadTransactionDetail(transactionId);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _updateInList(PhysicalTransaction updated) {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _transactions[idx] = updated;
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
