import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/error_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/repositories/auth_repository.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/domain/models/app_user.dart';

enum AuthBootstrapStatus { signedOut, loadingProfile, ready }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  BackendApiService? _backendApiService;

  StreamSubscription<AuthState>? _authSubscription;
  Future<void>? _profileRefreshFuture;
  int _profileRefreshGeneration = 0;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  AuthBootstrapStatus _bootstrapStatus = AuthBootstrapStatus.signedOut;
  bool _hasConnectionError = false;
  String? _errorMessage;
  User? _currentUser;
  AppUser? _appUser;
  KycStatus? _resolvedKycStatus;
  String? _kycApprovalToken;
  bool _shouldShowApprovedKycScreen = false;
  String? _selfieUrl;

  AuthViewModel(this._authRepository) {
    _isAuthenticated = _authRepository.currentSession != null;
    _currentUser = _authRepository.currentUser;
    _bootstrapStatus = _isAuthenticated
        ? AuthBootstrapStatus.loadingProfile
        : AuthBootstrapStatus.signedOut;
    if (_isAuthenticated) {
      unawaited(refreshProfile());
    }
    _authSubscription = _authRepository.authStateChanges.listen(
      _onAuthStateChange,
    );
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  AuthBootstrapStatus get bootstrapStatus => _bootstrapStatus;
  bool get isProfileLoading =>
      _bootstrapStatus == AuthBootstrapStatus.loadingProfile;
  bool get hasHydratedProfile => _bootstrapStatus == AuthBootstrapStatus.ready;
  bool get hasConnectionError => _hasConnectionError;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  AppUser? get appUser => _appUser;
  KycStatus get kycStatus =>
      _resolvedKycStatus ?? _appUser?.kycStatus ?? KycStatus.none;
  bool get isKycApproved => kycStatus == KycStatus.approved;
  bool get shouldShowApprovedKycScreen => _shouldShowApprovedKycScreen;
  String? get selfieUrl => _selfieUrl;

  void setBackendApiService(BackendApiService service) {
    _backendApiService = service;
  }

  void _onAuthStateChange(AuthState state) {
    final previousUserId = _currentUser?.id;
    _isAuthenticated = state.session != null;
    _currentUser = state.session?.user;

    if (!_isAuthenticated) {
      _profileRefreshGeneration++;
      _profileRefreshFuture = null;
      _bootstrapStatus = AuthBootstrapStatus.signedOut;
      _appUser = null;
      _resolvedKycStatus = null;
      _kycApprovalToken = null;
      _shouldShowApprovedKycScreen = false;
      _selfieUrl = null;
      notifyListeners();
      return;
    }

    final userChanged = previousUserId != _currentUser?.id;
    if (userChanged) {
      // An older user's in-flight profile request must never hydrate this
      // session or influence its route gates.
      _profileRefreshGeneration++;
      _profileRefreshFuture = null;
      _appUser = null;
      _resolvedKycStatus = null;
      _kycApprovalToken = null;
      _shouldShowApprovedKycScreen = false;
      _selfieUrl = null;
    }

    final shouldRefresh =
        userChanged ||
        state.event == AuthChangeEvent.signedIn ||
        _appUser == null;
    if (shouldRefresh) {
      _bootstrapStatus = AuthBootstrapStatus.loadingProfile;
    }
    notifyListeners();
    if (shouldRefresh) {
      unawaited(refreshProfile());
    }
  }

  bool _isNetworkError(Object error) =>
      error is SocketException || error is http.ClientException;

  bool _isCurrentProfileRefresh(int generation) =>
      _isAuthenticated && generation == _profileRefreshGeneration;

  Future<void> _syncAndLoadProfile(int generation) async {
    try {
      await _authRepository.syncWithBackend();
      if (!_isCurrentProfileRefresh(generation)) return;
      _hasConnectionError = false;
    } catch (e) {
      if (_isNetworkError(e) && _isCurrentProfileRefresh(generation)) {
        _hasConnectionError = true;
        return;
      }
    }

    try {
      final profileData = await _authRepository.getBackendProfile();
      if (!_isCurrentProfileRefresh(generation)) return;
      if (profileData != null) {
        _appUser = AppUser.fromBackendProfile(profileData);
      }
    } catch (e) {
      if (_isNetworkError(e) && _isCurrentProfileRefresh(generation)) {
        _hasConnectionError = true;
        return;
      }
    }

    try {
      final kycData = await _authRepository.getKycStatus();
      if (!_isCurrentProfileRefresh(generation)) return;
      final status = _parseKycStatus(kycData?['status'] as String?);
      _resolvedKycStatus = status ?? _appUser?.kycStatus;
      await _hydrateKycApprovalPresentation(kycData, generation);
      if (!_isCurrentProfileRefresh(generation)) return;
      await _fetchSelfieUrl(kycData, generation);
    } catch (e) {
      if (_isNetworkError(e) && _isCurrentProfileRefresh(generation)) {
        _hasConnectionError = true;
        return;
      }
      if (!_isCurrentProfileRefresh(generation)) return;
      _resolvedKycStatus ??= _appUser?.kycStatus;
      _kycApprovalToken = null;
      _shouldShowApprovedKycScreen = false;
    }
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
      _setError(friendlyErrorMessage(e));
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

  Future<bool> signOut() async {
    _setLoading(true);
    try {
      await _authRepository.signOut();
      _clearError();
      return true;
    } catch (_) {
      _setError('Sign out failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProfile() {
    if (!_isAuthenticated) {
      _bootstrapStatus = AuthBootstrapStatus.signedOut;
      return Future<void>.value();
    }

    final inFlight = _profileRefreshFuture;
    if (inFlight != null) return inFlight;

    final generation = ++_profileRefreshGeneration;
    _bootstrapStatus = AuthBootstrapStatus.loadingProfile;
    late final Future<void> future;
    future = _syncAndLoadProfile(generation).whenComplete(() {
      if (identical(_profileRefreshFuture, future) &&
          generation == _profileRefreshGeneration) {
        _profileRefreshFuture = null;
        _bootstrapStatus = _isAuthenticated
            ? AuthBootstrapStatus.ready
            : AuthBootstrapStatus.signedOut;
        notifyListeners();
      }
    });
    _profileRefreshFuture = future;
    notifyListeners();
    return future;
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

  void reportConnectionError() {
    if (_hasConnectionError) return;
    _hasConnectionError = true;
    notifyListeners();
  }

  Future<void> retryConnection() async {
    _setLoading(true);
    _hasConnectionError = false;
    _profileRefreshFuture = null;
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
    int generation,
  ) async {
    if (!_isCurrentProfileRefresh(generation)) return;
    final userId = _kycPreferenceUserId;
    final token = _buildKycApprovalToken(kycData);
    _kycApprovalToken = token;

    if (userId == null || token == null) {
      _shouldShowApprovedKycScreen = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrentProfileRefresh(generation)) return;
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

  Future<void> _fetchSelfieUrl(
    Map<String, dynamic>? kycData,
    int generation,
  ) async {
    if (!_isCurrentProfileRefresh(generation)) return;
    final selfieId = kycData?['selfie_id'] as String?;
    if (selfieId == null || _backendApiService == null) {
      _selfieUrl = null;
      return;
    }
    try {
      final selfieUrl = await _backendApiService!.getFileAccessUrl(selfieId);
      if (!_isCurrentProfileRefresh(generation)) return;
      _selfieUrl = selfieUrl;
    } catch (_) {
      if (!_isCurrentProfileRefresh(generation)) return;
      _selfieUrl = null;
    }
  }

  @override
  void dispose() {
    _profileRefreshGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
