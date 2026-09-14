import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';
import '../services/backend_api_service.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  Session? get currentSession;
  User? get currentUser;

  Future<void> sendPhoneOtp({required String phone});
  Future<void> resendPhoneOtp({required String phone});
  Future<void> verifyPhoneOtp({required String phone, required String token});
  Future<void> signOut();
  Future<Map<String, dynamic>> syncWithBackend();
  Future<Map<String, dynamic>?> getBackendProfile();
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  });
  Future<void> requestAgent();
  Future<Map<String, dynamic>?> getKycStatus();
  Future<Map<String, dynamic>> getKycDraft();
  Future<void> saveKycDraft(Map<String, dynamic> draft);

  Future<void> submitKyc({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  });
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
  Future<void> sendPhoneOtp({required String phone}) =>
      _authService.sendPhoneOtp(phone: phone);

  @override
  Future<void> resendPhoneOtp({required String phone}) =>
      _authService.resendPhoneOtp(phone: phone);

  @override
  Future<void> verifyPhoneOtp({required String phone, required String token}) =>
      _authService.verifyPhoneOtp(phone: phone, token: token);

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  }) => _backendService.updateProfile(firstName: firstName, lastName: lastName);

  @override
  Future<void> signOut() async {
    try {
      await _backendService.logout();
    } finally {
      await _authService.signOut();
    }
  }

  @override
  Future<Map<String, dynamic>> syncWithBackend() => _backendService.syncUser();

  @override
  Future<Map<String, dynamic>?> getBackendProfile() =>
      _backendService.getProfile();

  @override
  Future<void> requestAgent() => _backendService.requestAgent();

  @override
  Future<Map<String, dynamic>?> getKycStatus() =>
      _backendService.getKycStatus();

  @override
  Future<Map<String, dynamic>> getKycDraft() => _backendService.getKycDraft();

  @override
  Future<void> saveKycDraft(Map<String, dynamic> draft) =>
      _backendService.saveKycDraft(draft);

  @override
  Future<void> submitKyc({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) => _backendService.submitKyc(
    ghanaCardNumber: ghanaCardNumber,
    idFrontId: idFrontId,
    idBackId: idBackId,
    selfieId: selfieId,
    proofOfAddressId: proofOfAddressId,
  );
}
