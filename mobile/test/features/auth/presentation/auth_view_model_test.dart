import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/repositories/auth_repository.dart';
import 'package:momoplus/features/auth/presentation/auth_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
  }) : _session = session,
       _syncCompleter = syncCompleter;

  final StreamController<AuthState> _authStates =
      StreamController<AuthState>.broadcast(sync: true);
  final Completer<void>? _syncCompleter;
  Session? _session;
  int syncCalls = 0;
  int profileCalls = 0;

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
    };
  }

  @override
  Future<Map<String, dynamic>?> getKycStatus() async => {'status': 'approved'};

  @override
  Future<void> syncWithBackend() {
    syncCalls++;
    return _syncCompleter?.future ?? Future<void>.value();
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {}

  @override
  Future<void> signOut() async {}

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
