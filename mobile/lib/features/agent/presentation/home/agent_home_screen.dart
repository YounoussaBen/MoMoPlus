import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/data/services/backend_api_service.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_logo.dart';
import '../../../../core/ui/widgets/network_logo.dart';
import '../../../../core/ui/widgets/top_in_app_notification.dart';
import '../../../agent_profile/presentation/agent_profile_view_model.dart';
import '../../../auth/presentation/auth_view_model.dart';
import '../../../transactions/domain/physical_transaction.dart';
import '../../../transactions/presentation/transaction_view_model.dart';

const int _homePreviewLimit = 5;

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionViewModel>().loadTransactions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<TransactionViewModel>().loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = context.watch<AuthViewModel>().appUser;
    final txnVm = context.watch<TransactionViewModel>();

    if (appUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final displayName = appUser.firstName.isNotEmpty
        ? appUser.firstName
        : appUser.email.split('@').first;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        toolbarHeight: 56,
        title: const AppLogo(size: 100, useWhite: true),
        centerTitle: false,
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/bell-notification.svg',
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => _showNotifications(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Builder(
        builder: (context) {
          final activeTransactions = txnVm.transactions
              .where((t) => t.isActive)
              .toList();
          final historyTransactions = txnVm.transactions
              .where((t) => !t.isActive)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $displayName',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back to MoMo Plus',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _AvailabilityToggle(),
                ],
              ),
              const SizedBox(height: 28),
              _QuickActions(),
              const SizedBox(height: 28),
              _PendingRequests(
                transactions: activeTransactions
                    .take(_homePreviewLimit)
                    .toList(),
                totalCount: activeTransactions.length,
              ),
              const SizedBox(height: 28),
              _RecentTransactions(
                transactions: historyTransactions
                    .take(_homePreviewLimit)
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _NotificationsPage()));
  }
}

class _AvailabilityToggle extends StatelessWidget {
  const _AvailabilityToggle();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AgentProfileViewModel(ctx.read<BackendApiService>()),
      child: const _AvailabilityToggleChip(),
    );
  }
}

class _AvailabilityToggleChip extends StatefulWidget {
  const _AvailabilityToggleChip();

  @override
  State<_AvailabilityToggleChip> createState() =>
      _AvailabilityToggleChipState();
}

class _AvailabilityToggleChipState extends State<_AvailabilityToggleChip> {
  bool? _availabilityValue;
  bool _isProcessingAvailability = false;
  bool _didInitAvailability = false;

  void _initFromProfile(AgentProfileViewModel vm) {
    final profile = vm.profile;
    if (_didInitAvailability || profile == null) return;
    _didInitAvailability = true;
    _availabilityValue = profile.isAvailable;
  }

  Future<void> _handleTap() async {
    final vm = context.read<AgentProfileViewModel>();
    final currentValue = _availabilityValue ?? vm.profile?.isAvailable;
    if (currentValue == null) return;

    final nextValue = !currentValue;
    final shouldStartProcessing = !_isProcessingAvailability;

    setState(() {
      _availabilityValue = nextValue;
    });

    if (!shouldStartProcessing) return;
    await _syncAvailability();
  }

  Future<void> _syncAvailability() async {
    final vm = context.read<AgentProfileViewModel>();
    _isProcessingAvailability = true;
    try {
      while (mounted) {
        final serverValue = vm.profile?.isAvailable ?? false;
        final desiredValue = _availabilityValue ?? serverValue;

        if (serverValue == desiredValue) break;

        if (desiredValue && !vm.hasVerifiedWallet) {
          await vm.refreshWalletEligibility();
          if (!mounted) return;

          if (!vm.hasVerifiedWallet) {
            final revertedValue = vm.profile?.isAvailable ?? false;
            setState(() {
              _availabilityValue = revertedValue;
            });
            showTopInAppNotification(
              context,
              title: 'Wallet Required',
              message: vm.hasAnyWallet
                  ? 'Verify at least one mobile money wallet before making yourself available to users.'
                  : 'Add and verify a mobile money wallet before making yourself available to users.',
              type: AppNotificationType.info,
            );
            continue;
          }
        }

        if (desiredValue && !vm.hasLimitsSet) {
          final revertedValue = vm.profile?.isAvailable ?? false;
          setState(() {
            _availabilityValue = revertedValue;
          });
          showTopInAppNotification(
            context,
            title: 'Limits Required',
            message:
                'Set your minimum and maximum transaction limits before making yourself available to users.',
            type: AppNotificationType.info,
          );
          continue;
        }

        final ok = await vm.toggleAvailability();
        if (!mounted) return;

        final updatedServerValue = vm.profile?.isAvailable ?? serverValue;
        if (!ok) {
          setState(() {
            _availabilityValue = updatedServerValue;
          });
          showTopInAppNotification(
            context,
            title: 'Availability Not Updated',
            message:
                vm.errorMessage ??
                'We could not update your availability right now.',
            type: AppNotificationType.error,
          );
          break;
        }

        setState(() {
          _availabilityValue = updatedServerValue;
        });
      }
    } finally {
      _isProcessingAvailability = false;
      if (mounted) {
        setState(() {
          _availabilityValue =
              _availabilityValue ?? vm.profile?.isAvailable ?? false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentProfileViewModel>();
    _initFromProfile(vm);
    final currentValue = _availabilityValue ?? vm.profile?.isAvailable;
    if (currentValue == null) {
      return const SizedBox(width: 90, height: 36);
    }

    final isAvailable = currentValue;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAvailable
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.textSecondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAvailable
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAvailable
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isAvailable ? 'Available' : 'Offline',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAvailable
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Add Wallet',
            onTap: () => context.push('/wallet'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionTile(
            icon: Icons.tune_rounded,
            label: 'Set Limits',
            onTap: () => context.push('/agent/limits'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ActionTile(
            icon: Icons.location_on_rounded,
            label: 'My Location',
            onTap: () => context.push('/agent/service-area'),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequests extends StatelessWidget {
  final List<PhysicalTransaction> transactions;
  final int totalCount;

  const _PendingRequests({
    required this.transactions,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Requests${totalCount > 0 ? ' ($totalCount)' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/agent/transactions?tab=active'),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.swap_horiz_outlined,
                    size: 40,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No pending requests',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...transactions.map(
            (txn) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionCard(txn: txn),
            ),
          ),
      ],
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<PhysicalTransaction> transactions;

  const _RecentTransactions({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/agent/transactions?tab=history'),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...transactions.map(
            (txn) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionCard(txn: txn),
            ),
          ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final PhysicalTransaction txn;
  const _TransactionCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (txn.status) {
      'pending' => (Colors.orange, Icons.hourglass_top_rounded),
      'accepted' => (AppColors.primary, Icons.handshake_outlined),
      'completed' => (AppColors.primary, Icons.check_circle_outlined),
      'cancelled' => (AppColors.error, Icons.cancel_outlined),
      'rejected' => (AppColors.error, Icons.block_outlined),
      _ => (AppColors.textSecondary, Icons.info_outline),
    };

    return GestureDetector(
      onTap: () => context.push('/transactions/${txn.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, size: 22, color: statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${txn.typeLabel} · ${txn.userName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${txn.statusLabel} · ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      NetworkLogo(network: txn.network, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        txn.networkLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              'GHS ${txn.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    final notifications = [
      _NotificationItem(
        icon: Icons.campaign_rounded,
        title: 'Welcome Agent!',
        subtitle: 'You are now ready to receive loan requests from users.',
        time: '2h ago',
      ),
      _NotificationItem(
        icon: Icons.verified_rounded,
        title: 'Profile verified',
        subtitle: 'Your agent profile has been verified successfully.',
        time: '1d ago',
      ),
      _NotificationItem(
        icon: Icons.trending_up_rounded,
        title: 'Weekly tip',
        subtitle: 'Stay available during peak hours to get more requests.',
        time: '3d ago',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
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
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final n = notifications[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(n.icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  n.time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
