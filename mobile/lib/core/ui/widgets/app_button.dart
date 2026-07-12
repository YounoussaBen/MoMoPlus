import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final Widget? icon;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final content = _ButtonContent(
      label: label,
      icon: icon,
      trailingIcon: trailingIcon,
      isLoading: isLoading,
      progressColor: _progressColor(context),
      constrainLabel: variant != AppButtonVariant.ghost,
    );

    return switch (variant) {
      AppButtonVariant.primary => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(onPressed: effectiveOnPressed, child: content),
      ),
      AppButtonVariant.secondary => SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(onPressed: effectiveOnPressed, child: content),
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
      AppButtonVariant.destructive => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.appColors.errorContainer,
            foregroundColor: context.appColors.error,
            disabledBackgroundColor: context.appColors.surfaceDisabled,
            disabledForegroundColor: context.appColors.textDisabled,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.mediumBorderRadius,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          ),
          child: content,
        ),
      ),
    };
  }

  Color _progressColor(BuildContext context) => switch (variant) {
    AppButtonVariant.primary => context.appColors.onBrandAccent,
    AppButtonVariant.secondary => context.appColors.textPrimary,
    AppButtonVariant.ghost => context.appColors.brandStrong,
    AppButtonVariant.destructive => context.appColors.error,
  };
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.trailingIcon,
    required this.isLoading,
    required this.progressColor,
    required this.constrainLabel,
  });

  final String label;
  final Widget? icon;
  final Widget? trailingIcon;
  final bool isLoading;
  final Color progressColor;
  final bool constrainLabel;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Semantics(
        label: '$label, in progress',
        liveRegion: true,
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            color: progressColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final labelWidget = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: AppSpacing.space2)],
        if (constrainLabel) Flexible(child: labelWidget) else labelWidget,
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.space2),
          trailingIcon!,
        ],
      ],
    );
  }
}
