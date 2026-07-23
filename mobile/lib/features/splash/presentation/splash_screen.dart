import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ui/theme/app_motion.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
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
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.emphasized,
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.enter));
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final authViewModel = context.read<AuthViewModel>();
    final preferences = SharedPreferences.getInstance();

    if (authViewModel.isAuthenticated) {
      await authViewModel.refreshProfile(loadKycDetails: false);
    }
    final prefs = await preferences;
    if (!mounted) return;

    if (authViewModel.isAuthenticated) {
      if (authViewModel.hasConnectionError) {
        context.go('/connection-error');
      } else if (authViewModel.appUser?.isOnboarded != true) {
        context.go('/auth/profile-setup');
      } else if (!authViewModel.isKycApproved ||
          authViewModel.shouldShowApprovedKycScreen) {
        context.go('/kyc');
      } else {
        context.go(
          authViewModel.appUser?.isAgent == true ? '/agent/home' : '/user/home',
        );
      }
      return;
    }

    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    context.go(onboardingSeen ? '/auth/sign-in' : '/onboarding');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.appColors.brandAccent;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 132),
        const SizedBox(height: 20),
        Text(
          'Money help, close by.',
          style: context.appTextTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: brand,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: brand,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashTexture(),
            Center(
              child: reducedMotion
                  ? logo
                  : FadeTransition(
                      opacity: _opacity,
                      child: ScaleTransition(scale: _scale, child: logo),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashTexture extends StatelessWidget {
  const _SplashTexture();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(painter: _SplashTexturePainter()),
    );
  }
}

class _SplashTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.055);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.055);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.16), 128, soft);
    canvas.drawCircle(Offset(size.width * 1.02, size.height * 0.3), 172, dark);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.98), 210, dark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
