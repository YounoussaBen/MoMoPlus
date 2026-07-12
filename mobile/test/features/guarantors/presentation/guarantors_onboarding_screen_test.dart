import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/theme/app_theme_extension.dart';
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
    expect(find.text('Guarantor 1'), findsOneWidget);
    expect(find.text('Guarantor 2'), findsOneWidget);

    final whiteSurfaces = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).color == Colors.white,
        );
    expect(whiteSurfaces, isEmpty);
  });
}
