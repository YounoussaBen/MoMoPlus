import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../auth/presentation/auth_view_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final authVm = context.read<AuthViewModel>();

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    if (!mounted) return;

    if (authVm.isAuthenticated) {
      await authVm.refreshProfile();
      if (!mounted) return;

      if (authVm.hasConnectionError) {
        context.go('/connection-error');
        return;
      }

      final isAgent = authVm.appUser?.isAgent == true;
      if (!authVm.isKycApproved || authVm.shouldShowApprovedKycScreen) {
        context.go('/kyc');
        return;
      }
      context.go(isAgent ? '/agent/home' : '/user/home');
    } else if (!onboardingSeen) {
      context.go('/onboarding');
    } else {
      context.go('/auth/sign-in');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: const AppLogo(size: 140),
        ),
      ),
    );
  }
}
