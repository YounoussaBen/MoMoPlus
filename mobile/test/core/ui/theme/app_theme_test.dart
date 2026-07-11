import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_map_style.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/theme/app_theme_extension.dart';

void main() {
  group('AppTheme', () {
    test('provides complete semantic extensions in both appearances', () {
      final light = AppTheme.light.appColors;
      final dark = AppTheme.dark.appColors;

      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(light.canvas, isNot(dark.canvas));
      expect(light.surfaceSection, isNot(dark.surfaceSection));
      expect(light.brandAccent, isNot(dark.brandAccent));
    });

    test('critical text and action pairs meet normal-text contrast', () {
      final light = AppThemeExtension.light;
      final dark = AppThemeExtension.dark;

      expect(
        _contrast(light.textPrimary, light.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.textSecondary, light.surfaceSection),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.onBrandAccent, light.brandAccent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(dark.textPrimary, dark.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(dark.textSecondary, dark.surfaceSection),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(dark.onBrandAccent, dark.brandAccent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(light.brandAccent, light.canvas),
        greaterThanOrEqualTo(3),
      );
      expect(_contrast(dark.brandAccent, dark.canvas), greaterThanOrEqualTo(3));
    });

    test('structural components default to zero elevation and no dividers', () {
      final theme = AppTheme.light;

      expect(theme.cardTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.dividerTheme.color, Colors.transparent);
      expect(theme.dividerTheme.thickness, 0);
    });

    test('map appearances are valid JSON and follow brightness', () {
      expect(jsonDecode(AppMapStyle.light), isA<List<dynamic>>());
      expect(jsonDecode(AppMapStyle.dark), isA<List<dynamic>>());
      expect(AppMapStyle.forBrightness(Brightness.light), AppMapStyle.light);
      expect(AppMapStyle.forBrightness(Brightness.dark), AppMapStyle.dark);
    });
  });
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lightest = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darkest = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lightest + 0.05) / (darkest + 0.05);
}
