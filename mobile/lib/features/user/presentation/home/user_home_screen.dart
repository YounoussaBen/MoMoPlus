import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/theme/app_theme.dart';
import '../../../../core/ui/widgets/app_logo.dart';
import '../../../../core/ui/widgets/network_logo.dart';
import '../../../auth/presentation/auth_view_model.dart';
import '../../../loans/domain/loan.dart';
import '../../../loans/presentation/loan_view_model.dart';
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

    final activeTransactions = txnVm.transactions
        .where((t) => t.isActive)
        .toList();

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
          _GetFundsSection(loans: loanVm.ongoingLoans, isAgent: false),
          const SizedBox(height: 28),
          _CashServicesSection(
            transactions: activeTransactions,
            isAgent: false,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _NotificationsPage()));
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
                ? [AppColors.error, const Color(0xFFD32F2F)]
                : [AppColors.primary, const Color(0xFF4AA025)],
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
                        color: isOverdue ? AppColors.error : AppColors.primary,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF4AA025)],
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
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.25),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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

// ── Get Funds Section ───────────────────────────────────────────────────────

class _GetFundsSection extends StatelessWidget {
  final List<Loan> loans;
  final bool isAgent;

  const _GetFundsSection({required this.loans, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final basePath = isAgent ? '/agent' : '/user';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Get Funds${loans.isNotEmpty ? ' (${loans.length})' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('$basePath/activity?tab=getFunds'),
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
        if (loans.isEmpty)
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
                  child: _CompactLoanCard(loan: loan, isAgent: isAgent),
                ),
              ),
      ],
    );
  }
}

class _CompactLoanCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _CompactLoanCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (loan.status) {
      'pending' => (Colors.orange, Icons.hourglass_top_rounded),
      'approved' => (AppColors.primary, Icons.check_circle_outline),
      'disbursing' => (Colors.blue, Icons.sync_rounded),
      'active' => (AppColors.primary, Icons.account_balance_wallet_rounded),
      'repaying' => (Colors.blue, Icons.sync_rounded),
      _ => (AppColors.textSecondary, Icons.info_outline),
    };

    final displayStatus = loan.status == 'disbursing'
        ? 'Sending Funds'
        : loan.statusLabel;

    return GestureDetector(
      onTap: () => context.push('/loans/${loan.id}'),
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
                    isAgent ? loan.borrowerName : loan.agentName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$displayStatus · ${loan.networkLabel}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GHS ${loan.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (loan.isActive && loan.isOverdue)
                  const Text(
                    'OVERDUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
              ],
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

// ── Cash Services Section ───────────────────────────────────────────────────

class _CashServicesSection extends StatelessWidget {
  final List<PhysicalTransaction> transactions;
  final bool isAgent;

  const _CashServicesSection({
    required this.transactions,
    required this.isAgent,
  });

  @override
  Widget build(BuildContext context) {
    final basePath = isAgent ? '/agent' : '/user';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cash Services${transactions.isNotEmpty ? ' (${transactions.length})' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('$basePath/activity?tab=cashServices'),
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
          _EmptySection(
            icon: Icons.swap_horiz_outlined,
            message: 'No active cash services',
          )
        else
          ...transactions
              .take(_homePreviewLimit)
              .map(
                (txn) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CompactTransactionCard(txn: txn, isAgent: isAgent),
                ),
              ),
      ],
    );
  }
}

class _CompactTransactionCard extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;
  const _CompactTransactionCard({required this.txn, required this.isAgent});

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
                    '${txn.typeLabel} · ${isAgent ? txn.userName : txn.agentName}',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
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
        title: 'Welcome to MoMo Plus!',
        subtitle:
            'Get started by getting your first funds or finding an agent near you.',
        time: '2h ago',
      ),
      _NotificationItem(
        icon: Icons.verified_rounded,
        title: 'Complete your profile',
        subtitle: 'Add your details to unlock all features.',
        time: '1d ago',
      ),
      _NotificationItem(
        icon: Icons.local_offer_rounded,
        title: 'Special offer',
        subtitle: 'Low rates available for first-time users.',
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
