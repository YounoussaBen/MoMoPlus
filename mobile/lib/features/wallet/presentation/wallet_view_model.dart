import 'package:flutter/material.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../domain/wallet.dart';

class WalletViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<Wallet> _wallets = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Add wallet flow
  bool _isAdding = false;
  Wallet? _pendingWallet;

  // OTP verification
  bool _isVerifying = false;
  bool _isResending = false;

  WalletViewModel(this._api, {bool loadOnInit = true}) {
    if (loadOnInit) {
      loadWallets();
    }
  }

  List<Wallet> get wallets => _wallets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdding => _isAdding;
  Wallet? get pendingWallet => _pendingWallet;
  bool get isVerifying => _isVerifying;
  bool get isResending => _isResending;

  Future<void> loadWallets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getWallets();
      _wallets = data
          .map((e) => Wallet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addWallet({
    required String phoneNumber,
    required String network,
  }) async {
    _isAdding = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.addWallet(
        phoneNumber: phoneNumber,
        network: network,
      );
      _pendingWallet = Wallet.fromJson(data);
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isAdding = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String code) async {
    if (_pendingWallet == null) return false;
    _isVerifying = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.verifyWalletOtp(
        walletId: _pendingWallet!.id,
        code: code,
      );
      _pendingWallet = Wallet.fromJson(data);
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      _isVerifying = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp() async {
    if (_pendingWallet == null) return;
    _isResending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.resendWalletOtp(_pendingWallet!.id);
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _isResending = false;
      notifyListeners();
    }
  }

  Future<bool> setDefault(String walletId) async {
    _errorMessage = null;
    try {
      await _api.setDefaultWallet(walletId);
      await loadWallets();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    _errorMessage = null;
    try {
      await _api.deleteWallet(walletId);
      await loadWallets();
      return true;
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearPendingWallet() {
    _pendingWallet = null;
    notifyListeners();
  }

  void setPendingWallet({
    required String walletId,
    required String phoneNumber,
    String network = 'mtn',
  }) {
    _pendingWallet = Wallet(
      id: walletId,
      phoneNumber: phoneNumber,
      network: network,
      isVerified: false,
      isDefault: false,
      createdAt: DateTime.now(),
    );
    _errorMessage = null;
    notifyListeners();
  }
}
