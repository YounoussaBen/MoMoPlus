import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'app_button.dart';
import 'app_icon_button.dart';

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isActionLoading = false,
    this.iconColor,
    this.iconBackgroundColor,
  });

  const AppStateView.empty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isActionLoading = false,
    this.iconColor,
    this.iconBackgroundColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isActionLoading;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconTile(
              icon: icon,
              size: 80,
              iconSize: 36,
              backgroundColor: iconBackgroundColor ?? colors.surfaceSubtle,
              foregroundColor: iconColor ?? colors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.space6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.appTextTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.space6),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                isLoading: isActionLoading,
              ),
            ],
            if (secondaryActionLabel != null) ...[
              const SizedBox(height: AppSpacing.space2),
              AppButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
                variant: AppButtonVariant.ghost,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label,
        liveRegion: true,
        child: const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
