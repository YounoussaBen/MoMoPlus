import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/repositories/auth_repository.dart';
import 'package:momoplus/features/auth/presentation/auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('phone OTP request normalizes input and starts cooldown', () async {
    final repository = _FakeAuthRepository(session: null);
    final viewModel = AuthViewModel(repository);
    addTearDown(viewModel.dispose);
    addTearDown(repository.close);

    final sent = await viewModel.sendPhoneOtp('024 123 4567');

    expect(sent, isTrue);
    expect(repository.sentPhone, '+233241234567');
    expect(viewModel.pendingPhone, '+233241234567');
    expect(viewModel.resendSeconds, 60);
    expect(viewModel.canResendOtp, isFalse);
  });

  test(
    'phone OTP request rejects invalid input before repository call',
    () async {
      final repository = _FakeAuthRepository(session: null);
      final viewModel = AuthViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.close);

      final sent = await viewModel.sendPhoneOtp('not a phone');

      expect(sent, isFalse);
      expect(repository.sentPhone, isNull);
      expect(viewModel.errorMessage, isNotEmpty);
    },
  );

  testWidgets('phone OTP resend uses the dedicated resend API', (tester) async {
    final repository = _FakeAuthRepository(session: null);
    final viewModel = AuthViewModel(repository);
    addTearDown(viewModel.dispose);
    addTearDown(repository.close);

    expect(await viewModel.sendPhoneOtp('0241234567'), isTrue);
    await tester.pump(const Duration(seconds: 60));
    expect(viewModel.canResendOtp, isTrue);

    final resent = await viewModel.resendPhoneOtp();

    expect(resent, isTrue);
    expect(repository.resentPhone, '+233241234567');
    expect(viewModel.resendSeconds, 60);
    expect(viewModel.errorMessage, isNull);
    viewModel.editPhone();
    await tester.pump();
  });

  test(
    'authenticated startup stays loading until the profile is hydrated',
    () async {
      final syncCompleter = Completer<void>();
      final repository = _FakeAuthRepository(
        session: _session('user-1'),
        syncCompleter: syncCompleter,
      );
      final viewModel = AuthViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.close);

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.bootstrapStatus, AuthBootstrapStatus.loadingProfile);
      expect(viewModel.isProfileLoading, isTrue);
      expect(viewModel.appUser, isNull);

      final refresh = viewModel.refreshProfile();
      expect(repository.syncCalls, 1);
      syncCompleter.complete();
      await refresh;

      expect(viewModel.bootstrapStatus, AuthBootstrapStatus.ready);
      expect(viewModel.hasHydratedProfile, isTrue);
      expect(viewModel.appUser?.id, 'user-1');
      expect(viewModel.appUser?.isAgent, isTrue);
      expect(viewModel.isKycApproved, isTrue);
    },
  );

  test('sign out invalidates an in-flight profile bootstrap', () async {
    final syncCompleter = Completer<void>();
    final repository = _FakeAuthRepository(
      session: _session('user-1'),
      syncCompleter: syncCompleter,
    );
    final viewModel = AuthViewModel(repository);
    addTearDown(viewModel.dispose);
    addTearDown(repository.close);

    final refresh = viewModel.refreshProfile();
    repository.emit(const AuthState(AuthChangeEvent.signedOut, null));

    expect(viewModel.bootstrapStatus, AuthBootstrapStatus.signedOut);
    expect(viewModel.isAuthenticated, isFalse);

    syncCompleter.complete();
    await refresh;

    expect(repository.profileCalls, 0);
    expect(viewModel.bootstrapStatus, AuthBootstrapStatus.signedOut);
    expect(viewModel.appUser, isNull);
  });

  test(
    'unsafe local profile link failure signs out the Supabase session',
    () async {
      final repository = _FakeAuthRepository(
        session: _session('user-1'),
        syncError: Exception('identity conflict'),
      );
      final viewModel = AuthViewModel(repository);
      addTearDown(viewModel.dispose);
      addTearDown(repository.close);

      await viewModel.refreshProfile();

      expect(repository.signOutCalls, 1);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.appUser, isNull);
      expect(viewModel.errorMessage, contains('securely link'));
    },
  );

  test('KYC approval is presented only once across logins', () async {
    SharedPreferences.setMockInitialValues({});
    const approval = {
      'id': 'kyc-1',
      'status': 'approved',
      'updated_at': '2026-07-12T08:00:00Z',
    };
    final firstRepository = _FakeAuthRepository(
      session: _session('user-1'),
      kycStatus: approval,
    );
    final firstViewModel = AuthViewModel(firstRepository);

    await firstViewModel.refreshProfile();
    expect(firstViewModel.shouldShowApprovedKycScreen, isTrue);

    await firstViewModel.markKycApprovalPresented();
    expect(firstViewModel.shouldShowApprovedKycScreen, isTrue);

    firstViewModel.dispose();
    await firstRepository.close();

    final nextRepository = _FakeAuthRepository(
      session: _session('user-1'),
      kycStatus: approval,
    );
    final nextViewModel = AuthViewModel(nextRepository);
    addTearDown(nextViewModel.dispose);
    addTearDown(nextRepository.close);

    await nextViewModel.refreshProfile();
    expect(nextViewModel.isKycApproved, isTrue);
    expect(nextViewModel.shouldShowApprovedKycScreen, isFalse);
  });
}

Session _session(String userId) {
  return Session(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required Session? session,
    Completer<void>? syncCompleter,
    this.syncError,
    this.kycStatus,
  }) : _session = session,
       _syncCompleter = syncCompleter;

  final StreamController<AuthState> _authStates =
      StreamController<AuthState>.broadcast(sync: true);
  final Completer<void>? _syncCompleter;
  final Object? syncError;
  final Map<String, dynamic>? kycStatus;
  Session? _session;
  int syncCalls = 0;
  int profileCalls = 0;
  int signOutCalls = 0;

  void emit(AuthState state) {
    _session = state.session;
    _authStates.add(state);
  }

  Future<void> close() => _authStates.close();

  @override
  Stream<AuthState> get authStateChanges => _authStates.stream;

  @override
  Session? get currentSession => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Future<Map<String, dynamic>?> getBackendProfile() async {
    profileCalls++;
    return {
      'id': _session?.user.id ?? 'user-1',
      'email': 'agent@example.com',
      'first_name': 'Ama',
      'last_name': 'Mensah',
      'role': 'agent',
      'agent_status': 'approved',
      'kyc_status': 'approved',
      'has_guarantors': true,
      'is_onboarded': true,
    };
  }

  @override
  Future<Map<String, dynamic>?> getKycStatus() async =>
      kycStatus ?? {'status': 'approved'};

  @override
  Future<void> syncWithBackend() {
    syncCalls++;
    if (syncError case final error?) return Future<void>.error(error);
    return _syncCompleter?.future ?? Future<void>.value();
  }

  String? sentPhone;
  String? resentPhone;

  @override
  Future<void> sendPhoneOtp({required String phone}) async {
    sentPhone = phone;
  }

  @override
  Future<void> resendPhoneOtp({required String phone}) async {
    resentPhone = phone;
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {}

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  }) async => {
    'id': _session?.user.id ?? 'user-1',
    'email': 'agent@example.com',
    'phone': '+233241234567',
    'first_name': firstName,
    'last_name': lastName,
    'is_onboarded': true,
  };

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> requestAgent() async {}

  @override
  Future<Map<String, dynamic>> getKycDraft() async => {};

  @override
  Future<void> saveKycDraft(Map<String, dynamic> draft) async {}

  @override
  Future<void> submitKyc({
    required String idType,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) async {}
}
