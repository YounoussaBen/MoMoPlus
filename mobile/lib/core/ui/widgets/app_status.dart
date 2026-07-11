import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';

enum AppStatusTone { neutral, brand, info, success, warning, error }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (foreground, background) = switch (tone) {
      AppStatusTone.neutral => (colors.textSecondary, colors.surfaceSubtle),
      AppStatusTone.brand => (colors.brandStrong, colors.brandSoft),
      AppStatusTone.info => (colors.info, colors.infoContainer),
      AppStatusTone.success => (colors.success, colors.successContainer),
      AppStatusTone.warning => (colors.warning, colors.warningContainer),
      AppStatusTone.error => (colors.error, colors.errorContainer),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.pillBorderRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.space1),
            ],
            Text(
              label,
              style: context.appTextTheme.labelMedium?.copyWith(
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
