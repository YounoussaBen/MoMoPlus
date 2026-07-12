import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_motion.dart';
import '../../../core/ui/theme/app_radii.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/ghana_phone_field.dart';
import 'auth_view_model.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final sent = await context.read<AuthViewModel>().sendPhoneOtp(
      _phoneController.text,
    );
    if (sent && mounted) {
      _otpController.clear();
      _otpFocusNode.requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    await context.read<AuthViewModel>().verifyPhoneOtp(_otpController.text);
  }

  void _editPhone(AuthViewModel viewModel) {
    viewModel.editPhone();
    _otpController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      body: SafeArea(
        child: Consumer<AuthViewModel>(
          builder: (context, viewModel, _) {
            return AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.standard,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: viewModel.isAwaitingOtp
                  ? _OtpStep(
                      key: const ValueKey('otp-step'),
                      viewModel: viewModel,
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      onVerify: _verifyCode,
                      onEditPhone: () => _editPhone(viewModel),
                    )
                  : _PhoneStep(
                      key: const ValueKey('phone-step'),
                      formKey: _phoneFormKey,
                      controller: _phoneController,
                      viewModel: viewModel,
                      onContinue: _sendCode,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.title,
    required this.body,
    required this.content,
  });

  final String title;
  final String body;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.space3, gutter, 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).vertical -
              44,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 88,
              child: const Align(
                alignment: Alignment.topRight,
                child: AppLogo(size: 84),
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            Text(title, style: context.appTextTheme.displaySmall),
            const SizedBox(height: AppSpacing.space3),
            Text(
              body,
              style: context.appTextTheme.bodyLarge?.copyWith(
                color: context.appColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            content,
          ],
        ),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    super.key,
    required this.formKey,
    required this.controller,
    required this.viewModel,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final AuthViewModel viewModel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _AuthLayout(
      title: 'Welcome to\nMoMo Plus!',
      body: 'Enter your phone number to continue.',
      content: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mobile number', style: context.appTextTheme.titleSmall),
            const SizedBox(height: AppSpacing.space3),
            GhanaPhoneField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onContinue(),
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.space4),
              _ErrorNotice(message: viewModel.errorMessage!),
            ],
            const SizedBox(height: AppSpacing.space5),
            AppButton(
              label: 'Continue',
              onPressed: onContinue,
              isLoading: viewModel.isLoading,
              trailingIcon: const Icon(Icons.arrow_forward_rounded),
            ),
            const SizedBox(height: AppSpacing.space3),
            const _AgreementNotice(),
          ],
        ),
      ),
    );
  }
}

class _AgreementNotice extends StatelessWidget {
  const _AgreementNotice();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = context.appTextTheme.bodySmall?.copyWith(
      color: context.appColors.textSecondary,
      height: 1.45,
    );
    final linkStyle = bodyStyle?.copyWith(
      color: context.appColors.brandStrong,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: context.appColors.brandStrong,
    );

    return Center(
      child: Text.rich(
        TextSpan(
          text: 'By continuing, you agree to our ',
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _LegalLink(
                key: const ValueKey('terms-link'),
                label: 'Terms',
                style: linkStyle,
                onTap: () => _showLegalDocument(context, _termsDocument),
              ),
            ),
            const TextSpan(text: ' and '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _LegalLink(
                key: const ValueKey('privacy-policy-link'),
                label: 'Privacy Policy',
                style: linkStyle,
                onTap: () => _showLegalDocument(context, _privacyDocument),
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
        style: bodyStyle,
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    super.key,
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smallBorderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

Future<void> _showLegalDocument(BuildContext context, _LegalDocument document) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: context.appColors.scrim,
    builder: (dialogContext) {
      final screenHeight = MediaQuery.sizeOf(dialogContext).height;
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: screenHeight * 0.82,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.title,
                        style: context.appTextTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close ${document.title}',
                      onPressed: () => Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  document.updatedAt,
                  style: context.appTextTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.introduction,
                          style: context.appTextTheme.bodyMedium?.copyWith(
                            color: context.appColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        for (final section in document.sections) ...[
                          const SizedBox(height: AppSpacing.space5),
                          Text(
                            section.title,
                            style: context.appTextTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            section.body,
                            style: context.appTextTheme.bodyMedium?.copyWith(
                              color: context.appColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                AppButton(
                  label: 'Close',
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      Navigator.of(dialogContext, rootNavigator: true).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _LegalDocument {
  const _LegalDocument({
    required this.title,
    required this.updatedAt,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final String introduction;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

const _termsDocument = _LegalDocument(
  title: 'Terms of Use',
  updatedAt: 'Last updated: 12 July 2026',
  introduction:
      'These Terms govern your access to and use of MoMo Plus. By continuing, you confirm that you have read and accepted them.',
  sections: [
    _LegalSection(
      title: 'Account and access',
      body:
          'Provide accurate information and use a mobile number you control. Keep verification codes private. You are responsible for activity completed through your account unless you promptly report unauthorized access.',
    ),
    _LegalSection(
      title: 'Using MoMo Plus',
      body:
          'MoMo Plus helps you access money services and connect with participating agents. Service availability, agent availability and eligibility decisions are not guaranteed. Follow all instructions and verify transaction details before confirming.',
    ),
    _LegalSection(
      title: 'Fees and repayment',
      body:
          'Review the amount, fees, repayment terms and timing shown before accepting a service. When you confirm, you authorize the transaction and agree to meet any repayment obligation displayed to you.',
    ),
    _LegalSection(
      title: 'Acceptable use',
      body:
          'Do not use MoMo Plus for fraud, impersonation, unlawful activity, interference with the service or attempts to access another person’s account. We may restrict or suspend access to protect users and the platform.',
    ),
    _LegalSection(
      title: 'Availability and changes',
      body:
          'Mobile networks, payment providers and other third parties can affect availability. We may update the service or these Terms when necessary. Material changes will be communicated through the app or another appropriate channel.',
    ),
    _LegalSection(
      title: 'Support',
      body:
          'If you have a question, dispute or believe your account is being misused, contact MoMo Plus through the support option provided in the app.',
    ),
  ],
);

const _privacyDocument = _LegalDocument(
  title: 'Privacy Policy',
  updatedAt: 'Last updated: 12 July 2026',
  introduction:
      'This policy explains the information MoMo Plus handles, why we use it and the choices available to you.',
  sections: [
    _LegalSection(
      title: 'Information we collect',
      body:
          'We may collect your phone number, profile details, identity-verification information, wallet and transaction information, device data, diagnostic logs and location when you grant permission for a location-based feature.',
    ),
    _LegalSection(
      title: 'How we use information',
      body:
          'We use information to authenticate you, provide and personalize services, verify identity, connect you with agents, process transactions, prevent fraud, provide support and meet legal or regulatory obligations.',
    ),
    _LegalSection(
      title: 'When information is shared',
      body:
          'Information may be shared with service providers, payment or mobile-money partners, participating agents when needed to fulfil your request, and authorities when required by law. Partners receive only the information needed for their role.',
    ),
    _LegalSection(
      title: 'Security and retention',
      body:
          'We use reasonable safeguards designed to protect personal information. We keep information only as long as needed to provide the service, resolve disputes and satisfy legal, accounting or security requirements.',
    ),
    _LegalSection(
      title: 'Your choices',
      body:
          'You can manage device permissions in your phone settings. You may also ask to access or correct your information, or request deletion where applicable, using the support option in the app.',
    ),
    _LegalSection(
      title: 'Policy updates',
      body:
          'We may update this policy as the service or legal requirements change. We will communicate material updates through the app or another appropriate channel.',
    ),
  ],
);

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    super.key,
    required this.viewModel,
    required this.controller,
    required this.focusNode,
    required this.onVerify,
    required this.onEditPhone,
  });

  final AuthViewModel viewModel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onVerify;
  final VoidCallback onEditPhone;

  @override
  Widget build(BuildContext context) {
    final resendMinutes = viewModel.resendSeconds ~/ 60;
    final resendRemainingSeconds = viewModel.resendSeconds % 60;
    return _AuthLayout(
      title: 'Verification',
      body: 'Enter your 6-digit code to continue.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Verification code',
                  style: context.appTextTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onEditPhone,
                child: const Text('Edit number'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          _OtpEntry(
            controller: controller,
            focusNode: focusNode,
            onComplete: onVerify,
          ),
          if (viewModel.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: viewModel.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.space5),
          AppButton(
            label: 'Verify and continue',
            onPressed: onVerify,
            isLoading: viewModel.isLoading,
          ),
          const SizedBox(height: AppSpacing.space3),
          Center(
            child: viewModel.canResendOtp
                ? TextButton(
                    onPressed: viewModel.isLoading
                        ? null
                        : viewModel.resendPhoneOtp,
                    child: const Text('Send a new code'),
                  )
                : Text(
                    '${resendMinutes.toString().padLeft(2, '0')}:${resendRemainingSeconds.toString().padLeft(2, '0')}',
                    style: context.appTextTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OtpEntry extends StatefulWidget {
  const _OtpEntry({
    required this.controller,
    required this.focusNode,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onComplete;

  @override
  State<_OtpEntry> createState() => _OtpEntryState();
}

class _OtpEntryState extends State<_OtpEntry> {
  String? _lastCompletedCode;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.focusNode.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _handleCodeChanged(String value) {
    if (value.length < 6) {
      _lastCompletedCode = null;
      return;
    }
    if (value == _lastCompletedCode) return;

    _lastCompletedCode = value;
    TextInput.finishAutofillContext(shouldSave: false);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Semantics(
      label: '6-digit verification code',
      textField: true,
      value: '${code.length} of 6 digits entered',
      child: GestureDetector(
        onTap: widget.focusNode.requestFocus,
        child: SizedBox(
          height: 58,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: Row(
                  children: List.generate(6, (index) {
                    final hasDigit = index < code.length;
                    final active =
                        widget.focusNode.hasFocus &&
                        (index == code.length ||
                            (code.length == 6 && index == 5));
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index == 5 ? 0 : 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? context.appColors.brandSoft
                              : context.appColors.surfaceInteractive,
                          borderRadius: AppRadii.smallBorderRadius,
                        ),
                        child: Text(
                          hasDigit ? code[index] : '',
                          style: context.appTextTheme.titleLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    key: const ValueKey('otp-input'),
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: _handleCodeChanged,
                    onSubmitted: _handleCodeChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: context.appColors.errorContainer,
          borderRadius: AppRadii.smallBorderRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: context.appColors.error,
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: Text(
                message,
                style: context.appTextTheme.bodySmall?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
