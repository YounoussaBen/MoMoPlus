import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/widgets/app_bottom_navigation.dart';

class UserShell extends StatelessWidget {
  const UserShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    AppNavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    AppNavigationItem(
      icon: Icons.person_search_outlined,
      selectedIcon: Icons.person_search_rounded,
      label: 'Discover',
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
