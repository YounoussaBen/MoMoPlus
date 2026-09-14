import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late final Animation<double> _scale;
  late final Animation<double> _firstMProgress;
  late final Animation<double> _firstOProgress;
  late final Animation<double> _secondMProgress;
  late final Animation<double> _secondOProgress;
  late final Animation<double> _plusProgress;
  late final Animation<double> _taglineOpacity;
  bool _hasStarted = false;
  Future<void>? _animationDone;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.splash, vsync: this);
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.78, curve: AppMotion.enter),
    );
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.86, curve: AppMotion.enter),
      ),
    );
    _firstMProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.22, curve: AppMotion.enter),
    );
    _firstOProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.42, curve: AppMotion.enter),
    );
    _secondMProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.62, curve: AppMotion.enter),
    );
    _secondOProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.82, curve: AppMotion.enter),
    );
    _plusProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1, curve: AppMotion.enter),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.88, 1, curve: AppMotion.enter),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStarted) return;
    _hasStarted = true;

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!reducedMotion) {
      _animationDone = _controller.forward();
    }
    _navigate(animationDone: _animationDone);
  }

  Future<void> _navigate({Future<void>? animationDone}) async {
    final authViewModel = context.read<AuthViewModel>();
    final preferences = SharedPreferences.getInstance();

    if (authViewModel.isAuthenticated) {
      await authViewModel.refreshProfile(loadKycDetails: false);
    }
    final prefs = await preferences;
    if (animationDone != null) await animationDone;
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
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? colors.canvas : colors.brandAccent;
    final useLightSystemIcons = background.computeLuminance() < 0.5;
    final foreground = useLightSystemIcons
        ? colors.onBrandAccent
        : colors.textPrimary;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final completed = const AlwaysStoppedAnimation<double>(1);
    final logo = Semantics(
      container: true,
      label: 'MoMo Plus. Money help, close by.',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SplashBrandMark(
              asset: useLightSystemIcons
                  ? 'assets/logo-light.png'
                  : 'assets/logo.png',
              firstMProgress: reducedMotion ? completed : _firstMProgress,
              firstOProgress: reducedMotion ? completed : _firstOProgress,
              secondMProgress: reducedMotion ? completed : _secondMProgress,
              secondOProgress: reducedMotion ? completed : _secondOProgress,
              plusProgress: reducedMotion ? completed : _plusProgress,
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: reducedMotion ? completed : _taglineOpacity,
              child: Text(
                'Money help, close by.',
                style: context.appTextTheme.titleMedium?.copyWith(
                  color: foreground.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final animatedLogo = reducedMotion
        ? logo
        : FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(scale: _scale, child: logo),
          );

    final overlayStyle = useLightSystemIcons
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useLightSystemIcons
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: useLightSystemIcons
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: useLightSystemIcons
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SplashTexture(
              softColor: useLightSystemIcons
                  ? colors.onBrandAccent
                  : colors.brandAccent,
              contrastColor: useLightSystemIcons
                  ? colors.brandStrong
                  : colors.surfaceInverse,
            ),
            Center(child: animatedLogo),
          ],
        ),
      ),
    );
  }
}

class _SplashBrandMark extends StatelessWidget {
  const _SplashBrandMark({
    required this.asset,
    required this.firstMProgress,
    required this.firstOProgress,
    required this.secondMProgress,
    required this.secondOProgress,
    required this.plusProgress,
  });

  static const _sourceLeft = 198.0;
  static const _sourceTop = 400.0;
  static const _sourceBottom = 600.0;
  static const _sourceRight = 830.0;

  final String asset;
  final Animation<double> firstMProgress;
  final Animation<double> firstOProgress;
  final Animation<double> secondMProgress;
  final Animation<double> secondOProgress;
  final Animation<double> plusProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 252.0;
        final markWidth = math.min(252.0, math.max(0.0, availableWidth - 32));
        final scale = markWidth / (_sourceRight - _sourceLeft);
        final markHeight = (_sourceBottom - _sourceTop) * scale;

        return SizedBox(
          width: markWidth,
          height: markHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _SplashLogoPiece(
                asset: asset,
                sourceLeft: 198,
                sourceRight: 365,
                startOffset: -18,
                scale: scale,
                progress: firstMProgress,
              ),
              _SplashLogoPiece(
                asset: asset,
                sourceLeft: 348,
                sourceRight: 515,
                startOffset: -8,
                scale: scale,
                progress: firstOProgress,
              ),
              _SplashLogoPiece(
                asset: asset,
                sourceLeft: 498,
                sourceRight: 665,
                startOffset: 8,
                scale: scale,
                progress: secondMProgress,
              ),
              _SplashLogoPiece(
                asset: asset,
                sourceLeft: 646,
                sourceRight: 720,
                startOffset: 18,
                scale: scale,
                progress: secondOProgress,
              ),
              _SplashLogoPiece(
                asset: asset,
                sourceLeft: 706,
                sourceRight: 830,
                startOffset: 24,
                scale: scale,
                progress: plusProgress,
                isPlus: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SplashLogoPiece extends StatelessWidget {
  const _SplashLogoPiece({
    required this.asset,
    required this.sourceLeft,
    required this.sourceRight,
    required this.startOffset,
    required this.scale,
    required this.progress,
    this.isPlus = false,
  });

  static const _sourceTop = _SplashBrandMark._sourceTop;

  final String asset;
  final double sourceLeft;
  final double sourceRight;
  final double startOffset;
  final double scale;
  final Animation<double> progress;
  final bool isPlus;

  @override
  Widget build(BuildContext context) {
    final width = (sourceRight - sourceLeft) * scale;
    final height = (_SplashBrandMark._sourceBottom - _sourceTop) * scale;

    return Positioned(
      left: (sourceLeft - _SplashBrandMark._sourceLeft) * scale,
      top: 0,
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: progress,
        child: _assetSlice(),
        builder: (context, child) {
          final progressValue = progress.value;
          final offset = startOffset * scale * (1 - progressValue);
          final plusScale = isPlus ? 0.72 + (0.28 * progressValue) : 1.0;

          return Opacity(
            opacity: progressValue,
            child: Transform.translate(
              offset: Offset(offset, 0),
              child: isPlus
                  ? Transform.scale(
                      scale: plusScale,
                      alignment: Alignment.center,
                      child: child,
                    )
                  : child,
            ),
          );
        },
      ),
    );
  }

  Widget _assetSlice() {
    final imageSize = 1024 * scale;
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: -sourceLeft * scale,
            top: -_sourceTop * scale,
            width: imageSize,
            height: imageSize,
            child: Image.asset(
              asset,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashTexture extends StatelessWidget {
  const _SplashTexture({required this.softColor, required this.contrastColor});

  final Color softColor;
  final Color contrastColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _SplashTexturePainter(
          softColor: softColor,
          contrastColor: contrastColor,
        ),
      ),
    );
  }
}

class _SplashTexturePainter extends CustomPainter {
  const _SplashTexturePainter({
    required this.softColor,
    required this.contrastColor,
  });

  final Color softColor;
  final Color contrastColor;

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = softColor.withValues(alpha: 0.07);
    final dark = Paint()..color = contrastColor.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.16), 128, soft);
    canvas.drawCircle(Offset(size.width * 1.02, size.height * 0.3), 172, dark);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.98), 210, dark);
  }

  @override
  bool shouldRepaint(covariant _SplashTexturePainter oldDelegate) =>
      oldDelegate.softColor != softColor ||
      oldDelegate.contrastColor != contrastColor;
}
