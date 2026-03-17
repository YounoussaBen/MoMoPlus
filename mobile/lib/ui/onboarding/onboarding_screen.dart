import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'onboarding_view_model.dart';
import '../core/themes/app_theme.dart';
import '../core/widgets/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _vm = OnboardingViewModel();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _getStarted() async {
    await _vm.complete();
    if (mounted) context.go('/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Lottie.asset(
                'assets/animations/request-money.json',
                width: double.infinity,
                height: 300,
                fit: BoxFit.contain,
                repeat: true,
              ),
              const Spacer(),
              Text(
                'Emergency funds,\ninstantly.',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'When life catches\nyou off guard. No hidden fees.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(label: 'Get Started', onPressed: _getStarted),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
