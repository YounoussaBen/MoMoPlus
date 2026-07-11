import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';

class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.backgroundColor,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.space4,
      vertical: AppSpacing.space3,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? backgroundColor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveTrailing =
        trailing ??
        (showChevron
            ? Icon(
                Icons.chevron_right_rounded,
                color: colors.textMuted,
                size: 20,
              )
            : null);

    return Semantics(
      button: onTap != null,
      child: Material(
        color: backgroundColor ?? colors.surfaceInteractive,
        borderRadius: AppRadii.mediumBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          overlayColor: WidgetStatePropertyAll(
            colors.brandSoft.withValues(alpha: 0.72),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: contentPadding,
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.space3),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.appTextTheme.titleSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.space1),
                          Text(
                            subtitle!,
                            style: context.appTextTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (effectiveTrailing != null) ...[
                    const SizedBox(width: AppSpacing.space3),
                    effectiveTrailing,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
