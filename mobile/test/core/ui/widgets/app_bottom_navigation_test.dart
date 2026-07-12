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
                  icon: Icons.history_rounded,
                  selectedIcon: Icons.history_rounded,
                ),
                AppNavigationItem(
                  label: 'More',
                  icon: Icons.menu_rounded,
                  selectedIcon: Icons.menu_rounded,
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
    expect(
      AppTheme.light.navigationBarTheme.indicatorColor,
      Colors.transparent,
    );
    final floatingBar = tester.widget<DecoratedBox>(
      find.byKey(const Key('floating-bottom-navigation')),
    );
    final decoration = floatingBar.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(28));
    expect(decoration.boxShadow, isNotEmpty);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.backgroundColor,
      AppTheme.light.navigationBarTheme.backgroundColor,
    );
    final activityDestination = tester.widget<NavigationDestination>(
      find.byType(NavigationDestination).at(2),
    );
    expect((activityDestination.icon as Icon).icon, Icons.history_rounded);
    expect(
      (activityDestination.selectedIcon as Icon).icon,
      (activityDestination.icon as Icon).icon,
    );
    expect(tester.takeException(), isNull);
  });
}
