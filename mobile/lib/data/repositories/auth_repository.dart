import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';
import '../services/backend_api_service.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  Session? get currentSession;
  User? get currentUser;

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  });
  Future<void> signOut();
  Future<void> syncWithBackend();
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseAuthService _authService;
  final BackendApiService _backendService;

  const SupabaseAuthRepository({
    required SupabaseAuthService authService,
    required BackendApiService backendService,
  }) : _authService = authService,
       _backendService = backendService;

  @override
  Stream<AuthState> get authStateChanges => _authService.authStateChanges;

  @override
  Session? get currentSession => _authService.currentSession;

  @override
  User? get currentUser => _authService.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _authService.signIn(email: email, password: password);

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) => _authService.signUp(
    email: email,
    password: password,
    firstName: firstName,
    lastName: lastName,
  );

  @override
  Future<void> signOut() async {
    await _backendService.logout();
    await _authService.signOut();
  }

  @override
  Future<void> syncWithBackend() => _backendService.syncUser();
}
