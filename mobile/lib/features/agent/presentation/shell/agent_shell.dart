import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/widgets/app_bottom_navigation.dart';

class AgentShell extends StatelessWidget {
  const AgentShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    AppNavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    AppNavigationItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      label: 'Earnings',
    ),
    AppNavigationItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Activity',
    ),
    AppNavigationItem(
      icon: Icons.menu_rounded,
      selectedIcon: Icons.menu_rounded,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppNavigationShell(navigationShell: navigationShell, items: _items);
  }
}
