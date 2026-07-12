import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/features/agent_profile/presentation/widgets/agent_availability_pill.dart';

void main() {
  testWidgets('availability pill exposes a clear action in dark mode', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: AgentAvailabilityPill(
              isAvailable: false,
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsOneWidget);

    await tester.tap(find.text('Unavailable'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: AgentAvailabilityPill(isAvailable: true, onPressed: null),
          ),
        ),
      ),
    );

    expect(find.text('Available'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
