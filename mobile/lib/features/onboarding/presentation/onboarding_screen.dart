import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_screen.dart';
import 'onboarding_view_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _viewModel = OnboardingViewModel();

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
                  const _OnboardingLogo(),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
            ),
            const Expanded(child: _OnboardingPage()),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.space5,
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

class _OnboardingLogo extends StatelessWidget {
  const _OnboardingLogo();

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/logo-light.png'
        : 'assets/logo.png';
    return SizedBox(
      width: 140,
      height: 56,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 230,
          maxWidth: 230,
          minHeight: 230,
          maxHeight: 230,
          child: Image.asset(
            asset,
            width: 230,
            height: 230,
            semanticLabel: 'MoMo Plus',
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenHorizontal.copyWith(top: AppSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 340,
                  maxHeight: 330,
                ),
                child: const _CashHelpVisual(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space8),
          Text(
            'Cash help,\nwithout the scramble.',
            style: context.appTextTheme.displaySmall?.copyWith(height: 1.08),
          ),
        ],
      ),
    );
  }
}

class _CashHelpVisual extends StatelessWidget {
  const _CashHelpVisual();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Cash help from a nearby agent',
      child: ExcludeSemantics(
        child: SizedBox.expand(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CashRoutePainter(
                    routeColor: context.appColors.brandSoft,
                    dotColor: context.appColors.brandStrong,
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(-0.88, -0.56),
                child: _HelpNode(
                  size: 92,
                  backgroundColor: context.appColors.surfaceSection,
                  foregroundColor: context.appColors.brandStrong,
                  icon: Icons.person_rounded,
                  label: 'You',
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 116,
                  height: 116,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.appColors.brandAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    'GH₵',
                    style: context.appTextTheme.headlineMedium?.copyWith(
                      color: context.appColors.onBrandAccent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0.88, 0.5),
                child: _HelpNode(
                  size: 104,
                  backgroundColor: context.appColors.surfaceInverse,
                  foregroundColor: context.appColors.canvas,
                  icon: Icons.storefront_rounded,
                  label: 'Agent',
                ),
              ),
              Align(
                alignment: const Alignment(-0.2, 0.94),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceSection,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: context.appColors.success,
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Text(
                        'Ready when you need it',
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
    );
  }
}

class _HelpNode extends StatelessWidget {
  const _HelpNode({
    required this.size,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
  });

  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: size * 0.42, color: foregroundColor),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            label,
            style: context.appTextTheme.labelMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashRoutePainter extends CustomPainter {
  const _CashRoutePainter({required this.routeColor, required this.dotColor});

  final Color routeColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final route = Path()
      ..moveTo(size.width * 0.19, size.height * 0.28)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.18,
        size.width * 0.58,
        size.height * 0.82,
        size.width * 0.83,
        size.height * 0.64,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = routeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );

    final dots = Paint()..color = dotColor.withValues(alpha: 0.24);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.72), 8, dots);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.15), 5, dots);
    canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.28), 11, dots);
  }

  @override
  bool shouldRepaint(covariant _CashRoutePainter oldDelegate) =>
      routeColor != oldDelegate.routeColor || dotColor != oldDelegate.dotColor;
}
