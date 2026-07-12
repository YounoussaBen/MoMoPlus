import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('shows only the first onboarding experience', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const OnboardingScreen()),
    );

    expect(find.text('Cash help,\nwithout the scramble.'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('01'), findsNothing);
    expect(find.text('Know the cost\nbefore you commit.'), findsNothing);
    expect(find.text('Your number.\nYour secure access.'), findsNothing);
    expect(find.byType(PageView), findsNothing);
  });
}
