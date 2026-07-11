import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeController', () {
    test('defaults to the system theme when no preference is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppThemeController();

      await controller.load();

      expect(controller.preference, AppThemePreference.system);
      expect(controller.themeMode, ThemeMode.system);
      expect(controller.isLoaded, isTrue);
    });

    test('restores a saved dark preference', () async {
      SharedPreferences.setMockInitialValues({
        AppThemeController.preferenceKey: AppThemePreference.dark.name,
      });
      final controller = AppThemeController();

      await controller.load();

      expect(controller.preference, AppThemePreference.dark);
      expect(controller.themeMode, ThemeMode.dark);
    });

    test('persists a new preference', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppThemeController();
      await controller.load();

      await controller.setPreference(AppThemePreference.light);

      final preferences = await SharedPreferences.getInstance();
      expect(controller.themeMode, ThemeMode.light);
      expect(
        preferences.getString(AppThemeController.preferenceKey),
        AppThemePreference.light.name,
      );
    });
  });
}
