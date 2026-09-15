import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/theme/app_theme_extension.dart';
import '../../../../core/ui/widgets/app_logo.dart';
import '../../../../core/ui/widgets/app_section.dart';
import '../../../../core/ui/widgets/network_logo.dart';
import '../../../auth/presentation/auth_view_model.dart';
import '../../../loans/domain/loan.dart';
import '../../../loans/presentation/loan_view_model.dart';
import '../../../notifications/presentation/notification_bell.dart';
import '../../../notifications/presentation/notifications_screen.dart';
import '../../../transactions/domain/physical_transaction.dart';
import '../../../transactions/presentation/transaction_view_model.dart';

const int _homePreviewLimit = 3;

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionViewModel>().loadTransactions();
      context.read<LoanViewModel>().loadLoans();
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
      context.read<LoanViewModel>().loadLoans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = context.watch<AuthViewModel>().appUser;
    final txnVm = context.watch<TransactionViewModel>();
    final loanVm = context.watch<LoanViewModel>();

    if (appUser == null) {
      return Scaffold(
        backgroundColor: context.appColors.canvas,
        body: Center(
          child: CircularProgressIndicator(
            color: context.appColors.brandAccent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final displayName = appUser.firstName.isNotEmpty
        ? appUser.firstName
        : appUser.email.split('@').first;

    final activeTransactions = txnVm.activeTransactions;

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        backgroundColor: context.appColors.canvas,
        toolbarHeight: 56,
        title: const AppLogo(size: 100),
        centerTitle: false,
        actions: [
          NotificationBell(onPressed: () => _showNotifications(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
        children: [
          const SizedBox(height: 24),
          Text(
            'Hello, $displayName',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back to MoMo Plus',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _SpotlightCard(
            ongoingLoans: loanVm.ongoingLoans,
            activeTransactions: activeTransactions,
            isAgent: false,
          ),
          const SizedBox(height: 28),
          _QuickActions(),
          const SizedBox(height: 28),
          _GetFundsSection(
            loans: loanVm.recentLoans,
            isAgent: false,
            errorMessage: loanVm.errorMessage,
            onRetry: loanVm.loadLoans,
          ),
          const SizedBox(height: 28),
          _CashServicesSection(
            transactions: txnVm.recentTransactions,
            isAgent: false,
            errorMessage: txnVm.errorMessage,
            onRetry: txnVm.loadTransactions,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }
}

// ── Spotlight Card ──────────────────────────────────────────────────────────

class _SpotlightCard extends StatefulWidget {
  final List<Loan> ongoingLoans;
  final List<PhysicalTransaction> activeTransactions;
  final bool isAgent;

  const _SpotlightCard({
    required this.ongoingLoans,
    required this.activeTransactions,
    required this.isAgent,
  });

  @override
  State<_SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends State<_SpotlightCard> {
  Timer? _timer;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> _buildCards() {
    final cards = <Widget>[];

    // Active loans with countdown
    for (final loan in widget.ongoingLoans.where(
      (l) => l.isActive || l.isRepaying,
    )) {
      cards.add(_ActiveFundsSpotlight(loan: loan, isAgent: widget.isAgent));
    }

    // Active cash service transactions
    for (final txn in widget.activeTransactions) {
      cards.add(_ActiveCashServiceSpotlight(txn: txn, isAgent: widget.isAgent));
    }

    // Pending loans
    for (final loan in widget.ongoingLoans.where(
      (l) => l.isPending || l.isApproved || l.isDisbursing,
    )) {
      cards.add(_PendingFundsSpotlight(loan: loan, isAgent: widget.isAgent));
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards();

    if (cards.isEmpty) return _EmptySpotlight();
    if (cards.length == 1) return cards.first;

    // Clamp current page if list shrinks
    if (_currentPage >= cards.length) {
      _currentPage = cards.length - 1;
    }

    return _SwipeableSpotlight(
      pageController: _pageController,
      currentPage: _currentPage,
      onPageChanged: (i) => setState(() => _currentPage = i),
      cards: cards,
    );
  }
}

class _ActiveFundsSpotlight extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _ActiveFundsSpotlight({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final remaining = loan.timeRemaining;
    final isOverdue = loan.isOverdue;

    String timeText;
    if (remaining == null || isOverdue) {
      timeText = 'Overdue';
    } else {
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      final s = remaining.inSeconds % 60;
      timeText =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return GestureDetector(
      onTap: () => context.push('/loans/${loan.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOverdue
                ? [colors.error, colors.error.withValues(alpha: 0.82)]
                : [colors.brandAccent, colors.brandStrong],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAgent ? 'Funds Sent' : 'Funds Received',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GHS ${loan.outstandingBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'outstanding balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.timer_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isOverdue ? 'Overdue' : timeText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (!isAgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Repay Now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isOverdue ? colors.error : colors.brandStrong,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCashServiceSpotlight extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;
  const _ActiveCashServiceSpotlight({required this.txn, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/transactions/${txn.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Cash Service',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
            Text(
              '${txn.typeLabel} · GHS ${txn.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                NetworkLogo(network: txn.network, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${txn.networkLabel} · ${isAgent ? txn.userName : txn.agentName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    txn.statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingFundsSpotlight extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _PendingFundsSpotlight({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final statusText = switch (loan.status) {
      'pending' => isAgent ? 'New funding request' : 'Waiting for agent',
      'approved' =>
        isAgent ? 'Ready to send funds' : 'Approved, awaiting funds',
      'disbursing' => 'Sending funds...',
      _ => loan.statusLabel,
    };

    return GestureDetector(
      onTap: () => context.push('/loans/${loan.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF57C00), Color(0xFFEF6C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Get Funds',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
            Text(
              'GHS ${loan.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySpotlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brandAccent, colors.brandStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All clear!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find an agent to get funds or initiate cash services',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeableSpotlight extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final List<Widget> cards;

  const _SwipeableSpotlight({
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxWidth * 0.5;
            return SizedBox(
              height: height.clamp(160.0, 220.0),
              child: PageView.builder(
                controller: pageController,
                itemCount: cards.length,
                onPageChanged: onPageChanged,
                itemBuilder: (_, i) => cards[i],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: currentPage == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: currentPage == i
                    ? context.appColors.brandStrong
                    : context.appColors.textMuted,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Quick Actions ───────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSection(
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Add Wallet',
              onTap: () => context.push('/wallet'),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _ActionTile(
              icon: Icons.person_search_rounded,
              label: 'Find Agent',
              onTap: () => context.go('/user/discover'),
            ),
          ),
        ],
      ),
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
          color: context.appColors.surfaceInteractive,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appColors.brandSoft,
              ),
              child: Icon(icon, color: context.appColors.brandStrong, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Get Funds Section ───────────────────────────────────────────────────────

class _GetFundsSection extends StatelessWidget {
  final List<Loan> loans;
  final bool isAgent;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  const _GetFundsSection({
    required this.loans,
    required this.isAgent,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final basePath = isAgent ? '/agent' : '/user';
    return AppSection(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Get Funds${loans.isNotEmpty ? ' (${loans.length})' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('$basePath/activity?tab=getFunds'),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.brandStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loans.isEmpty && errorMessage != null)
            _ActivityErrorSection(message: errorMessage!, onRetry: onRetry)
          else if (loans.isEmpty)
            _EmptySection(
              icon: Icons.account_balance_wallet_outlined,
              message: 'No activity yet',
            )
          else
            ...loans
                .take(_homePreviewLimit)
                .map(
                  (loan) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompactLoanCard(loan: loan),
                  ),
                ),
        ],
      ),
    );
  }
}

class _CompactLoanCard extends StatelessWidget {
  final Loan loan;
  const _CompactLoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (loan.status) {
      'pending' => (context.appColors.warning, Icons.hourglass_top_rounded),
      'approved' => (context.appColors.success, Icons.check_circle_outline),
      'disbursing' => (context.appColors.info, Icons.sync_rounded),
      'active' => (
        context.appColors.brandStrong,
        Icons.account_balance_wallet_rounded,
      ),
      'repaying' => (context.appColors.info, Icons.sync_rounded),
      _ => (context.appColors.textSecondary, Icons.info_outline),
    };

    final displayStatus = loan.isActive && loan.isOverdue
        ? 'Overdue'
        : loan.status == 'disbursing'
        ? 'Sending Funds'
        : loan.statusLabel;

    return GestureDetector(
      onTap: () => context.push('/loans/${loan.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surfaceInteractive,
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
                    displayStatus,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loan.networkLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'GHS ${loan.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cash Services Section ───────────────────────────────────────────────────

class _CashServicesSection extends StatelessWidget {
  final List<PhysicalTransaction> transactions;
  final bool isAgent;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  const _CashServicesSection({
    required this.transactions,
    required this.isAgent,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final basePath = isAgent ? '/agent' : '/user';
    return AppSection(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cash Services${transactions.isNotEmpty ? ' (${transactions.length})' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('$basePath/activity?tab=cashServices'),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.brandStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty && errorMessage != null)
            _ActivityErrorSection(message: errorMessage!, onRetry: onRetry)
          else if (transactions.isEmpty)
            _EmptySection(
              icon: Icons.swap_horiz_outlined,
              message: 'No cash services yet',
            )
          else
            ...transactions
                .take(_homePreviewLimit)
                .map(
                  (txn) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompactTransactionCard(txn: txn),
                  ),
                ),
        ],
      ),
    );
  }
}

class _CompactTransactionCard extends StatelessWidget {
  final PhysicalTransaction txn;
  const _CompactTransactionCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (txn.status) {
      'pending' => (context.appColors.warning, Icons.hourglass_top_rounded),
      'accepted' => (context.appColors.brandStrong, Icons.handshake_outlined),
      'completed' => (context.appColors.success, Icons.check_circle_outlined),
      'cancelled' => (context.appColors.error, Icons.cancel_outlined),
      'rejected' => (context.appColors.error, Icons.block_outlined),
      _ => (context.appColors.textSecondary, Icons.info_outline),
    };

    return GestureDetector(
      onTap: () => context.push('/transactions/${txn.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surfaceInteractive,
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
                    txn.typeLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${txn.statusLabel} · ${txn.networkLabel}',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              'GHS ${txn.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared ──────────────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: context.appColors.textMuted),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityErrorSection extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ActivityErrorSection({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appColors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.appColors.error),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appColors.error, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
