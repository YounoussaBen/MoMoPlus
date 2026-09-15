import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_text_field.dart';
import 'auth_view_model.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appUser = context.read<AuthViewModel>().appUser;
    _firstNameController.text = appUser?.firstName ?? '';
    _lastNameController.text = appUser?.lastName ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final isResubmission =
        GoRouterState.of(context).uri.queryParameters['resubmit'] == '1';
    final didComplete = await context.read<AuthViewModel>().completeProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
    );
    if (didComplete && isResubmission && mounted) {
      context.go('/kyc?resubmit=1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isResubmission =
        GoRouterState.of(context).uri.queryParameters['resubmit'] == '1';
    return AppScreen(
      body: SafeArea(
        child: Consumer<AuthViewModel>(
          builder: (context, viewModel, _) => ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpacing.screenHorizontal.copyWith(
              top: AppSpacing.space3,
              bottom: AppSpacing.space8,
            ),
            children: [
              const Align(
                alignment: Alignment.topRight,
                child: AppLogo(size: 84),
              ),
              const SizedBox(height: AppSpacing.space10),
              Text(
                isResubmission
                    ? 'Review your details'
                    : 'Complete your profile',
                style: context.appTextTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                isResubmission
                    ? 'Confirm your name before resubmitting your verification.'
                    : 'Enter your details to continue.',
                style: context.appTextTheme.bodyLarge?.copyWith(
                  color: context.appColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.space8),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      hint: 'First names',
                      controller: _firstNameController,
                      autofillHints: const [AutofillHints.givenName],
                      validator: _requiredName,
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    AppTextField(
                      hint: 'Last name',
                      controller: _lastNameController,
                      autofillHints: const [AutofillHints.familyName],
                      textInputAction: TextInputAction.done,
                      validator: _requiredName,
                      onFieldSubmitted: (_) => _continue(),
                    ),
                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.space3),
                      Text(
                        viewModel.errorMessage!,
                        style: context.appTextTheme.bodySmall?.copyWith(
                          color: context.appColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.space5),
                    AppButton(
                      label: 'Continue',
                      onPressed: _continue,
                      isLoading: viewModel.isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredName(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 2) return 'Enter at least 2 characters.';
    return null;
  }
}
