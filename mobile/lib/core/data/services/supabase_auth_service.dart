import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Future<void> sendPhoneOtp({required String phone}) async {
    await _client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: true,
      channel: OtpChannel.sms,
    );
  }

  Future<void> resendPhoneOtp({required String phone}) async {
    await _client.auth.resend(phone: phone, type: OtpType.sms);
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    if (response.session == null || response.user == null) {
      throw const AuthException('Verification did not return a session.');
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
