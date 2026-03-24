import 'package:flutter/material.dart';
import '../../../core/data/services/backend_api_service.dart';
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

  AgentProfileViewModel(this._api) {
    load();
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

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getAgentProfile();
      if (data != null) _profile = AgentProfile.fromJson(data);

      final certData = await _api.getCertificationStatus();
      if (certData != null) {
        _certification = CertificationApplication.fromJson(certData);
      }

      await refreshWalletEligibility(notify: false);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> fields) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.updateAgentProfile(fields);
      _profile = AgentProfile.fromJson(data);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> toggleAvailability() async {
    _errorMessage = null;
    try {
      final data = await _api.toggleAvailability();
      _profile = AgentProfile.fromJson(data);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshWalletEligibility({bool notify = true}) async {
    try {
      final wallets = await _api.getWallets();
      _hasAnyWallet = wallets.isNotEmpty;
      _hasVerifiedWallet = wallets.any((wallet) {
        final data = wallet as Map<String, dynamic>;
        return data['is_verified'] == true;
      });
    } catch (_) {
      // Keep the last known wallet state if the wallet check fails.
    } finally {
      if (notify) notifyListeners();
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
      _certification = CertificationApplication.fromJson(data);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
