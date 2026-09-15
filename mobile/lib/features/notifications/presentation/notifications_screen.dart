import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_theme_extension.dart';
import '../domain/app_notification.dart';
import 'notifications_view_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsViewModel>().load();
    });
  }

  Future<void> _openNotification(AppNotification notification) async {
    final viewModel = context.read<NotificationsViewModel>();
    if (!notification.isRead) {
      await viewModel.setReadState(notification.id, isRead: true);
    }
    if (!mounted) return;
    if (notification.resourceType == 'loan' &&
        notification.resourceId.isNotEmpty) {
      context.push('/loans/${notification.resourceId}');
    } else if (notification.resourceType == 'transaction' &&
        notification.resourceId.isNotEmpty) {
      context.push('/transactions/${notification.resourceId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<NotificationsViewModel>();
    final notifications = viewModel.notifications;

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        backgroundColor: context.appColors.canvas,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: viewModel.unreadCount == 0 || viewModel.isUpdating
                ? null
                : viewModel.markAllAsRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        color: context.appColors.brandStrong,
        child: viewModel.isLoading && notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.appColors.brandAccent,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ],
              )
            : viewModel.errorMessage != null && notifications.isEmpty
            ? _MessageState(
                icon: Icons.cloud_off_outlined,
                message: viewModel.errorMessage!,
                actionLabel: 'Try again',
                onAction: viewModel.load,
              )
            : notifications.isEmpty
            ? const _MessageState(
                icon: Icons.notifications_none_rounded,
                message: 'You have no notifications yet.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationCard(
                    notification: notification,
                    onTap: () => _openNotification(notification),
                    onToggleRead: () =>
                        context.read<NotificationsViewModel>().setReadState(
                          notification.id,
                          isRead: !notification.isRead,
                        ),
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onToggleRead;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final icon = switch (notification.kind) {
      'loan_request' => Icons.account_balance_wallet_outlined,
      'loan_status' => Icons.account_balance_wallet_rounded,
      'transaction_request' => Icons.swap_horiz_rounded,
      'transaction_status' => Icons.check_circle_outline_rounded,
      _ => Icons.notifications_none_rounded,
    };

    return Material(
      color: unread
          ? context.appColors.brandSoft.withValues(alpha: 0.55)
          : context.appColors.surfaceSection,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appColors.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: context.appColors.brandStrong,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: context.appColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: unread ? 'Mark as read' : 'Mark as unread',
                onPressed: onToggleRead,
                icon: Icon(
                  unread
                      ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                  size: 20,
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 42, color: context.appColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 10),
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);
  if (difference.isNegative || difference.inMinutes < 1) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';
  final weeks = difference.inDays ~/ 7;
  if (weeks < 5) return '${weeks}w';
  return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}
