import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/features/settings/presentation/design_system_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontLoader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/android/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/android/Roboto-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/android/Roboto-Bold.ttf'));
    await fontLoader.load();
  });

  for (final brightness in Brightness.values) {
    testWidgets('design system preview ${brightness.name}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previewKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: previewKey,
            child: const DesignSystemPreviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(previewKey),
        matchesGoldenFile('design_system_preview_${brightness.name}.png'),
      );
    });
  }
}
