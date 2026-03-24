import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../loans/domain/loan.dart';
import '../../loans/presentation/loan_view_model.dart';
import '../../transactions/domain/physical_transaction.dart';
import '../../transactions/presentation/transaction_view_model.dart';

class ActivityScreen extends StatefulWidget {
  final bool isAgent;
  final int initialTabIndex;

  const ActivityScreen({
    super.key,
    required this.isAgent,
    this.initialTabIndex = 0,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanVm = context.watch<LoanViewModel>();
    final txnVm = context.watch<TransactionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Activity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: 'Get Funds (${loanVm.loans.length})'),
            Tab(text: 'Cash Services (${txnVm.transactions.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GetFundsTab(
            loans: loanVm.loans,
            isLoading: loanVm.isLoading,
            isAgent: widget.isAgent,
            onRefresh: loanVm.loadLoans,
          ),
          _CashServicesTab(
            transactions: txnVm.transactions,
            isLoading: txnVm.isLoading,
            isAgent: widget.isAgent,
            onRefresh: txnVm.loadTransactions,
          ),
        ],
      ),
    );
  }
}

// ── Get Funds Tab ───────────────────────────────────────────────────────────

class _GetFundsTab extends StatelessWidget {
  final List<Loan> loans;
  final bool isLoading;
  final bool isAgent;
  final Future<void> Function() onRefresh;

  const _GetFundsTab({
    required this.loans,
    required this.isLoading,
    required this.isAgent,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && loans.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (loans.isEmpty) {
      return _RefreshableEmptyState(
        onRefresh: onRefresh,
        icon: Icons.account_balance_wallet_outlined,
        title: 'No activity yet',
      );
    }

    // Sort: ongoing first, then by created date descending
    final sorted = List<Loan>.from(loans)
      ..sort((a, b) {
        if (a.isOngoing && !b.isOngoing) return -1;
        if (!a.isOngoing && b.isOngoing) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _LoanCard(loan: sorted[index], isAgent: isAgent),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final bool isAgent;
  const _LoanCard({required this.loan, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon) = switch (loan.status) {
      'pending' => (Colors.orange, Icons.hourglass_top_rounded),
      'approved' => (AppColors.primary, Icons.check_circle_outline),
      'disbursing' => (Colors.blue, Icons.sync_rounded),
      'active' => (AppColors.primary, Icons.account_balance_wallet_rounded),
      'repaying' => (Colors.blue, Icons.sync_rounded),
      'completed' => (AppColors.primary, Icons.check_circle_rounded),
      'defaulted' => (AppColors.error, Icons.warning_amber_rounded),
      'rejected' => (AppColors.error, Icons.block_rounded),
      'cancelled' => (AppColors.textSecondary, Icons.cancel_outlined),
      'failed' => (AppColors.error, Icons.error_outline_rounded),
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
                  Row(
                    children: [
                      Text(
                        '$displayStatus · ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      NetworkLogo(network: loan.network, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        loan.networkLabel,
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

// ── Cash Services Tab ───────────────────────────────────────────────────────

class _CashServicesTab extends StatelessWidget {
  final List<PhysicalTransaction> transactions;
  final bool isLoading;
  final bool isAgent;
  final Future<void> Function() onRefresh;

  const _CashServicesTab({
    required this.transactions,
    required this.isLoading,
    required this.isAgent,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && transactions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (transactions.isEmpty) {
      return _RefreshableEmptyState(
        onRefresh: onRefresh,
        icon: Icons.swap_horiz_outlined,
        title: 'No cash services yet',
      );
    }

    // Sort: active first, then by created date descending
    final sorted = List<PhysicalTransaction>.from(transactions)
      ..sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _TransactionCard(txn: sorted[index], isAgent: isAgent),
      ),
    );
  }
}

class _RefreshableEmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final IconData icon;
  final String title;

  const _RefreshableEmptyState({
    required this.onRefresh,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final PhysicalTransaction txn;
  final bool isAgent;
  const _TransactionCard({required this.txn, required this.isAgent});

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
