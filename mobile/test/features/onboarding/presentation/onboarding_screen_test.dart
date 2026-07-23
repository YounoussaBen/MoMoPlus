import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontLoader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/android/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/android/Roboto-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/android/Roboto-Bold.ttf'));
    await fontLoader.load();
  });

  testWidgets('shows only the first onboarding experience', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const OnboardingScreen()),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/logo.png'),
        tester.element(find.byType(OnboardingScreen)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash help,\nwithout the scramble.'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Ready when you need it'), findsOneWidget);
    expect(find.text('Nearby'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('Know the cost\nbefore you commit.'), findsNothing);
    expect(find.text('Your number.\nYour secure access.'), findsNothing);
    expect(find.byType(PageView), findsNothing);

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/onboarding_screen.png'),
    );
  });
}
