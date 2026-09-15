import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_theme_extension.dart';
import 'notifications_view_model.dart';

class NotificationBell extends StatelessWidget {
  final VoidCallback onPressed;

  const NotificationBell({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsViewModel>().unreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: Icon(
            Icons.notifications_none_rounded,
            size: 26,
            color: context.appColors.textPrimary,
          ),
          onPressed: onPressed,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: context.appColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appColors.canvas, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
