import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/repositories/auth_repository.dart';
import 'package:momoplus/features/auth/presentation/auth_view_model.dart';
import 'package:momoplus/features/kyc/data/kyc_repository.dart';
import 'package:momoplus/features/kyc/data/kyc_submission_model.dart';
import 'package:momoplus/features/kyc/presentation/kyc_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('KycViewModel status loading', () {
    late _FakeAuthRepository authRepository;
    late AuthViewModel authViewModel;
    late _FakeKycRepository kycRepository;
    late KycViewModel viewModel;

    setUp(() {
      authRepository = _FakeAuthRepository();
      authViewModel = AuthViewModel(authRepository);
      kycRepository = _FakeKycRepository();
      viewModel = KycViewModel(
        repository: kycRepository,
        authViewModel: authViewModel,
        autoLoad: false,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      authViewModel.dispose();
      await authRepository.close();
    });

    test('keeps a load failure distinct from a fresh wizard', () async {
      kycRepository.error = Exception('Service unavailable');

      await viewModel.refreshStatus(showLoading: true);

      expect(viewModel.screenState, KycScreenState.error);
      expect(viewModel.errorMessage, isNotNull);
    });

    test(
      'opens the wizard only when the server confirms no submission',
      () async {
        kycRepository.status = null;

        await viewModel.refreshStatus(showLoading: true);

        expect(viewModel.screenState, KycScreenState.wizard);
        expect(kycRepository.draftLoads, 1);
      },
    );

    test('preserves pending status when a manual refresh fails', () async {
      kycRepository.status = const KycSubmission(
        id: 'kyc-1',
        status: 'pending',
        idType: 'national_id',
        ghanaCardNumber: 'GHA-123456789-0',
        rejectionReason: '',
      );
      await viewModel.refreshStatus(showLoading: true);
      expect(viewModel.screenState, KycScreenState.pending);

      kycRepository.error = Exception('Connection interrupted');
      await viewModel.refreshStatus();

      expect(viewModel.screenState, KycScreenState.pending);
      expect(viewModel.errorMessage, isNotNull);
    });

    test('resubmit flow starts at the beginning of the wizard', () async {
      kycRepository.status = const KycSubmission(
        id: 'kyc-rejected',
        status: 'rejected',
        idType: 'national_id',
        ghanaCardNumber: 'GHA-123456789-0',
        idFrontId: 'front-id',
        idBackId: 'back-id',
        selfieId: 'selfie-id',
        proofOfAddressId: 'proof-id',
        rejectionReason: 'Name mismatch',
      );
      final resubmitViewModel = KycViewModel(
        repository: kycRepository,
        authViewModel: authViewModel,
        startInResubmitFlow: true,
      );
      addTearDown(resubmitViewModel.dispose);

      final observedStates = <KycScreenState>[];
      resubmitViewModel.addListener(
        () => observedStates.add(resubmitViewModel.screenState),
      );

      await Future<void>.delayed(Duration.zero);

      expect(resubmitViewModel.screenState, KycScreenState.wizard);
      expect(resubmitViewModel.step, 0);
      expect(resubmitViewModel.ghanaCardNumber, 'GHA-123456789-0');
      expect(observedStates, isNot(contains(KycScreenState.rejected)));
    });
  });
}

class _FakeKycRepository implements KycRepositoryContract {
  KycSubmission? status;
  Object? error;
  int draftLoads = 0;

  @override
  Future<KycSubmission?> getStatus() async {
    if (error != null) throw error!;
    return status;
  }

  @override
  Future<Map<String, dynamic>> getDraft() async {
    draftLoads++;
    return {};
  }

  @override
  Future<void> saveDraft(Map<String, dynamic> draft) async {}

  @override
  Future<void> deleteFile(String assetId) async {}

  @override
  Future<String?> getFileAccessUrl(String assetId) async => null;

  @override
  Future<String> uploadFile(File file, String kind, String contentType) async =>
      'asset-id';

  @override
  Future<void> submit({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) async {}
}

class _FakeAuthRepository implements AuthRepository {
  final _authStates = StreamController<AuthState>.broadcast();

  Future<void> close() => _authStates.close();

  @override
  Stream<AuthState> get authStateChanges => _authStates.stream;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Future<Map<String, dynamic>?> getBackendProfile() async => null;

  @override
  Future<Map<String, dynamic>?> getKycStatus() async => null;

  @override
  Future<Map<String, dynamic>> getKycDraft() async => {};

  @override
  Future<void> requestAgent() async {}

  @override
  Future<void> saveKycDraft(Map<String, dynamic> draft) async {}

  @override
  Future<void> sendPhoneOtp({required String phone}) async {}

  @override
  Future<void> resendPhoneOtp({required String phone}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {}

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  }) async => {};

  @override
  Future<void> submitKyc({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) async {}

  @override
  Future<Map<String, dynamic>> syncWithBackend() async => {};
}
