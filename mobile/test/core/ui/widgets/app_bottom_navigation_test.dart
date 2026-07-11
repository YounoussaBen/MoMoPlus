import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/ui/theme/app_theme.dart';
import 'package:momoplus/core/ui/widgets/app_bottom_navigation.dart';

void main() {
  testWidgets('bottom navigation remains usable on a compact phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: selectedIndex,
              items: const [
                AppNavigationItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                ),
                AppNavigationItem(
                  label: 'Discover',
                  icon: Icons.person_search_outlined,
                  selectedIcon: Icons.person_search_rounded,
                ),
                AppNavigationItem(
                  label: 'Activity',
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long_rounded,
                ),
                AppNavigationItem(
                  label: 'More',
                  icon: Icons.more_horiz_rounded,
                  selectedIcon: Icons.more_rounded,
                ),
              ],
              onSelect: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
