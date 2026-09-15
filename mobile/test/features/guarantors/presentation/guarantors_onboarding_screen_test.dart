import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/theme/app_theme_extension.dart';
import 'package:momoplus/core/ui/widgets/ghana_phone_field.dart';
import 'package:momoplus/features/guarantors/presentation/guarantors_onboarding_screen.dart';

void main() {
  testWidgets('loan guarantors onboarding uses dark theme surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const GuarantorsOnboardingScreen(),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.appColors.canvas);
    expect(find.text('Loan Guarantors'), findsOneWidget);
    expect(find.text('Guarantor 1 of 2'), findsOneWidget);
    expect(find.text('Guarantor 2'), findsNothing);
    expect(
      find.textContaining('We will verify one guarantor at a time.'),
      findsOneWidget,
    );

    final whiteSurfaces = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).color == Colors.white,
        );
    expect(whiteSurfaces, isEmpty);
  });

  testWidgets('guarantor phone fields match Ghana login validation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GuarantorsOnboardingScreen(),
      ),
    );

    final phoneFields = find.descendant(
      of: find.byType(GhanaPhoneField),
      matching: find.byType(TextFormField),
    );
    expect(phoneFields, findsOneWidget);
    expect(find.text('🇬🇭'), findsOneWidget);
    expect(find.text('+233'), findsOneWidget);

    await tester.enterText(phoneFields.first, '0');
    var firstPhone = tester.widget<TextFormField>(phoneFields.first);
    expect(firstPhone.controller?.text, isEmpty);

    await tester.enterText(phoneFields.first, '0301234567');
    await tester.pump();
    firstPhone = tester.widget<TextFormField>(phoneFields.first);
    expect(firstPhone.controller?.text, '30 123 4567');
    expect(find.text('Enter a valid Ghana mobile number.'), findsOneWidget);

    await tester.enterText(phoneFields.first, '0241234567');
    await tester.pump();
    firstPhone = tester.widget<TextFormField>(phoneFields.first);
    expect(firstPhone.controller?.text, '24 123 4567');
    expect(find.text('Enter a valid Ghana mobile number.'), findsNothing);
  });
}
