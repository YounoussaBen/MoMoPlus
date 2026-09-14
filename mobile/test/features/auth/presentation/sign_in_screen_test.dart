import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/repositories/auth_repository.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/features/auth/presentation/auth_view_model.dart';
import 'package:momoplus/features/auth/presentation/sign_in_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('phone entry advances to six-digit OTP step', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _PhoneAuthRepository();
    final viewModel = AuthViewModel(repository);
    addTearDown(viewModel.dispose);
    addTearDown(repository.close);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: viewModel,
        child: MaterialApp(theme: AppTheme.light, home: const SignInScreen()),
      ),
    );

    expect(find.text('Secure sign in'), findsNothing);
    expect(find.text('Welcome to\nMoMo Plus!'), findsOneWidget);
    expect(
      find.text(
        'Standard SMS rates may apply. We never ask you to share this code.',
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('terms-link')));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Account and access'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('privacy-policy-link')));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsNWidgets(2));
    expect(find.text('Information we collect'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '0241234567');
    final phoneField = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(phoneField.controller?.text, '24 123 4567');
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(repository.sentPhone, '+233241234567');
    expect(find.text('Code sent'), findsNothing);
    expect(find.text('Verification'), findsOneWidget);
    expect(find.text('Enter your 6-digit code to continue.'), findsOneWidget);
    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('Verify and continue'), findsNothing);
    expect(find.byIcon(Icons.verified_user_outlined), findsNothing);

    final otpField = tester.widget<TextField>(
      find.byKey(const ValueKey('otp-input')),
    );
    expect(otpField.autofillHints, contains(AutofillHints.oneTimeCode));

    await tester.enterText(find.byKey(const ValueKey('otp-input')), '123456');
    await tester.pump();

    expect(repository.verifiedPhone, '+233241234567');
    expect(repository.verifiedToken, '123456');

    viewModel.editPhone();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PhoneAuthRepository implements AuthRepository {
  final _authStates = StreamController<AuthState>.broadcast();
  String? sentPhone;
  String? verifiedPhone;
  String? verifiedToken;

  Future<void> close() => _authStates.close();

  @override
  Stream<AuthState> get authStateChanges => _authStates.stream;

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Future<void> sendPhoneOtp({required String phone}) async {
    sentPhone = phone;
  }

  @override
  Future<void> resendPhoneOtp({required String phone}) async {
    sentPhone = phone;
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    verifiedPhone = phone;
    verifiedToken = token;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<Map<String, dynamic>> syncWithBackend() async => {};

  @override
  Future<Map<String, dynamic>?> getBackendProfile() async => null;

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  }) async => {};

  @override
  Future<void> requestAgent() async {}

  @override
  Future<Map<String, dynamic>?> getKycStatus() async => null;

  @override
  Future<Map<String, dynamic>> getKycDraft() async => {};

  @override
  Future<void> saveKycDraft(Map<String, dynamic> draft) async {}

  @override
  Future<void> submitKyc({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) async {}
}
