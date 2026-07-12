import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/theme/app_radii.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../../core/ui/widgets/app_screen.dart';
import 'onboarding_view_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _viewModel = OnboardingViewModel();

  static const _page = _OnboardingPageData(
    title: 'Cash help,\nwithout the scramble.',
    body: '',
    icon: Icons.near_me_rounded,
    supportingIcon: Icons.location_on_outlined,
    label: 'Nearby',
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _viewModel.complete();
    if (mounted) context.go('/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.space2,
                AppSpacing.space2,
                0,
              ),
              child: Row(
                children: [
                  const AppLogo(size: 84),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(child: _OnboardingPage(data: _page)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.space3,
                AppSpacing.screenGutter,
                AppSpacing.space6,
              ),
              child: AppButton(label: 'Continue', onPressed: _finish),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenHorizontal.copyWith(top: AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(child: _OnboardingVisual(data: data)),
          ),
          const SizedBox(height: AppSpacing.space6),
          Text(data.title, style: context.appTextTheme.displaySmall),
          const SizedBox(height: AppSpacing.space3),
          Text(
            data.body,
            style: context.appTextTheme.bodyLarge?.copyWith(
              color: context.appColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: data.label,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.12,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.space6),
            decoration: BoxDecoration(
              color: context.appColors.brandSoft,
              borderRadius: AppRadii.xLargeBorderRadius,
            ),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(-0.45, -0.15),
                  child: Container(
                    width: 116,
                    height: 116,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.appColors.brandAccent,
                      borderRadius: AppRadii.xLargeBorderRadius,
                    ),
                    child: Icon(
                      data.icon,
                      size: 54,
                      color: context.appColors.onBrandAccent,
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0.7, 0.7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                      vertical: AppSpacing.space3,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.surfaceSection,
                      borderRadius: AppRadii.mediumBorderRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          data.supportingIcon,
                          size: 20,
                          color: context.appColors.brandStrong,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          data.label,
                          style: context.appTextTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.icon,
    required this.supportingIcon,
    required this.label,
  });

  final String title;
  final String body;
  final IconData icon;
  final IconData supportingIcon;
  final String label;
}
