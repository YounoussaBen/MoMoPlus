import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme_extension.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onSelect,
  }) : assert(items.length >= 2);

  final int currentIndex;
  final List<AppNavigationItem> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DecoratedBox(
        key: const Key('floating-bottom-navigation'),
        decoration: BoxDecoration(
          color: colors.navigationSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? colors.surfaceInteractive
                : colors.surfaceSubtle.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            backgroundColor: colors.navigationSurface,
            selectedIndex: currentIndex,
            onDestinationSelected: onSelect,
            destinations: [
              for (final item in items)
                NavigationDestination(
                  label: item.label,
                  icon: Icon(item.icon),
                  // Selection uses color and scale only, without a circle.
                  selectedIcon: Icon(item.icon),
                  tooltip: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({
    super.key,
    required this.navigationShell,
    required this.items,
  });

  final StatefulNavigationShell navigationShell;
  final List<AppNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigationShell.currentIndex,
        items: items,
        onSelect: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
