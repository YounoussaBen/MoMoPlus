import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_motion.dart';
import '../../../core/ui/theme/app_radii.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_icon_button.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_text_field.dart';
import '../../../core/utils/ghana_phone.dart';
import '../../../core/utils/ghana_phone_input_formatter.dart';
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
    this.eyebrow,
    this.leading,
  });

  final String? eyebrow;
  final String title;
  final String body;
  final Widget content;
  final Widget? leading;

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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading ?? const SizedBox.shrink(),
                  const Spacer(),
                  const AppLogo(size: 84),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
            if (eyebrow != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3,
                  vertical: AppSpacing.space2,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.brandSoft,
                  borderRadius: AppRadii.pillBorderRadius,
                ),
                child: Text(
                  eyebrow!,
                  style: context.appTextTheme.labelMedium?.copyWith(
                    color: context.appColors.brandStrong,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
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
            AppTextField(
              hint: '24 123 4567',
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: const [GhanaNationalPhoneInputFormatter()],
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🇬🇭', style: context.appTextTheme.titleMedium),
                    const SizedBox(width: 8),
                    Text('+233', style: context.appTextTheme.titleSmall),
                  ],
                ),
              ),
              validator: (value) {
                try {
                  normalizeGhanaPhone(value ?? '');
                  return null;
                } on GhanaPhoneException catch (error) {
                  return error.message;
                }
              },
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
            ),
          ],
        ),
      ),
    );
  }
}

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
    final phone = viewModel.pendingPhone!;
    return _AuthLayout(
      eyebrow: 'Code sent',
      title: 'Check your\nmessages.',
      body: 'Enter the 6-digit code sent to ${maskGhanaPhone(phone)}.',
      leading: AppIconButton(
        icon: Icons.arrow_back_rounded,
        label: 'Change phone number',
        onPressed: onEditPhone,
      ),
      content: AppSection(
        child: Column(
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
              icon: const Icon(Icons.verified_user_outlined),
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
                      'New code available in 0:${viewModel.resendSeconds.toString().padLeft(2, '0')}',
                      style: context.appTextTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
            ),
          ],
        ),
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
                    onSubmitted: (_) => widget.onComplete(),
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
