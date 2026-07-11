import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/ui/widgets/app_logo.dart';
import '../../../core/ui/theme/app_motion.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
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
      duration: AppMotion.emphasized,
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final authVm = context.read<AuthViewModel>();

    final minimumDisplay = Future<void>.delayed(AppMotion.emphasized);
    final preferencesFuture = SharedPreferences.getInstance();

    if (authVm.isAuthenticated) {
      await Future.wait([minimumDisplay, authVm.refreshProfile()]);
    } else {
      await minimumDisplay;
    }
    final prefs = await preferencesFuture;
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    if (!mounted) return;

    if (authVm.isAuthenticated) {
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
      backgroundColor: context.appColors.canvas,
      body: Center(
        child: MediaQuery.disableAnimationsOf(context)
            ? AppLogo(
                size: 140,
                useWhite: Theme.of(context).brightness == Brightness.dark,
              )
            : FadeTransition(
                opacity: _opacity,
                child: AppLogo(
                  size: 140,
                  useWhite: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
      ),
    );
  }
}
