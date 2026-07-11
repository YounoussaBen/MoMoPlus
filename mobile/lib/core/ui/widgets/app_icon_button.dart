import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme_extension.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor:
            backgroundColor ?? context.appColors.surfaceInteractive,
        foregroundColor: foregroundColor ?? context.appColors.textPrimary,
        disabledBackgroundColor: context.appColors.surfaceDisabled,
        disabledForegroundColor: context.appColors.textDisabled,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.smallBorderRadius,
        ),
      ),
    );
  }
}

class AppIconTile extends StatelessWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final String? semanticLabel;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.appColors.surfaceInteractive,
        borderRadius: AppRadii.smallBorderRadius,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: foregroundColor ?? context.appColors.textSecondary,
      ),
    );

    if (semanticLabel == null) return ExcludeSemantics(child: tile);
    return Semantics(label: semanticLabel, image: true, child: tile);
  }
}
