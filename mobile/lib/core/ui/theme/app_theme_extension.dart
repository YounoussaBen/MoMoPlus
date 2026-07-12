import 'package:flutter/material.dart';

/// MoMo Plus semantic colors that do not map cleanly to Material roles.
///
/// Read these values through `context.appColors` so appearance changes are
/// resolved from the active theme rather than from global color constants.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.canvas,
    required this.surfaceSection,
    required this.surfaceSubtle,
    required this.surfaceInteractive,
    required this.surfaceDisabled,
    required this.surfaceInverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.brandAccent,
    required this.onBrandAccent,
    required this.brandStrong,
    required this.brandSoft,
    required this.navigationSurface,
    required this.onNavigation,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.scrim,
  });

  static const light = AppThemeExtension(
    canvas: Color(0xFFF2F8EC),
    surfaceSection: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFE9ECE6),
    surfaceInteractive: Color(0xFFE2E7DF),
    surfaceDisabled: Color(0xFFE1E3DF),
    surfaceInverse: Color(0xFF171A17),
    textPrimary: Color(0xFF0D100D),
    textSecondary: Color(0xFF5B625B),
    textMuted: Color(0xFF697069),
    textDisabled: Color(0xFF939993),
    brandAccent: Color(0xFF2A5F49),
    onBrandAccent: Color(0xFFFFFFFF),
    brandStrong: Color(0xFF24513F),
    brandSoft: Color(0xFFDCEBE4),
    navigationSurface: Color(0xFFFFFFFF),
    onNavigation: Color(0xFF24513F),
    success: Color(0xFF247A3B),
    successContainer: Color(0xFFE3F6E8),
    warning: Color(0xFF8A5900),
    warningContainer: Color(0xFFFFF0D3),
    error: Color(0xFFB42318),
    errorContainer: Color(0xFFFDE7E5),
    info: Color(0xFF0B63A5),
    infoContainer: Color(0xFFE2F1FC),
    scrim: Color(0x8F000000),
  );

  static const dark = AppThemeExtension(
    canvas: Color(0xFF090B09),
    surfaceSection: Color(0xFF121512),
    surfaceSubtle: Color(0xFF1A1E1A),
    surfaceInteractive: Color(0xFF232823),
    surfaceDisabled: Color(0xFF252825),
    surfaceInverse: Color(0xFFF4F7F2),
    textPrimary: Color(0xFFF6F8F4),
    textSecondary: Color(0xFFA8AFA8),
    textMuted: Color(0xFF858C85),
    textDisabled: Color(0xFF666D66),
    brandAccent: Color(0xFF34795D),
    onBrandAccent: Color(0xFFFFFFFF),
    brandStrong: Color(0xFF83D0AB),
    brandSoft: Color(0xFF19372B),
    navigationSurface: Color(0xFF151815),
    onNavigation: Color(0xFFF5F7F3),
    success: Color(0xFF74E59A),
    successContainer: Color(0xFF193322),
    warning: Color(0xFFFFCA72),
    warningContainer: Color(0xFF3A2A0F),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF3D201D),
    info: Color(0xFF91CAFF),
    infoContainer: Color(0xFF173047),
    scrim: Color(0xA3000000),
  );

  final Color canvas;
  final Color surfaceSection;
  final Color surfaceSubtle;
  final Color surfaceInteractive;
  final Color surfaceDisabled;
  final Color surfaceInverse;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color brandAccent;
  final Color onBrandAccent;
  final Color brandStrong;
  final Color brandSoft;
  final Color navigationSurface;
  final Color onNavigation;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;
  final Color scrim;

  Color get actionPrimary => brandAccent;
  Color get onActionPrimary => onBrandAccent;
  Color get statusSuccess => success;
  Color get statusWarning => warning;
  Color get statusError => error;
  Color get statusInfo => info;

  @override
  AppThemeExtension copyWith({
    Color? canvas,
    Color? surfaceSection,
    Color? surfaceSubtle,
    Color? surfaceInteractive,
    Color? surfaceDisabled,
    Color? surfaceInverse,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? brandAccent,
    Color? onBrandAccent,
    Color? brandStrong,
    Color? brandSoft,
    Color? navigationSurface,
    Color? onNavigation,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? infoContainer,
    Color? scrim,
  }) {
    return AppThemeExtension(
      canvas: canvas ?? this.canvas,
      surfaceSection: surfaceSection ?? this.surfaceSection,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceInteractive: surfaceInteractive ?? this.surfaceInteractive,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      brandAccent: brandAccent ?? this.brandAccent,
      onBrandAccent: onBrandAccent ?? this.onBrandAccent,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      navigationSurface: navigationSurface ?? this.navigationSurface,
      onNavigation: onNavigation ?? this.onNavigation,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceSection: Color.lerp(surfaceSection, other.surfaceSection, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceInteractive: Color.lerp(
        surfaceInteractive,
        other.surfaceInteractive,
        t,
      )!,
      surfaceDisabled: Color.lerp(surfaceDisabled, other.surfaceDisabled, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      onBrandAccent: Color.lerp(onBrandAccent, other.onBrandAccent, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      navigationSurface: Color.lerp(
        navigationSurface,
        other.navigationSurface,
        t,
      )!,
      onNavigation: Color.lerp(onNavigation, other.onNavigation, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Approved hero treatments. Ordinary cards and rows should use solid semantic
/// surfaces; gradients are limited to one hero treatment per screen.
abstract final class AppGradients {
  static const forestHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A5F49), Color(0xFF183B29)],
  );

  static const darkChartFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x3383D0AB), Color(0x0083D0AB)],
  );
}

extension AppThemeDataAccess on ThemeData {
  AppThemeExtension get appColors {
    final colors = extension<AppThemeExtension>();
    assert(colors != null, 'AppThemeExtension is missing from ThemeData.');
    return colors!;
  }
}

extension AppThemeContextAccess on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  AppThemeExtension get appColors => appTheme.appColors;
  TextTheme get appTextTheme => appTheme.textTheme;
}

/// Semantic aliases for type roles that do not have a one-to-one Material name.
extension AppTextThemeAccess on TextTheme {
  TextStyle get displayAmount => displayMedium!;
  TextStyle get screenTitle => headlineLarge!;
  TextStyle get caption => bodySmall!;
}
