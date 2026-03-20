import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/repositories/auth_repository.dart';
import '../../../core/domain/models/app_user.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  StreamSubscription<AuthState>? _authSubscription;
  Future<void>? _profileRefreshFuture;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _hasConnectionError = false;
  String? _errorMessage;
  User? _currentUser;
  AppUser? _appUser;
  KycStatus? _resolvedKycStatus;
  String? _kycApprovalToken;
  bool _shouldShowApprovedKycScreen = false;

  AuthViewModel(this._authRepository) {
    _isAuthenticated = _authRepository.currentSession != null;
    _currentUser = _authRepository.currentUser;
    if (_isAuthenticated) {
      unawaited(refreshProfile());
    }
    _authSubscription = _authRepository.authStateChanges.listen(
      _onAuthStateChange,
    );
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get hasConnectionError => _hasConnectionError;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  AppUser? get appUser => _appUser;
  KycStatus get kycStatus =>
      _resolvedKycStatus ?? _appUser?.kycStatus ?? KycStatus.none;
  bool get isKycApproved => kycStatus == KycStatus.approved;
  bool get shouldShowApprovedKycScreen => _shouldShowApprovedKycScreen;

  void _onAuthStateChange(AuthState state) {
    _isAuthenticated = state.session != null;
    _currentUser = state.session?.user;
    if (state.event == AuthChangeEvent.signedOut) {
      _appUser = null;
      _resolvedKycStatus = null;
      _kycApprovalToken = null;
      _shouldShowApprovedKycScreen = false;
    }
    notifyListeners();
    if (state.session != null &&
        (state.event == AuthChangeEvent.signedIn || _appUser == null)) {
      unawaited(refreshProfile());
    }
  }

  Future<void> _syncAndLoadProfile() async {
    try {
      await _authRepository.syncWithBackend();
      _hasConnectionError = false;
    } on SocketException {
      _hasConnectionError = true;
      notifyListeners();
      return;
    } on http.ClientException {
      _hasConnectionError = true;
      notifyListeners();
      return;
    } catch (_) {}

    try {
      final profileData = await _authRepository.getBackendProfile();
      if (profileData != null) {
        _appUser = AppUser.fromBackendProfile(profileData);
      }
    } on SocketException {
      _hasConnectionError = true;
      notifyListeners();
      return;
    } on http.ClientException {
      _hasConnectionError = true;
      notifyListeners();
      return;
    } catch (_) {}

    try {
      final kycData = await _authRepository.getKycStatus();
      final status = _parseKycStatus(kycData?['status'] as String?);
      _resolvedKycStatus = status ?? _appUser?.kycStatus;
      await _hydrateKycApprovalPresentation(kycData);
    } catch (_) {
      _resolvedKycStatus ??= _appUser?.kycStatus;
      _kycApprovalToken = null;
      _shouldShowApprovedKycScreen = false;
    }

    notifyListeners();
  }

  Future<void> requestAgent() async {
    _setLoading(true);
    try {
      await _authRepository.requestAgent();
      final profileData = await _authRepository.getBackendProfile();
      if (profileData != null) {
        _appUser = AppUser.fromBackendProfile(profileData);
      }
      _clearError();
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _authRepository.signIn(email: email, password: password);
      _clearError();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Something went wrong. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    _setLoading(true);
    try {
      await _authRepository.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      _clearError();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Something went wrong. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authRepository.signOut();
      _clearError();
    } catch (_) {
      _setError('Sign out failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProfile() {
    final inFlight = _profileRefreshFuture;
    if (inFlight != null) return inFlight;

    final future = _syncAndLoadProfile();
    _profileRefreshFuture = future;
    return future.whenComplete(() {
      if (identical(_profileRefreshFuture, future)) {
        _profileRefreshFuture = null;
      }
    });
  }

  Future<void> acknowledgeKycApproval() async {
    final userId = _kycPreferenceUserId;
    final token = _kycApprovalToken;

    if (userId == null || token == null) {
      _shouldShowApprovedKycScreen = false;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKycApprovalKey(userId), token);
    _shouldShowApprovedKycScreen = false;
    notifyListeners();
  }

  Future<void> retryConnection() async {
    _setLoading(true);
    _hasConnectionError = false;
    notifyListeners();
    await refreshProfile();
    _setLoading(false);
  }

  void clearError() => _clearError();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  KycStatus? _parseKycStatus(String? value) {
    if (value == null || value.isEmpty) return null;
    return KycStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => KycStatus.none,
    );
  }

  Future<void> _hydrateKycApprovalPresentation(
    Map<String, dynamic>? kycData,
  ) async {
    final userId = _kycPreferenceUserId;
    final token = _buildKycApprovalToken(kycData);
    _kycApprovalToken = token;

    if (userId == null || token == null) {
      _shouldShowApprovedKycScreen = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seenToken = prefs.getString(_seenKycApprovalKey(userId));
    _shouldShowApprovedKycScreen = seenToken != token;
  }

  String? _buildKycApprovalToken(Map<String, dynamic>? kycData) {
    final status = kycData?['status'] as String?;
    if (status != KycStatus.approved.name) return null;

    final submissionId = kycData?['id'] as String?;
    if (submissionId == null || submissionId.isEmpty) return null;

    final updatedAt = kycData?['updated_at'] as String? ?? '';
    return '$submissionId:$updatedAt';
  }

  String? get _kycPreferenceUserId => _appUser?.id ?? _currentUser?.id;

  String _seenKycApprovalKey(String userId) => 'seen_kyc_approval_$userId';

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
