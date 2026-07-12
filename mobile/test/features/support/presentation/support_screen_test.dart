import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/theme/app_theme_extension.dart';
import 'package:momoplus/features/support/presentation/support_screen.dart';

void main() {
  testWidgets('uses dark theme surfaces and readable content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const SupportScreen()),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppTheme.dark.appColors.canvas);

    expect(find.text('Support'), findsOneWidget);
    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Live Chat'), findsOneWidget);
    expect(find.text('Resources'.toUpperCase()), findsOneWidget);

    final whiteCards = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).color == Colors.white,
        );
    expect(whiteCards, isEmpty);
  });
}
