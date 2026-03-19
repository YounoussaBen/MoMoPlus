import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/theme/app_theme.dart';

class AgentShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AgentShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          navigationShell,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: bottomPadding + 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surface.withValues(alpha: 0),
                      AppColors.surface.withValues(alpha: 0.6),
                      AppColors.surface.withValues(alpha: 0.95),
                      AppColors.surface,
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomPadding + 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      _TabItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: selectedIndex == 0,
                        onTap: () => _onTap(0),
                      ),
                      _TabItem(
                        icon: Icons.move_to_inbox_outlined,
                        activeIcon: Icons.move_to_inbox_rounded,
                        label: 'Requests',
                        isSelected: selectedIndex == 1,
                        onTap: () => _onTap(1),
                      ),
                      _TabItem(
                        icon: Icons.sync_outlined,
                        activeIcon: Icons.sync_rounded,
                        label: 'Active',
                        isSelected: selectedIndex == 2,
                        onTap: () => _onTap(2),
                      ),
                      _TabItem(
                        icon: Icons.more_vert_outlined,
                        activeIcon: Icons.more_vert_rounded,
                        label: 'More',
                        isSelected: selectedIndex == 3,
                        onTap: () => _onTap(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : Colors.white;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
