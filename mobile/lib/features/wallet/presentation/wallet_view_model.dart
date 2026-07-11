import 'dart:async';

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
  Future<void>? _loadWalletsFuture;
  String? _sessionId;
  bool _isSessionActive = false;
  bool _isDisposed = false;
  int _sessionGeneration = 0;

  WalletViewModel(this._api, {bool loadOnInit = true, bool autoStart = true}) {
    if (autoStart) {
      _startSession(loadImmediately: loadOnInit);
    }
  }

  List<Wallet> get wallets => _wallets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdding => _isAdding;
  Wallet? get pendingWallet => _pendingWallet;
  bool get isVerifying => _isVerifying;
  bool get isResending => _isResending;
  bool get isSessionActive => _isSessionActive;

  /// Switches this cache to [sessionId], clearing the previous user's wallets
  /// and any in-progress OTP flow before loading the new session.
  void setSession(String? sessionId) {
    if (sessionId == null) {
      clearSession();
      return;
    }
    if (_isSessionActive && _sessionId == sessionId) return;
    _startSession(sessionId: sessionId);
  }

  /// Invalidates in-flight requests and clears all authenticated-user state.
  void clearSession() {
    if (_isDisposed) return;
    _resetSessionState();
    _notifyListeners();
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
    _isLoading = true;
    _errorMessage = null;
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
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> addWallet({
    required String phoneNumber,
    required String network,
  }) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _isAdding = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.addWallet(
        phoneNumber: phoneNumber,
        network: network,
      );
      if (!_isCurrentSession(generation)) return false;
      _pendingWallet = Wallet.fromJson(data);
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isAdding = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> verifyOtp(String code) async {
    if (!_isSessionActive || _isDisposed || _pendingWallet == null) {
      return false;
    }
    final generation = _sessionGeneration;
    final walletId = _pendingWallet!.id;
    _isVerifying = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.verifyWalletOtp(walletId: walletId, code: code);
      if (!_isCurrentSession(generation)) return false;
      _pendingWallet = Wallet.fromJson(data);
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isVerifying = false;
        _notifyListeners();
      }
    }
  }

  Future<void> resendOtp() async {
    if (!_isSessionActive || _isDisposed || _pendingWallet == null) return;
    final generation = _sessionGeneration;
    final walletId = _pendingWallet!.id;
    _isResending = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.resendWalletOtp(walletId);
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentSession(generation)) {
        _isResending = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> setDefault(String walletId) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _errorMessage = null;
    try {
      await _api.setDefaultWallet(walletId);
      if (!_isCurrentSession(generation)) return false;
      await loadWallets();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      _notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWallet(String walletId) async {
    if (!_isSessionActive || _isDisposed) return false;
    final generation = _sessionGeneration;
    _errorMessage = null;
    try {
      await _api.deleteWallet(walletId);
      if (!_isCurrentSession(generation)) return false;
      await loadWallets();
      if (!_isCurrentSession(generation)) return false;
      return true;
    } catch (e) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(e);
      _notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    _notifyListeners();
  }

  void clearPendingWallet() {
    _pendingWallet = null;
    _notifyListeners();
  }

  void setPendingWallet({
    required String walletId,
    required String phoneNumber,
    String network = 'mtn',
  }) {
    if (!_isSessionActive || _isDisposed) return;
    _pendingWallet = Wallet(
      id: walletId,
      phoneNumber: phoneNumber,
      network: network,
      isVerified: false,
      isDefault: false,
      createdAt: DateTime.now(),
    );
    _errorMessage = null;
    _notifyListeners();
  }

  void _startSession({String? sessionId, bool loadImmediately = true}) {
    _resetSessionState();
    _sessionId = sessionId;
    _isSessionActive = true;
    if (loadImmediately) unawaited(loadWallets());
  }

  void _resetSessionState() {
    _sessionGeneration++;
    _sessionId = null;
    _isSessionActive = false;
    _loadWalletsFuture = null;
    _wallets = [];
    _isLoading = false;
    _errorMessage = null;
    _isAdding = false;
    _pendingWallet = null;
    _isVerifying = false;
    _isResending = false;
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
