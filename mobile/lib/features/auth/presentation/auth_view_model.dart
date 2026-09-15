import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/error_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/repositories/auth_repository.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/domain/models/app_user.dart';
import '../../../core/utils/ghana_phone.dart';

enum AuthBootstrapStatus { signedOut, loadingProfile, ready }

class AuthViewModel extends ChangeNotifier {
  static const _bootstrapTimeout = Duration(seconds: 6);

  final AuthRepository _authRepository;
  BackendApiService? _backendApiService;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _resendTimer;
  Future<void>? _profileRefreshFuture;
  bool _profileRefreshLoadsKycDetails = false;
  int _profileRefreshGeneration = 0;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  AuthBootstrapStatus _bootstrapStatus = AuthBootstrapStatus.signedOut;
  bool _hasConnectionError = false;
  String? _errorMessage;
  User? _currentUser;
  AppUser? _appUser;
  KycStatus? _resolvedKycStatus;
  bool _shouldShowApprovedKycScreen = false;
  String? _selfieUrl;
  Map<String, dynamic>? _kycSubmission;
  Map<String, String> _kycDocumentUrls = const {};
  String? _pendingPhone;
  int _resendSeconds = 0;

  AuthViewModel(this._authRepository) {
    _isAuthenticated = _authRepository.currentSession != null;
    _currentUser = _authRepository.currentUser;
    _bootstrapStatus = _isAuthenticated
        ? AuthBootstrapStatus.loadingProfile
        : AuthBootstrapStatus.signedOut;
    if (_isAuthenticated) {
      unawaited(refreshProfile(loadKycDetails: false));
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
  Map<String, dynamic>? get kycSubmission => _kycSubmission;
  Map<String, String> get kycDocumentUrls => _kycDocumentUrls;
  String? get pendingPhone => _pendingPhone;
  bool get isAwaitingOtp => _pendingPhone != null;
  int get resendSeconds => _resendSeconds;
  bool get canResendOtp => _pendingPhone != null && _resendSeconds == 0;

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
      _clearPendingOtp();
      _bootstrapStatus = AuthBootstrapStatus.signedOut;
      _appUser = null;
      _resolvedKycStatus = null;
      _shouldShowApprovedKycScreen = false;
      _selfieUrl = null;
      _kycSubmission = null;
      _kycDocumentUrls = const {};
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
      _shouldShowApprovedKycScreen = false;
      _selfieUrl = null;
      _kycSubmission = null;
      _kycDocumentUrls = const {};
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
      unawaited(refreshProfile(loadKycDetails: false));
    }
  }

  bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;

  bool _isCurrentProfileRefresh(int generation) =>
      _isAuthenticated && generation == _profileRefreshGeneration;

  Future<void> _syncAndLoadProfile(
    int generation, {
    required bool loadKycDetails,
  }) async {
    try {
      final profileData = await _authRepository.syncWithBackend().timeout(
        _bootstrapTimeout,
      );
      if (!_isCurrentProfileRefresh(generation)) return;
      _appUser = AppUser.fromBackendProfile(profileData);
      _resolvedKycStatus ??= _appUser?.kycStatus;
      _hasConnectionError = false;
      _errorMessage = null;
    } catch (e) {
      if (!_isCurrentProfileRefresh(generation)) return;
      final invalidSession =
          e is BackendApiException &&
          (e.statusCode == 401 || e.statusCode == 403);
      if (invalidSession) {
        _errorMessage =
            'Your session is no longer valid. Please sign in again.';
        await _authRepository.signOut();
        return;
      }

      _hasConnectionError = true;
      _errorMessage =
          'We could not reach the service. Your session is still saved; try again.';
      return;
    }

    if (!loadKycDetails) {
      _shouldShowApprovedKycScreen = false;
      unawaited(_loadKycDetails(generation, reportConnectionError: false));
      return;
    }

    await _loadKycDetails(generation, reportConnectionError: true);
  }

  Future<void> _loadKycDetails(
    int generation, {
    required bool reportConnectionError,
  }) async {
    try {
      final kycData = await _authRepository.getKycStatus().timeout(
        _bootstrapTimeout,
      );
      if (!_isCurrentProfileRefresh(generation)) return;
      final previousKycStatus = _resolvedKycStatus;
      _kycSubmission = kycData == null
          ? null
          : Map<String, dynamic>.unmodifiable(kycData);
      final status = _parseKycStatus(kycData?['status'] as String?);
      _resolvedKycStatus = status ?? _appUser?.kycStatus;
      _shouldShowApprovedKycScreen =
          previousKycStatus == KycStatus.pending &&
          _resolvedKycStatus == KycStatus.approved;
      notifyListeners();
      unawaited(_fetchKycMediaUrls(kycData, generation));
    } catch (e) {
      if (reportConnectionError &&
          _isNetworkError(e) &&
          _isCurrentProfileRefresh(generation)) {
        _hasConnectionError = true;
        return;
      }
      if (!_isCurrentProfileRefresh(generation)) return;
      _resolvedKycStatus ??= _appUser?.kycStatus;
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

  Future<bool> sendPhoneOtp(String rawPhone) async {
    _setLoading(true);
    try {
      final phone = normalizeGhanaPhone(rawPhone);
      await _authRepository.sendPhoneOtp(phone: phone);
      _pendingPhone = phone;
      _startResendCooldown();
      _clearError();
      return true;
    } on GhanaPhoneException catch (e) {
      _setError(e.message);
      return false;
    } on AuthException catch (e) {
      _setError(_friendlyOtpSendError(e));
      return false;
    } catch (_) {
      _setError('We could not send a code. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyPhoneOtp(String token) async {
    final phone = _pendingPhone;
    if (phone == null) {
      _setError('Enter your phone number again to request a new code.');
      return false;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      _setError('Enter the complete 6-digit code.');
      return false;
    }

    _setLoading(true);
    try {
      await _authRepository.verifyPhoneOtp(phone: phone, token: token);
      await refreshProfile();
      if (!_isAuthenticated || _appUser == null) return false;
      _clearError();
      return true;
    } on AuthException catch (e) {
      _setError(_friendlyOtpVerifyError(e));
      return false;
    } catch (_) {
      if (_errorMessage == null) {
        _setError('We could not verify that code. Please try again.');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendPhoneOtp() async {
    final phone = _pendingPhone;
    if (phone == null || !canResendOtp) return false;

    _setLoading(true);
    try {
      await _authRepository.resendPhoneOtp(phone: phone);
      _startResendCooldown();
      _clearError();
      return true;
    } on AuthException catch (e) {
      _setError(_friendlyOtpSendError(e));
      return false;
    } catch (_) {
      _setError('We could not send a new code. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void editPhone() {
    _clearPendingOtp();
    _clearError();
  }

  Future<bool> completeProfile({
    required String firstName,
    required String lastName,
  }) async {
    final resolvedFirstName = firstName.trim();
    final resolvedLastName = lastName.trim();
    if (resolvedFirstName.isEmpty || resolvedLastName.isEmpty) {
      _setError('Enter both your first and last name.');
      return false;
    }

    _setLoading(true);
    try {
      final profile = await _authRepository.updateProfile(
        firstName: resolvedFirstName,
        lastName: resolvedLastName,
      );
      _appUser = AppUser.fromBackendProfile(profile);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(friendlyErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signOut() async {
    _setLoading(true);
    try {
      await _authRepository.signOut();
      // Do not let the sign-in screen reopen on a stale verification step
      // after the router redirects the signed-out session.
      _clearPendingOtp();
      _clearError();
      return true;
    } catch (_) {
      _setError('Sign out failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProfile({bool loadKycDetails = true}) {
    if (!_isAuthenticated) {
      _bootstrapStatus = AuthBootstrapStatus.signedOut;
      return Future<void>.value();
    }

    final inFlight = _profileRefreshFuture;
    if (inFlight != null) {
      if (!loadKycDetails || _profileRefreshLoadsKycDetails) return inFlight;
      return inFlight.then((_) => refreshProfile());
    }

    final generation = ++_profileRefreshGeneration;
    _bootstrapStatus = AuthBootstrapStatus.loadingProfile;
    _profileRefreshLoadsKycDetails = loadKycDetails;
    late final Future<void> future;
    future = _syncAndLoadProfile(generation, loadKycDetails: loadKycDetails)
        .whenComplete(() {
          if (identical(_profileRefreshFuture, future) &&
              generation == _profileRefreshGeneration) {
            _profileRefreshFuture = null;
            _profileRefreshLoadsKycDetails = false;
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
    _profileRefreshLoadsKycDetails = false;
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

  void _clearPendingOtp() {
    _pendingPhone = null;
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendSeconds = 0;
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendSeconds = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        _resendSeconds = 0;
        timer.cancel();
      } else {
        _resendSeconds--;
      }
      notifyListeners();
    });
  }

  String _friendlyOtpSendError(AuthException error) {
    final message = error.message.toLowerCase();
    final code = error.code?.toLowerCase() ?? '';
    if (message.contains('rate') ||
        message.contains('seconds') ||
        code.contains('rate_limit')) {
      return 'Please wait a moment before requesting another code.';
    }
    return 'We could not send a code to that number. Please try again.';
  }

  String _friendlyOtpVerifyError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('expired')) {
      return 'That code has expired. Request a new one.';
    }
    return 'That code is incorrect or no longer valid.';
  }

  KycStatus? _parseKycStatus(String? value) {
    if (value == null || value.isEmpty) return null;
    return KycStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => KycStatus.none,
    );
  }

  Future<void> _fetchKycMediaUrls(
    Map<String, dynamic>? kycData,
    int generation,
  ) async {
    if (!_isCurrentProfileRefresh(generation)) return;
    const mediaFields = [
      'selfie_id',
      'id_front_id',
      'id_back_id',
      'proof_of_address_id',
    ];
    final api = _backendApiService;
    if (kycData == null || api == null) {
      _selfieUrl = null;
      _kycDocumentUrls = const {};
      return;
    }

    try {
      final urls = await Future.wait(
        mediaFields.map((field) async {
          final assetId = kycData[field]?.toString();
          if (assetId == null || assetId.isEmpty) {
            return MapEntry(field, null);
          }
          return MapEntry(field, await api.getFileAccessUrl(assetId));
        }),
      );
      if (!_isCurrentProfileRefresh(generation)) return;
      final resolvedUrls = <String, String>{
        for (final entry in urls)
          if (entry.value != null && entry.value!.isNotEmpty)
            entry.key: entry.value!,
      };
      _selfieUrl = resolvedUrls.remove('selfie_id');
      _kycDocumentUrls = Map<String, String>.unmodifiable(resolvedUrls);
      notifyListeners();
    } catch (_) {
      if (!_isCurrentProfileRefresh(generation)) return;
      _selfieUrl = null;
      _kycDocumentUrls = const {};
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _profileRefreshGeneration++;
    _authSubscription?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }
}
