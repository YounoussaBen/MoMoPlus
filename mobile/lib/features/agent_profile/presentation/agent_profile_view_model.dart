import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../domain/agent_profile.dart';
import '../domain/certification.dart';

enum AvailabilityGuardFailure {
  walletRequired,
  limitsRequired,
  profileUnavailable,
}

class AvailabilityGuardResult {
  final AvailabilityGuardFailure failure;
  final String title;
  final String message;

  const AvailabilityGuardResult({
    required this.failure,
    required this.title,
    required this.message,
  });
}

class AgentProfileViewModel extends ChangeNotifier {
  final BackendApiService _api;

  AgentProfile? _profile;
  CertificationApplication? _certification;
  bool _hasAnyWallet = false;
  bool _hasVerifiedWallet = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _sessionId;
  int _sessionGeneration = 0;

  AgentProfileViewModel(this._api, {bool autoStart = true}) {
    if (autoStart) unawaited(load());
  }

  AgentProfile? get profile => _profile;
  CertificationApplication? get certification => _certification;
  bool get hasAnyWallet => _hasAnyWallet;
  bool get hasVerifiedWallet => _hasVerifiedWallet;
  bool get hasLimitsSet =>
      _profile != null &&
      _profile!.minAmount > 0 &&
      _profile!.maxAmount != null &&
      _profile!.maxAmount! > 0;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  void setSession(String? sessionId) {
    if (_sessionId == sessionId) return;
    _sessionId = sessionId;
    _sessionGeneration++;
    _profile = null;
    _certification = null;
    _hasAnyWallet = false;
    _hasVerifiedWallet = false;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
    if (sessionId != null) unawaited(load());
  }

  bool _isCurrentSession(int generation, String? sessionId) =>
      generation == _sessionGeneration && sessionId == _sessionId;

  Future<void> load() async {
    final generation = _sessionGeneration;
    final sessionId = _sessionId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getAgentProfile();
      if (!_isCurrentSession(generation, sessionId)) return;
      if (data != null) _profile = AgentProfile.fromJson(data);

      final certData = await _api.getCertificationStatus();
      if (!_isCurrentSession(generation, sessionId)) return;
      if (certData != null) {
        _certification = CertificationApplication.fromJson(certData);
      }

      await refreshWalletEligibility(notify: false);
    } catch (e) {
      if (_isCurrentSession(generation, sessionId)) {
        _errorMessage = friendlyErrorMessage(e);
      }
    } finally {
      if (_isCurrentSession(generation, sessionId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    final generation = _sessionGeneration;
    final sessionId = _sessionId;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.updateAgentProfile(fields);
      if (!_isCurrentSession(generation, sessionId)) return false;
      _profile = AgentProfile.fromJson(data);
      return true;
    } catch (e) {
      if (_isCurrentSession(generation, sessionId)) {
        _errorMessage = friendlyErrorMessage(e);
      }
      return false;
    } finally {
      if (_isCurrentSession(generation, sessionId)) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleAvailability() async {
    final generation = _sessionGeneration;
    final sessionId = _sessionId;
    _errorMessage = null;
    try {
      final data = await _api.toggleAvailability();
      if (!_isCurrentSession(generation, sessionId)) return false;
      _profile = AgentProfile.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      if (_isCurrentSession(generation, sessionId)) {
        _errorMessage = friendlyErrorMessage(e);
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> refreshWalletEligibility({bool notify = true}) async {
    final generation = _sessionGeneration;
    final sessionId = _sessionId;
    try {
      final wallets = await _api.getWallets();
      if (!_isCurrentSession(generation, sessionId)) return;
      _hasAnyWallet = wallets.isNotEmpty;
      _hasVerifiedWallet = wallets.any((wallet) {
        final data = wallet as Map<String, dynamic>;
        return data['is_verified'] == true;
      });
    } catch (_) {
      // Keep the last known wallet state if the wallet check fails.
    } finally {
      if (notify && _isCurrentSession(generation, sessionId)) {
        notifyListeners();
      }
    }
  }

  Future<AvailabilityGuardResult?> validateAvailabilityChange(
    bool desiredValue,
  ) async {
    if (!desiredValue) return null;

    if (_profile == null) {
      await load();
      if (_profile == null) {
        return const AvailabilityGuardResult(
          failure: AvailabilityGuardFailure.profileUnavailable,
          title: 'Profile Unavailable',
          message:
              'We could not load your agent profile right now. Try again in a moment.',
        );
      }
    }

    await refreshWalletEligibility(notify: false);

    if (!hasVerifiedWallet) {
      return AvailabilityGuardResult(
        failure: AvailabilityGuardFailure.walletRequired,
        title: 'Wallet Required',
        message: hasAnyWallet
            ? 'Verify at least one mobile money wallet before making yourself available to users.'
            : 'Add and verify a mobile money wallet before making yourself available to users.',
      );
    }

    if (!hasLimitsSet) {
      return const AvailabilityGuardResult(
        failure: AvailabilityGuardFailure.limitsRequired,
        title: 'Limits Required',
        message:
            'Set your minimum and maximum transaction limits before making yourself available to users.',
      );
    }

    return null;
  }

  Future<bool> applyCertification({
    required String agentIdNumber,
    required String agentIdPhotoId,
    required String businessLocationPhotoId,
    String businessRegistrationNumber = '',
  }) async {
    final generation = _sessionGeneration;
    final sessionId = _sessionId;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.applyCertification(
        agentIdNumber: agentIdNumber,
        agentIdPhotoId: agentIdPhotoId,
        businessLocationPhotoId: businessLocationPhotoId,
        businessRegistrationNumber: businessRegistrationNumber,
      );
      if (!_isCurrentSession(generation, sessionId)) return false;
      _certification = CertificationApplication.fromJson(data);
      return true;
    } catch (e) {
      if (_isCurrentSession(generation, sessionId)) {
        _errorMessage = friendlyErrorMessage(e);
      }
      return false;
    } finally {
      if (_isCurrentSession(generation, sessionId)) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
