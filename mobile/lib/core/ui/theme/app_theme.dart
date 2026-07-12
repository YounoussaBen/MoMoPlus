import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_theme_extension.dart';

String get _fontFamily =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'SF-Pro-Text' : 'Roboto';

/// Compatibility colors for screens that have not moved to semantic tokens.
///
/// Redesigned UI must use `context.appColors`; these constants cannot respond
/// to dark mode and will be removed after the migration is complete.
abstract final class AppColors {
  static const background = Color(0xFFF2F8EC);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2A5F49);
  static const textPrimary = Color(0xFF0D100D);
  static const textSecondary = Color(0xFF5B625B);
  static const error = Color(0xFFB42318);

  /// Legacy structural strokes render as a subtle surface during migration.
  static const divider = Color(0xFFE9ECE6);
}

abstract final class AppTheme {
  static ThemeData get light =>
      _build(brightness: Brightness.light, colors: AppThemeExtension.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, colors: AppThemeExtension.dark);

  static ThemeData _build({
    required Brightness brightness,
    required AppThemeExtension colors,
  }) {
    final isDark = brightness == Brightness.dark;
    final font = _fontFamily;
    final textTheme = _textTheme(font, colors);
    final colorScheme = _colorScheme(brightness, colors);
    final transparentSide = const BorderSide(color: Colors.transparent);
    final noOutline = OutlineInputBorder(
      borderRadius: AppRadii.mediumBorderRadius,
      borderSide: transparentSide,
    );
    final focusOutline = OutlineInputBorder(
      borderRadius: AppRadii.mediumBorderRadius,
      borderSide: BorderSide(color: colors.brandStrong, width: 2),
    );
    final errorOutline = OutlineInputBorder(
      borderRadius: AppRadii.mediumBorderRadius,
      borderSide: BorderSide(color: colors.error, width: 2),
    );
    final primaryButtonStyle = _primaryButtonStyle(colors, textTheme);
    final secondaryButtonStyle = _secondaryButtonStyle(colors, textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: font,
      textTheme: textTheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      cardColor: colors.surfaceSection,
      disabledColor: colors.textDisabled,
      dividerColor: Colors.transparent,
      focusColor: colors.brandSoft,
      highlightColor: colors.brandSoft,
      hoverColor: colors.surfaceSubtle,
      shadowColor: Colors.transparent,
      splashColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        titleSpacing: AppSpacing.screenGutter,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
        actionsIconTheme: IconThemeData(color: colors.textPrimary, size: 24),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: colors.canvas,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceInteractive,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space4,
        ),
        constraints: const BoxConstraints(minHeight: 56),
        border: noOutline,
        enabledBorder: noOutline,
        disabledBorder: noOutline,
        focusedBorder: focusOutline,
        errorBorder: errorOutline,
        focusedErrorBorder: errorOutline,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: colors.brandStrong,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
        helperStyle: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.error),
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.brandStrong,
        selectionColor: colors.brandAccent.withValues(alpha: 0.32),
        selectionHandleColor: colors.brandStrong,
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: primaryButtonStyle.copyWith(
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.textDisabled;
            }
            return colors.brandStrong;
          }),
          overlayColor: WidgetStatePropertyAll(
            colors.brandSoft.withValues(alpha: 0.72),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space3),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.mediumBorderRadius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.textDisabled;
            }
            return colors.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colors.surfaceInteractive;
            }
            return Colors.transparent;
          }),
          minimumSize: const WidgetStatePropertyAll(Size.square(48)),
          maximumSize: const WidgetStatePropertyAll(Size.square(48)),
          iconSize: const WidgetStatePropertyAll(24),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.smallBorderRadius),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.brandAccent,
        foregroundColor: colors.onBrandAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.mediumBorderRadius,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceSection,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.largeBorderRadius,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: colors.brandSoft,
        selectedColor: colors.textPrimary,
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
        leadingAndTrailingTextStyle: textTheme.labelMedium?.copyWith(
          color: colors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        ),
        horizontalTitleGap: AppSpacing.space3,
        minVerticalPadding: AppSpacing.space2,
        minTileHeight: 64,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.mediumBorderRadius,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        space: AppSpacing.sectionBand,
        thickness: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: colors.navigationSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        indicatorShape: const StadiumBorder(side: BorderSide.none),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colors.onNavigation
                : colors.onNavigation.withValues(alpha: 0.5),
            size: selected ? 25 : 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected
                ? colors.onNavigation
                : colors.onNavigation.withValues(alpha: 0.5),
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.navigationSurface,
        selectedItemColor: colors.onNavigation,
        unselectedItemColor: colors.onNavigation.withValues(alpha: 0.72),
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 22),
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.navigationSurface,
        elevation: 0,
        indicatorColor: colors.brandAccent,
        selectedIconTheme: IconThemeData(color: colors.onBrandAccent),
        unselectedIconTheme: IconThemeData(
          color: colors.onNavigation.withValues(alpha: 0.72),
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colors.onNavigation,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colors.onNavigation.withValues(alpha: 0.72),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceInteractive,
        selectedColor: colors.brandAccent,
        disabledColor: colors.surfaceDisabled,
        deleteIconColor: colors.textSecondary,
        labelStyle: textTheme.labelMedium?.copyWith(color: colors.textPrimary),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colors.onBrandAccent,
        ),
        side: transparentSide,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        elevation: 0,
        pressElevation: 0,
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.brandAccent;
            }
            return colors.surfaceInteractive;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.onBrandAccent;
            }
            return colors.textSecondary;
          }),
          side: const WidgetStatePropertyAll(BorderSide.none),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textDisabled;
          if (states.contains(WidgetState.selected)) {
            return colors.onBrandAccent;
          }
          return colors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceDisabled;
          }
          if (states.contains(WidgetState.selected)) return colors.brandAccent;
          return colors.surfaceInteractive;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceDisabled;
          }
          if (states.contains(WidgetState.selected)) return colors.brandAccent;
          return colors.surfaceInteractive;
        }),
        checkColor: WidgetStatePropertyAll(colors.onBrandAccent),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textDisabled;
          if (states.contains(WidgetState.selected)) return colors.brandStrong;
          return colors.textMuted;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.brandStrong,
        linearTrackColor: colors.surfaceInteractive,
        circularTrackColor: colors.surfaceInteractive,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceSection,
        modalBackgroundColor: colors.surfaceSection,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: colors.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xLarge),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: colors.textMuted,
        dragHandleSize: const Size(36, 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceSection,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.xLargeBorderRadius,
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceInverse,
        actionTextColor: isDark
            ? AppThemeExtension.light.brandAccent
            : AppThemeExtension.dark.brandStrong,
        disabledActionTextColor: colors.textDisabled,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF0D100D) : const Color(0xFFF6F8F4),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.mediumBorderRadius,
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          AppSpacing.space2,
          AppSpacing.space4,
          AppSpacing.space4,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceSection,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        textStyle: textTheme.bodyMedium,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.mediumBorderRadius,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceSection),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.mediumBorderRadius),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: colors.brandStrong,
        labelColor: colors.textPrimary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        overlayColor: WidgetStatePropertyAll(colors.brandSoft),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceInverse,
          borderRadius: AppRadii.smallBorderRadius,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? const Color(0xFF0D100D) : const Color(0xFFF6F8F4),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  static ColorScheme _colorScheme(
    Brightness brightness,
    AppThemeExtension colors,
  ) {
    final isDark = brightness == Brightness.dark;
    final onInverseSurface = isDark
        ? const Color(0xFF0D100D)
        : const Color(0xFFF6F8F4);
    final onDarkStatus = const Color(0xFF0D100D);
    final onLightStatus = const Color(0xFFFFFFFF);

    return ColorScheme(
      brightness: brightness,
      primary: colors.brandAccent,
      onPrimary: colors.onBrandAccent,
      primaryContainer: colors.brandSoft,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.brandAccent,
      onSecondary: colors.onBrandAccent,
      secondaryContainer: colors.brandSoft,
      onSecondaryContainer: colors.textPrimary,
      tertiary: colors.info,
      onTertiary: isDark ? onDarkStatus : onLightStatus,
      tertiaryContainer: colors.infoContainer,
      onTertiaryContainer: colors.info,
      error: colors.error,
      onError: isDark ? onDarkStatus : onLightStatus,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.error,
      surface: colors.surfaceSection,
      onSurface: colors.textPrimary,
      surfaceDim: colors.canvas,
      surfaceBright: colors.surfaceSection,
      surfaceContainerLowest: colors.canvas,
      surfaceContainerLow: colors.surfaceSection,
      surfaceContainer: colors.surfaceSubtle,
      surfaceContainerHigh: colors.surfaceInteractive,
      surfaceContainerHighest: colors.surfaceDisabled,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.textMuted,
      outlineVariant: colors.surfaceSubtle,
      shadow: Colors.transparent,
      scrim: colors.scrim,
      inverseSurface: colors.surfaceInverse,
      onInverseSurface: onInverseSurface,
      inversePrimary: isDark
          ? AppThemeExtension.light.brandAccent
          : AppThemeExtension.dark.brandStrong,
      surfaceTint: Colors.transparent,
    );
  }

  static TextTheme _textTheme(String font, AppThemeExtension colors) {
    TextStyle style({
      required double size,
      required double height,
      required FontWeight weight,
      Color? color,
      double? letterSpacing,
      List<FontFeature>? fontFeatures,
    }) {
      return TextStyle(
        fontFamily: font,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color ?? colors.textPrimary,
        letterSpacing: letterSpacing,
        fontFeatures: fontFeatures,
      );
    }

    return TextTheme(
      displayLarge: style(
        size: 34,
        height: 38,
        weight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displayMedium: style(
        size: 40,
        height: 44,
        weight: FontWeight.w700,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: style(
        size: 32,
        height: 38,
        weight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: style(
        size: 28,
        height: 34,
        weight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: style(
        size: 24,
        height: 30,
        weight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: style(
        size: 22,
        height: 28,
        weight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: style(size: 22, height: 28, weight: FontWeight.w700),
      titleMedium: style(size: 18, height: 24, weight: FontWeight.w600),
      titleSmall: style(size: 16, height: 22, weight: FontWeight.w600),
      bodyLarge: style(size: 16, height: 24, weight: FontWeight.w400),
      bodyMedium: style(
        size: 14,
        height: 20,
        weight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      bodySmall: style(
        size: 12,
        height: 16,
        weight: FontWeight.w400,
        color: colors.textMuted,
      ),
      labelLarge: style(size: 14, height: 18, weight: FontWeight.w600),
      labelMedium: style(size: 12, height: 16, weight: FontWeight.w600),
      labelSmall: style(
        size: 11,
        height: 16,
        weight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }

  static ButtonStyle _primaryButtonStyle(
    AppThemeExtension colors,
    TextTheme textTheme,
  ) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.surfaceDisabled;
        }
        return colors.brandAccent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.textDisabled;
        return colors.onBrandAccent;
      }),
      overlayColor: WidgetStatePropertyAll(
        colors.onBrandAccent.withValues(alpha: 0.08),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadii.mediumBorderRadius),
      ),
    );
  }

  static ButtonStyle _secondaryButtonStyle(
    AppThemeExtension colors,
    TextTheme textTheme,
  ) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.surfaceDisabled;
        }
        return colors.surfaceInteractive;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.textDisabled;
        return colors.textPrimary;
      }),
      overlayColor: WidgetStatePropertyAll(
        colors.textPrimary.withValues(alpha: 0.06),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.space5),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadii.mediumBorderRadius),
      ),
    );
  }
}
