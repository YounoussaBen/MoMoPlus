import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/theme/app_theme_controller.dart';
import 'package:momoplus/features/settings/presentation/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('appearance selector updates and persists dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppThemeController();
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppThemeController>.value(
        value: controller,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: controller.themeMode,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(controller.preference, AppThemePreference.dark);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect(
      preferences.getString(AppThemeController.preferenceKey),
      AppThemePreference.dark.name,
    );
  });
}
